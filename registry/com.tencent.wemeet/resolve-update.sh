#!/usr/bin/env bash
# Update resolver for WeMeet (Tencent Meeting).
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "3.26.10.401", "releaseDate": "",
#     "sources": [ { "filename": "wemeet.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# Tencent's official download-info service. channel 0300000000 = officialwebsite.
q='[{"package-type":"app","channel":"0300000000","platform":"linux","arch":"x86_64","decorators":["deb"]}]'
resp="$(curl -fsSL -G "https://meeting.tencent.com/web-service/query-download-info" \
          --data-urlencode "q=$q" --data-urlencode "nonce=123456789abcdefg")"

version="$(jq -r '.["info-list"][0].version // empty' <<<"$resp")"
url="$(jq -r '.["info-list"][0].url // empty' <<<"$resp")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve wemeet release" >&2; echo "$resp" | head -c 500 >&2; exit 1; }
echo "resolved wemeet $version: $url" >&2

# releaseDate is left empty: the service exposes no publish date. The metainfo
# <releases> date is maintained by hand when the version bumps.
jq -n --arg v "$version" --arg u "$url" \
  '{version:$v, releaseDate:"", sources:[{filename:"wemeet.deb", url:$u}]}'
