#!/usr/bin/env bash
# Resolve the latest stable upstream release to its official x86_64 .deb.
# The repo also publishes plugin releases (plugin-<name>-v<ver>) that can
# briefly hold "latest", so scan the release list for the newest app tag
# instead of trusting releases/latest. Asset names gained the version in
# v0.5.1 (OpenTrader_0.5.1_linux_amd64.deb); match both forms (flatpark#1593).
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

args=(-fsSL)
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  args+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi
releases="$(curl "${args[@]}" 'https://api.github.com/repos/deepentropy/opentrader/releases?per_page=30')"
release="$(jq -ec '[.[] | select((.draft | not) and (.prerelease | not) and (.tag_name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")))] | sort_by(.published_at) | last // error("no stable app release in the last 30 releases")' <<<"$releases")"

version="$(jq -er '.tag_name | ltrimstr("v")' <<<"$release")"
date="$(jq -er '.published_at[0:10]' <<<"$release")"
url="$(jq -er '[.assets[] | select((.name | test("^OpenTrader_([0-9.]+_)?linux_amd64\\.deb$")) and .state == "uploaded")] | if length == 1 then .[0].browser_download_url else error("expected exactly one OpenTrader linux_amd64 .deb") end' <<<"$release")"

echo "resolved OpenTrader $version ($date): $url" >&2
jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"opentrader.deb", url:$u}]}'
