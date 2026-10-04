#!/usr/bin/env bash
# Update resolver for Stoat.
#
# Prints the latest version, release date and the official Linux x86_64 zip as
# JSON on stdout; logs go to stderr. Hashing and manifest rewriting are handled
# by FlatPark's update automation.
#
# The release ships the Electron Forge zip (Stoat-linux-x64-<ver>.zip) next to
# an arm64 zip, x86_64/aarch64 AppImages and .flatpak bundles, and the
# macOS/Windows builds. It is matched on its full name pattern, never assembled
# from the tag, and an ambiguous match is an error rather than a silent
# first-match.
set -euo pipefail

repo="stoatchat/for-desktop"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r '[.assets[] | select(.name | test("^Stoat-linux-x64-[^/]*\\.zip$")) | .browser_download_url]
              | if length == 1 then .[0] else empty end' <<<"$rel")"

[ -n "$version" ] && [ -n "$date" ] && [ -n "$url" ] || {
  echo "failed to resolve Stoat release" >&2
  exit 1
}
echo "resolved Stoat $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"app.zip", url:$u}]}'
