#!/usr/bin/env bash
# Update resolver for OpenCloud Desktop.
#
# Prints the current version + the Linux x86_64 AppImage as JSON on stdout.
# Logs go to stderr. No hashing, no manifest rewriting: FlatPark downloads the
# URL and computes the extra-data sha256/size itself.
set -euo pipefail

repo="opencloud-eu/desktop"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# releases/latest excludes prereleases (upstream tags release candidates as
# -rc.N prereleases) and drafts.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

tag="$(jq -r '.tag_name' <<<"$rel")"
version="${tag#v}"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Exactly OpenCloud_Desktop-<tag>-linux-gcc-x86_64.AppImage: not its .sha256,
# nor the macOS packages.
url="$(jq -r --arg n "OpenCloud_Desktop-$tag-linux-gcc-x86_64.AppImage" \
  '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ "$tag" != null ] && [ -n "$url" ] || { echo "failed to resolve OpenCloud Desktop release" >&2; exit 1; }
echo "resolved OpenCloud Desktop $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"opencloud.AppImage", url:$u}]}'
