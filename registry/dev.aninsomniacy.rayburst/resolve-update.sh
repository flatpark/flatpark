#!/usr/bin/env bash
# Update resolver for Rayburst.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "4.0.1", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "rayburst.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# Stable channel only, via /releases/latest. Upstream renamed Motrix Next to
# Rayburst in v4.0.0-beta.1 and the 4.x line was beta-only at first, so this
# used to take prereleases too; v4.0.0 made it the stable line, and upstream
# keeps publishing `-beta.<n>` prereleases that this package should not ship.
set -euo pipefail

repo="AnInsomniacy/rayburst"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Match the asset by its exact name. Each release also carries the arm64 .deb,
# both .rpm builds, the AppImages, the macOS/Windows bundles and a detached .sig
# for most of them, and a loose suffix match would let sort order decide.
url="$(jq -r --arg v "$version" \
  '.assets[] | select(.name == ("Rayburst_" + $v + "_amd64.deb")) | .browser_download_url' <<<"$rel")"

if [ -z "$version" ] || [ -z "$url" ]; then
    echo "failed to resolve a Rayburst_*_amd64.deb for $version" >&2
    exit 1
fi
echo "resolved rayburst $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"rayburst.deb", url:$u}]}'
