#!/usr/bin/env bash
# Update resolver for VectorCraft.
#
# Prints the current version + the official Linux release tarball as JSON on
# stdout:
#   { "version": "0.4.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "vectorcraft.tar.gz", "arch": "x86_64",  "url": "..." },
#                  { "filename": "vectorcraft.tar.gz", "arch": "aarch64", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="storytold/vectorcraft"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# releases/latest is the newest non-prerelease.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"

# vectorcraft-<ver>-linux-<arch>.tar.gz exactly: excludes the .AppImage/.deb/.rpm/
# .flatpak of the same builds.
asset_url() {
  jq -r --arg n "vectorcraft-$version-linux-$1.tar.gz" \
    '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel" | head -n1
}
url_x86_64="$(asset_url x86_64)"
url_aarch64="$(asset_url aarch64)"

[ -n "$version" ] && [ -n "$url_x86_64" ] && [ -n "$url_aarch64" ] || {
  echo "failed to resolve VectorCraft release" >&2
  exit 1
}
echo "resolved VectorCraft $version ($date): $url_x86_64" >&2

jq -n --arg v "$version" --arg d "$date" --arg ux "$url_x86_64" --arg ua "$url_aarch64" \
  '{version:$v, releaseDate:$d, sources:[
     {filename:"vectorcraft.tar.gz", arch:"x86_64",  url:$ux},
     {filename:"vectorcraft.tar.gz", arch:"aarch64", url:$ua}
   ]}'
