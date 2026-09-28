#!/usr/bin/env bash
# Update resolver for Concat.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "0.2.4", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "concat.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="jub0t/Concat"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The Linux x86_64 build is the single `Concat-<version>-linux-x86_64.deb`
# asset. The release also carries the aarch64 .deb, .rpm, AppImage and Arch
# packages plus the macOS/Windows/mobile builds; matching the whole name keeps
# those out.
url="$(jq -r --arg v "$version" \
        '.assets[] | select(.name == ("Concat-" + $v + "-linux-x86_64.deb")) | .browser_download_url' \
        <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve concat release" >&2; exit 1; }
echo "resolved concat $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"concat.deb", url:$u}]}'
