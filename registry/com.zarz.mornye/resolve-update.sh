#!/usr/bin/env bash
# Resolve the newest Mornye desktop release and its exact amd64 .deb.
# FlatPark computes and rewrites the managed SHA-256 and size pins.
set -euo pipefail

repo=mornyeapp/Mornye-Desktop
need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases/latest")"
tag="$(jq -er '.tag_name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))' <<<"$release")"
version="${tag#v}"
date="$(jq -er '.published_at | split("T")[0]' <<<"$release")"

# Each release carries .deb, AppImage, Windows and macOS builds; match the exact
# expected .deb names so a new artifact flavour is never picked up by accident.
asset_url() {
  local name="$1" url
  url="$(jq -er --arg name "$name" \
    '[.assets[] | select(.name == $name)] | if length == 1 then .[0].browser_download_url else error("expected exactly one \($name)") end' \
    <<<"$release")"
  [[ "$url" == "https://github.com/$repo/releases/download/$tag/$name" ]] || {
    echo "refusing unexpected release asset URL: $url" >&2
    exit 1
  }
  printf '%s\n' "$url"
}
amd64="$(asset_url "Mornye-${tag}-linux-amd64.deb")"

echo "resolved Mornye $version ($date)" >&2
jq -n --arg v "$version" --arg d "$date" --arg a "$amd64" \
  --arg r "https://github.com/$repo/releases/tag/$tag" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[
     {filename:"mornye.deb", url:$a}
   ]}'
