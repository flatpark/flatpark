#!/usr/bin/env bash
# Update resolver for WorkBuddy AI, the international (workbuddy.ai) build.
#
# Prints the current version + the x86_64 .deb as JSON on stdout:
#   { "version": "5.7.6.40488862-3e43260f", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "workbuddyai-amd64.deb", "url": "...",
#                    "size": 421733316 } ] }
# Logs go to stderr. FlatPark downloads the URL and computes the extra-data
# sha256/size at build time; the version is compared against the latest
# <release> in the AppStream metainfo.
#
# The international site runs the same desktop updater endpoint as the China
# build, one JSON document per platform, and the published filename carries a
# commit hash after the numeric build — the version is taken from the FILENAME,
# keeping the hash, as in com.tencent.WorkBuddy (upstream re-cuts a build under
# the same numeric version).
#
# Two things differ from the China build:
#
# - The Linux feed's URL is not where the package lives. It names
#   linux-x64-deb/WorkBuddy-linux-x64-deb-<build>.deb, which does not exist;
#   the .deb is uploaded as linux-x64/WorkBuddy-linux-x64-<build>.deb in the
#   same bucket. The path is mapped to that layout here.
# - The Linux feed lags: it said 5.5.2 while the 5.7.6 Linux .deb was already
#   uploaded and works, so 5.7.6 was pinned by hand. A build that is merely in
#   the bucket is not necessarily a good one (the China build's 5.8.2 Linux
#   .deb was uploaded with a required binary missing and cannot start), so this
#   resolver does not go looking past the feed. Instead it never moves the pin
#   backwards: while the feed's build is older than the latest <release> in the
#   metainfo, it reports the build that is already pinned, unchanged.
#
# Either way the size is the object's current Content-Length (a HEAD, no
# download), so update-pins re-pins if upstream re-uploads in place.
#
# aarch64 is not published yet, so only the x86_64 package is resolved.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

BUCKET=https://codebuddy-1328495429.cos.accelerate.myqcloud.com/workbuddy/saas
# The feed names the same objects through this CDN host (same ETag and COS
# version id); the pin always goes to the bucket itself.
CDN=https://download.codebuddy.ai/workbuddy/saas
FEED=https://www.workbuddy.ai/v2/update

# Content-Length of a bucket object, or nothing when it does not exist.
size_of() {
  curl -fsSIL "$1" 2>/dev/null | tr -d '\r' |
    awk 'tolower($1)=="content-length:" {n=$2} END {print n}'
}

# Feed JSON -> "<version-with-hash> <timestamp> <Linux .deb URL>". Whatever a
# feed answers is pinned into the manifest unattended by the daily update job,
# so constrain the download to WorkBuddy's own bucket path here: a feed that
# ever starts pointing elsewhere must fail loudly instead of re-pinning the app
# at another host.
candidate() {
  local platform="$1" dir="${1#workbuddy-}" json feed_url build
  json="$(curl -fsSL "$FEED?platform=$platform")"
  feed_url="$(jq -r '.url // empty' <<<"$json")"
  [ -n "$feed_url" ] || { echo "$platform feed did not return a url" >&2; return 1; }
  case "$feed_url" in
    "$BUCKET/$dir"/* | "$CDN/$dir"/*) ;;
    *) echo "refusing a download URL outside WorkBuddy's bucket: $feed_url" >&2; return 1 ;;
  esac
  # WorkBuddy-<dir>-5.7.6.40488862-3e43260f.<ext> -> 5.7.6.40488862-3e43260f
  build="${feed_url##*/}"; build="${build%.*}"; build="${build#WorkBuddy-"$dir"-}"
  [[ "$build" =~ ^[0-9]+(\.[0-9]+)+-[0-9a-f]+$ ]] || {
    echo "unexpected version shape in $feed_url" >&2; return 1; }
  printf '%s %s %s\n' "$build" "$(jq -r '.timestamp // empty' <<<"$json")" \
    "$BUCKET/linux-x64/WorkBuddy-linux-x64-$build.deb"
}

read -r version ts url < <(candidate workbuddy-linux-x64-deb)

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pinned="$(sed -n 's/.*<release version="\([^"]*\)".*/\1/p' "$here/com.tencent.WorkBuddyAI.metainfo.xml" | head -n1)"
if [ -n "$pinned" ] && [ "$pinned" != "$version" ] &&
   [ "$(printf '%s\n%s\n' "${version%-*}" "${pinned%-*}" | sort -V | tail -n1)" = "${pinned%-*}" ]; then
  echo "Linux feed is at $version, behind the pinned $pinned; keeping the pin" >&2
  version="$pinned"
  url="$BUCKET/linux-x64/WorkBuddy-linux-x64-$pinned.deb"
  ts="$(date -u -d "$(sed -n 's/.*<release version="[^"]*" date="\([^"]*\)".*/\1/p' "$here/com.tencent.WorkBuddyAI.metainfo.xml" | head -n1)" +%s)"
fi

size="$(size_of "$url")"
[[ "$size" =~ ^[0-9]+$ ]] || { echo "bucket did not report a size for $url" >&2; exit 1; }

date="$(date -u -d "@$ts" +%Y-%m-%d 2>/dev/null || date -u +%Y-%m-%d)"

echo "resolved WorkBuddy AI $version ($date, $size bytes): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --argjson s "$size" \
  '{version:$v, releaseDate:$d,
    sources:[{filename:"workbuddyai-amd64.deb", url:$u, size:$s}]}'
