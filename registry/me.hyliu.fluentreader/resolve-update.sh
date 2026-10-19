#!/usr/bin/env bash
# Update resolver for Fluent Reader.
#
# Prints the latest version, release date and the Linux x86_64 AppImage as JSON
# on stdout; logs go to stderr. Hashing and manifest rewriting are handled by
# FlatPark's update automation.
#
# Each release carries `Fluent.Reader.<ver>.AppImage` next to the macOS dmg,
# the Windows installer and a Windows "Unpacked" zip. The AppImage is matched
# on its full name pattern, and an ambiguous match is an error rather than a
# silent first-match.
set -euo pipefail

repo="yang991178/fluent-reader"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# releases/latest excludes prereleases and drafts, so this tracks the stable
# channel.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r '[.assets[] | select(.name | test("^Fluent\\.Reader\\.[0-9][0-9.]*\\.AppImage$")) | .browser_download_url]
              | if length == 1 then .[0] else empty end' <<<"$rel")"

[ -n "$version" ] && [ -n "$date" ] && [ -n "$url" ] || {
  echo "failed to resolve Fluent Reader release" >&2
  exit 1
}
echo "resolved Fluent Reader $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"fluent-reader.AppImage", url:$u}]}'
