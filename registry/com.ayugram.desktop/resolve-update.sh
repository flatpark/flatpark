#!/usr/bin/env bash
# Update resolver for AyuGram.
#
# Upstream publishes no Linux binary; flatpark/ayugram-release builds one from
# each upstream tag on GitHub Actions. Prints that build as JSON on stdout:
#   { "version": "7.0.9", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "ayugram.tar.zst", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="flatpark/ayugram-release"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

# A rebuild of the same upstream version is published as v<ver>-<rev>; the
# revision stays in the version so a re-pin is picked up.
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r '.assets[] | select(.name | test("^ayugram-.*-x86_64\\.tar\\.zst$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve AyuGram release" >&2; exit 1; }
echo "resolved AyuGram $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"ayugram.tar.zst", url:$u}]}'
