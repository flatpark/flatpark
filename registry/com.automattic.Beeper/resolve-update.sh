#!/usr/bin/env bash
# Update resolver for Beeper.
#
# Prints the current version + the Linux x86_64 AppImage as JSON on stdout:
#   { "version": "4.3.264", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "beeper.AppImage", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# Beeper's own download endpoint for the stable Linux x64 channel answers with a
# redirect to the versioned AppImage on its download host.
channel="https://api.beeper.com/desktop/download/linux/x64/stable/com.automattic.beeper.desktop"
url="$(curl -fsS -o /dev/null -w '%{redirect_url}' "$channel")"

# Matched on the full versioned name, so a different arch or format behind the
# same endpoint fails here instead of being pinned.
re='^https://beeper-desktop\.download\.beeper\.com/builds/Beeper-([0-9]+(\.[0-9]+)+)-x86_64\.AppImage$'
[[ "$url" =~ $re ]] || { echo "unexpected Beeper download URL: '$url'" >&2; exit 1; }
version="${BASH_REMATCH[1]}"

# No release feed: the file's Last-Modified is when the build was published.
modified="$(curl -fsSI "$url" | tr -d '\r' | sed -n 's/^[Ll]ast-[Mm]odified: //p' | head -n1)"
date="$(date -u -d "$modified" +%F 2>/dev/null || date -u +%F)"

echo "resolved beeper $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"beeper.AppImage", url:$u}]}'
