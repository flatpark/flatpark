#!/usr/bin/env bash
# Resolve the latest Helium Linux tarballs.
#
# The resolver only discovers URLs and release metadata. FlatPark's
# update-pins.mjs downloads each archive and computes its sha256 and size.
set -euo pipefail

repo="imputnet/helium-linux"
api="https://api.github.com/repos/$repo/releases/latest"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} "$api")"
version="$(jq -r '.tag_name' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"

url_for() {
    local arch="$1"
    jq -r --arg name "helium-${version}-${arch}_linux.tar.xz" \
        '.assets[] | select(.name == $name) | .browser_download_url' <<<"$rel" | head -n1
}

x86_64="$(url_for x86_64)"
arm64="$(url_for arm64)"
[ -n "$version" ] && [ -n "$x86_64" ] && [ -n "$arm64" ] \
    || { echo "latest release has no complete Helium Linux tarball set" >&2; exit 1; }

echo "resolved Helium $version ($date)" >&2
jq -n --arg v "$version" --arg d "$date" --arg x "$x86_64" --arg a "$arm64" \
    '{version:$v, releaseDate:$d, sources:[
      {filename:"helium-x86_64.tar.xz", url:$x},
      {filename:"helium-arm64.tar.xz", url:$a}
    ]}'
