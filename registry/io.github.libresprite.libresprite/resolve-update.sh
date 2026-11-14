#!/usr/bin/env bash
# Update resolver for LibreSprite: the latest GitHub release and its AppImage.
# Prints { "version", "releaseDate", "sources": [...] } on stdout; logs go to
# stderr. FlatPark downloads the URL and computes the sha256/size itself.
set -euo pipefail

repo="LibreSprite/LibreSprite"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | sub("^v";"")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Anchored on both ends, with the arch: upstream also attaches Windows and
# macOS builds (and source archives) to the same release.
url="$(jq -r '.assets[] | select(.name | test("^libresprite-.*-linux-x86_64\\.AppImage$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve libresprite release" >&2; exit 1; }
echo "resolved libresprite $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"libresprite.AppImage", url:$u}]}'
