#!/usr/bin/env bash
# Update resolver for CC Switch.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "4.0.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "cc-switch.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="farion1231/cc-switch"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# Highest version of any kind, prereleases included — hence /releases rather than
# /releases/latest, which skips them. The package tracks the 4.x line, which
# upstream still flags as a prerelease (v4.0.0); following stable only would pin
# it back to 3.20.x on the next refresh. Pick by version, not publish date, so a
# later 3.20.x backport cannot downgrade it either. Revisit once 4.x goes stable:
# /releases/latest is enough again then.
releases="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases?per_page=100")"

# Drafts are not downloadable and would resolve to a dead URL.
tag="$(jq -r '.[] | select(.draft | not) | .tag_name' <<<"$releases" | sort -V | tail -n1)"
rel="$(jq -c --arg t "$tag" '.[] | select(.tag_name == $t)' <<<"$releases")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The Linux x86_64 build is the `CC-Switch-v<version>-Linux-x86_64.deb` asset
# (the arm64 .deb, the .rpm/.AppImage and the macOS/Windows builds are skipped).
url="$(jq -r --arg v "$version" \
  '.assets[] | select(.name == ("CC-Switch-v" + $v + "-Linux-x86_64.deb")) | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve cc-switch release" >&2; exit 1; }
echo "resolved cc-switch $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"cc-switch.deb", url:$u}]}'
