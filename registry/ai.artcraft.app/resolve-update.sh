#!/usr/bin/env bash
# Update resolver for ArtCraft Studio.
#
# storytold/artcraft publishes only ArtCraft releases (artcraft-v<version>),
# and each carries the Linux tarballs, so this reads releases/latest and fails
# when either arch's tarball is missing instead of settling on an older one.
set -euo pipefail

repo="storytold/artcraft"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

tag="$(jq -r '.tag_name' <<<"$rel")"
case "$tag" in
  artcraft-v*) version="${tag#artcraft-v}" ;;
  *) echo "unexpected ArtCraft tag: $tag" >&2; exit 1 ;;
esac
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"

asset_url() {
  jq -r --arg n "artcraft-$version-linux-$1.tar.gz" \
    '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel" | head -n1
}
url_x86_64="$(asset_url x86_64)"
url_aarch64="$(asset_url aarch64)"

[ -n "$version" ] && [ -n "$url_x86_64" ] && [ -n "$url_aarch64" ] || {
  echo "failed to resolve ArtCraft Studio release" >&2
  exit 1
}
echo "resolved ArtCraft Studio $version ($date): $url_x86_64" >&2

jq -n --arg v "$version" --arg d "$date" --arg ux "$url_x86_64" --arg ua "$url_aarch64" \
  '{version:$v, releaseDate:$d, sources:[
     {filename:"artcraft.tar.gz", arch:"x86_64",  url:$ux},
     {filename:"artcraft.tar.gz", arch:"aarch64", url:$ua}
   ]}'
