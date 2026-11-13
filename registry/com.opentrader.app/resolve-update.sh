#!/usr/bin/env bash
# Resolve the latest stable upstream release to its official x86_64 .deb.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

args=(-fsSL)
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  args+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi
release="$(curl "${args[@]}" https://api.github.com/repos/deepentropy/opentrader/releases/latest)"

version="$(jq -er '.tag_name | select(test("^v[0-9]")) | ltrimstr("v")' <<<"$release")"
date="$(jq -er '.published_at[0:10]' <<<"$release")"
url="$(jq -er '[.assets[] | select(.name == "OpenTrader_linux_amd64.deb" and .state == "uploaded")] | if length == 1 then .[0].browser_download_url else error("expected exactly one OpenTrader_linux_amd64.deb") end' <<<"$release")"

echo "resolved OpenTrader $version ($date): $url" >&2
jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"opentrader.deb", url:$u}]}'
