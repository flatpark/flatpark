#!/usr/bin/env bash
# Update resolver for Rayburst.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "4.0.0-beta.2", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "rayburst.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# Newest release of any kind, prereleases included — hence /releases rather than
# /releases/latest, which skips them. The 4.x line that carries the Rayburst name
# is still in beta (upstream renamed the project in v4.0.0-beta.1), so tracking
# stable only would leave this package with nothing to pin. The 3.9.x stable line
# still ships under the former name and is packaged separately as
# com.motrix.next. Revisit this when 4.x has a stable release: at that point this
# should most likely go back to /releases/latest.
set -euo pipefail

repo="AnInsomniacy/rayburst"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

releases="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases?per_page=100")"

# Sort by published_at rather than trusting list order, and skip drafts — a draft
# is not downloadable and would resolve to a dead URL.
rel="$(jq -c '[.[] | select(.draft | not)] | sort_by(.published_at) | last' <<<"$releases")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Match the asset by its exact name. Each release also carries the arm64 .deb,
# both .rpm builds, the AppImages, the macOS/Windows bundles and a detached .sig
# for most of them, and a loose suffix match would let sort order decide.
url="$(jq -r --arg v "$version" \
  '.assets[] | select(.name == ("Rayburst_" + $v + "_amd64.deb")) | .browser_download_url' <<<"$rel")"

if [ -z "$version" ] || [ -z "$url" ]; then
    echo "failed to resolve a Rayburst_*_amd64.deb for $version" >&2
    echo "Releases before v4.0.0-beta.1 are named MotrixNext_*_amd64.deb and" >&2
    echo "belong to com.motrix.next, not here." >&2
    exit 1
fi
echo "resolved rayburst $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"rayburst.deb", url:$u}]}'
