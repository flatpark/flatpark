#!/usr/bin/env bash
set -euo pipefail
repo=artcraft-android/procraft
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} "https://api.github.com/repos/$repo/releases/latest")"
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at[:10]' <<<"$rel")"
url_x="$(jq -r --arg n "procraft-$version-linux-x86_64.tar.gz" '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel")"
url_a="$(jq -r --arg n "procraft-$version-linux-aarch64.tar.gz" '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel")"
[ -n "$version" ] && [ -n "$date" ] && [ -n "$url_x" ] && [ -n "$url_a" ] || { echo "failed to resolve ProCraft release" >&2; exit 1; }
jq -n --arg v "$version" --arg d "$date" --arg x "$url_x" --arg a "$url_a" '{version:$v, releaseDate:$d, sources:[{filename:"procraft.tar.gz",arch:"x86_64",url:$x},{filename:"procraft.tar.gz",arch:"aarch64",url:$a}]}'
