#!/usr/bin/env bash
# Update resolver for OpenShot.
#
# Prints the current version + the Linux x86_64 AppImage as JSON on stdout:
#   { "version": "4.0.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "openshot.AppImage", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# Only openshot.AppImage is resolved here; appimage-tools.tar.xz is pinned
# by hand outside the managed block in the manifest.
set -euo pipefail

repo="OpenShot/openshot-qt"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# releases/latest excludes prereleases and drafts, so this tracks the stable
# channel OpenShot publishes its AppImage on.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The lone x86_64 AppImage asset: OpenShot-v<version>-x86_64.AppImage (the other
# assets are the .exe / .dmg installers and the .torrent / .sha256sum sidecars).
url="$(jq -r '.assets[] | select(.name | test("-x86_64\\.AppImage$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve openshot release" >&2; exit 1; }
echo "resolved openshot $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"openshot.AppImage", url:$u}]}'
