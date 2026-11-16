#!/usr/bin/env bash
set -euo pipefail
repo=jiesou/taobao-linux-release
rel=$(curl -fsSL "https://api.github.com/repos/$repo/releases/tags/taobao-3.0.1")
url=$(jq -r '.assets[] | select(.name | endswith("-x86_64.tar.zst")) | .browser_download_url' <<<"$rel")
date=$(jq -r '.published_at' <<<"$rel" | cut -c1-10)
[ -n "$url" ] || { echo 'payload asset not found' >&2; exit 1; }
printf '{"version":"3.0.1","releaseDate":"%s","sources":[{"filename":"taobao-linux.tar.zst","arch":"x86_64","url":"%s"}]}\n' "$date" "$url"
