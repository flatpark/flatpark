#!/usr/bin/env bash
# Update resolver for Voltius.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "0.42.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "voltius.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="VoltiusApp/voltius"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Exact Tauri bundle name: the release also carries the rpm, AppImage, a bare
# voltius_linux_x64 CLI binary and the macOS/Windows bundles.
url="$(jq -r --arg v "$version" '.assets[] | select(.name == "Voltius_\($v)_amd64.deb") | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve voltius release" >&2; exit 1; }
[ "$(wc -l <<<"$url")" -eq 1 ] || { echo "expected exactly one amd64 .deb asset, got:" >&2; echo "$url" >&2; exit 1; }
echo "resolved voltius $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"voltius.deb", url:$u}]}'
