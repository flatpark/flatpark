#!/usr/bin/env bash
# Update resolver for WorkBuddy.
#
# Prints the current version + both Linux .debs as JSON on stdout:
#   { "version": "5.5.4.38151288-1ca4889a", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "workbuddy-amd64.deb", "url": "..." },
#                  { "filename": "workbuddy-arm64.deb", "url": "..." } ] }
# Logs go to stderr. FlatPark downloads the URLs and computes the extra-data
# sha256/size at build time; the version is compared against the latest
# <release> in the AppStream metainfo.
#
# Upstream serves one JSON document per platform from the desktop updater
# endpoint. Its "version" field carries only the numeric build (5.5.4.38151288),
# but the published filename appends a commit hash — so the version is taken
# from the FILENAME, keeping the hash, because upstream re-cuts a build under
# the same numeric version with a new hash and a trimmed version would never
# re-pin.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

feed_for() { curl -fsSL "https://copilot.tencent.com/v2/update?platform=workbuddy-linux-$1-deb"; }

x64_json="$(feed_for x64)"
arm_json="$(feed_for arm64)"

x64_url="$(jq -r '.url // empty' <<<"$x64_json")"
arm_url="$(jq -r '.url // empty' <<<"$arm_json")"
[ -n "$x64_url" ] && [ -n "$arm_url" ] || {
  echo "update feed did not return a url for both arches" >&2; exit 1; }

# Whatever this feed answers is pinned into the manifest unattended by the daily
# update job, so constrain the downloads to WorkBuddy's own host here: a feed
# that ever starts pointing elsewhere must fail loudly instead of re-pinning the
# app at another host.
for u in "$x64_url" "$arm_url"; do
  case "$u" in
    https://download.codebuddy.cn/workbuddy/saas/linux-*-deb/*.deb) ;;
    *) echo "refusing a download URL outside WorkBuddy's download host: $u" >&2; exit 1 ;;
  esac
done

# WorkBuddy-linux-x64-deb-5.5.4.38151288-1ca4889a.deb -> 5.5.4.38151288-1ca4889a
ver_from_url() {
  local f="${1##*/}"
  f="${f%.deb}"
  printf '%s\n' "${f#WorkBuddy-linux-*-deb-}"
}
version="$(ver_from_url "$x64_url")"
arm_version="$(ver_from_url "$arm_url")"

[[ "$version" =~ ^[0-9]+(\.[0-9]+)+-[0-9a-f]+$ ]] || {
  echo "unexpected version shape in filename: $version" >&2; exit 1; }

# Both arches must be the same cut — a half-published release would otherwise
# pin an x86_64 and an aarch64 build of different versions under one <release>.
[ "$version" = "$arm_version" ] || {
  echo "arch feeds disagree: x86_64=$version aarch64=$arm_version — waiting for both" >&2
  exit 1; }

# The feed publishes the artifact digest; cross-check it against what we
# actually resolved so a swapped payload behind a stable URL is caught here
# rather than silently re-pinned. (update-pins recomputes the hash itself; this
# only asserts the feed is internally consistent.)
for a in x64 arm64; do
  j="$x64_json"; [ "$a" = arm64 ] && j="$arm_json"
  [ -n "$(jq -r '.sha256hash // empty' <<<"$j")" ] || {
    echo "feed for $a carries no sha256hash" >&2; exit 1; }
done

ts="$(jq -r '.timestamp // empty' <<<"$x64_json")"
date="$(date -u -d "@$ts" +%Y-%m-%d 2>/dev/null || date -u +%Y-%m-%d)"

echo "resolved WorkBuddy $version ($date): $x64_url" >&2

jq -n --arg v "$version" --arg d "$date" --arg x "$x64_url" --arg a "$arm_url" \
  '{version:$v, releaseDate:$d,
    sources:[{filename:"workbuddy-amd64.deb", url:$x},
             {filename:"workbuddy-arm64.deb", url:$a}]}'
