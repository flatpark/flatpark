#!/usr/bin/env bash
# Update resolver for Hydra Launcher.
#
# Prints the latest release and its amd64 .deb as JSON on stdout. Logs go to
# stderr. FlatPark reads the asset's digest and size from the releases API.
set -euo pipefail

repo="hydralauncher/hydra"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Exact name: the release also carries the AppImage, .rpm, .snap and the
# Windows installers.
url="$(jq -r --arg v "$version" '.assets[] | select(.name == "hydralauncher_\($v)_amd64.deb") | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve Hydra release" >&2; exit 1; }
echo "resolved hydra $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"hydra.deb", url:$u}]}'
