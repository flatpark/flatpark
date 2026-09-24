#!/usr/bin/env bash
# Update resolver for Decodium.
#
# Prints the current version + the Linux x86_64 AppImage as JSON on stdout:
#   { "version": "1.0.649", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "decodium.AppImage", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="iu8lmc/Decodium-4.0-Core-Shannon"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Exact name, anchored on the version: the release also carries the aarch64
# AppImage and a .sha256.txt next to each, which a loose `\.AppImage` or
# `x86_64` match would pick up.
url="$(jq -r --arg v "$version" \
        '.assets[] | select(.name == "decodium4-ft2-\($v)-linux-x86_64.AppImage") | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve decodium release" >&2; exit 1; }
[ "$(wc -l <<<"$url")" -eq 1 ] || { echo "expected exactly one x86_64 AppImage asset, got:" >&2; echo "$url" >&2; exit 1; }
echo "resolved decodium $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"decodium.AppImage", url:$u}]}'
