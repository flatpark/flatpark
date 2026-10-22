#!/usr/bin/env bash
# Update resolver for Epic Games Launcher.
#
# Epic's installer API answers the Linux download with a redirect to a
# versioned build on its CDN:
#   .../Builds/EGLv2/<version>+g<commit>/Linux/EpicGamesLauncher-x86_64.AppImage
# That versioned URL is what gets pinned; the version is the part before "+g".
# Prints the version + URL as JSON on stdout; logs go to stderr.
set -euo pipefail

api="https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncher-x86_64.AppImage"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

url="$(curl -fsS -o /dev/null -w '%{redirect_url}' "$api")"
case "$url" in
    https://*.epicgames.com/Builds/EGLv2/*/Linux/EpicGamesLauncher-x86_64.AppImage*) ;;
    *) echo "unexpected redirect from the installer API: '$url'" >&2; exit 1 ;;
esac
# Drop the query string (?launcherfilename=...); the path alone is the build.
url="${url%%\?*}"
build="$(sed -E 's#.*/Builds/EGLv2/([^/]+)/Linux/.*#\1#' <<<"$url")"
build="${build//%2B/+}"
version="${build%%+*}"
[[ "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]] || { echo "could not read a version from '$url'" >&2; exit 1; }
echo "resolved Epic Games Launcher $version ($build): $url" >&2

jq -n --arg v "$version" --arg u "$url" \
  '{version:$v, sources:[{filename:"epic.AppImage", url:$u}]}'
