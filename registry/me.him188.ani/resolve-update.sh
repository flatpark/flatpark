#!/usr/bin/env bash
# Update resolver for Animeko.
#
# Reads the newest stable release from GitHub. Upstream also has a
# release-info endpoint (https://danmaku-cn.myani.org/v1/updates/latest), but
# it is hosted in China and the CI runners often cannot reach it, so the
# sweep failed on a timeout (#1150). releases/latest skips the -betaNN tags.
# Prints the FlatPark resolver JSON on stdout; logs go to stderr.
set -euo pipefail

repo="open-ani/animeko"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name // empty | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at // empty' <<<"$rel" | cut -c1-10)"

[ -n "$version" ] && [ -n "$date" ] || { echo "failed to read the Animeko release" >&2; exit 1; }

# Stable releases only (6.4.0). Anything else is a prerelease or a layout change, not a pin.
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || { echo "unexpected Animeko version: $version" >&2; exit 1; }

# Match the exact asset name so the .sha1 and .zsync sidecars are never picked up.
url="$(jq -r --arg n "ani-${version}-linux-x86_64.appimage" \
        '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel")"
[ -n "$url" ] || { echo "Animeko $version has no Linux x86_64 AppImage" >&2; exit 1; }
echo "resolved Animeko $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"animeko.AppImage", url:$u}]}'
