#!/usr/bin/env bash
# Update resolver for Imladris on FlatPark.
#
# Prints the current version + the Flatpak /app tarball as JSON on stdout:
#   { "version": "0.27.1", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "imladris-flatpak.tar.gz", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time.
# Never fall back to .deb: FlatPark must always package the Flatpak build.
set -euo pipefail

repo="Antux912012/imladris"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r '.assets[] | select(.name | test("^io\\.github\\.Antux912012\\.Imladris-flatpak-x86_64\\.tar\\.gz$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve Imladris Flatpak archive release asset (refusing .deb fallback)" >&2; exit 1; }
echo "resolved imladris $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"imladris-flatpak.tar.gz", url:$u}]}'
