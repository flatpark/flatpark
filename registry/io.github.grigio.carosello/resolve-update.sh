#!/usr/bin/env bash
# Update resolver for Carosello.
#
# Prints the current version + the x86_64 Linux binary as JSON on stdout:
#   { "version": "1.0.6", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "carosello", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="grigio/carosello"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The Linux x86_64 build is the bare `carosello` binary (the release also ships
# a `carosello.flatpak` bundle, which is deliberately not used: a Flatpak
# bundle is not an accepted vendor payload). The exact name is the anchor.
url="$(jq -r '.assets[] | select(.name == "carosello") | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ "$version" != "null" ] && [ -n "$url" ] && [ "$url" != "null" ] || { echo "failed to resolve carosello release" >&2; exit 1; }
echo "resolved carosello $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"carosello", url:$u}]}'
