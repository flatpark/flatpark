#!/usr/bin/env bash
# Update resolver for Beifahrer, written by `gjsify flatpark`.
#
# Prints the latest release on stdout as JSON:
#   { "version": "…", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "app.tar.gz", "arch": "…", "url": "…" } ] }
# Logs go to stderr. No hashing and no manifest rewriting: FlatPark downloads
# each URL and computes the extra-data sha256 and size itself.
set -euo pipefail

repo="JumpLink/beifahrer"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
[ -n "$version" ] && [ "$version" != "null" ] || { echo "failed to resolve the latest release of $repo" >&2; exit 1; }

url_x86_64="$(jq -r '.assets[] | select(.name | test("^beifahrer-[0-9][0-9A-Za-z.+~-]*-linux-x86_64-flatpak\\.tar\\.gz$")) | .browser_download_url' <<<"$rel" | head -n1)"
[ -n "$url_x86_64" ] || { echo "no x86_64 asset in this release" >&2; exit 1; }
echo "resolved Beifahrer $version ($date)" >&2

jq -n --arg v "$version" --arg d "$date" --arg u_x86_64 "$url_x86_64" \
  '{version:$v, releaseDate:$d, sources:[{filename:"app.tar.gz", arch:"x86_64", url:$u_x86_64}]}'
