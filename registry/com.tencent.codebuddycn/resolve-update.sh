#!/usr/bin/env bash
# Update resolver for CodeBuddy CN.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "4.11.3.37298507-2345dde1-cn", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "codebuddy.deb", "arch": "x86_64",  "url": "..." },
#                  { "filename": "codebuddy.deb", "arch": "aarch64", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# Upstream publishes a per-platform manifest at aiide/version.json; the Linux
# x86_64 build's stable channel carries the full version string, and the .deb
# filename is that string verbatim. The version keeps its build number and
# commit hash because upstream re-cuts a release under the same 4.x.y with a new
# hash — a trimmed "4.11.3" would never re-pin.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

feed="https://download.codebuddy.cn/aiide/version.json"
json="$(curl -fsSL "$feed")"

version="$(jq -r '."linux-x64".stable.version // empty' <<<"$json")"

[ -n "$version" ] || {
  echo "failed to resolve a CodeBuddy CN linux-x64 stable version from $feed" >&2
  exit 1
}

url="https://download.codebuddy.cn/aiide/linux-x64/CodeBuddy-linux-x64-${version}.deb"

# Whatever this feed answers is pinned into the manifest unattended by the daily
# update job, so constrain the download to CodeBuddy's own host here: a feed
# that ever starts pointing elsewhere must fail loudly instead of re-pinning the
# app at another host.
case "$url" in
  https://download.codebuddy.cn/aiide/linux-x64/*) ;;
  *) echo "refusing a download URL outside CodeBuddy's download host: $url" >&2; exit 1 ;;
esac

# Confirm the artifact is actually published before pinning it, and take its
# Last-Modified as the <release> date. Keep the fetch out of the `date -d`
# argument so a HEAD that fails falls back to today rather than aborting under
# `set -e`.
head="$(curl -fsSI "$url")" || {
  echo "resolved version $version but its .deb is not published yet: $url" >&2
  exit 1
}
# The arm64 build is listed separately in the same feed; one <release> covers
# both pins, so it must be the same version and already published.
[ "$(jq -r '."linux-arm64".stable.version // empty' <<<"$json")" = "$version" ] || {
  echo "CodeBuddy CN linux-arm64 stable is not on $version yet" >&2
  exit 1
}
url_arm="https://download.codebuddy.cn/aiide/linux-arm64/CodeBuddy-linux-arm64-${version}.deb"
curl -fsSI "$url_arm" >/dev/null || {
  echo "resolved version $version but its arm64 .deb is not published yet: $url_arm" >&2
  exit 1
}

last_modified="$(sed -n 's/^[Ll]ast-[Mm]odified:[[:space:]]*//p' <<<"$head" | tr -d '\r' | tail -n 1 || true)"
date="$(date -u -d "$last_modified" +%Y-%m-%d 2>/dev/null || date -u +%Y-%m-%d)"

echo "resolved CodeBuddy CN $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg ua "$url_arm" \
  '{version:$v, releaseDate:$d, sources:[
     {filename:"codebuddy.deb", arch:"x86_64",  url:$u},
     {filename:"codebuddy.deb", arch:"aarch64", url:$ua}
   ]}'
