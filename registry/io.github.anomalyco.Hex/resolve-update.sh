#!/usr/bin/env bash
set -euo pipefail
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} https://api.github.com/repos/anomalyco/hex/releases/latest)"
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at | split("T")[0]' <<<"$rel")"
x64="$(jq -er --arg name "hex-${version}-linux-x64.deb" '.assets[] | select(.name == $name) | .browser_download_url' <<<"$rel")"
arm64="$(jq -er --arg name "hex-${version}-linux-arm64.deb" '.assets[] | select(.name == $name) | .browser_download_url' <<<"$rel")"
jq -n --arg v "$version" --arg d "$date" --arg x "$x64" --arg a "$arm64" '{version:$v, releaseDate:$d, sources:[{filename:"hex.deb",arch:"x86_64",url:$x},{filename:"hex.deb",arch:"aarch64",url:$a}]}'
