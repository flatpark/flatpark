#!/usr/bin/env bash
# Update resolver for CrealityPrint.
#
# Prints the latest version, release date and the official Linux x86_64
# AppImage as JSON on stdout; logs go to stderr. Hashing and manifest rewriting
# are handled by FlatPark's update automation.
#
# Releases are tagged v<version>. Asset names have varied a lot between
# releases: alongside the plain build,
# CrealityPrint-V<version>.<build>-x86_64-Release.AppImage, some releases carry
# distro-specific (ubuntu2204/ubuntu2404), Wayland or Flatpak-tuned Beta
# AppImages, sometimes with a newer build number than the tag. Only the plain
# Release name is accepted, and it must match exactly once; anything else is an
# error rather than a silent first-match, so a release that drops the plain
# build holds the pin instead of shipping a variant.
set -euo pipefail

repo="CrealityOfficial/CrealityPrint"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r '[.assets[] | select(.name | test("^CrealityPrint-V[0-9.]+-x86_64-Release\\.AppImage$")) | .browser_download_url]
              | if length == 1 then .[0] else empty end' <<<"$rel")"

[ -n "$version" ] && [ -n "$date" ] && [ -n "$url" ] || {
  echo "failed to resolve CrealityPrint release" >&2
  exit 1
}
echo "resolved CrealityPrint $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"crealityprint.AppImage", url:$u}]}'
