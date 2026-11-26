#!/usr/bin/env bash
# Track the official Unsloth desktop release for Linux.
set -euo pipefail
repo="unslothai/unsloth"
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
url="$(jq -r '.assets[] | select(.name == "Unsloth-Desktop-Ubuntu.deb") | .browser_download_url' <<<"$rel" | head -n1)"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve release" >&2; exit 1; }
jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"app.deb", url:$u}]}'
