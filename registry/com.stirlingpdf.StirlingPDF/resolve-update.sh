#!/usr/bin/env bash
# Update resolver for Stirling PDF.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "2.14.3", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "stirling-pdf.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting - FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="Stirling-Tools/Stirling-PDF"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

# Tags are `v<version>`.
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The Linux desktop build we package. The asset name carries no version, so it
# is matched exactly - the .rpm and the AppImage of the same build, the server
# jars and the macOS/Windows artifacts are all skipped.
url="$(jq -r '.assets[] | select(.name == "Stirling-PDF-linux-x86_64.deb") | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve stirling-pdf release" >&2; exit 1; }
echo "resolved stirling-pdf $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"stirling-pdf.deb", url:$u}]}'
