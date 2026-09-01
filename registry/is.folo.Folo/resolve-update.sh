#!/usr/bin/env bash
# Update resolver for Folo.
#
# Prints the current version + the Linux x86_64 AppImage as JSON on stdout:
#   { "version": "1.12.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "folo.AppImage", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# Only folo.AppImage is resolved here; appimage-tools.tar.xz is pinned by hand
# outside the managed block in the manifest.
set -euo pipefail

repo="RSSNext/Folo"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# Folo tags its desktop releases "desktop/v<version>". releases/latest already
# filters out prereleases and drafts.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | sub("^desktop/v";"") | sub("^v";"")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The lone Linux artifact: Folo-<version>-linux-x64.AppImage.
url="$(jq -r '.assets[] | select(.name | test("-linux-x64\\.AppImage$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve folo release" >&2; exit 1; }
echo "resolved folo $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"folo.AppImage", url:$u}]}'
