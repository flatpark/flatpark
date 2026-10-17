#!/usr/bin/env bash
# Update resolver for Cherry Studio.
#
# Prints the current version + the Linux .deb builds as JSON on stdout:
#   { "version": "2.1.6", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "cherrystudio.deb", "arch": "x86_64", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# Upstream publishes GitHub releases; the latest release JSON carries every
# Linux artifact for the current build, of which we take the .deb (x64 and
# arm64, named Cherry-Studio-<version>-linux-{x64,arm64}.deb).
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

feed="https://api.github.com/repos/CherryHQ/cherry-studio/releases/latest"
json="$(curl -fsSL -H 'Accept: application/vnd.github+json' "$feed")"

version="$(jq -r '.tag_name // empty' <<<"$json" | sed 's/^v//')"
[ -n "$version" ] || {
  echo "failed to resolve a Cherry Studio release from $feed" >&2
  exit 1
}

url="$(jq -r --arg v "$version" '.assets[] | select(.name == "Cherry-Studio-\($v)-linux-x64.deb") | .browser_download_url' <<<"$json")"
url_arm="$(jq -r --arg v "$version" '.assets[] | select(.name == "Cherry-Studio-\($v)-linux-arm64.deb") | .browser_download_url' <<<"$json")"

[ -n "$url" ] && [ -n "$url_arm" ] || {
  echo "Cherry Studio $version does not offer both Linux .deb builds" >&2
  exit 1
}

# Whatever this endpoint answers is pinned into the manifest unattended by the
# daily update job, so constrain it to the project's own release host here: an
# endpoint that ever starts pointing somewhere else must fail loudly instead of
# re-pinning the app at another host.
case "$url" in
  https://github.com/CherryHQ/cherry-studio/releases/download/*) ;;
  *) echo "refusing a download URL outside Cherry Studio's release host: $url" >&2; exit 1 ;;
esac
case "$url_arm" in
  https://github.com/CherryHQ/cherry-studio/releases/download/*) ;;
  *) echo "refusing a download URL outside Cherry Studio's release host: $url_arm" >&2; exit 1 ;;
esac

# published_at supplies the <release> date. Keep the fetch out of the `date -d`
# argument so a parse failure falls back to today rather than aborting under
# `set -e` before the fallback can run.
published="$(jq -r '.published_at // empty' <<<"$json")"
date="$(date -u -d "$published" +%Y-%m-%d 2>/dev/null || date -u +%Y-%m-%d)"

echo "resolved Cherry Studio $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg ua "$url_arm" \
  '{version:$v, releaseDate:$d, sources:[
     {filename:"cherrystudio.deb", arch:"x86_64",  url:$u},
     {filename:"cherrystudio.deb", arch:"aarch64", url:$ua}
   ]}'
