#!/bin/bash
set -euo pipefail

# Follow the GitHub release marked Latest (not the highest tag: v1.0.15 is a
# stray tag older than v1.0.0) and take its amd64 .deb.
repo="Pratyay360/drawx"
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
url="$(jq -r '.assets[] | select(.name | test("amd64\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve release" >&2; exit 1; }

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"drawx.deb", url:$u}]}'
