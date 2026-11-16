#!/usr/bin/env bash
# Update resolver for Fluux Messenger.
#
# Prints the latest release and its Linux x86_64 tarball as JSON on stdout:
#   { "version": "0.18.2", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "fluux.tar.gz", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting: FlatPark pins the
# sha256 and size from the GitHub release asset's own digest.
set -euo pipefail

repo="processone/fluux-messenger"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The release carries a tarball per OS and arch next to .deb, .rpm and .flatpak
# files of the same build. Match the Linux x86_64 tarball exactly.
url="$(jq -r '.assets[] | select(.name | test("^Fluux-Messenger_[0-9][^_]*_Linux_x64\\.tar\\.gz$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ "$version" != "null" ] && [ -n "$url" ] || { echo "failed to resolve fluux release" >&2; exit 1; }
echo "resolved fluux $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"fluux.tar.gz", url:$u}]}'
