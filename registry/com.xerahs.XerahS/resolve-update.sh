#!/usr/bin/env bash
# Update resolver for XerahS.
#
# Prints the current version + the Linux x64 tarball as JSON on stdout:
#   { "version": "0.25.5", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "xerahs.tar.gz", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="ShareX/XerahS"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Exact name: the same release carries the macOS tarball, the arm64 build and
# the .deb/.rpm/AppImage/.flatpak variants.
url="$(jq -r --arg v "$version" '.assets[] | select(.name == "XerahS-\($v)-linux-x64.tar.gz") | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve XerahS release" >&2; exit 1; }
[ "$(wc -l <<<"$url")" -eq 1 ] || { echo "expected exactly one linux-x64 tarball, got:" >&2; echo "$url" >&2; exit 1; }
echo "resolved xerahs $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"xerahs.tar.gz", url:$u}]}'
