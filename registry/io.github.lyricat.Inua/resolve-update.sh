#!/usr/bin/env bash
# Update resolver for inua's light apps.
#
# Prints the latest release and its Linux amd64 and arm64 tarballs as JSON:
#   { "version": "0.1.29", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "inua.tar.gz", "arch": "x86_64", "url": "..." },
#                  { "filename": "inua.tar.gz", "arch": "aarch64", "url": "..." } ] }
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
# each tarball exactly.
asset() {
  jq -r --arg n "inua_linux_$1.tar.gz" \
    '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel" | head -n1
}
url="$(asset amd64)"
url_arm="$(asset arm64)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve inua release" >&2; exit 1; }
[ -n "$url_arm" ] || { echo "no arm64 tarball in inua $version" >&2; exit 1; }
echo "resolved inua $version ($date): $url $url_arm" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg ua "$url_arm" \
  '{version:$v, releaseDate:$d, sources:[{filename:"inua.tar.gz", arch:"x86_64", url:$u}, {filename:"inua.tar.gz", arch:"aarch64", url:$ua}]}'
