#!/usr/bin/env bash
# Update resolver for PI-Desktop.
#
# Prints the current version + the x86_64 Linux .deb as JSON on stdout:
#   { "version": "0.15.6", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "pi-desktop.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="vastsa/PI-Desktop"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# releases/latest is the newest non-prerelease tag; PI-Desktop marks its stable
# releases as such, so preview/prerelease tags stay out of the pin.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The x86_64 Linux build is `pi-desktop_<ver>_amd64.deb`. Match it exactly so
# the .rpm/.AppImage assets and the macOS/Windows assets are all excluded.
url="$(jq -r '.assets[] | select(.name | test("^pi-desktop_[0-9.]+_amd64\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve PI-Desktop release" >&2; exit 1; }
echo "resolved PI-Desktop $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"pi-desktop.deb", url:$u}]}'
