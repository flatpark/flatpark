#!/usr/bin/env bash
# Update resolver for ChimpStackr.
#
# Prints the current version + the Linux x86_64 AppImage as JSON on stdout:
#   { "version": "0.3.5", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "chimpstackr.AppImage", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="noah-peeters/ChimpStackr"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The AppImage name carries no version, so the tag in the URL is what pins it.
# Exact match: releases also carry the macOS .dmg, the Windows .zip and, in
# some versions, a .flatpak bundle.
url="$(jq -r '.assets[] | select(.name == "ChimpStackr-Linux-x86_64.AppImage") | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve chimpstackr release" >&2; exit 1; }
[ "$(wc -l <<<"$url")" -eq 1 ] || { echo "expected exactly one x86_64 AppImage asset, got:" >&2; echo "$url" >&2; exit 1; }
echo "resolved chimpstackr $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"chimpstackr.AppImage", url:$u}]}'
