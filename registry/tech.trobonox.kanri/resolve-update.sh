#!/usr/bin/env bash
# Resolve the latest official Kanri Linux x86_64 Debian release.
set -euo pipefail

repo="kanriapp/kanri"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

tag="$(jq -r '.tag_name' <<<"$rel")"
version="$(jq -r '.tag_name | sub("^app-v"; "") | sub("^v"; "")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The release also ships arm64/armhf .deb, rpm, AppImage, dmg and msi builds,
# so match the amd64 .deb exactly and treat an ambiguous match as an error
# rather than silently taking the first hit.
url="$(jq -r '[.assets[] | select(.name | test("_amd64\\.deb$")) | .browser_download_url]
              | if length == 1 then .[0] else empty end' <<<"$rel")"

[ -n "$tag" ] && [ -n "$version" ] && [ -n "$url" ] || {
  echo "failed to resolve Kanri release" >&2
  exit 1
}
echo "resolved Kanri $version from $tag ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"kanri.deb", url:$u}]}'
