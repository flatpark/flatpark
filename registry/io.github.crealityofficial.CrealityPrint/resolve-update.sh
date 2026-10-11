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
# Release name is accepted; a release that drops the plain build fails instead
# of shipping a variant.
#
# A release can carry several plain builds: v7.3.0 has .6149, .6151 and .6157,
# re-uploaded fixes under the same tag. The highest build is the current one,
# and the version reported is <tag>.<build>, so a later re-upload under the
# same tag still counts as an update.
set -euo pipefail

repo="CrealityOfficial/CrealityPrint"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

tag="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
asset="$(jq -c --arg t "$tag" '
  [.assets[]
   | (.name | capture("^CrealityPrint-V(?<v>[0-9.]+)-x86_64-Release\\.AppImage$")) as $m
   | select($m.v | startswith($t + "."))
   | {build: ($m.v | ltrimstr($t + ".") | tonumber), v: $m.v, url: .browser_download_url}]
  | sort_by(.build) | last // empty' <<<"$rel")"
version="$(jq -r '.v // empty' <<<"${asset:-null}")"
url="$(jq -r '.url // empty' <<<"${asset:-null}")"

[ -n "$version" ] && [ -n "$date" ] && [ -n "$url" ] || {
  echo "failed to resolve CrealityPrint release" >&2
  exit 1
}
echo "resolved CrealityPrint $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"crealityprint.AppImage", url:$u}]}'
