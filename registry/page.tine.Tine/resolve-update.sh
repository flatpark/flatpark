#!/usr/bin/env bash
# Update resolver for Tine.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "0.5.1", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "tine.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="martinkoutecky/tine"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The Linux x86_64 build is `Tine_<version>_amd64.deb`. Exclude the `.sig`
# sidecars (Tauri updater signatures) that sit next to every Linux artifact.
url="$(jq -r '.assets[] | select(.name | test("_amd64\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"
url_arm="$(jq -r '.assets[] | select(.name | test("_arm64\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"
[ -n "$url_arm" ] || { echo "no aarch64 build in this release" >&2; exit 1; }

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve tine release" >&2; exit 1; }
echo "resolved tine $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg ua "$url_arm" \
  '{version:$v, releaseDate:$d, sources:[{filename:"tine.deb", arch:"x86_64", url:$u}, {filename:"tine.deb", arch:"aarch64", url:$ua}]}'
