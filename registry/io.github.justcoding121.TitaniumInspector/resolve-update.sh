#!/usr/bin/env bash
# Update resolver for Titanium Inspector.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "7.0.11", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "titanium-inspector.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="justcoding121/titanium-web-proxy"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# releases/latest excludes prereleases and drafts; upstream cuts a `-beta`
# prerelease before most stable tags.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# One release carries the library, the CLI and the Inspector for every platform
# and libc: match the Inspector's glibc x64 .deb by its exact name, not by a
# loose suffix that would also hit Titanium.Cli-linux-x64.deb or the arm64 build.
url="$(jq -r '.assets[] | select(.name == "TitaniumInspector-linux-x64.deb") | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve Titanium Inspector release" >&2; exit 1; }
[ "$(wc -l <<<"$url")" -eq 1 ] || { echo "expected exactly one Inspector x64 .deb asset, got:" >&2; echo "$url" >&2; exit 1; }
echo "resolved titanium-inspector $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"titanium-inspector.deb", url:$u}]}'
