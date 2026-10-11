#!/usr/bin/env bash
# Update resolver for ZCode.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "3.6.5", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "zcode.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URLs and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# Z.ai publishes no release index: the download page carries the current
# version's URLs, and each release directory carries the electron-builder
# latest.yml. Read the URLs off the page, then confirm the version against that
# release's latest.yml so a page-layout change cannot pin a bogus version.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq; need sort

page_url="https://zcode.z.ai/en"
cdn="https://cdn-zcode\.z\.ai/zcode/electron/releases"

page="$(curl -fsSL "$page_url")"

url_amd64="$(grep -oE "${cdn}/[0-9][0-9.]*/linux-x64/ZCode-[0-9][0-9.]*-linux-x64\.deb" <<<"$page" \
  | sort -uV | tail -n 1 || true)"

[ -n "$url_amd64" ] || {
  echo "failed to find a ZCode Linux x86_64 .deb link on $page_url" >&2
  exit 1
}

version="$(sed -E 's#.*/releases/([0-9][0-9.]*)/linux-x64/.*#\1#' <<<"$url_amd64")"

# electron-builder's own manifest for this release: authoritative version and
# publish date for the artifacts the page links to.
latest="$(curl -fsSL "${url_amd64%/*}/latest.yml")"
latest_version="$(sed -n 's/^version: *//p' <<<"$latest" | head -n 1 | tr -d "'\"")"

[ "$latest_version" = "$version" ] || {
  echo "download page and latest.yml disagree: page=$version latest.yml=$latest_version" >&2
  exit 1
}

date="$(sed -n "s/^releaseDate: *//p" <<<"$latest" | head -n 1 | tr -d "'\"" | cut -c1-10)"

# The arm64 .deb sits beside it under linux-arm64/; take it only from the same
# page, for the same version.
url_arm64="$(grep -oE "${cdn}/${version//./\\.}/linux-arm64/ZCode-${version//./\\.}-linux-arm64\.deb" <<<"$page" \
  | head -n 1 || true)"
[ -n "$url_arm64" ] || {
  echo "no ZCode $version Linux arm64 .deb link on $page_url" >&2
  exit 1
}

echo "resolved ZCode $version (${date:-unknown date})" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url_amd64" --arg ua "$url_arm64" \
  '{version:$v, releaseDate:$d, sources:[
     {filename:"zcode.deb", arch:"x86_64",  url:$u},
     {filename:"zcode.deb", arch:"aarch64", url:$ua}
   ]}'
