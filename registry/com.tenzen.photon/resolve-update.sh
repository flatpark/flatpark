#!/usr/bin/env bash
# Update resolver for Photon Studio.
#
# Prints the current version + the Linux x86_64 AppImage as JSON on stdout:
#   { "version": "0.1.35", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "photon.AppImage", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

api="https://tenzen.studio/api/v1/photon"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# The same endpoint the download page reads ("Version x.y.z"). It serves the
# stable channel only.
rel="$(curl -fsSL "$api/releases/latest")"
version="$(jq -r '.version // empty' <<<"$rel")"
jq -e '.targets[] | select(.platform == "linux" and .arch == "x64") | .formats | index("appimage")' \
    <<<"$rel" >/dev/null || { echo "no linux/x64 AppImage in the latest Photon release" >&2; exit 1; }

# The download button is a redirect to the versioned file on
# downloads.tenzen.studio; follow it rather than assembling the URL, so a change
# to upstream's file naming is picked up instead of guessed at. The version in
# the resolved URL must match the one the API reported.
url="$(curl -fsS -o /dev/null -w '%{redirect_url}' \
        "$api/download?platform=linux&arch=x64&kind=appimage")"
case "$url" in
    https://*/"$version"/*.AppImage) ;;
    *) echo "unexpected Photon download URL for $version: '$url'" >&2; exit 1 ;;
esac

# The API carries no release date; the file's Last-Modified is when it was
# published.
lm="$(curl -fsSI "$url" | sed -n 's/^[Ll]ast-[Mm]odified: *//p' | tr -d '\r')"
date="$(date -u -d "$lm" +%Y-%m-%d)"

[ -n "$version" ] && [ -n "$date" ] || { echo "failed to resolve photon release" >&2; exit 1; }
echo "resolved photon $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"photon.AppImage", url:$u}]}'
