#!/usr/bin/env bash
# Update resolver for Music Generator (Vulkan/CPU).
#
# The same GitHub release also ships a CUDA AppImage, plus Windows and macOS.
# Take only Music-Generator-<version>-linux-x64.AppImage, not the -cuda file,
# from releases/latest. The daily-*/develop-* builds are prereleases, which
# /releases/latest skips; every stable release carries the AppImage, so a
# missing one fails instead of settling on an older release.
# Prints JSON on stdout:
#   { "version": "0.2.0", "releaseDate": "YYYY-MM-DD", "releaseUrl": "...",
#     "sources": [ { "filename": "music-generator.AppImage", "arch": "x86_64", "url": "..." } ] }
set -euo pipefail

repo="rabbitfiremediacreation/music-generator-desktop"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases/latest")"

tag="$(jq -r '.tag_name' <<<"$rel")"
[[ "$tag" =~ ^v[0-9]+(\.[0-9]+)*$ ]] || { echo "unexpected Music Generator tag: $tag" >&2; exit 1; }
date="$(jq -r '.published_at // empty' <<<"$rel" | cut -c1-10)"
release_url="$(jq -r '.html_url // empty' <<<"$rel")"
read -r version url < <(jq -r '
  [ .assets[] | select(.name | test("^Music-Generator-[0-9][0-9.]*-linux-x64\\.AppImage$")) ]
  | if length == 1 then .[0] else empty end
  | "\(.name | capture("^Music-Generator-(?<v>[0-9][0-9.]*)-linux-x64\\.AppImage$").v) \(.browser_download_url)"
' <<<"$rel") || true

[ -n "${version:-}" ] && [ -n "${url:-}" ] || { echo "failed to resolve Music Generator release" >&2; exit 1; }
echo "resolved Music Generator $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg r "$release_url" --arg u "$url" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[
     {filename:"music-generator.AppImage", arch:"x86_64", url:$u}
   ]}'
