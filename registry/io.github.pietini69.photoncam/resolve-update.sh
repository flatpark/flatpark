#!/usr/bin/env bash
# Update resolver for PhotonCAM.
#
# Older tags (v1.2.0 and before) shipped this project as LaserBurn-*.tar.gz.
# Take only PhotonCAM-<version>-linux-x86_64.tar.gz, from releases/latest:
# every release since v1.2.5 carries it, so a missing one fails instead of
# settling on an older release.
# Prints JSON on stdout:
#   { "version": "1.2.8", "releaseDate": "YYYY-MM-DD", "releaseUrl": "...",
#     "sources": [ { "filename": "photoncam.tar.gz", "arch": "x86_64", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting.
set -euo pipefail

repo="pietini69/photoncam"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases/latest")"

date="$(jq -r '.published_at // empty' <<<"$rel" | cut -c1-10)"
release_url="$(jq -r '.html_url // empty' <<<"$rel")"
read -r version url < <(jq -r '
  [ .assets[] | select(.name | test("^PhotonCAM-[0-9]+(\\.[0-9]+)*-linux-x86_64\\.tar\\.gz$")) ]
  | if length == 1 then .[0] else empty end
  | "\(.name | capture("^PhotonCAM-(?<v>[0-9]+(\\.[0-9]+)*)-linux-x86_64\\.tar\\.gz$").v) \(.browser_download_url)"
' <<<"$rel") || true

[ -n "${version:-}" ] && [ -n "${url:-}" ] || { echo "failed to resolve PhotonCAM release" >&2; exit 1; }
echo "resolved PhotonCAM $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg r "$release_url" --arg u "$url" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[
     {filename:"photoncam.tar.gz", arch:"x86_64", url:$u}
   ]}'
