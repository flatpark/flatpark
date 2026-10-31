#!/usr/bin/env bash
# Update resolver for Meditate.
#
# Prints the latest stable release and its two app tree tarballs as JSON:
#   { "version": "26.10.3", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "meditate.tar.gz", "arch": "...", "url": "..." } ] }
# Upstream attaches the tarballs shortly after publishing a release, so this
# fails until both are there rather than pinning only one architecture.
# The .flatpak bundles on the same release are not an accepted payload.
set -euo pipefail

repo="janekbt/MeditationApp"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
asset() { jq -r --arg re "linux-$1\\.tar\\.gz$" --arg f "$2" '.assets[] | select(.name | test($re)) | .[$f]' <<<"$rel" | head -n1; }
url="$(asset x86_64 browser_download_url)"; size="$(asset x86_64 size)"
url_arm="$(asset aarch64 browser_download_url)"; size_arm="$(asset aarch64 size)"

[ -n "$version" ] && [ "$version" != "null" ] || { echo "failed to resolve Meditate release" >&2; exit 1; }
[ -n "$url" ] && [ -n "$url_arm" ] || { echo "release $version has no app tree for both arches yet" >&2; exit 1; }
echo "resolved Meditate $version ($date): $url" >&2

# size lets FlatPark notice a replaced file under the same version.
jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg ua "$url_arm" \
  --argjson s "$size" --argjson sa "$size_arm" \
  '{version:$v, releaseDate:$d, sources:[{filename:"meditate.tar.gz", arch:"x86_64", url:$u, size:$s}, {filename:"meditate.tar.gz", arch:"aarch64", url:$ua, size:$sa}]}'
