#!/usr/bin/env bash
# Update resolver for PdfCraft.
#
# Prints the current version + the official Linux release tarball as JSON on
# stdout:
#   { "version": "0.2.1", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "pdfcraft-x86_64.tar.gz", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="storytold/pdfcraft"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# releases/latest is the newest non-prerelease.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"

# pdfcraft-<ver>-linux-x86_64.tar.gz exactly: excludes the .AppImage/.deb/.rpm
# of the same build and the aarch64 tarball.
url="$(jq -r --arg v "$version" \
  '.assets[] | select(.name == "pdfcraft-\($v)-linux-x86_64.tar.gz") | .browser_download_url' \
  <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || {
  echo "failed to resolve PdfCraft release" >&2
  exit 1
}
echo "resolved PdfCraft $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"pdfcraft-x86_64.tar.gz", url:$u}]}'
