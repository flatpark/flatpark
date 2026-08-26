#!/usr/bin/env bash
# Resolve the latest official x86_64 Debian release for Elasticvue.
set -euo pipefail

repo="cars10/elasticvue"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing command: $1" >&2
    exit 1
  }
}

need curl
need jq

curl_args=(-fsSL)
if [ -n "${GITHUB_TOKEN:-}" ]; then
  curl_args+=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi

rel="$(curl "${curl_args[@]}" "https://api.github.com/repos/$repo/releases/latest")"
version="$(jq -er '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -er '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -er '[.assets[] | select(.name | test("_amd64\\.deb$")) | .browser_download_url] | if length == 1 then .[0] else empty end' <<<"$rel")"

[ -n "$version" ] && [ -n "$date" ] && [ -n "$url" ] || {
  echo "failed to resolve Elasticvue release" >&2
  exit 1
}

echo "resolved Elasticvue $version ($date): $url" >&2
jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"elasticvue.deb", url:$u}]}'
