#!/usr/bin/env bash
set -euo pipefail
release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} https://api.github.com/repos/spalencsar/bearwave/releases/latest)"
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$release")"
date="$(jq -r '.published_at' <<<"$release" | cut -c1-10)"
name="bearwave-$version-linux-x86_64.tar.xz"
url="$(jq -r --arg n "$name" '.assets[] | select(.name == $n) | .browser_download_url' <<<"$release")"
[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve BearWave release" >&2; exit 1; }
jq -n --arg version "$version" --arg releaseDate "$date" --arg url "$url" '{version:$version,releaseDate:$releaseDate,sources:[{filename:"bearwave.tar.xz",arch:"x86_64",url:$url}]}'
