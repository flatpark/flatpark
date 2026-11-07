#!/usr/bin/env bash
# Update resolver for the RemoteID driver: the latest GitHub release of
# LLawli/RemoteID-linux and its remoteid-x86_64.tar.gz, built on the GNOME 51
# SDK by the release workflow.
#
# Prints:
#   { "version": "0.4.1", "releaseDate": "2026-11-07", "releaseUrl": "...",
#     "sources": [ { "filename": "remoteid.tar.gz", "url": "..." } ] }
#
# Logs go to stderr.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

repo="LLawli/RemoteID-linux"
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
url="$(jq -r '.assets[] | select(.name == "remoteid-x86_64.tar.gz") | .browser_download_url' <<<"$rel" | head -n1)"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
page="$(jq -r '.html_url' <<<"$rel")"
[ -n "$version" ] && [ "$version" != null ] && [ -n "$url" ] || { echo "failed to resolve the latest RemoteID release" >&2; exit 1; }

echo "resolved RemoteID $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg p "$page" \
  '{version:$v, releaseDate:$d, releaseUrl:$p, sources:[{filename:"remoteid.tar.gz", url:$u}]}'
