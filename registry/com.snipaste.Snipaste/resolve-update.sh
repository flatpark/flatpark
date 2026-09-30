#!/usr/bin/env bash
# Update resolver for Snipaste.
#
# Prints the current version + the Linux x86_64 AppImage as JSON on stdout:
#   { "version": "2.11.3", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "snipaste.AppImage", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# Snipaste is closed source with no release feed and no repository, but the
# download page's own "Linux" button is a stable redirector:
# dl.snipaste.com/linux answers 302 with the versioned archive URL, e.g.
#   https://download.snipaste.com/archives/Snipaste-2.11.3-x86_64.AppImage
# and upstream keeps older archives in place, so a pinned URL stays valid. The
# version is read out of that filename; the release date comes from the
# download page's own table and is omitted if that table changes shape.
#
# Only snipaste.AppImage is resolved here; appimage-tools.tar.xz is pinned by
# hand outside the managed block in the manifest.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# One hop only: -I without -L, so this reads the redirector's own Location
# rather than following it to the file.
location="$(curl -fsSI https://dl.snipaste.com/linux \
              | awk 'BEGIN{IGNORECASE=1} /^location:/{print $2}' | tr -d '\r' | tail -n1)"
[ -n "$location" ] || { echo "dl.snipaste.com/linux did not redirect" >&2; exit 1; }

case "$location" in
    https://download.snipaste.com/archives/Snipaste-*-x86_64.AppImage) ;;
    *) echo "unexpected download URL: $location" >&2; exit 1 ;;
esac

version="${location##*/Snipaste-}"
version="${version%-x86_64.AppImage}"
[[ "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]] || { echo "could not read a version out of: $location" >&2; exit 1; }

# The download table lists one release-date cell per version, newest first, so
# the first YYYY/MM/DD after the "Release Date" header belongs to the release
# the redirector just pointed at. Best effort: a missing or reshaped table only
# costs the date attribute on the new <release> entry.
date=""
page="$(curl -fsSL https://www.snipaste.com/download.html || true)"
if [ -n "$page" ]; then
    raw="$(tr -d '\n' <<<"$page" \
            | sed -n 's/.*Release Date<\/th>//p' \
            | grep -oE '[0-9]{4}/[0-9]{2}/[0-9]{2}' | head -n1)"
    [ -n "$raw" ] && date="${raw//\//-}"
fi

echo "resolved snipaste $version (${date:-date unknown}): $location" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$location" \
  'if $d == "" then {version:$v, sources:[{filename:"snipaste.AppImage", url:$u}]}
   else {version:$v, releaseDate:$d, sources:[{filename:"snipaste.AppImage", url:$u}]} end'
