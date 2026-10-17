#!/usr/bin/env bash
# Update resolver for Trae CN.
#
# Prints the current version + the Linux .deb builds as JSON on stdout:
#   { "version": "3.4.3", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "trae-cn.deb", "arch": "x86_64", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting; FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# Upstream publishes a version-less JSON API (the download page is a SPA with no
# parsable feed). The response carries several sub-manifests; only the main
# Linux manifest at .data.manifest.linux is this app. Its versions[] entries are
# per-region/per-format; take the cn region .deb pair. Every region mirrors the
# same build, so cn pins the host this package already downloads from.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

api="https://api.trae.com.cn/icube/api/v1/native/version/trae/cn/latest"
json="$(curl -fsSL "$api")"

# jq may not be able to parse a truncated or error body; fail loudly.
printf '%s\n' "$json" | jq -e . >/dev/null 2>&1 || {
  echo "Trae CN version API did not return JSON: $api" >&2
  exit 1
}

url="$(printf '%s\n' "$json" | jq -r '.data.manifest.linux.versions[] | select(.region=="cn" and .arch=="x64.deb") | .url' | head -n 1 || true)"
url_arm="$(printf '%s\n' "$json" | jq -r '.data.manifest.linux.versions[] | select(.region=="cn" and .arch=="arm64.deb") | .url' | head -n 1 || true)"
version="$(printf '%s\n' "$json" | jq -r '.data.manifest.linux.versions[] | select(.region=="cn" and .arch=="x64.deb") | .version' | head -n 1 || true)"
version_arm="$(printf '%s\n' "$json" | jq -r '.data.manifest.linux.versions[] | select(.region=="cn" and .arch=="arm64.deb") | .version' | head -n 1 || true)"

[ -n "$url" ] && [ -n "$url_arm" ] && [ -n "$version" ] || {
  echo "failed to resolve Trae CN Linux .deb URLs from $api" >&2
  exit 1
}
[ "$version" = "$version_arm" ] || {
  echo "Trae CN version API disagrees on the version: x64=$version arm64=$version_arm" >&2
  exit 1
}

# Whatever this API answers is pinned into the manifest unattended by the
# daily update job, so constrain it to Trae CN's own download host here: a feed
# that ever starts pointing somewhere else must fail loudly instead of
# re-pinning the app at another host.
case "$url" in
  https://lf-cdn.trae.com.cn/obj/trae-com-cn/pkg/app/releases/stable/*) ;;
  *) echo "refusing a download URL outside Trae CN's download host: $url" >&2; exit 1 ;;
esac
case "$url_arm" in
  https://lf-cdn.trae.com.cn/obj/trae-com-cn/pkg/app/releases/stable/*) ;;
  *) echo "refusing a download URL outside Trae CN's download host: $url_arm" >&2; exit 1 ;;
esac

# Last-Modified supplies the <release> date. Keep the fetch out of the `date -d`
# argument so a HEAD that fails falls back to today rather than aborting under
# `set -e` before the fallback can run.
last_modified="$(curl -fsSI "$url" | sed -n 's/^[Ll]ast-[Mm]odified:[[:space:]]*//p' | tr -d '\r' | tail -n 1 || true)"
date="$(date -u -d "$last_modified" +%Y-%m-%d 2>/dev/null || date -u +%Y-%m-%d)"

echo "resolved Trae CN $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg ua "$url_arm" \
  '{version:$v, releaseDate:$d, sources:[
     {filename:"trae-cn.deb", arch:"x86_64",  url:$u},
     {filename:"trae-cn.deb", arch:"aarch64", url:$ua}
   ]}'
