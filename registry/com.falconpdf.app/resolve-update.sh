#!/usr/bin/env bash
# Update resolver for Falcon PDF.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "2026.09", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "falconpdf.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="avrapps/falcon-pdf-app"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

# The version is the tag (2026.09), which is what upstream calls the release;
# the file names carry a semver spelling of it (2026.9.0).
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Exact bundle name pattern: the release also carries the .rpm, .pacman,
# AppImage, a .flatpak bundle and the Android/macOS/Windows builds.
url="$(jq -r '.assets[] | select(.name | test("^falconpdf-[0-9][0-9.]*-linux-amd64\\.deb$")) | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve falconpdf release" >&2; exit 1; }
[ "$(wc -l <<<"$url")" -eq 1 ] || { echo "expected exactly one amd64 .deb asset, got:" >&2; echo "$url" >&2; exit 1; }
echo "resolved falconpdf $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"falconpdf.deb", url:$u}]}'
