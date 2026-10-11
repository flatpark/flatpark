#!/usr/bin/env bash
# Update resolver for electerm.
#
# Prints the current version + the x86_64 Linux tarball as JSON on stdout:
#   { "version": "3.15.69", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "electerm.tar.gz", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="electerm/electerm"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The modern x86_64 desktop build is `electerm-<ver>-linux-x64.tar.gz`. Match it
# exactly so the `-x64-legacy`, arm64/armv7l/loong64 and the .deb/.rpm/.AppImage/
# .snap assets are all excluded.
url="$(jq -r '.assets[] | select(.name | test("-linux-x64\\.tar\\.gz$")) | .browser_download_url' <<<"$rel" | head -n1)"
url_arm="$(jq -r '.assets[] | select(.name | test("-linux-arm64\\.tar\\.gz$")) | .browser_download_url' <<<"$rel" | head -n1)"
[ -n "$url_arm" ] || { echo "no aarch64 build in this release" >&2; exit 1; }

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve electerm release" >&2; exit 1; }
echo "resolved electerm $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg ua "$url_arm" \
  '{version:$v, releaseDate:$d, sources:[{filename:"electerm.tar.gz", arch:"x86_64", url:$u}, {filename:"electerm.tar.gz", arch:"aarch64", url:$ua}]}'
