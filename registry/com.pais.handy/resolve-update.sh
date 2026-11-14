#!/usr/bin/env bash
# Resolve Handy's official Linux x86_64 Debian release asset.
set -euo pipefail

repo="cjpais/Handy"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases/latest")"
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
asset="Handy_${version}_amd64.deb"
url="$(jq -r --arg name "$asset" \
  '.assets[] | select(.name == $name) | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$date" ] && [ -n "$url" ] || {
  echo "failed to resolve Handy Linux x86_64 .deb release" >&2
  exit 1
}
echo "resolved Handy $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"handy.deb", url:$u}]}'
