#!/usr/bin/env bash
# Update resolver for Valhalla.
#
# Prints the current version + the x86_64 and aarch64 portable tarballs as
# JSON on stdout:
#   { "version": "1.6.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "valhalla.tar.gz", "arch": "x86_64", "url": "..." },
#                  { "filename": "valhalla.tar.gz", "arch": "aarch64", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads
# the URL and computes the extra-data sha256/size at build time. The version
# is compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="tunix/valhalla"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The portable tarball is the official payload; the AppImages and the
# .flatpak bundle in the same release are deliberately not used (bundles are
# not an accepted vendor payload and the AppImage would only add an unpack
# tool). Anchored patterns so the .zsync sidecars never match.
url="$(jq -r '.assets[] | select(.name | test("^valhalla-v[0-9.]+-x86_64\\.tar\\.gz$")) | .browser_download_url' <<<"$rel" | head -n1)"
url_arm="$(jq -r '.assets[] | select(.name | test("^valhalla-v[0-9.]+-aarch64\\.tar\\.gz$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ "$version" != "null" ] && [ -n "$url" ] || { echo "failed to resolve Valhalla release" >&2; exit 1; }
[ -n "$url_arm" ] || { echo "no aarch64 build in this release" >&2; exit 1; }
echo "resolved Valhalla $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg ua "$url_arm" \
  '{version:$v, releaseDate:$d, sources:[{filename:"valhalla.tar.gz", arch:"x86_64", url:$u}, {filename:"valhalla.tar.gz", arch:"aarch64", url:$ua}]}'
