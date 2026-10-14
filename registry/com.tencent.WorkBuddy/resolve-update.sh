#!/usr/bin/env bash
# Update resolver for WorkBuddy.
#
# Prints the current version + the x86_64 .deb as JSON on stdout:
#   { "version": "5.5.4.38151288-1ca4889a", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "workbuddy-amd64.deb", "url": "...",
#                    "size": 429329908 } ] }
# Logs go to stderr. FlatPark downloads the URL and computes the extra-data
# sha256/size at build time; the version is compared against the latest
# <release> in the AppStream metainfo.
#
# Upstream serves one JSON document per platform from the desktop updater
# endpoint. Its "version" field carries only the numeric build (5.5.4.38151288),
# but the published filename appends a commit hash — so the version is taken
# from the FILENAME, keeping the hash, because upstream re-cuts a build under
# the same numeric version with a new hash and a trimmed version would never
# re-pin.
#
# The feed points at download.codebuddy.cn, a CDN that does not serve the same
# bytes everywhere: upstream re-uploads builds in place under the same versioned
# filename, and mainland edges kept serving the earlier upload while overseas
# edges serve the new one, so any single pin fails to install in one region or
# the other (issue #648). The pin therefore goes to the CDN's origin COS bucket
# through its global acceleration endpoint — one object, the same bytes for
# every user — under the same path. And because an in-place re-upload keeps
# the version, the source reports the object's current Content-Length (a HEAD,
# no download) so update-pins re-pins when the bytes change under a pin.
#
# aarch64 is not published yet, so only the x86_64 feed is resolved.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

ORIGIN=https://acc-1258344699.cos.accelerate.myqcloud.com

json="$(curl -fsSL "https://copilot.tencent.com/v2/update?platform=workbuddy-linux-x64-deb")"
feed_url="$(jq -r '.url // empty' <<<"$json")"
[ -n "$feed_url" ] || { echo "update feed did not return a url" >&2; exit 1; }

# Whatever this feed answers is pinned into the manifest unattended by the daily
# update job, so constrain the download to WorkBuddy's own path here: a feed
# that ever starts pointing elsewhere must fail loudly instead of re-pinning the
# app at another host.
case "$feed_url" in
  https://download.codebuddy.cn/workbuddy/saas/linux-x64-deb/*.deb) ;;
  *) echo "refusing a download URL outside WorkBuddy's download host: $feed_url" >&2; exit 1 ;;
esac
url="$ORIGIN/${feed_url#https://download.codebuddy.cn/}"

# WorkBuddy-linux-x64-deb-5.5.4.38151288-1ca4889a.deb -> 5.5.4.38151288-1ca4889a
f="${url##*/}"; f="${f%.deb}"
version="${f#WorkBuddy-linux-x64-deb-}"
[[ "$version" =~ ^[0-9]+(\.[0-9]+)+-[0-9a-f]+$ ]] || {
  echo "unexpected version shape in filename: $version" >&2; exit 1; }

size="$(curl -fsSIL "$url" | tr -d '\r' | awk 'tolower($1)=="content-length:" {n=$2} END {print n}')"
[[ "$size" =~ ^[0-9]+$ ]] || { echo "origin did not report a size for $url" >&2; exit 1; }

ts="$(jq -r '.timestamp // empty' <<<"$json")"
date="$(date -u -d "@$ts" +%Y-%m-%d 2>/dev/null || date -u +%Y-%m-%d)"

echo "resolved WorkBuddy $version ($date, $size bytes): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --argjson s "$size" \
  '{version:$v, releaseDate:$d,
    sources:[{filename:"workbuddy-amd64.deb", url:$u, size:$s}]}'
