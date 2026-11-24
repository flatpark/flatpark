#!/usr/bin/env bash
# Update resolver for Software (gnome-software-next).
#
# Prints the newest build as JSON on stdout:
#   { "version": "51.1.818.ga2d879480", "releaseDate": "YYYY-MM-DD",
#     "releaseUrl": "...", "releaseNotes": "<p>...</p><ul>...</ul>",
#     "sources": [ { "filename": "app.tar.xz", "url": "..." } ] }
# The notes list the changes since the build pinned in org.gnome.Software.yml,
# from the commits between the two; releaseUrl is that comparison on GitLab.
# Logs go to stderr. No hashing: FlatPark downloads the URL and pins it.
#
# The project releases on GitLab (gitlab.gnome.org) into its generic package
# registry, one package version per build, with the tarball
# gnome-software-next-<version>-x86_64.tar.xz; the API needs no token.
set -euo pipefail

api="https://gitlab.gnome.org/api/v4/projects/user_c1a5830a%2Fgnome-software-next"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

pkg="$(curl -fsSL "$api/packages?package_type=generic&package_name=gnome-software-next&order_by=created_at&sort=desc&per_page=1" | jq -c 'first // empty')"
[ -n "$pkg" ] || { echo "no gnome-software-next package in the registry" >&2; exit 1; }

version="$(jq -r '.version' <<<"$pkg")"
date="$(jq -r '.created_at' <<<"$pkg" | cut -c1-10)"
file="gnome-software-next-$version-x86_64.tar.xz"
url="$api/packages/generic/gnome-software-next/$version/$file"

curl -fsSIL -o /dev/null "$url" || { echo "missing $url" >&2; exit 1; }
echo "resolved gnome-software-next $version ($date): $url" >&2

# Release notes: the fork's changes between the pinned build and this one.
# Each package is one CI build of the fork's next branch, named by its
# commit. An upstream release comes in as a "Merge upstream X.Y" commit: it
# becomes one "Includes GNOME Software X.Y" line, listed first, and the
# commits that only its upstream side brings in are left out. So are the
# other merges, and the commits that change only the CI, the docs, the
# tests or translations. Any failure here only drops the notes.
project="https://gitlab.gnome.org/user_c1a5830a/gnome-software-next"
here="$(cd "$(dirname "$0")" && pwd)"
new_sha="$(jq -r '.pipeline.sha // empty' <<<"$pkg")"
old_version="$(sed -n 's#.*/packages/generic/gnome-software-next/\([^/]*\)/.*#\1#p' "$here/org.gnome.Software.yml" 2>/dev/null | head -1 || true)"
old_sha="${old_version##*.g}"
notes=""
release_url=""
if [[ "$new_sha" =~ ^[0-9a-f]{40}$ && "$old_sha" =~ ^[0-9a-f]{7,40}$ && "$old_version" != "$version" ]]; then
  if compare="$(curl -fsSL "$api/repository/compare?from=$old_sha&to=$new_sha&straight=true")"; then
    release_url="$project/-/compare/$old_sha...${new_sha:0:9}"
    # The commits each upstream release brings in: those its merge's second
    # parent (upstream's tag) has and its first parent doesn't. The commits
    # API lists them without the diff the compare API would add (a whole
    # major release), 100 a page.
    upstream_ids="[]"
    while read -r first second; do
      [[ "$first" =~ ^[0-9a-f]{40}$ && "$second" =~ ^[0-9a-f]{40}$ ]] || { upstream_ids=""; break; }
      for (( page = 1; page <= 50; page++ )); do
        ids="$(curl -fsSL "$api/repository/commits?ref_name=$first..$second&per_page=100&page=$page" | jq -c '[.[].id]')" \
          || { upstream_ids=""; break 2; }
        upstream_ids="$(jq -cn --argjson a "$upstream_ids" --argjson b "$ids" '$a + $b')"
        [ "$(jq length <<<"$ids")" -eq 100 ] || break
      done
    done < <(jq -r '.commits[]
      | select((.parent_ids | length) > 1 and (.title | test("^Merge upstream [0-9]+[.][0-9]+$")))
      | "\(.parent_ids[0]) \(.parent_ids[1])"' <<<"$compare")
    if [ -n "$upstream_ids" ]; then
      notes="$(jq -r --argjson upstream "$upstream_ids" '
        def esc: gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;");
        ($upstream | map({key: ., value: true}) | from_entries) as $up
        | [ .commits[] | select((.parent_ids | length) > 1)
            | .title | capture("^Merge upstream (?<tag>[0-9]+[.][0-9]+)$")?
            | "Includes GNOME Software \(.tag)" ] as $releases
        | [ .commits[] | select((.parent_ids | length) == 1 and ($up[.id] | not))
            | .title
            | select((test("^(ci|doc|docs|tests?|flows?|po|help|upstream-sync|README|AGENTS|CHANGES[A-Z-]*)(:| )"; "i")
                      or test("translation"; "i")) | not) ] as $changes
        | ($releases + $changes) as $items
        | if ($items | length) == 0 then
            "<p>Changes to the build, tests and documentation only.</p>"
          else
            "<p>Changes since the last build:</p>\n<ul>\n"
            + ([ $items[:10][] | "  <li>" + esc + "</li>" ] | join("\n"))
            + "\n</ul>"
            + (if ($items | length) > 10 then "\n<p>And \($items | length - 10) more.</p>" else "" end)
          end' <<<"$compare")" || notes=""
    else
      echo "upstream release commits unavailable; no release notes" >&2
    fi
  else
    echo "compare $old_sha..$new_sha failed; no release notes" >&2
  fi
fi

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg r "$release_url" --arg n "$notes" \
  '{version:$v, releaseDate:$d, sources:[{filename:"app.tar.xz", url:$u}]}
   + (if $r != "" then {releaseUrl:$r} else {} end)
   + (if $n != "" then {releaseNotes:$n} else {} end)'
