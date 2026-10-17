#!/usr/bin/env bash
# Update resolver for SolidCraft.
#
# Prints the current version + the official Linux release tarballs as JSON on
# stdout:
#   { "version": "0.3.1", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "solidcraft.tar.gz", "arch": "x86_64",  "url": "..." },
#                  { "filename": "solidcraft.tar.gz", "arch": "aarch64", "url": "..." } ] }
# Logs go to stderr. No hashing — FlatPark downloads the URL and computes the
# extra-data sha256/size. The version is compared against the latest
# <release> in the AppStream metainfo.
set -euo pipefail

repo="tangency-labs/solidcraft"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# releases/latest is the newest non-prerelease.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"

# solidcraft-<ver>-linux-<arch>.tar.gz exactly: excludes the AppImage, deb,
# rpm, flatpak and the FreeBSD tarball.
asset_url() {
  jq -r --arg n "solidcraft-$version-linux-$1.tar.gz" \
    '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel" | head -n1
}
url_x86_64="$(asset_url x86_64)"
url_aarch64="$(asset_url aarch64)"

[ -n "$version" ] && [ "$version" != "null" ] && [ -n "$url_x86_64" ] && [ -n "$url_aarch64" ] || {
  echo "failed to resolve SolidCraft release" >&2
  exit 1
}
echo "resolved SolidCraft $version ($date): $url_x86_64" >&2

jq -n --arg v "$version" --arg d "$date" --arg ux "$url_x86_64" --arg ua "$url_aarch64" \
  '{version:$v, releaseDate:$d, sources:[
     {filename:"solidcraft.tar.gz", arch:"x86_64",  url:$ux},
     {filename:"solidcraft.tar.gz", arch:"aarch64", url:$ua}
   ]}'
