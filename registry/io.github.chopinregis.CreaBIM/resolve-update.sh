#!/usr/bin/env bash
# Update resolver for CreaBIM.
#
# The same GitHub release also ships Windows archives. Take the official
# Linux x86_64 tar.gz from releases/latest: every release carries it, so a
# missing one fails instead of settling on an older release. There is no
# desktop aarch64 archive.
# Prints JSON on stdout:
#   { "version": "1.1.0", "releaseDate": "YYYY-MM-DD", "releaseUrl": "...",
#     "sources": [ { "filename": "creabim.tar.gz", "url": "..." } ] }
set -euo pipefail

repo="chopinregis/CreaBIM"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | select(test("^v[0-9]+(\\.[0-9]+)*$")) | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at // empty' <<<"$rel" | cut -c1-10)"
release_url="$(jq -r '.html_url // empty' <<<"$rel")"
url="$(jq -r '[ .assets[] | select(.name | test("^CreaBIM-[0-9][0-9.]*-[0-9]{4}-[0-9]{2}-[0-9]{2}-linux-x64\\.tar\\.gz$")) ]
              | if length == 1 then .[0].browser_download_url else empty end' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve CreaBIM release" >&2; exit 1; }
echo "resolved CreaBIM $version ($date)" >&2

jq -n --arg v "$version" --arg d "$date" --arg r "$release_url" --arg u "$url" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[{filename:"creabim.tar.gz", url:$u}]}'
