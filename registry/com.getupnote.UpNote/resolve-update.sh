#!/usr/bin/env bash
# Update resolver for UpNote.
#
# UpNote publishes one Linux build per format at a fixed path and ships the
# electron-updater feed next to it, so the feed is the version anchor and the
# download URL never changes:
#
#   https://download.getupnote.com/app/latest-linux.yml
#     version: 9.22.4
#     files:
#       - url: upnote_amd64.deb
#         size: 106532180
#     releaseDate: '2026-09-12T23:54:10.378Z'
#
# Prints the current version + the official amd64 Debian package URL:
#   { "version": "9.22.4", "releaseDate": "2026-09-12", "sources": [
#       { "filename": "upnote-amd64.deb", "url": "..." }
#   ] }
# Only an amd64 .deb (and an x86_64 AppImage/rpm of the same build) is
# published, so only x86_64 is packaged.
#
# Logs go to stderr. No hashing, no manifest rewriting - FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo. Because the
# URL is the same for every release, a re-pin is what keeps the pinned sha256
# matching the bytes the URL serves.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

base="https://download.getupnote.com/app"
feed="$base/latest-linux.yml"

yml="$(curl -fsSL "$feed")"

# Plain `key: value` scalars at the top level of the feed; strip the quotes
# electron-updater puts around the date.
version="$(printf '%s\n' "$yml" | sed -nE "s/^version:[[:space:]]*['\"]?([^'\"[:space:]]+)['\"]?[[:space:]]*$/\1/p" | head -n1)"
release_date="$(printf '%s\n' "$yml" | sed -nE "s/^releaseDate:[[:space:]]*['\"]?([0-9]{4}-[0-9]{2}-[0-9]{2}).*$/\1/p" | head -n1)"

[ -n "$version" ] || { echo "no version in $feed" >&2; exit 1; }

# The .deb has to be listed in the same feed entry, otherwise the build the feed
# describes is not the build behind the download link.
deb_name="$(printf '%s\n' "$yml" | sed -nE 's#^[[:space:]]*-[[:space:]]*url:[[:space:]]*([^[:space:]]+\.deb)[[:space:]]*$#\1#p' | head -n1)"
[ -n "$deb_name" ] || { echo "no .deb listed in $feed" >&2; exit 1; }

echo "resolved UpNote $version (${release_date:-no date}, $deb_name)" >&2

jq -n \
  --arg v "$version" \
  --arg d "$release_date" \
  --arg u "$base/$deb_name" \
  '{version:$v} + (if $d == "" then {} else {releaseDate:$d} end) + {sources:[{filename:"upnote-amd64.deb", url:$u}]}'
