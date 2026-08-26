#!/usr/bin/env bash
# Update resolver for Wealthfolio.
#
# Prints the latest version, release date and the official Linux x86_64 .deb as
# JSON on stdout; logs go to stderr. Hashing and manifest rewriting are handled
# by FlatPark's update automation.
#
# The URL is read from the GitHub releases API, never assembled from the tag.
# The release carries a long asset list — arm64 .deb, rpm, AppImage, .dmg,
# .msi, the separate self-hosted server tarball and a .sig for nearly every one
# of them — so the amd64 .deb is matched exactly and an ambiguous match is an
# error rather than a silent first-match.
set -euo pipefail

repo="wealthfolio/wealthfolio"

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
  echo "failed to resolve Wealthfolio release" >&2
  exit 1
}
echo "resolved Wealthfolio $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"wealthfolio.deb", url:$u}]}'
