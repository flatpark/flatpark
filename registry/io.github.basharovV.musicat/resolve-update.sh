#!/usr/bin/env bash
# Update resolver for Musicat.
#
# Prints the latest version, release date and the official Linux x86_64 .deb as
# JSON on stdout; logs go to stderr. Hashing and manifest rewriting are handled
# by FlatPark's update automation.
#
# The download URL is never assembled from the tag — it is read from the GitHub
# releases API. The release also ships an AppImage, an rpm, macOS .app tarballs,
# .dmg and .msi builds, so the asset is matched exactly on the amd64 .deb suffix
# and an ambiguous match is an error rather than a silent first-match.
set -euo pipefail

repo="basharovV/musicat"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r '[.assets[] | select(.name | test("_amd64\\.deb$")) | .browser_download_url]
              | if length == 1 then .[0] else empty end' <<<"$rel")"

[ -n "$version" ] && [ -n "$date" ] && [ -n "$url" ] || {
  echo "failed to resolve Musicat release" >&2
  exit 1
}
echo "resolved Musicat $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"musicat.deb", url:$u}]}'
