#!/usr/bin/env bash
# Update resolver for xLights.
#
# Prints the current version + the Linux x86_64 AppImage as JSON on stdout:
#   { "version": "2026.17", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "xlights.AppImage", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# Only xlights.AppImage is resolved here; appimage-tools.tar.xz is pinned by
# hand outside the managed block in the manifest.
set -euo pipefail

repo="xLightsSequencer/xLights"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# releases/latest excludes prereleases and drafts. That matters more than usual
# here: xLights keeps a permanently-updating `nightly` prerelease at the top of
# the releases list, so anything that just took the newest release would track
# nightly builds instead of the ~fortnightly stable tags (2026.17, 2026.16, …).
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

# Tags are bare calendar versions with no `v` prefix (2026.17); ltrimstr is a
# no-op guard in case that ever changes.
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The lone Linux asset: xLights-<version>-x86_64.AppImage. Anchoring on both the
# arch infix and the extension keeps this off the Windows .exe/.map, the macOS
# .zip and the .snap, which all carry the same version string.
url="$(jq -r '.assets[] | select(.name | test("-x86_64\\.AppImage$")) | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve xlights release" >&2; exit 1; }
[ "$(wc -l <<<"$url")" -eq 1 ] || { echo "expected exactly one x86_64 AppImage asset, got:" >&2; echo "$url" >&2; exit 1; }
echo "resolved xlights $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"xlights.AppImage", url:$u}]}'
