#!/usr/bin/env bash
set -euo pipefail
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} https://api.github.com/repos/keptaduona/wickline/releases/latest)"
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at | .[0:10]' <<<"$rel")"
url="$(jq -r '[.assets[] | select(.name | test("^Wickline-Linux-[0-9.]+\\.AppImage$")) | .browser_download_url] | if length == 1 then .[0] else empty end' <<<"$rel")"
[ -n "$version" ] && [ -n "$date" ] && [ -n "$url" ] || { echo 'failed to resolve Wickline release' >&2; exit 1; }
jq -n --arg v "$version" --arg d "$date" --arg u "$url" '{version:$v, releaseDate:$d, sources:[{filename:"app.AppImage", url:$u}]}'
