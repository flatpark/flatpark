#!/usr/bin/env bash
# Resolve the latest stable release and both official Linux archives.
# Prints { version, releaseDate, sources } as JSON for FlatPark's pin updater.
set -euo pipefail

repo="flowsurface-rs/flowsurface"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
    "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -er '.tag_name | sub("^v"; "")' <<<"$rel")"
date="$(jq -er '.published_at[:10]' <<<"$rel")"

asset_url() {
    local name="$1" url
    url="$(jq -er --arg name "$name" \
        '[.assets[] | select(.name == $name) | .browser_download_url] | if length == 1 then .[0] else empty end' \
        <<<"$rel")" || {
        echo "expected exactly one $name asset in the latest $repo release" >&2
        exit 1
    }
    [ -n "$url" ] || { echo "missing $name asset in the latest $repo release" >&2; exit 1; }
    printf '%s' "$url"
}

x86_url="$(asset_url flowsurface-x86_64-linux.tar.gz)"
arm_url="$(asset_url flowsurface-aarch64-linux.tar.gz)"

echo "resolved Flowsurface $version ($date)" >&2
jq -n --arg v "$version" --arg d "$date" --arg x "$x86_url" --arg a "$arm_url" \
  '{version:$v, releaseDate:$d,
    sources:[
      {filename:"flowsurface-linux.tar.gz", arch:"x86_64", url:$x},
      {filename:"flowsurface-linux.tar.gz", arch:"aarch64", url:$a}
    ]}'
