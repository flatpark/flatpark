#!/usr/bin/env bash
# Update resolver for Rayburst.
#
# Prints the current version + the Linux x86_64 AppImage as JSON on stdout:
#   { "version": "4.0.1", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "rayburst.AppImage", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# Newest release with the amd64 AppImage, prereleases included. Upstream
# publishes `-beta.<n>` prereleases between stable versions; this package takes
# them too, so fixes for the Flatpak build (e.g. the sandboxed ksni tray in
# v4.1.3-beta.1, AnInsomniacy/rayburst#825) reach users without waiting for the
# next stable. A release whose assets are still uploading is skipped, so a
# fresh tag falls back to the previous release until its AppImage is there.
set -euo pipefail

repo="AnInsomniacy/rayburst"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

releases="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases?per_page=30")"

# Match the asset by its exact name. Each release also carries the aarch64
# AppImage, the .deb and .rpm builds, the macOS/Windows bundles and a detached
# .AppImage.sig beside each AppImage, and a loose suffix match would let sort
# order decide.
rel="$(jq '[ .[] | select(.draft == false)
             | (.tag_name | ltrimstr("v")) as $v
             | select(any(.assets[]; .name == ("Rayburst_" + $v + "_amd64.AppImage"))) ]
           | sort_by(.published_at) | last // empty' <<<"$releases")"

version="$(jq -r '.tag_name // "" | ltrimstr("v")' <<<"${rel:-null}")"
date="$(jq -r '.published_at // ""' <<<"${rel:-null}" | cut -c1-10)"
url="$(jq -r --arg v "$version" \
  '.assets[]? | select(.name == ("Rayburst_" + $v + "_amd64.AppImage")) | .browser_download_url' <<<"${rel:-null}")"

if [ -z "$version" ] || [ -z "$url" ]; then
    echo "failed to resolve a release with Rayburst_<version>_amd64.AppImage" >&2
    exit 1
fi
echo "resolved rayburst $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"rayburst.AppImage", url:$u}]}'
