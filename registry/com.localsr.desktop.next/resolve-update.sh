#!/usr/bin/env bash
# Update resolver for LocalSR (CPU build).
#
# Upstream publishes its betas (v0.5.0-beta) as regular releases, so
# releases/latest is the newest one. The same release carries the CUDA and
# ROCm AppImages (in .part-NNNN pieces), engine packages for the in-app
# updater, and Windows and macOS builds; take only the CPU AppImage.
# Prints JSON on stdout; logs go to stderr.
set -euo pipefail

repo="HerRei/local-upscale"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
release_url="$(jq -r '.html_url' <<<"$rel")"
url="$(jq -r '.assets[] | select(.name | test("^LocalSR-v[0-9][0-9A-Za-z.+~-]*-Linux-CPU-x86_64\\.AppImage$")) | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve LocalSR release" >&2; exit 1; }
[ "$(wc -l <<<"$url")" -eq 1 ] || { echo "expected exactly one CPU AppImage, got:" >&2; echo "$url" >&2; exit 1; }
echo "resolved LocalSR $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg r "$release_url" --arg u "$url" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[
     {filename:"localsr.AppImage", arch:"x86_64", url:$u}
   ]}'
