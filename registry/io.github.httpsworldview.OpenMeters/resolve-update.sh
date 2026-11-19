#!/usr/bin/env bash
# Update resolver for OpenMeters.
#
# Each GitHub release ships an RPM, a .deb and one tarball. Take only
# openmeters-<version>-x86_64-linux-gnu.tar.xz, the relocatable Linux build.
# Packaging revisions use a tag like v1.15.2-2 but keep the base version in the
# tarball name, so both the tag and the asset are resolved from the base.
# Prints JSON on stdout:
#   { "version": "1.18.0", "releaseDate": "YYYY-MM-DD", "releaseUrl": "...",
#     "sources": [ { "filename": "openmeters.tar.xz", "arch": "x86_64", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting.
set -euo pipefail

repo="httpsworldview/openmeters"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# Highest version among recent stable releases, not the newest by date and not
# releases/latest: a patch to an older line published later would otherwise
# downgrade the pin. The trailing -N is a packaging revision, ordered after the
# plain release it revises.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases?per_page=30" | jq '
  def base: .tag_name | ltrimstr("v") | sub("-[0-9]+$"; "");
  def revision: .tag_name | ltrimstr("v")
    | if test("-[0-9]+$") then (split("-") | last | tonumber) else 0 end;
  def version: base | split(".") | map(tonumber);
  [ .[] | select((.draft or .prerelease) | not)
        | select(.tag_name | test("^v?[0-9]+(\\.[0-9]+)*(-[0-9]+)?$")) ]
  | sort_by([ version, revision ]) | last')"

version="$(jq -r '.tag_name | ltrimstr("v") | sub("-[0-9]+$"; "")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
release_url="$(jq -r '.html_url' <<<"$rel")"

# Exact asset name: excludes the .deb, .rpm and SHA256SUMS.
url="$(jq -r --arg n "openmeters-$version-x86_64-linux-gnu.tar.xz" \
  '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || {
  echo "failed to resolve OpenMeters release" >&2
  exit 1
}
echo "resolved OpenMeters $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg r "$release_url" --arg u "$url" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[
     {filename:"openmeters.tar.xz", arch:"x86_64", url:$u}
   ]}'
