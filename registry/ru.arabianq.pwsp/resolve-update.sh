#!/usr/bin/env bash
# Update resolver for PipeWire Soundpad: the latest GitHub release and its two
# Linux zips (x86_64 and aarch64). Prints { "version", "releaseDate",
# "sources": [...] } on stdout; logs go to stderr. FlatPark reads the sha256 and
# size of each asset from the releases API and pins them itself.
set -euo pipefail

repo="arabianq/pipewire-soundpad"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# One `pwsp-v<version>-linux-<arch>.zip` per architecture. The .deb, the
# .flatpak bundles and the other assets are not used.
url_x64="$(jq -r '.assets[] | select(.name | test("^pwsp-v[0-9][^/]*-linux-x64\\.zip$")) | .browser_download_url' <<<"$rel" | head -n1)"
url_arm="$(jq -r '.assets[] | select(.name | test("^pwsp-v[0-9][^/]*-linux-arm64\\.zip$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ "$version" != "null" ] && [ -n "$url_x64" ] && [ -n "$url_arm" ] \
  || { echo "failed to resolve PipeWire Soundpad release" >&2; exit 1; }
echo "resolved PipeWire Soundpad $version ($date): $url_x64" >&2

jq -n --arg v "$version" --arg d "$date" --arg ux "$url_x64" --arg ua "$url_arm" \
  '{version:$v, releaseDate:$d, sources:[
      {filename:"pwsp.zip", arch:"x86_64",  url:$ux},
      {filename:"pwsp.zip", arch:"aarch64", url:$ua}]}'
