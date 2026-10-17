#!/usr/bin/env bash
# Update resolver for BlueShell: the latest stable GitHub release and its
# per-arch tarballs (the prebuilt /app tree; see tuna-os/blueshell#156).
# Prints { "version", "releaseDate", "sources": [...] } on stdout; logs go to
# stderr. FlatPark downloads the URLs and computes the sha256/size itself.
#
# Both arches are matched tightly (anchored name, arch, extension) and each
# must resolve to exactly one asset: a release missing aarch64 fails rather
# than silently shipping one arch behind.
set -euo pipefail

repo="tuna-os/blueshell"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | sub("^v";"")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r '[.assets[] | select(.name | test("^blueshell-x86_64\\.tar\\.gz$")) | .browser_download_url]
              | if length == 1 then .[0] else empty end' <<<"$rel")"
url_arm="$(jq -r '[.assets[] | select(.name | test("^blueshell-aarch64\\.tar\\.gz$")) | .browser_download_url]
              | if length == 1 then .[0] else empty end' <<<"$rel")"
[ -n "$url_arm" ] || { echo "no aarch64 build in this release" >&2; exit 1; }

[ -n "$version" ] && [ -n "$date" ] && [ -n "$url" ] || { echo "failed to resolve blueshell release" >&2; exit 1; }
echo "resolved blueshell $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg ua "$url_arm" \
  '{version:$v, releaseDate:$d, sources:[{filename:"blueshell.tar.gz", arch:"x86_64", url:$u}, {filename:"blueshell.tar.gz", arch:"aarch64", url:$ua}]}'
