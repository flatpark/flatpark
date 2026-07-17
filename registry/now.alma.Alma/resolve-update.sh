#!/usr/bin/env bash
# Resolve the newest published Alma release and its exact amd64 Debian package.
# FlatPark computes and rewrites the managed SHA-256 and size pins.
set -euo pipefail

repo=yetone/alma-releases
need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases/latest")"
tag="$(jq -er '.tag_name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))' <<<"$release")"
version="${tag#v}"
date="$(jq -er '.published_at | split("T")[0]' <<<"$release")"
asset="alma-${version}-linux-amd64.deb"
url="$(jq -er --arg name "$asset" \
  '[.assets[] | select(.name == $name)] | if length == 1 then .[0].browser_download_url else error("expected exactly one amd64 .deb") end' \
  <<<"$release")"

[[ "$url" == "https://github.com/$repo/releases/download/$tag/$asset" ]] || {
  echo "refusing unexpected release asset URL: $url" >&2
  exit 1
}
echo "resolved Alma $version ($date): $url" >&2
jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"alma.deb", url:$u}]}'
