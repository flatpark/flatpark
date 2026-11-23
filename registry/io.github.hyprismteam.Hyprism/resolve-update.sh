#!/usr/bin/env bash
set -euo pipefail
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} https://api.github.com/repos/hyprismteam/Hyprism/releases/latest)"
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at[:10]' <<<"$rel")"
url="$(jq -r --arg name "Hyprism-linux-x64-${version}.tar.xz" '.assets[] | select(.name == $name) | .browser_download_url' <<<"$rel")"
[ -n "$version" ] && [ -n "$url" ] || { echo 'Hyprism release asset not found' >&2; exit 1; }
jq -n --arg v "$version" --arg d "$date" --arg u "$url" '{version:$v, releaseDate:$d, sources:[{filename:"hyprism.tar.xz",url:$u}]}'
