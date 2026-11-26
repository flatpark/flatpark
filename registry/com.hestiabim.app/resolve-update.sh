#!/usr/bin/env bash
# Update resolver for Hestia.
#
# The same GitHub release also ships an AppImage, an rpm, a Windows
# installer and a macOS disk image, plus the web app's static files.
# Take the official amd64 .deb from releases/latest: every release since
# v0.2.2 carries it, so a missing .deb fails instead of settling on an
# older release. There is no desktop aarch64 archive.
# Prints JSON on stdout:
#   { "version": "0.2.6", "releaseDate": "YYYY-MM-DD", "releaseUrl": "...",
#     "sources": [ { "filename": "hestia.deb", "url": "..." } ] }
set -euo pipefail

repo="engdennylsonsantos-cloud/Hestia"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | select(test("^v[0-9]+(\\.[0-9]+)*$")) | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at // empty' <<<"$rel" | cut -c1-10)"
release_url="$(jq -r '.html_url // empty' <<<"$rel")"
url="$(jq -r '[ .assets[] | select(.name | test("^Hestia_[0-9][0-9.]*_amd64\\.deb$")) ]
              | if length == 1 then .[0].browser_download_url else empty end' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve Hestia release" >&2; exit 1; }
echo "resolved Hestia $version ($date)" >&2

jq -n --arg v "$version" --arg d "$date" --arg r "$release_url" --arg u "$url" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[{filename:"hestia.deb", url:$u}]}'
