#!/usr/bin/env bash
# Update resolver for flatpark-spawn (the shared extension org.flatpark.Spawn).
#
# Each release of flatpark/flatpark-spawn ships one tarball per arch,
# flatpark-spawn-<version>-<arch>.tar.gz, with SHA256SUMS and SIZES listing
# both. The pins are taken from those two files, so nothing is downloaded to
# hash it. Branch 1 is the ABI major: a release that breaks apps using the
# extension starts branch 2 and a new manifest, not a pin bump here, so only
# 0.x and 1.x tags are followed.
# Prints JSON on stdout:
#   { "version": "0.1.0", "releaseDate": "YYYY-MM-DD", "releaseUrl": "...",
#     "sources": [ { "filename": "flatpark-spawn.tar.gz", "arch": "x86_64",
#                    "url": "...", "sha256": "...", "size": 123 }, ... ] }
# Logs go to stderr.
set -euo pipefail

repo="flatpark/flatpark-spawn"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

get() { curl -fsSL --retry 3 ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} "$@"; }

# Highest 0.x/1.x stable release, not the newest by date.
rel="$(get "https://api.github.com/repos/$repo/releases?per_page=30" | jq '
  def version: .tag_name | ltrimstr("v") | split(".") | map(tonumber);
  [ .[] | select((.draft or .prerelease) | not)
        | select(.tag_name | test("^v?[01]\\.[0-9]+\\.[0-9]+$")) ]
  | sort_by(version) | last')"
[ "$rel" != null ] || { echo "no flatpark-spawn release found" >&2; exit 1; }

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
release_url="$(jq -r '.html_url' <<<"$rel")"
asset_url() { jq -r --arg n "$1" '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel" | head -n1; }

sums_url="$(asset_url SHA256SUMS)"; sizes_url="$(asset_url SIZES)"
[ -n "$sums_url" ] && [ -n "$sizes_url" ] || { echo "flatpark-spawn $version has no SHA256SUMS or SIZES" >&2; exit 1; }
sums="$(get "$sums_url")"; sizes="$(get "$sizes_url")"

sources="[]"
for arch in x86_64 aarch64; do
    name="flatpark-spawn-$version-$arch.tar.gz"
    url="$(asset_url "$name")"
    sha256="$(awk -v n="$name" '$2 == n || $2 == "*" n { print $1 }' <<<"$sums")"
    size="$(awk -v n="$name" '$2 == n { print $1 }' <<<"$sizes")"
    [[ -n "$url" && "$sha256" =~ ^[0-9a-f]{64}$ && "$size" =~ ^[0-9]+$ ]] \
        || { echo "flatpark-spawn $version: no asset, sha256 or size for $name" >&2; exit 1; }
    sources="$(jq --arg a "$arch" --arg u "$url" --arg s "$sha256" --argjson z "$size" \
        '. + [{filename:"flatpark-spawn.tar.gz", arch:$a, url:$u, sha256:$s, size:$z}]' <<<"$sources")"
done
echo "resolved flatpark-spawn $version ($date)" >&2

jq -n --arg v "$version" --arg d "$date" --arg r "$release_url" --argjson s "$sources" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:$s}'
