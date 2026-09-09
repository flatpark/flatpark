#!/usr/bin/env bash
# Resolve the newest published Vynody release and its exact x86_64 Linux
# tarball. FlatPark computes and rewrites the managed SHA-256 and size pins.
set -euo pipefail

repo=axel10/vynody
need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases/latest")"
tag="$(jq -er '.tag_name | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))' <<<"$release")"
version="$tag"
date="$(jq -er '.published_at | split("T")[0]' <<<"$release")"

# Upstream ships several Linux artifacts per release (.deb, .rpm, .AppImage and
# this plain tarball); match the exact expected name so a new artifact flavour
# can never be picked up by a loose suffix match.
asset="vynody-linux-${version}.tar.gz"
url="$(jq -er --arg name "$asset" \
  '[.assets[] | select(.name == $name)] | if length == 1 then .[0].browser_download_url else error("expected exactly one Linux tarball") end' \
  <<<"$release")"

[[ "$url" == "https://github.com/$repo/releases/download/$tag/$asset" ]] || {
  echo "refusing unexpected release asset URL: $url" >&2
  exit 1
}
echo "resolved Vynody $version ($date): $url" >&2
jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"vynody-linux.tar.gz", url:$u}]}'
