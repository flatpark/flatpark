#!/usr/bin/env bash
# Update resolver for phpo.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "0.1.45", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "phpo.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="xiaokentrl/phpo"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The Linux x86_64 build is the lone `phpo_<version>_amd64.deb` asset (the
# others are the .rpm, the Windows/macOS installers, their `.sig` sidecars,
# checksums.txt and the in-app updater's manifest.json). Anchor on the exact
# name so a sidecar or a future variant can't win by sort order.
url="$(jq -r --arg n "phpo_${version}_amd64.deb" '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve phpo release" >&2; exit 1; }
echo "resolved phpo $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"phpo.deb", url:$u}]}'
