#!/usr/bin/env bash
# Update resolver for PDFsam Basic.
#
# Reads the latest GitHub release of torakiki/pdfsam and picks the portable
# x86_64 Linux tarball, whose name carries the version:
#
#   pdfsam-basic-6.0.6-linux-x64.tar.gz
#
# The same release also has a .deb, Windows and macOS builds and a .asc
# signature for each; the pattern is anchored so none of them can match.
# Upstream publishes no arm64 Linux build, so only x86_64 is packaged.
#
# Prints:
#   { "version": "6.0.6", "releaseDate": "2026-10-02", "releaseUrl": "...",
#     "sources": [ { "filename": "pdfsam.tar.gz", "url": "..." } ] }
#
# Logs go to stderr. No hashing: update-pins reads the asset's digest and size
# from the releases API.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

repo="torakiki/pdfsam"

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name // empty | ltrimstr("v")' <<<"$rel")"
[[ "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]] || { echo "unexpected tag in the latest release of $repo: '$version'" >&2; exit 1; }

url="$(jq -r --arg n "pdfsam-basic-$version-linux-x64.tar.gz" \
  '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel")"
[ "$(printf '%s\n' "$url" | grep -c .)" -eq 1 ] \
  || { echo "expected one pdfsam-basic-$version-linux-x64.tar.gz in release v$version" >&2; exit 1; }

date="$(jq -r '.published_at // empty' <<<"$rel" | cut -c1-10)"
release_url="$(jq -r '.html_url // empty' <<<"$rel")"

echo "resolved PDFsam Basic $version (${date:-no date}): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg r "$release_url" --arg u "$url" \
  '{version:$v}
   + (if $d == "" then {} else {releaseDate:$d} end)
   + (if $r == "" then {} else {releaseUrl:$r} end)
   + {sources:[{filename:"pdfsam.tar.gz", url:$u}]}'
