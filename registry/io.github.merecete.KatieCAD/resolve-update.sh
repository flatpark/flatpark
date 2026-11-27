#!/usr/bin/env bash
# Update resolver for KatieCAD.
#
# The same GitHub release also ships a .deb, a Windows installer and a
# macOS disk image. Take the official Linux x86_64 tarball from
# releases/latest: every release carries one, so a missing or renamed one
# fails instead of settling on an older release. It is
# KatieCAD-Linux-x86_64_v<version>.tar.xz, except v1.2.1 which shipped
# .tar.gz; accept either, but exactly one. The extra-data keeps the name
# katiecad.tar.gz for both, since apply_extra.sh lets bsdtar detect the
# format. There is no desktop aarch64 archive.
# Prints JSON on stdout:
#   { "version": "1.2.1", "releaseDate": "YYYY-MM-DD", "releaseUrl": "...",
#     "sources": [ { "filename": "katiecad.tar.gz", "url": "..." } ] }
set -euo pipefail

repo="Merecete/KatieCAD"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | select(test("^v[0-9]+(\\.[0-9]+)*$")) | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at // empty' <<<"$rel" | cut -c1-10)"
release_url="$(jq -r '.html_url // empty' <<<"$rel")"
url="$(jq -r --arg n "KatieCAD-Linux-x86_64_v$version" \
  '[ .assets[] | select(.name == ($n + ".tar.xz") or .name == ($n + ".tar.gz")) ]
   | if length == 1 then .[0].browser_download_url else empty end' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve KatieCAD release" >&2; exit 1; }
echo "resolved KatieCAD $version ($date)" >&2

jq -n --arg v "$version" --arg d "$date" --arg r "$release_url" --arg u "$url" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[{filename:"katiecad.tar.gz", url:$u}]}'
