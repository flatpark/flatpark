#!/usr/bin/env bash
# Update resolver for Hermes Light.
#
# Upstream (NousResearch/hermes-agent) publishes no Linux desktop packages
# (#98171); tunix/homebrew-tap builds the light variant from each upstream tag
# and publishes it as a hermes-desktop-v<version> release. Prints that build as
# JSON on stdout:
#   { "version": "0.22.5", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "hermes-light.AppImage", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="tunix/homebrew-tap"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# The tap hosts releases for several packages; only the hermes-desktop-v* tags
# carry the Hermes Light artifact. A catch-up run can publish an older version
# after a newer one is already out, so the newest is chosen by version, not by
# the releases API's publish-date order.
rels="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases?per_page=100")"

rel="$(jq -c 'map(select(.tag_name | test("^hermes-desktop-v[0-9]")))
              | sort_by(.tag_name | sub("^hermes-desktop-v"; "") | split(".") | map(tonumber))
              | last' <<<"$rels")"
[ -n "$rel" ] && [ "$rel" != "null" ] || { echo "no hermes-desktop-v* release found on $repo" >&2; exit 1; }

version="$(jq -r '.tag_name | ltrimstr("hermes-desktop-v")' <<<"$rel")"
date="$(jq -r '.published_at // .created_at' <<<"$rel" | cut -c1-10)"
# Anchored match with the arch: electron-builder names the asset
# HermesLight-<version>-linux-x86_64.AppImage; a loose pattern would pick
# whichever variant sorts first if upstream adds one.
url="$(jq -r '[.assets[] | select(.name | test("^HermesLight-[0-9][0-9.]*-linux-x86_64\\.AppImage$"))][0].browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] && [ "$url" != "null" ] \
    || { echo "failed to resolve a Hermes Light AppImage on $repo" >&2; exit 1; }
echo "resolved Hermes Light $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"hermes-light.AppImage", url:$u}]}'
