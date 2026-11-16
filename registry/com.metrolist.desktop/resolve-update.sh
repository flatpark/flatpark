#!/usr/bin/env bash
# Resolve the newest Metrolist release and its exact Linux x86_64 and arm64
# AppImages. FlatPark computes and rewrites the managed SHA-256 and size pins.
set -euo pipefail

repo=MetrolistGroup/Metrolist
need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases/latest")"
tag="$(jq -er '.tag_name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))' <<<"$release")"
version="${tag#v}"
date="$(jq -er '.published_at | split("T")[0]' <<<"$release")"

# Each release carries Android, iOS, Windows, macOS and Linux builds; match
# the exact AppImage names so a new flavour is never picked up.
asset() { # name
  local url
  url="$(jq -er --arg name "$1" \
    '[.assets[] | select(.name == $name)] | if length == 1 then .[0].browser_download_url else error("expected exactly one \($name)") end' \
    <<<"$release")"
  [[ "$url" == "https://github.com/$repo/releases/download/$tag/$1" ]] || {
    echo "refusing unexpected release asset URL: $url" >&2
    exit 1
  }
  printf '%s\n' "$url"
}
url_x64="$(asset "metrolist-desktop-linux-x64-${version}.AppImage")"
url_arm="$(asset "metrolist-desktop-linux-arm64-${version}.AppImage")"

echo "resolved Metrolist $version ($date)" >&2
jq -n --arg v "$version" --arg d "$date" --arg u "$url_x64" --arg ua "$url_arm" \
  --arg r "https://github.com/$repo/releases/tag/$tag" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[
     {filename:"metrolist.AppImage", arch:"x86_64", url:$u},
     {filename:"metrolist.AppImage", arch:"aarch64", url:$ua}
   ]}'
