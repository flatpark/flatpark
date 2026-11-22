#!/usr/bin/env bash
set -euo pipefail
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} https://api.github.com/repos/shadstoneofficial/bob-wallet/releases/latest)"
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at[:10]' <<<"$rel")"
url="$(jq -r --arg name "Bob.LearnHNS-${version}.AppImage" '[.assets[] | select(.name == $name) | .browser_download_url] | if length == 1 then .[0] else empty end' <<<"$rel")"
[ -n "$version" ] && [ "$version" != null ] && [ -n "$url" ] || { echo 'failed to resolve Bob LearnHNS release' >&2; exit 1; }
jq -n --arg v "$version" --arg d "$date" --arg u "$url" '{version:$v, releaseDate:$d, sources:[{filename:"bob.AppImage", url:$u}]}'
