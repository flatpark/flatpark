#!/usr/bin/env bash
# Update resolver for DaVinci Resolve (FlatPark packaging).
#
# Prints the current version + the installer bundle's x86_64 tarball as JSON on
# stdout:
#   { "version": "0.0.4", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "resolve-flatpak.tar.gz", "size": "…",
#                    "url": "…" } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size. The version is compared against
# the latest <release> in the AppStream metainfo.
#
# This tracks the resolve-flatpak project's releases, NOT Blackmagic's: the
# package's extra-data payload is the self-contained installer/launcher bundle
# built by that project, and the installer fetches DaVinci Resolve itself at
# first launch. appimage-tools.tar.xz and libglu1-mesa.deb are pinned by hand
# outside the managed block in the manifest.
#
# `size` is reported so a tarball re-uploaded under the same tag is detected and
# re-pinned (update-pins.mjs re-pins a source whose size no longer matches), and
# so a placeholder pin with a wrong size self-heals on the first run.
set -euo pipefail

repo="night199uk/resolve-flatpak"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# releases/latest excludes prereleases and drafts.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r '.assets[] | select(.name | test("^resolve-flatpak-.*-x86_64\\.tar\\.gz$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ "$version" != "null" ] && [ -n "$url" ] && [ "$url" != "null" ] \
    || { echo "failed to resolve resolve-flatpak release" >&2; exit 1; }
echo "resolved resolve-flatpak $version ($date): $url" >&2

# Content-Length of the asset (follows GitHub's redirect to the object host).
size="$(curl -fsSIL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} "$url" \
        | awk 'BEGIN{IGNORECASE=1} /^content-length:/{v=$2} END{gsub(/[^0-9]/,"",v); print v}')"
[ -n "$size" ] || { echo "failed to read Content-Length for $url" >&2; exit 1; }

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg s "$size" \
  '{version:$v, releaseDate:$d, sources:[{filename:"resolve-flatpak.tar.gz", url:$u, size:$s}]}'
