#!/usr/bin/env bash
# Resolve the newest TraceDraw release and its two official Linux tarballs.
# Upstream also publishes a rolling "nightly" pre-release; releases/latest
# leaves it out, and the tag check below refuses anything but vX.Y.Z.
# FlatPark computes and rewrites the managed SHA-256 and size pins.
set -euo pipefail

repo=tracedraw/tracedraw
need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases/latest")"
tag="$(jq -er '.tag_name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))' <<<"$release")"
version="${tag#v}"
date="$(jq -er '.published_at | split("T")[0]' <<<"$release")"

# tracedraw-<ver>-linux-<arch>.tar.gz exactly: the AppImage and .deb of the same
# release have other names.
asset_url() {
  local asset="tracedraw-$version-linux-$1.tar.gz" url
  url="$(jq -er --arg name "$asset" \
    '[.assets[] | select(.name == $name)] | if length == 1 then .[0].browser_download_url else error("expected exactly one Linux archive") end' \
    <<<"$release")"
  [[ "$url" == "https://github.com/$repo/releases/download/$tag/$asset" ]] || {
    echo "refusing unexpected release asset URL: $url" >&2
    exit 1
  }
  printf '%s\n' "$url"
}
url_x86_64="$(asset_url x86_64)"
url_aarch64="$(asset_url arm64)"

echo "resolved TraceDraw $version ($date): $url_x86_64" >&2
jq -n --arg v "$version" --arg d "$date" --arg ux "$url_x86_64" --arg ua "$url_aarch64" \
  '{version:$v, releaseDate:$d, sources:[
     {filename:"tracedraw.tar.gz", arch:"x86_64",  url:$ux},
     {filename:"tracedraw.tar.gz", arch:"aarch64", url:$ua}
   ]}'
