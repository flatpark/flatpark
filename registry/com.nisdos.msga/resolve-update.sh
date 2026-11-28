#!/usr/bin/env bash
# The latest MSGA release and its Linux x86_64 executable, as JSON on stdout.
# Releases are tagged by date (2026-11-24); every one carries the Linux build.
set -euo pipefail

repo="punarinta/make-slack-great-again"

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The exact name: the release also has a .manifest beside each build.
url="$(jq -r '.assets[] | select(.name == "msga-linux-x86_64") | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve the MSGA release" >&2; exit 1; }
echo "resolved MSGA $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"msga-linux-x86_64", url:$u}]}'
