#!/usr/bin/env bash
set -euo pipefail

repo="tuna-os/gtk-office-suite"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | sub("^v";"")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r '[.assets[] | select(.name | test("^tables-x86_64\\.tar\\.gz$")) | .browser_download_url]
              | if length == 1 then .[0] else empty end' <<<"$rel")"

[ -n "$version" ] && [ -n "$date" ] && [ -n "$url" ] || { echo "failed to resolve tables release" >&2; exit 1; }
echo "resolved tables $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"tables.tar.gz", arch:"x86_64", url:$u}]}'
