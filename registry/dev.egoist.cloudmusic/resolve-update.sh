#!/usr/bin/env bash
# Resolve the newest published MyGo Cloud Music release and its exact Linux
# tarballs for x86_64 and aarch64. FlatPark computes and rewrites the managed
# SHA-256 and size pins.
set -euo pipefail

repo=egoist/mygo-cloudmusic
need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases/latest")"
tag="$(jq -er '.tag_name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))' <<<"$release")"
version="${tag#v}"
date="$(jq -er '.published_at | split("T")[0]' <<<"$release")"

# Each release also carries a .deb, deltas for the in-app updater and builds
# for other platforms; match the exact tarball names.
asset_url() {
  local name="mygo-cloudmusic-${version}-linux-$1.tar.gz" url
  url="$(jq -er --arg name "$name" \
    '[.assets[] | select(.name == $name)] | if length == 1 then .[0].browser_download_url else error("expected exactly one \($name)") end' \
    <<<"$release")"
  [[ "$url" == "https://github.com/$repo/releases/download/$tag/$name" ]] || {
    echo "refusing unexpected release asset URL: $url" >&2
    exit 1
  }
  printf '%s\n' "$url"
}
x86="$(asset_url amd64)"
arm="$(asset_url arm64)"

echo "resolved MyGo Cloud Music $version ($date)" >&2
jq -n --arg v "$version" --arg d "$date" --arg x "$x86" --arg a "$arm" \
  '{version:$v, releaseDate:$d, releaseUrl:("https://github.com/egoist/mygo-cloudmusic/releases/tag/v"+$v), sources:[
    {arch:"x86_64", filename:"mygo-cloudmusic.tar.gz", url:$x},
    {arch:"aarch64", filename:"mygo-cloudmusic.tar.gz", url:$a}]}'
