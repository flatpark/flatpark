#!/usr/bin/env bash
# Update resolver for Beeper.
#
# Prints the current version + the Linux x86_64 and arm64 AppImages as JSON on
# stdout:
#   { "version": "4.3.264", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "beeper.AppImage", "arch": "x86_64", "url": "..." },
#                  { "filename": "beeper.AppImage", "arch": "aarch64", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# Beeper's own download endpoints for the stable Linux channel answer with a
# redirect to the versioned AppImage on its download host, one per arch.
resolve() { # arch as the endpoint names it: x64 | arm64
  curl -fsS -o /dev/null -w '%{redirect_url}' \
    "https://api.beeper.com/desktop/download/linux/$1/stable/com.automattic.beeper.desktop"
}
url_x64="$(resolve x64)"
url_arm="$(resolve arm64)"

# Matched on the full versioned name, so a different arch or format behind an
# endpoint fails here instead of being pinned.
re_x64='^https://beeper-desktop\.download\.beeper\.com/builds/Beeper-([0-9]+(\.[0-9]+)+)-x86_64\.AppImage$'
re_arm='^https://beeper-desktop\.download\.beeper\.com/builds/Beeper-([0-9]+(\.[0-9]+)+)-arm64\.AppImage$'
[[ "$url_x64" =~ $re_x64 ]] || { echo "unexpected x86_64 URL: '$url_x64'" >&2; exit 1; }
version="${BASH_REMATCH[1]}"
[[ "$url_arm" =~ $re_arm ]] || { echo "unexpected arm64 URL: '$url_arm'" >&2; exit 1; }
# One version for both arches: if arm64 lags, hold the pin rather than mix.
[ "${BASH_REMATCH[1]}" = "$version" ] || { echo "x86_64 is $version but arm64 is ${BASH_REMATCH[1]}" >&2; exit 1; }

# No release feed: the file's Last-Modified is when the build was published.
modified="$(curl -fsSI "$url_x64" | tr -d '\r' | sed -n 's/^[Ll]ast-[Mm]odified: //p' | head -n1)"
date="$(date -u -d "$modified" +%F 2>/dev/null || date -u +%F)"

echo "resolved beeper $version ($date): $url_x64 $url_arm" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url_x64" --arg ua "$url_arm" \
  '{version:$v, releaseDate:$d, sources:[{filename:"beeper.AppImage", arch:"x86_64", url:$u}, {filename:"beeper.AppImage", arch:"aarch64", url:$ua}]}'
