#!/usr/bin/env bash
# Print the latest stable Linux x86_64 AppImage release as FlatPark update JSON.
set -euo pipefail

repo="getopenscreen/openscreen"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

curl_args=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
    curl_args+=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi
release="$(curl -fsSL "${curl_args[@]}" "https://api.github.com/repos/$repo/releases/latest")"
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$release")"
date="$(jq -r '.published_at | split("T")[0]' <<<"$release")"
asset="Openscreen-Linux-${version}.AppImage"
url="$(jq -r --arg name "$asset" '.assets[] | select(.name == $name) | .browser_download_url' <<<"$release" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] \
    || { echo "failed to resolve the stable OpenScreen AppImage" >&2; exit 1; }
echo "resolved OpenScreen $version ($date): $url" >&2

jq -n --arg version "$version" --arg date "$date" --arg url "$url" \
    '{version:$version,releaseDate:$date,sources:[{filename:"openscreen.AppImage",url:$url}]}'
