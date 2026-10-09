#!/usr/bin/env bash
# Update resolver for PKHeX-Avalonia.
#
# Prints the current version + the Linux x64 zip as JSON on stdout:
#   { "version": "1.89.4", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "pkhex-avalonia.zip", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="realgarit/PKHeX-Avalonia"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Exact name: the asset carries no version, and the same release has the
# AppImage, the .flatpak bundle and the macOS/Windows zips beside it.
url="$(jq -r '.assets[] | select(.name == "PKHeX-Avalonia-linux-x64.zip") | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve PKHeX-Avalonia release" >&2; exit 1; }
[ "$(wc -l <<<"$url")" -eq 1 ] || { echo "expected exactly one linux-x64 zip, got:" >&2; echo "$url" >&2; exit 1; }
echo "resolved pkhex-avalonia $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"pkhex-avalonia.zip", url:$u}]}'
