#!/usr/bin/env bash
# Update resolver for Music Generator (Vulkan/CPU).
#
# The same GitHub release also ships a CUDA AppImage, plus Windows and macOS.
# Take only Music-Generator_<version>_linux-x64.AppImage, not the -cuda file.
# Among the releases that have it, pick the highest version number, not the
# newest publish date.
# Prints JSON on stdout:
#   { "version": "0.2.0", "releaseDate": "YYYY-MM-DD", "releaseUrl": "...",
#     "sources": [ { "filename": "music-generator.AppImage", "arch": "x86_64", "url": "..." } ] }
set -euo pipefail

repo="rabbitfiremediacreation/music-generator-desktop"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

best="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases?per_page=30" | jq '
  [ .[] | select((.draft or .prerelease) | not)
        | select(.tag_name | test("^v[0-9]+(\\.[0-9]+)*$"))
        | . as $r
        | .assets[]
        | select(.name | test("^Music-Generator-[0-9][0-9.]*-linux-x64\\.AppImage$"))
        | { published: $r.published_at,
            html: $r.html_url,
            url: .browser_download_url,
            ver: (.name | capture("^Music-Generator-(?<v>[0-9][0-9.]*)-linux-x64\\.AppImage$").v) } ]
  | max_by(.ver | split(".") | map(tonumber))')"

version="$(jq -r '.ver // empty' <<<"$best")"
date="$(jq -r '.published // empty' <<<"$best" | cut -c1-10)"
release_url="$(jq -r '.html // empty' <<<"$best")"
url="$(jq -r '.url // empty' <<<"$best")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve Music Generator release" >&2; exit 1; }
echo "resolved Music Generator $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg r "$release_url" --arg u "$url" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[
     {filename:"music-generator.AppImage", arch:"x86_64", url:$u}
   ]}'
