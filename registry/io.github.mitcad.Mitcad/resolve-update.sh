#!/usr/bin/env bash
# Update resolver for MitCad.
#
# The same GitHub release also ships Windows archives, a macOS disk image
# and a separate browser zip. Take the official Linux x86_64 AppImage from
# releases/latest: every release carries it, so a missing AppImage fails
# instead of settling on an older release. There is no desktop aarch64
# archive.
# Prints JSON on stdout:
#   { "version": "0.64.0", "releaseDate": "YYYY-MM-DD", "releaseUrl": "...",
#     "sources": [ { "filename": "mitcad.AppImage", "url": "..." } ] }
set -euo pipefail

repo="mitcad/Mitcad"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | select(test("^v[0-9]+(\\.[0-9]+)*$")) | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at // empty' <<<"$rel" | cut -c1-10)"
release_url="$(jq -r '.html_url // empty' <<<"$rel")"
url="$(jq -r '[ .assets[] | select(.name | test("^Mitcad-[0-9][0-9.]*-x86_64\\.AppImage$")) ]
              | if length == 1 then .[0].browser_download_url else empty end' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve MitCad release" >&2; exit 1; }
echo "resolved MitCad $version ($date)" >&2

jq -n --arg v "$version" --arg d "$date" --arg r "$release_url" --arg u "$url" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[{filename:"mitcad.AppImage", url:$u}]}'
