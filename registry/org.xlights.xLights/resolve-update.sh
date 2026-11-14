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

# Walk the recent releases instead of taking releases/latest. Two reasons:
#  - xLights keeps a permanently-updating `nightly` prerelease at the top of the
#    list; dropping drafts/prereleases keeps us on the ~fortnightly stable tags
#    (2026.17, 2026.16, …) instead of nightly builds.
#  - The Linux AppImage is not guaranteed to land with the release: 2026.20 went
#    out with only the Windows and macOS assets (flatpark#1173). Picking the
#    newest stable release that actually carries the AppImage keeps us on the
#    last Linux build instead of failing, and picks the new one up if it is
#    uploaded later.
# Tags are bare calendar versions with no `v` prefix (2026.17); ltrimstr is a
# no-op guard in case that ever changes. The lone Linux asset is
# xLights-<version>-x86_64.AppImage; anchoring on both the arch infix and the
# extension keeps this off the Windows .exe/.map, the macOS .zip and the .snap,
# which all carry the same version string.
best="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases?per_page=30" | jq '
  [ .[] | select((.draft or .prerelease) | not)
        | select(.tag_name | ltrimstr("v") | test("^[0-9]+(\\.[0-9]+)*$"))
        | { ver: (.tag_name | ltrimstr("v")),
            date: (.published_at | .[0:10]),
            urls: [ .assets[] | select(.name | test("-x86_64\\.AppImage$")) | .browser_download_url ] }
        | select(.urls | length > 0) ]
  | max_by(.ver | split(".") | map(tonumber)) // empty')"

[ -n "$best" ] || { echo "failed to resolve xlights release" >&2; exit 1; }
version="$(jq -r '.ver' <<<"$best")"
date="$(jq -r '.date' <<<"$best")"
url="$(jq -r '.urls[]' <<<"$best")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve xlights release" >&2; exit 1; }
[ "$(wc -l <<<"$url")" -eq 1 ] || { echo "expected exactly one x86_64 AppImage asset, got:" >&2; echo "$url" >&2; exit 1; }
echo "resolved xlights $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"xlights.AppImage", url:$u}]}'
