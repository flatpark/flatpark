#!/usr/bin/env bash
# Update resolver for Tabularis.
#
# Prints the current version + the Linux .deb as JSON on stdout:
#   { "version": "0.13.2", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "tabularis.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="TabularisDB/tabularis"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The Linux build is the lone `tabularis_<version>_amd64.deb` asset (the others
# are the .AppImage, .rpm, macOS .dmg/.app and the Windows .msi/.exe).
url="$(jq -r '.assets[] | select(.name | test("_amd64\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve tabularis release" >&2; exit 1; }
echo "resolved tabularis $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"tabularis.deb", url:$u}]}'
