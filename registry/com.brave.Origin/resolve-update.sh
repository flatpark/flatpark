#!/usr/bin/env bash
# Resolve the latest stable Brave Origin Linux archives.
#
# The resolver only discovers URLs and release metadata. FlatPark's
# update-pins.mjs downloads each archive and computes its sha256 and size.
set -euo pipefail

repo="brave/brave-browser"
api="https://api.github.com/repos/$repo/releases/latest"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} "$api")"
tag="$(jq -r '.tag_name' <<<"$rel")"
version="${tag#v}"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"

url_for() {
    local arch="$1"
    jq -r --arg pattern "^brave-origin-${version}-linux-${arch}\\.zip$" \
        '.assets[] | select(.name | test($pattern)) | .browser_download_url' <<<"$rel" | head -n1
}

amd64="$(url_for amd64)"
arm64="$(url_for arm64)"
[ "$tag" != "$version" ] && [ -n "$amd64" ] && [ -n "$arm64" ] \
    || { echo "latest stable release has no complete Brave Origin Linux archive set" >&2; exit 1; }

echo "resolved Brave Origin $version ($date)" >&2
jq -n --arg v "$version" --arg d "$date" --arg x "$amd64" --arg a "$arm64" \
    '{version:$v, releaseDate:$d, sources:[
      {filename:"brave-origin-amd64.zip", url:$x},
      {filename:"brave-origin-arm64.zip", url:$a}
    ]}'
