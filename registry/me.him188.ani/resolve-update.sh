#!/usr/bin/env bash
# Update resolver for Animeko.
#
# Upstream publishes the desktop build through its own release-info endpoint:
#   https://danmaku-cn.myani.org/v1/updates/latest
# It returns the stable version, a publish timestamp and a map of platform
# download URLs. We use the version to build the official GitHub release URL
# (the map's alternatives include a third-party mirror, which we do not pin),
# check that it exists, and print the FlatPark resolver JSON on stdout.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

meta="$(curl -fsSL https://danmaku-cn.myani.org/v1/updates/latest)"
version="$(jq -r '.version // empty' <<<"$meta")"
published="$(jq -r '.publishTime // empty' <<<"$meta")"

[ -n "$version" ] && [ -n "$published" ] || { echo "failed to read Animeko update info" >&2; exit 1; }
version="${version#v}"

# 6.4.0, or a prerelease suffix. Anything else is a layout change, not a pin.
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?$ ]] \
    || { echo "unexpected Animeko version: $version" >&2; exit 1; }

date="$(date -u -d "@$published" +%F)"
url="https://github.com/open-ani/animeko/releases/download/v${version}/ani-${version}-linux-x86_64.appimage"

curl -fsIL -o /dev/null --max-time 60 "$url" \
    || { echo "Animeko asset does not resolve: $url" >&2; exit 1; }
echo "resolved Animeko $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"animeko.AppImage", url:$u}]}'
