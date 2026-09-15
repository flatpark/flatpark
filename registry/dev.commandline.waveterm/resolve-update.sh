#!/usr/bin/env bash
# Update resolver for Wave Terminal.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "0.14.5", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "waveterm.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="wavetermdev/waveterm"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# releases/latest excludes prereleases and drafts; upstream tags every release
# candidate as `vX.Y.Z-beta.N` alongside the stable `vX.Y.Z`, so this matters.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Anchor on the `-amd64-` infix, not just the extension: the same release also
# publishes waveterm-linux-arm64-<version>.deb, and a loose `\.deb$` match would
# pick whichever sorted first.
url="$(jq -r '.assets[] | select(.name | test("^waveterm-linux-amd64-.*\\.deb$")) | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve waveterm release" >&2; exit 1; }
[ "$(wc -l <<<"$url")" -eq 1 ] || { echo "expected exactly one amd64 .deb asset, got:" >&2; echo "$url" >&2; exit 1; }
echo "resolved waveterm $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"waveterm.deb", url:$u}]}'
