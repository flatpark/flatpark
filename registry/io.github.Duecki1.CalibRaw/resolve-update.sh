#!/usr/bin/env bash
# Update resolver for CalibRaw.
#
# Prints the latest version, release date and the official Linux AppImage
# as JSON on stdout; logs go to stderr. Hashing and manifest rewriting
# are handled by FlatPark's update automation.
#
# Releases are tagged v<version> (v1.2.1, v1.2.0, etc.). The Linux builds are
# CalibRaw-v<version>-<arch>.AppImage for both x86_64 and aarch64.
set -euo pipefail

repo="Duecki1/CalibRaw"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"

# Resolve both x86_64 and aarch64 AppImages
pick() {
  local arch_pattern="$1"
  jq -r --arg re "$arch_pattern" '[.assets[] | select(.name | test($re)) | .browser_download_url]
                       | if length == 1 then .[0] else empty end' <<<"$rel"
}

url_x86_64="$(pick '^CalibRaw-v[^/]*-x86_64\\.AppImage$')"
url_aarch64="$(pick '^CalibRaw-v[^/]*-aarch64\\.AppImage$')"

[ -n "$version" ] && [ -n "$date" ] || {
  echo "failed to resolve CalibRaw version or date" >&2
  exit 1
}

# At least one arch must be found
[ -n "$url_x86_64" ] || [ -n "$url_aarch64" ] || {
  echo "failed to resolve CalibRaw AppImage URLs" >&2
  exit 1
}

echo "resolved CalibRaw $version ($date): x86_64=$url_x86_64 aarch64=$url_aarch64" >&2

# Build sources array - only include arches that have URLs
sources=()
[ -n "$url_x86_64" ] && sources+=("{filename:\"CalibRaw-x86_64.AppImage\", url:\"$url_x86_64\"}")
[ -n "$url_aarch64" ] && sources+=("{filename:\"CalibRaw-aarch64.AppImage\", url:\"$url_aarch64\"}")

# Use jq to build the final JSON
sources_json=$(printf '%s' "${sources[@]}" | jq -s 'join(", ")')

jq -n --arg v "$version" --arg d "$date" --argjson s "$sources_json" \
  '{version:$v, releaseDate:$d, sources:$s}'
