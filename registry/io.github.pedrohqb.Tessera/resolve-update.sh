#!/usr/bin/env bash
# Update resolver for Tessera: the latest GitHub release of pedrohqb/tessera
# and its tessera-x86_64.tar.gz, the /app tree of Tessera's own Flatpak build.
#
# Prints:
#   { "version": "0.1.0", "releaseDate": "2026-10-29", "releaseUrl": "...",
#     "sources": [ { "filename": "tessera.tar.gz", "url": "..." } ] }
#
# Only Tessera's own download is resolved. The vendors' driver downloads stay
# on their fixed pins in the manifest (outside the managed block).
# Logs go to stderr.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

repo="pedrohqb/tessera"
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
url="$(jq -r '.assets[] | select(.name == "tessera-x86_64.tar.gz") | .browser_download_url' <<<"$rel" | head -n1)"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
page="$(jq -r '.html_url' <<<"$rel")"
[ -n "$version" ] && [ "$version" != null ] && [ -n "$url" ] || { echo "failed to resolve the latest Tessera release" >&2; exit 1; }

echo "resolved Tessera $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg p "$page" \
  '{version:$v, releaseDate:$d, releaseUrl:$p, sources:[{filename:"tessera.tar.gz", url:$u}]}'
