#!/usr/bin/env bash
# Update resolver for Blanc.
#
# Prints the current version + the Linux x86_64 AppImage as JSON on stdout:
#   { "version": "1.27.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "blanc.AppImage", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="bnfy/blanc"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# releases/latest excludes prereleases and drafts, so this tracks the stable
# channel.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The Linux x86_64 build is `Blanc-<version>.AppImage` — the only AppImage in
# the release. Matched on the full asset name rather than a suffix, so a later
# arm64 AppImage (electron-builder names those `-arm64.AppImage`) can never be
# picked by sort order.
url="$(jq -r --arg n "Blanc-$version.AppImage" '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve blanc release" >&2; exit 1; }
echo "resolved blanc $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"blanc.AppImage", url:$u}]}'
