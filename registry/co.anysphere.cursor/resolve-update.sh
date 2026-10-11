#!/usr/bin/env bash
# Update resolver for Cursor.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "3.16.17", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "cursor.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# Upstream publishes no release index; the download page is driven by the same
# JSON endpoint the site itself calls. Its `stable` track carries every Linux
# artifact for the current build, of which we take the .deb — the AppImage needs
# libfuse, which no Flatpak runtime ships.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

feed="https://cursor.com/api/download?platform=linux-x64&releaseTrack=stable"
json="$(curl -fsSL "$feed")"

version="$(jq -r '.version // empty' <<<"$json")"
url="$(jq -r '.debUrl // empty' <<<"$json")"

[ -n "$version" ] && [ -n "$url" ] || {
  echo "failed to resolve a Cursor Linux x86_64 .deb from $feed" >&2
  exit 1
}

# Whatever this endpoint answers is pinned into the manifest unattended by the
# daily update job, so constrain it to Cursor's own download host here: an
# endpoint that ever starts pointing somewhere else must fail loudly instead of
# re-pinning the app at another host.
case "$url" in
  https://downloads.cursor.com/production/*) ;;
  *) echo "refusing a download URL outside Cursor's download host: $url" >&2; exit 1 ;;
esac

# Last-Modified supplies the <release> date. Keep the fetch out of the `date -d`
# argument so a HEAD that fails falls back to today rather than aborting under
# `set -e` before the fallback can run.
# The arm64 build comes from the same feed for platform=linux-arm64, and must be
# the same release.
json_arm="$(curl -fsSL "https://cursor.com/api/download?platform=linux-arm64&releaseTrack=stable")"
url_arm="$(jq -r '.debUrl // empty' <<<"$json_arm")"
[ "$(jq -r '.version // empty' <<<"$json_arm")" = "$version" ] && [ -n "$url_arm" ] || {
  echo "Cursor linux-arm64 feed does not offer a $version .deb" >&2
  exit 1
}
case "$url_arm" in
  https://downloads.cursor.com/production/*) ;;
  *) echo "refusing a download URL outside Cursor's download host: $url_arm" >&2; exit 1 ;;
esac

last_modified="$(curl -fsSI "$url" | sed -n 's/^[Ll]ast-[Mm]odified:[[:space:]]*//p' | tr -d '\r' | tail -n 1 || true)"
date="$(date -u -d "$last_modified" +%Y-%m-%d 2>/dev/null || date -u +%Y-%m-%d)"

echo "resolved Cursor $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg ua "$url_arm" \
  '{version:$v, releaseDate:$d, sources:[
     {filename:"cursor.deb", arch:"x86_64",  url:$u},
     {filename:"cursor.deb", arch:"aarch64", url:$ua}
   ]}'
