#!/usr/bin/env bash
# Resolve the newest official Linux tarball. Linux releases can lag mobile:
# many releases (v6.5.3, v6.5.2, v6.5.0, v6.4.6, ...) carry only the mobile,
# macOS and Windows builds, and a later release may re-attach an older Linux
# tarball (v6.5.4 carries Cake_Wallet_v6.4.4_Linux.tar.xz). So this skips
# releases without Cake_Wallet_v<x.y.z>_Linux.tar.xz and takes the most
# recently published one that has it.
set -euo pipefail

repo="cake-tech/cake_wallet"
headers=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
  headers=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi

releases="$(curl -fsSL "${headers[@]}" \
  "https://api.github.com/repos/$repo/releases?per_page=100")"
release="$(jq -c '
  map(select(.draft == false and .prerelease == false))
  | map(. as $release
      | .assets |= map(select(.name | test("^Cake_Wallet_v[0-9]+\\.[0-9]+\\.[0-9]+_Linux\\.tar\\.xz$")))
      | select(.assets | length > 0))
  | sort_by(.published_at) | last // empty
' <<<"$releases")"
[ -n "$release" ] || { echo "no official Cake Wallet Linux tarball found" >&2; exit 1; }

asset="$(jq -c '.assets[0]' <<<"$release")"
name="$(jq -r '.name' <<<"$asset")"
version="${name#Cake_Wallet_v}"
version="${version%_Linux.tar.xz}"
date="$(jq -r '.published_at | .[0:10]' <<<"$release")"
url="$(jq -r '.browser_download_url' <<<"$asset")"
digest="$(jq -r '.digest // empty' <<<"$asset")"
size="$(jq -r '.size // 0' <<<"$asset")"
release_url="$(jq -r '.html_url' <<<"$release")"

[ -n "$version" ] && [ -n "$date" ] && [ -n "$url" ] || {
  echo "incomplete Cake Wallet Linux release metadata" >&2
  exit 1
}
[[ "$digest" =~ ^sha256:[[:xdigit:]]{64}$ ]] && [ "$size" -gt 0 ] || {
  echo "missing SHA-256 or size for $name" >&2
  exit 1
}

jq -n \
  --arg version "$version" \
  --arg date "$date" \
  --arg url "$url" \
  --arg releaseUrl "$release_url" \
  --arg sha256 "${digest#sha256:}" \
  --argjson size "$size" \
  '{version:$version, releaseDate:$date, releaseUrl:$releaseUrl,
    sources:[{filename:"cake-wallet.tar.xz", url:$url, sha256:$sha256, size:$size}]}'
