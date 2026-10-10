#!/usr/bin/env bash
# Update resolver for Drop Alpha.
#
# Resolves the latest rolling alpha GitHub release asset and outputs FlatPark resolver JSON:
#   { "version": "0.4.0-alpha.1.a1b2c3d", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "drop-alpha.deb", "url": "..." } ] }
set -euo pipefail

repo="Heretek-Games/drop"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# Fetch release info for tag 'alpha'
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/${repo}/releases/tags/alpha" 2>/dev/null || true)"

if [ -z "$rel" ] || [ "$(jq -r '.id // empty' <<<"$rel")" = "" ]; then
  # Fallback to querying recent releases matching alpha
  releases="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
    "https://api.github.com/repos/${repo}/releases?per_page=20" 2>/dev/null || true)"
  rel="$(jq -c '[.[] | select(.tag_name | test("^alpha"))] | sort_by(.published_at) | last // empty' <<<"${releases:-[]}")"
fi

if [ -z "$rel" ]; then
  # Initial fallback before first alpha run: resolve latest v0.4.0 with alpha suffix
  releases="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
    "https://api.github.com/repos/${repo}/releases?per_page=5")"
  rel="$(jq -c '[.[] | select(.draft == false)] | sort_by(.published_at) | last // empty' <<<"$releases")"
fi

[ -n "$rel" ] || { echo "no release found for alpha resolver" >&2; exit 1; }

date="$(jq -r '.published_at | split("T")[0]' <<<"$rel")"
asset="$(jq -c '
  [ .assets[]
    | select(.name | test(".*_amd64\\.deb$"))
  ] | last // empty' <<<"$rel")"

[ -n "$asset" ] || { echo "no amd64.deb asset found in release" >&2; exit 1; }

url="$(jq -r '.browser_download_url' <<<"$asset")"
asset_name="$(jq -r '.name' <<<"$asset")"

# Extract version from asset name: Drop.Desktop.Client_<version>_amd64.deb
version="$(echo "$asset_name" | sed -E 's/.*_([0-9]+\.[0-9]+\.[0-9]+-alpha\.[0-9]+\.[a-z0-9]+)_amd64\.deb/\1/')"
if [ "$version" = "$asset_name" ]; then
  # If the asset had no alpha suffix yet (e.g. initial v0.4.0 pin), use tag or default alpha baseline
  tag="$(jq -r '.tag_name' <<<"$rel")"
  if [[ "$tag" =~ ^alpha- ]]; then
    version="${tag#alpha-}"
  else
    version="$(echo "$tag" | sed 's/^v//')-alpha.1.initial"
  fi
fi

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve drop alpha release" >&2; exit 1; }
echo "resolved drop alpha $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"drop-alpha.deb", url:$u}]}'
