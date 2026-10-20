#!/usr/bin/env bash
# Update resolver for ElyTree.
#
# Ely Office releases on GitHub (ELY-Open-Source/ElyOffice; it moved there from
# the developer's own Forgejo in 2026-10). One release carries every app of the
# suite; each app's Linux x86_64 build is the single
# `ely-tree_<version>-<revision>_amd64.deb` asset.
#
# Not every release carries Linux builds (v0.1.1 and v0.1.2 carry no assets;
# v0.1.7 never reached GitHub), so this walks the newest releases and takes
# the first one that has this app's .deb, rather than trusting the latest
# release.
#
# Prints JSON on stdout, logs on stderr; no hashing, no file writes.
set -euo pipefail

api="https://api.github.com/repos/ELY-Open-Source/ElyOffice/releases?per_page=20"
slug="ely-tree"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rels="$(curl -fsSL --retry 3 --max-time 60 ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} "$api")"

out="$(jq -c --arg slug "$slug" '
  [ .[] | select((.draft | not) and (.prerelease | not))
        | . as $r
        | ($r.assets[]
           | select(.name | test("^" + $slug + "_[0-9][0-9A-Za-z.+~]*-[0-9]+_amd64\\.deb$"))
           | {rel: $r, asset: .}) ]
  | first // empty' <<<"$rels")"

[ -n "$out" ] || { echo "no release with ${slug}_*_amd64.deb" >&2; exit 1; }

tag="$(jq -r '.rel.tag_name | ltrimstr("v")' <<<"$out")"
name="$(jq -r '.asset.name' <<<"$out")"
# The .deb revision (-1) is normally the same for every release; a re-cut of
# the same version under -2 must still count as a new version.
rev="$(sed -E 's/^.*-([0-9]+)_amd64\.deb$/\1/' <<<"$name")"
version="$tag"
[ "$rev" = 1 ] || version="$tag-$rev"

echo "resolved $slug $version: $name" >&2
jq --arg v "$version" '{
  version: $v,
  releaseDate: (.rel.published_at | .[0:10]),
  releaseUrl: .rel.html_url,
  sources: [{filename: "ely-tree.deb", url: .asset.browser_download_url, size: .asset.size}]
}' <<<"$out"
