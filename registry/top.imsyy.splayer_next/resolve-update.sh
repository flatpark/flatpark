#!/usr/bin/env bash
# Update resolver for SPlayer-Next.
#
# Prints the latest stable version, release date and the official Linux
# portable tarballs (x86_64 and aarch64) as JSON on stdout; logs go to stderr.
# Hashing and manifest rewriting are handled by FlatPark's update automation.
#
# The release ships both tarballs beside .deb/.rpm/.pacman/AppImage builds and
# electron-updater feed files. Each tarball is matched by an anchored pattern so
# the other variants and the other architecture are excluded.
set -euo pipefail

repo="SPlayer-Dev/SPlayer-Next"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url() {
    jq -r --arg re "$1" '[.assets[] | select(.name | test($re)) | .browser_download_url]
                         | if length == 1 then .[0] else empty end' <<<"$rel"
}
x64="$(url '^splayer-next-[^/]+-x64\.tar\.gz$')"
arm64="$(url '^splayer-next-[^/]+-arm64\.tar\.gz$')"

[ -n "$version" ] && [ -n "$date" ] && [ -n "$x64" ] && [ -n "$arm64" ] || {
    echo "failed to resolve SPlayer-Next release" >&2
    exit 1
}
echo "resolved SPlayer-Next $version ($date)" >&2
echo "  x86_64: $x64" >&2
echo "  aarch64: $arm64" >&2

jq -n --arg v "$version" --arg d "$date" --arg x "$x64" --arg a "$arm64" \
  '{version:$v, releaseDate:$d, sources:[
      {filename:"splayer-next.tar.gz", arch:"x86_64", url:$x},
      {filename:"splayer-next.tar.gz", arch:"aarch64", url:$a}]}'
