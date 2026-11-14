#!/usr/bin/env bash
# Update resolver for BenchUp.
#
# The same GitHub release also ships a Velopack nupkg that only wraps this
# AppImage, plus Windows, macOS and a browser build. Take the AppImage.
# Among the releases that have it, pick the highest version number, not the
# newest publish date. Older releases named the file after Ketchup; those
# are not this asset.
# Prints JSON on stdout:
#   { "version": "0.6.7", "releaseDate": "YYYY-MM-DD", "releaseUrl": "...",
#     "sources": [ { "filename": "benchup.AppImage", "arch": "x86_64", "url": "..." } ] }
set -euo pipefail

repo="BenchUp3D/benchup"
asset="io.github.BenchUp3D.BenchUp-linux-x64.AppImage"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

best="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases?per_page=30" | jq --arg asset "$asset" '
  [ .[] | select((.draft or .prerelease) | not)
        | select(.tag_name | test("^v[0-9]+(\\.[0-9]+)*$"))
        | select(any(.assets[]; .name == $asset))
        | { published: .published_at,
            html: .html_url,
            ver: (.tag_name | ltrimstr("v")),
            url: (.assets[] | select(.name == $asset) | .browser_download_url) } ]
  | max_by(.ver | split(".") | map(tonumber))')"

version="$(jq -r '.ver // empty' <<<"$best")"
date="$(jq -r '.published // empty' <<<"$best" | cut -c1-10)"
release_url="$(jq -r '.html // empty' <<<"$best")"
url="$(jq -r '.url // empty' <<<"$best")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve BenchUp release" >&2; exit 1; }
echo "resolved BenchUp $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg r "$release_url" --arg u "$url" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[
     {filename:"benchup.AppImage", arch:"x86_64", url:$u}
   ]}'
