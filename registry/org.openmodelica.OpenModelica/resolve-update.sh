#!/usr/bin/env bash
# The release bundle combines official OpenModelica binaries with Qt WebEngine
# and runtime dependencies. Rebuild suffixes track dependency/security updates.
set -euo pipefail
repo="rhgKc2yp/OMEdit-release"
need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
    "https://api.github.com/repos/$repo/releases/latest")"
version="$(jq -er '.tag_name | ltrimstr("v")' <<<"$release")"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-r[0-9a-f]{16}$ ]] || { echo "unexpected bundle version: $version" >&2; exit 1; }
asset="$(jq -ce --arg n "omedit-$version-x86_64.tar.gz" \
    '[.assets[] | select(.name == $n)] | if length == 1 then .[0] else error("expected exactly one x86_64 bundle") end' <<<"$release")"
url="$(jq -er .browser_download_url <<<"$asset")"
size="$(jq -er '.size | select(. > 0)' <<<"$asset")"
date="$(jq -er '.published_at | split("T")[0]' <<<"$release")"
release_url="$(jq -er .html_url <<<"$release")"
echo "resolved OMEdit bundle $version ($date): $url" >&2
jq -n --arg v "$version" --arg d "$date" --arg r "$release_url" --arg u "$url" --argjson s "$size" \
    '{version:$v,releaseDate:$d,releaseUrl:$r,sources:[{filename:"omedit.tar.gz",url:$u,size:$s}]}'
