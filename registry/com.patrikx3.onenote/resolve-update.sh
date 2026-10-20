#!/usr/bin/env bash
# Update resolver for P3X OneNote.
#
# Prints the latest version, release date and the official Linux x86_64
# AppImage as JSON on stdout; logs go to stderr. Hashing and manifest rewriting
# are handled by FlatPark's update automation.
set -euo pipefail

repo="patrikx3/onenote"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

# releases/latest excludes prereleases and drafts.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The x86_64 build is `P3X-OneNote-<version>.AppImage`; the arm build is
# `-arm64.AppImage`. Match exactly one name with no arch suffix, so an
# ambiguous release is an error rather than a silent first match.
url="$(jq -r '[.assets[] | select(.name | test("^P3X-OneNote-[0-9.]+\\.AppImage$")) | .browser_download_url]
              | if length == 1 then .[0] else empty end' <<<"$rel")"

[ -n "$version" ] && [ -n "$date" ] && [ -n "$url" ] || {
  echo "failed to resolve P3X OneNote release" >&2
  exit 1
}
echo "resolved P3X OneNote $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"app.AppImage", url:$u}]}'
