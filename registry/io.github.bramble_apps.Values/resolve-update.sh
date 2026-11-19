#!/usr/bin/env bash
# Update resolver for Values: the latest Bramble Office release and its
# Values-x86_64.AppImage. Bramble Office releases all its apps together under one
# tag, so the four packages follow the same releases.
# Prints { "version", "releaseDate", "sources": [...] } on stdout; logs go to
# stderr. FlatPark reads the asset's digest and size from the releases API.
set -euo pipefail

repo="bramble-apps/bramble-office"
asset="Values-x86_64.AppImage"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# releases/latest is the newest non-prerelease.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The exact name: the same release also carries this app's .flatpak bundle,
# and the Bramble-Office tarball with every app in it.
url="$(jq -r --arg n "$asset" '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve values release" >&2; exit 1; }
echo "resolved values $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"values.AppImage", url:$u}]}'
