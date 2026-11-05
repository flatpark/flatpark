#!/usr/bin/env bash
# Update resolver for UU Remote Viewer.
#
# Prints the latest stable upstream release's version, release date and the
# official x86_64 Linux tarball as JSON on stdout; logs go to stderr. Hashing
# and manifest rewriting are FlatPark's job.
#
# The release carries x86_64 and aarch64 tarballs, .deb packages and .sha256
# files for each asset. This package is published for x86_64 only — the
# ffmpeg-full prebuilt stack it decodes with has no aarch64 build — so the
# anchored pattern selects the x86_64 tarball and excludes the checksum files
# and the other architecture.
set -euo pipefail

repo="VallierDev/uu-remote-linux"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r '[.assets[] | select(.name | test("^uu-remote-linux-v[0-9][0-9.]*-x86_64-linux\\.tar\\.gz$")) | .browser_download_url]
              | if length == 1 then .[0] else empty end' <<<"$rel")"

[ -n "$version" ] && [ -n "$date" ] && [ -n "$url" ] || {
    echo "failed to resolve the upstream release" >&2
    exit 1
}
echo "resolved $version ($date)" >&2
echo "  x86_64: $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"uu-remote-linux.tar.gz", url:$u}]}'
