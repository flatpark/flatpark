#!/usr/bin/env bash
# Update resolver for Grab.
#
# Prints the current version + the x86_64 Linux prebuilt tarball as JSON on
# stdout:
#   { "version": "2.3.2", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "grab.tar.gz", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="houssemko/Grab"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The prebuilt install tree is the lone `Grab-<ver>-linux-x86_64.tar.gz` asset
# (the .flatpak bundle is deliberately not used: it is not an accepted vendor
# payload).
url="$(jq -r '.assets[] | select(.name | test("linux.*x86_64.*\\.tar\\.gz$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ "$version" != "null" ] && [ -n "$url" ] || { echo "failed to resolve Grab release" >&2; exit 1; }
echo "resolved Grab $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"grab.tar.gz", url:$u}]}'
