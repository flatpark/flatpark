#!/usr/bin/env bash
set -euo pipefail
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} https://api.github.com/repos/ImageMagick/ImageMagick/releases/latest)"
version="$(jq -r '.tag_name' <<<"$rel")"
date="$(jq -r '.published_at[:10]' <<<"$rel")"
url="$(jq -r --arg v "$version" '[.assets[] | select(.name == ("ImageMagick-" + $v + "-portable-Q16-HDRI-linux-x64.tar.xz")) | .browser_download_url] | first // empty' <<<"$rel")"
[ -n "$version" ] && [ -n "$url" ] || { echo "ImageMagick release or Linux tarball missing" >&2; exit 1; }
jq -n --arg v "$version" --arg d "$date" --arg u "$url" '{version:$v,releaseDate:$d,sources:[{filename:"imagemagick.tar.xz",url:$u}]}'
