#!/usr/bin/env bash
# Update resolver for SculptForge.
#
# The same GitHub release also ships installers, an AppImage, a single-file
# Flatpak, VFX-platform tarballs, and macOS and Windows archives. Take only
# SculptForge-<version>-linux-x86_64.tar.gz.
# Prints JSON on stdout:
#   { "version": "0.10.1", "releaseDate": "YYYY-MM-DD", "releaseUrl": "...",
#     "sources": [ { "filename": "sculptforge.tar.gz", "arch": "x86_64", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting.
set -euo pipefail

repo="islandmed/SculptForge"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# Highest version among recent stable releases, not the newest by date and not
# releases/latest: a new release becomes "latest" by default, so a patch to an
# older line published later would otherwise downgrade the pin.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases?per_page=30" | jq '
  [ .[] | select((.draft or .prerelease) | not)
        | select(.tag_name | test("^v?[0-9]+(\\.[0-9]+)*$")) ]
  | max_by(.tag_name | ltrimstr("v") | split(".") | map(tonumber))')"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
release_url="$(jq -r '.html_url' <<<"$rel")"

# SculptForge-<ver>-linux-x86_64.tar.gz exactly: excludes the -vfx* tarballs and
# the unversioned aliases.
url="$(jq -r --arg n "SculptForge-$version-linux-x86_64.tar.gz" \
  '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve SculptForge release" >&2; exit 1; }
echo "resolved SculptForge $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg r "$release_url" --arg u "$url" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[
     {filename:"sculptforge.tar.gz", arch:"x86_64", url:$u}
   ]}'
