#!/usr/bin/env bash
# Update resolver for inua's light apps.
#
# Prints the latest release and its Linux x86_64 tarball as JSON:
#   { "version": "0.0.19", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "inua.tar.gz", "url": "..." } ] }
# Logs go to stderr.
set -euo pipefail

repo="lyricat/inua"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Each release carries an amd64 and an arm64 tarball and checksums.txt; match
# the amd64 tarball exactly.
url="$(jq -r '.assets[] | select(.name == "inua_linux_amd64.tar.gz") | .browser_download_url' \
        <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve inua release" >&2; exit 1; }
echo "resolved inua $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"inua.tar.gz", url:$u}]}'
