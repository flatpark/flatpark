#!/usr/bin/env bash
# Update resolver for GoldenCheetah.
#
# Prints the latest version, release date and the official Linux x86_64
# AppImage as JSON on stdout; logs go to stderr. Hashing and manifest rewriting
# are handled by FlatPark's update automation.
#
# Releases are tagged v<version> (v3.8, v3.7-SP1). The Linux build is
# GoldenCheetah_v<version>_x64.AppImage; one past release (v3.7-SP1) instead
# shipped two variants, _x64Qt5 and _x64Qt6. The plain name is taken when
# present, otherwise the Qt 6 variant — the bundle this package's wrapper and
# permissions are written for. Anything else, or more than one match at the
# chosen tier, is an error rather than a silent first-match.
set -euo pipefail

repo="GoldenCheetah/GoldenCheetah"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
pick() {
  jq -r --arg re "$1" '[.assets[] | select(.name | test($re)) | .browser_download_url]
                       | if length == 1 then .[0] else empty end' <<<"$rel"
}
url="$(pick '^GoldenCheetah_v[^/]*_x64\.AppImage$')"
[ -n "$url" ] || url="$(pick '^GoldenCheetah_v[^/]*_x64Qt6\.AppImage$')"

[ -n "$version" ] && [ -n "$date" ] && [ -n "$url" ] || {
  echo "failed to resolve GoldenCheetah release" >&2
  exit 1
}
echo "resolved GoldenCheetah $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"goldencheetah.AppImage", url:$u}]}'
