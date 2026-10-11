#!/usr/bin/env bash
# Update resolver for Tabby.
#
# Prints the current version + the x86_64 Linux .deb as JSON on stdout:
#   { "version": "1.0.234", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "tabby.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="Eugeny/tabby"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The x86_64 desktop build is `tabby-<ver>-linux-x64.deb`. Match it exactly so
# the arm64/armv7l .deb, the .rpm/.pacman/.tar.gz/.AppImage, the portable .zip
# and the macOS assets are all excluded.
url="$(jq -r '.assets[] | select(.name | test("-linux-x64\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"
url_arm="$(jq -r '.assets[] | select(.name | test("-linux-arm64\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"
[ -n "$url_arm" ] || { echo "no aarch64 build in this release" >&2; exit 1; }

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve Tabby release" >&2; exit 1; }
echo "resolved Tabby $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg ua "$url_arm" \
  '{version:$v, releaseDate:$d, sources:[{filename:"tabby.deb", arch:"x86_64", url:$u}, {filename:"tabby.deb", arch:"aarch64", url:$ua}]}'
