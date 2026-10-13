#!/usr/bin/env bash
# Update resolver for Timezones: the latest GitHub release and its FlatPark
# tree, as JSON on stdout. Logs go to stderr; FlatPark does the hashing.
set -euo pipefail

repo="hernantz/timezones"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Each release also carries the .flatpak bundle; only the FlatPark tree is
# staged here, matched by its exact name.
url="$(jq -r --arg v "$version" \
  '.assets[] | select(.name == "timezones-\($v)-flatpark-x86_64.tar.xz") | .browser_download_url' \
  <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve the timezones release" >&2; exit 1; }
echo "resolved timezones $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"timezones.tar.xz", url:$u}]}'
