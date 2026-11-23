#!/usr/bin/env bash
# Update resolver for Impasto.
#
# Prints the current version + the x86_64 Linux self-contained zip as JSON on
# stdout; logs go to stderr. No hashing — FlatPark downloads the URL and computes
# the extra-data sha256/size at build time.
set -euo pipefail

repo="zbcoding/ImpastoPaint"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The Linux build is published as `Impasto-linux-dotnet-<sdk>.zip` (the other
# assets are the .dmg/.exe installers and the prebuilt .flatpak bundle).
url="$(jq -r '.assets[] | select(.name | test("^Impasto-linux-dotnet-.*\\.zip$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve impasto release" >&2; exit 1; }
echo "resolved impasto $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"impasto.zip", url:$u}]}'
