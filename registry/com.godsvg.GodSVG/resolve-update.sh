#!/usr/bin/env bash
# Update resolver for GodSVG.
#
# Prints the current version + the Linux x86_64 zip as JSON on stdout:
#   { "version": "1.0-alpha17", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "godsvg.zip", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="MewPurPur/GodSVG"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# GodSVG has no stable release yet: every 1.0 alpha is published as a GitHub
# prerelease, so releases/latest would 404. Take the newest non-draft release
# instead, prereleases included.
rels="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases?per_page=10")"
rel="$(jq -c '[.[] | select(.draft | not)] | sort_by(.published_at) | last' <<<"$rels")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The Linux x86_64 build is `GodSVG_v<version>.Linux.x86_64.zip`. Matched on
# the full asset name, so the AppImage, its zsync file and the zipped AppImage
# (`.Linux.AppImage.zip`) beside it can never be picked by sort order.
url="$(jq -r --arg n "GodSVG_v$version.Linux.x86_64.zip" '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve godsvg release" >&2; exit 1; }
echo "resolved godsvg $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"godsvg.zip", url:$u}]}'
