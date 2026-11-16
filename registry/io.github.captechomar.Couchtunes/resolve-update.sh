#!/usr/bin/env bash
# Update resolver for Couchtunes.
#
# Prints the latest stable release + its Linux x86_64 AppImage as JSON on stdout:
#   { "version": "2.16.7", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "couchtunes.AppImage", "url": "..." } ] }
# Logs go to stderr. GitHub's API carries the asset's sha256 and size, so
# update-pins pins it without a download.
#
# Stable releases only: upstream runs its own beta channel and asked FlatPark
# to follow stable releases (flatpark#1286). releases/latest never points at a
# prerelease or a draft, so a `vX.Y.Z-beta.N` ping resolves to the current
# stable release and changes nothing.
set -euo pipefail

repo="CaptechOmar/Couchtunes"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name // empty | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# `Couchtunes-<version>-linux-x86_64.AppImage`. Anchored on the full shape so a
# zsync file or another arch is never picked.
url="$(jq -r '.assets[] | select(.name | test("^Couchtunes-[0-9][0-9.]*-linux-x86_64\\.AppImage$")) | .browser_download_url' <<<"$rel")"

# The latest release must carry the file. Falling back to an older release
# would look like a new version to update-pins (it only checks equality) and
# roll users back; a release whose AppImage isn't uploaded yet is retried on
# the next run instead.
[ -n "$version" ] || { echo "failed to read the couchtunes version" >&2; exit 1; }
[ "$(grep -c . <<<"$url")" = 1 ] || { echo "expected one Linux AppImage on couchtunes $version, found: ${url:-none}" >&2; exit 1; }
echo "resolved couchtunes $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"couchtunes.AppImage", url:$u}]}'
