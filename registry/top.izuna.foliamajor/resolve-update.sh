#!/usr/bin/env bash
# Update resolver for Folia.
#
# Prints the current version + x86_64 Linux .deb as JSON on stdout:
#   { "version": "0.5.17", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "folia-major.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time.
set -euo pipefail

repo="chthollyphile/folia-major"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r '.assets[] | select(.name | test("^folia-major-[0-9.]+-linux-amd64\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve Folia release" >&2; exit 1; }
echo "resolved Folia $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"folia-major.deb", url:$u}]}'
