#!/usr/bin/env bash
# Update resolver for OpenWork.
#
# The same GitHub release also ships cloud and enterprise builds, and an
# AppImage beside the tarball. Take only openwork-linux-x64-<version>.tar.gz.
# Every stable release carries it (the repo's other tags, alpha-windows-latest
# and coworker-*, are prereleases), so this reads releases/latest and fails
# when the tarball is missing instead of settling on an older release.
# Prints JSON on stdout:
#   { "version": "0.18.62", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "openwork.tar.gz", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting.
set -euo pipefail

repo="different-ai/openwork"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases/latest")"

date="$(jq -r '.published_at[0:10]' <<<"$rel")"
read -r version url < <(jq -r '
  [ .assets[] | select(.name | test("^openwork-linux-x64-[0-9.]+\\.tar\\.gz$")) ]
  | if length == 1 then .[0] else empty end
  | "\(.name | capture("^openwork-linux-x64-(?<v>[0-9.]+)\\.tar\\.gz$").v) \(.browser_download_url)"
' <<<"$rel") || true

[ -n "${version:-}" ] && [ -n "${url:-}" ] || { echo "failed to resolve OpenWork release" >&2; exit 1; }
echo "resolved OpenWork $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"openwork.tar.gz", url:$u}]}'
