#!/usr/bin/env bash
# Update resolver for FlClash.
#
# Prints the latest version, release date and the official Linux amd64 .deb as
# JSON on stdout; logs go to stderr. Hashing and manifest rewriting are handled
# by FlatPark's update automation.
#
# Each release ships amd64 and arm64 builds of the AppImage, .deb and .rpm
# alongside the Windows and macOS ones. The amd64 .deb is matched on its name,
# never assembled from the tag, and an ambiguous match is an error rather than
# a silent first-match. Only the amd64 build is pinned: the ayatana tray stack
# this package needs is prebuilt for x86_64 alone, so the app stays x86_64-only
# until a gnome-51 aarch64 stack exists.
set -euo pipefail

repo="chen08209/FlClash"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r '[.assets[] | select(.name | test("^FlClash-.*-linux-amd64\\.deb$")) | .browser_download_url]
              | if length == 1 then .[0] else empty end' <<<"$rel")"

[ -n "$version" ] && [ -n "$date" ] && [ -n "$url" ] || {
  echo "failed to resolve FlClash release" >&2
  exit 1
}
echo "resolved FlClash $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"app.deb", arch:"x86_64", url:$u}]}'
