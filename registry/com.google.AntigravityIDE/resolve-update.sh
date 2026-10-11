#!/usr/bin/env bash
# Update resolver for Antigravity IDE.
#
# Upstream publishes the update endpoint the IDE itself checks; its `latest`
# form answers unauthenticated with the current stable build:
# https://antigravity-ide-auto-updater-974169037036.us-central1.run.app/api/update/linux-x64/stable/latest
# That JSON carries the download URL (edgedl.me.gvt1.com) and the opaque build
# id, whose leading segment is the version. The feed also publishes its own
# sha256hash; we do not forward it, because the resolver contract has no field
# for a hash and update-pins.mjs recomputes sha256/size from the same URL.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

feed="https://antigravity-ide-auto-updater-974169037036.us-central1.run.app/api/update/linux-x64/stable/latest"
json="$(curl -fsSL "$feed")"

url="$(jq -r '.url // empty' <<<"$json")"
[ -n "$url" ] || { echo "failed to resolve Antigravity IDE release from $feed" >&2; exit 1; }

# Whatever this feed answers is pinned into the manifest unattended by the daily
# update job, so constrain it to Google's own download CDN here: an endpoint that
# ever starts pointing somewhere else must fail loudly instead of re-pinning the
# app at another host.
case "$url" in
  https://edgedl.me.gvt1.com/edgedl/release2/*) ;;
  *) echo "refusing a download URL outside Google's CDN: $url" >&2; exit 1 ;;
esac

url_encoded="${url// /%20}"

version="$(sed -n 's|.*/stable/\([0-9.]*\)-.*|\1|p' <<<"$url")"
[ -n "$version" ] || { echo "failed to parse version from URL: $url" >&2; exit 1; }

# Last-Modified supplies the <release> date. Keep the fetch out of the `date -d`
# argument so a HEAD that fails falls back to today rather than aborting under
# `set -e` before the fallback can run.
last_modified="$(curl -fsSI "$url_encoded" | sed -n 's/^[Ll]ast-[Mm]odified:[[:space:]]*//p' | tr -d '\r' || true)"
date="$(date -u -d "$last_modified" +%Y-%m-%d 2>/dev/null || date -u +%Y-%m-%d)"

# The arm64 build comes from the same updater (its path says linux-arm, but the
# tarball is aarch64) and must be the same release.
json_arm="$(curl -fsSL "${feed/linux-x64/linux-arm64}")"
url_arm="$(jq -r '.url // empty' <<<"$json_arm")"
case "$url_arm" in
  https://edgedl.me.gvt1.com/edgedl/release2/*) ;;
  *) echo "refusing an arm64 download URL outside Google's CDN: $url_arm" >&2; exit 1 ;;
esac
[ "$(sed -n 's|.*/stable/\([0-9.]*\)-.*|\1|p' <<<"$url_arm")" = "$version" ] || {
  echo "Antigravity IDE arm64 feed is not on $version: $url_arm" >&2
  exit 1
}
url_arm_encoded="${url_arm// /%20}"
echo "resolved Antigravity IDE $version ($date): $url_encoded" >&2
jq -n --arg v "$version" --arg d "$date" --arg u "$url_encoded" --arg ua "$url_arm_encoded" \
  '{version: $v, releaseDate: $d, sources: [
     {filename: "Antigravity IDE.tar.gz", arch: "x86_64",  url: $u},
     {filename: "Antigravity IDE.tar.gz", arch: "aarch64", url: $ua}
   ]}'
