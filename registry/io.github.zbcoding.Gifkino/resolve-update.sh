#!/usr/bin/env bash
# Update resolver for Gifkino.
#
# Prints the current version + the x86_64 app-tree tarball as JSON on stdout:
#   { "version": "0.1.3", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "gifkino-app.tar.xz", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="zbcoding/gifkino"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Three assets ship per release: the AppImage and the Gifkino.flatpak bundle,
# both for direct download, and Gifkino-flatpark-x86_64.tar.xz — the /app tree
# out of upstream's own flatpak build, published for this package. Only the
# last one is staged here; matching it by name keeps the other two out.
url="$(jq -r '.assets[] | select(.name | test("-flatpark-x86_64\\.tar\\.xz$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve gifkino release" >&2; exit 1; }
echo "resolved gifkino $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"gifkino-app.tar.xz", url:$u}]}'
