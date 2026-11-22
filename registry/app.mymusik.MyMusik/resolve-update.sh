#!/usr/bin/env bash
set -euo pipefail
base=https://shaggai.net/linux/client/MyMusik.AppImage
version="$(curl -fsSL "$base.version" | tr -d '\r\n')"
checksum="$(curl -fsSL "$base.sha256" | awk 'NR == 1 { print $1 }')"
[[ "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]] || { echo 'Invalid version' >&2; exit 1; }
[[ "$checksum" =~ ^[a-f0-9]{64}$ ]] || { echo 'Invalid checksum' >&2; exit 1; }
jq -n --arg version "$version" --arg url "$base" --arg sha "$checksum" \
  '{version:$version,sources:[{filename:"MyMusik.AppImage",url:$url,arch:"x86_64",sha256:$sha}]}'
