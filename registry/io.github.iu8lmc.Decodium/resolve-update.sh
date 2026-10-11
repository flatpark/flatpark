#!/usr/bin/env bash
# Update resolver for Decodium.
#
# Prints the current version + the Linux x86_64 AppImage as JSON on stdout:
#   { "version": "1.0.649", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "decodium.AppImage", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# Not every release has a Linux build: v1.0.670-672 shipped only the Windows
# installer. So this takes the newest non-draft, non-prerelease release that
# does carry the x86_64 AppImage, and logs the newer ones it had to skip.
set -euo pipefail

repo="iu8lmc/Decodium-4.0-Core-Shannon"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

releases="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases?per_page=30")"

# Exact name, anchored on the version: a release also carries the aarch64
# AppImage and a .sha256.txt next to each, which a loose `\.AppImage` or
# `x86_64` match would pick up.
linux='(.tag_name | ltrimstr("v")) as $v
       | [.assets[] | select(.name == "decodium4-ft2-\($v)-linux-x86_64.AppImage")]'
# Newest first; everything ahead of the first one with a Linux build is skipped.
stable="$(jq -c '[.[] | select((.draft or .prerelease) | not)] | sort_by(.published_at) | reverse' <<<"$releases")"
i="$(jq "map($linux | length > 0) | index(true) // empty" <<<"$stable")"
[ -n "$i" ] || { echo "no recent release carries a Linux x86_64 AppImage" >&2; exit 1; }
rel="$(jq -c ".[$i]" <<<"$stable")"
[ "$i" -eq 0 ] || echo "no Linux AppImage in $(jq -r ".[:$i] | map(.tag_name) | join(\", \")" <<<"$stable"); using the newest release that has one" >&2

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r "$linux | .[].browser_download_url" <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve decodium release" >&2; exit 1; }
[ "$(wc -l <<<"$url")" -eq 1 ] || { echo "expected exactly one x86_64 AppImage asset, got:" >&2; echo "$url" >&2; exit 1; }
echo "resolved decodium $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"decodium.AppImage", url:$u}]}'
