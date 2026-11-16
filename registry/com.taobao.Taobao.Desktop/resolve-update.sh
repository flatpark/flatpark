#!/usr/bin/env bash
set -euo pipefail
repo=jiesou/taobao-linux-release
rel=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest")
tag=$(jq -r '.tag_name' <<<"$rel")
version=${tag#taobao-}
date=$(jq -r '.published_at' <<<"$rel" | cut -c1-10)
url=$(jq -r '.assets[] | select(.name | endswith("-x86_64.tar.zst")) | .browser_download_url' <<<"$rel" | head -n1)
[ -n "$version" ] && [ -n "$url" ] || { echo 'latest payload release not found' >&2; exit 1; }
jq -cn --arg version "$version" --arg date "$date" --arg url "$url" \
  '{version: $version, releaseDate: $date, sources: [{filename: "taobao-linux.tar.zst", arch: "x86_64", url: $url}]}'
