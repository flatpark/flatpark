#!/usr/bin/env bash
# Update resolver for paint.js.
#
# Prints the current version + the Linux x86_64 AppImage as JSON on stdout.
# Logs go to stderr. No hashing, no manifest rewriting: FlatPark downloads the
# URL and computes the extra-data sha256/size itself.
set -euo pipefail

repo="LabyStudio/paintdotjs"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# releases/latest excludes prereleases and drafts.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Exactly paintdotjs-<ver>-linux-x86_64.AppImage: not the .flatpak bundle of
# the same build, nor the macOS files.
url="$(jq -r --arg n "paintdotjs-$version-linux-x86_64.AppImage" \
  '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve paint.js release" >&2; exit 1; }
echo "resolved paint.js $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"paintdotjs.AppImage", url:$u}]}'
