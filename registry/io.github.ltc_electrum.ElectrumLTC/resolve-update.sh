#!/usr/bin/env bash
set -euo pipefail
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} https://api.github.com/repos/ltc-electrum/electrum-ltc/releases/latest)"
version="$(jq -er '.tag_name | sub("^v"; "")' <<<"$rel")"
date="$(jq -er '.published_at | .[0:10]' <<<"$rel")"
url="$(jq -er --arg name "electrum-ltc-${version}-x86_64.AppImage" '[.assets[] | select(.name == $name) | .browser_download_url] | if length == 1 then .[0] else error("expected one AppImage") end' <<<"$rel")"
jq -n --arg v "$version" --arg d "$date" --arg u "$url" '{version:$v, releaseDate:$d, sources:[{filename:"electrum-ltc.AppImage",url:$u}]}'
