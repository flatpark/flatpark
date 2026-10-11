#!/usr/bin/env bash
# Update resolver for Yaak.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "2026.4.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "yaak.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="mountain-loop/yaak"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# releases/latest excludes prereleases, so this tracks the stable channel (Yaak
# also publishes frequent betas as prereleases).
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The Linux x86_64 build we package is `yaak_<version>_amd64.deb` (the others are
# the arm64 .deb, the .rpm/.AppImage, and the macOS/Windows installers). Match it
# anchored at the start: upstream also publishes a second amd64 .deb from its CEF
# variant, `yaak-cef_<version>_amd64.deb`, which sorts first in the asset list and
# lays its tree out under a different name (usr/bin/yaak-cef, usr/lib/yaak-cef).
# This manifest, apply_extra and the wrapper all target the WebKitGTK build.
url="$(jq -r '.assets[] | select(.name | test("^yaak_[^/]*_amd64\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"
url_arm="$(jq -r '.assets[] | select(.name | test("^yaak_[^/]*_arm64\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"
[ -n "$url_arm" ] || { echo "no aarch64 build in this release" >&2; exit 1; }

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve yaak release" >&2; exit 1; }
echo "resolved yaak $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg ua "$url_arm" \
  '{version:$v, releaseDate:$d, sources:[{filename:"yaak.deb", arch:"x86_64", url:$u}, {filename:"yaak.deb", arch:"aarch64", url:$ua}]}'
