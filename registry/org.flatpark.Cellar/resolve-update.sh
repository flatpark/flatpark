#!/usr/bin/env bash
# Update resolver for Cellar.
#
# Prints the current version + the Linux x86_64 GUI binary as JSON on stdout:
#   { "version": "0.1.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "cellar-x86_64", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="jing2uo/cellar"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The assets are cellar-x86_64 (GUI + CLI), cellar-cli-x86_64 (static, no GUI)
# and SHA256SUMS. Match the exact name so the CLI-only build can't win.
url="$(jq -r '.assets[] | select(.name == "cellar-x86_64") | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve cellar release" >&2; exit 1; }
echo "resolved cellar $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"cellar-x86_64", url:$u}]}'
