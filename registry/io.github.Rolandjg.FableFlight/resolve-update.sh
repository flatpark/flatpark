#!/usr/bin/env bash
# Update resolver for Fable Flight.
#
# Prints the latest GitHub release and its Linux x86_64 and arm64 tarballs as
# JSON on stdout; logs go to stderr.
set -euo pipefail

repo="Rolandjg/fableflight"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Anchored on the full name: the release also carries macOS and Windows builds.
asset() { jq -r --arg n "fableflight-v$version-linux-$1.tar.gz" \
            '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel"; }
x64="$(asset x86_64)"
arm="$(asset arm64)"

[ -n "$version" ] && [ -n "$x64" ] && [ -n "$arm" ] || { echo "failed to resolve fableflight release" >&2; exit 1; }
echo "resolved fableflight $version ($date)" >&2

jq -n --arg v "$version" --arg d "$date" --arg x "$x64" --arg a "$arm" \
  '{version:$v, releaseDate:$d, sources:[
     {filename:"fableflight.tar.gz", arch:"x86_64", url:$x},
     {filename:"fableflight.tar.gz", arch:"aarch64", url:$a}]}'
