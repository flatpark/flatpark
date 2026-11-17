#!/usr/bin/env bash
# Update resolver for RustGIS.
#
# The same GitHub release also ships AppImages, .deb/.rpm packages, Python
# wheels, mobile builds and macOS and Windows installers. Take only
# RustGIS-<version>-linux-x86_64.tar.gz and -linux-aarch64.tar.gz.
# Prints JSON on stdout:
#   { "version": "0.7.0", "releaseDate": "YYYY-MM-DD", "releaseUrl": "...",
#     "sources": [ { "filename": "rustgis.tar.gz", "arch": "x86_64", "url": "..." },
#                  { "filename": "rustgis.tar.gz", "arch": "aarch64", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting.
set -euo pipefail

repo="opengeos/RustGIS"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# Highest version among recent stable releases, not the newest by date and not
# releases/latest: a patch to an older line published later would otherwise
# downgrade the pin.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases?per_page=30" | jq '
  [ .[] | select((.draft or .prerelease) | not)
        | select(.tag_name | test("^v?[0-9]+(\\.[0-9]+)*$")) ]
  | max_by(.tag_name | ltrimstr("v") | split(".") | map(tonumber))')"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
release_url="$(jq -r '.html_url' <<<"$rel")"

# Exact asset names: excludes the AppImages, their .zsync files and the packages.
asset_url() {
  jq -r --arg n "RustGIS-$version-linux-$1.tar.gz" \
    '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel" | head -n1
}
url_x86_64="$(asset_url x86_64)"
url_aarch64="$(asset_url aarch64)"

[ -n "$version" ] && [ -n "$url_x86_64" ] && [ -n "$url_aarch64" ] || {
  echo "failed to resolve RustGIS release" >&2
  exit 1
}
echo "resolved RustGIS $version ($date): $url_x86_64" >&2

jq -n --arg v "$version" --arg d "$date" --arg r "$release_url" --arg ux "$url_x86_64" --arg ua "$url_aarch64" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[
     {filename:"rustgis.tar.gz", arch:"x86_64",  url:$ux},
     {filename:"rustgis.tar.gz", arch:"aarch64", url:$ua}
   ]}'
