#!/usr/bin/env bash
# Update resolver for MotrixNext.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "3.9.7", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "motrix-next.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# Stable channel only. Upstream also publishes frequent `-beta.<n>` prereleases,
# and `/releases/latest` already excludes them, so the plain endpoint is what we
# want here — unlike the Motrix 2.x package, whose stable line has not moved
# since 2023.
#
# Upstream renamed the project to Rayburst in v4.0.0-beta.1 (2026-09-17): the repo
# is now AnInsomniacy/rayburst, the Tauri `identifier` went from com.motrix.next to
# dev.aninsomniacy.rayburst, `productName` from MotrixNext to Rayburst, and the
# asset from MotrixNext_<v>_amd64.deb to Rayburst_<v>_amd64.deb. **All of that is
# beta-only** — v3.9.9, the current stable and what this package ships, is still
# MotrixNext with identifier com.motrix.next.
#
# The 4.x line is packaged separately, under upstream's new identifier, as
# registry/dev.aninsomniacy.rayburst. This package stays on the 3.9.x stable line
# that still ships under the old name, so the asset match below stays strict on
# the MotrixNext name on purpose: a Rayburst payload under a MotrixNext listing
# would be wrong, and this resolver fails rather than quietly re-pinning one.
# Once upstream's stable channel has caught up to the new name, this package is
# de-listed rather than re-pinned.
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
  '.assets[] | select(.name == ("MotrixNext_" + $v + "_amd64.deb")) | .browser_download_url' <<<"$rel")"

if [ -z "$version" ] || [ -z "$url" ]; then
    echo "failed to resolve a MotrixNext_*_amd64.deb for stable $version." >&2
    echo "If that release is v4.0.0 or later it is the Rayburst rename, not a" >&2
    echo "broken resolver: that line lives in dev.aninsomniacy.rayburst, and" >&2
    echo "this package gets de-listed rather than re-pinned. See the header." >&2
    exit 1
fi
echo "resolved motrix-next $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"motrix-next.deb", url:$u}]}'
