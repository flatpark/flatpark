#!/usr/bin/env bash
# Update resolver for Kiro.
#
# Prints the current version + the Linux .deb builds as JSON on stdout:
#   { "version": "1.3.11", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "kiro.deb", "arch": "x86_64", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting; FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# The download page renders its links client-side from per-artifact metadata
# JSON on Kiro's download host (the same feed the in-app updater reads); the
# static HTML carries no URLs and lists only the x64 .deb, so the resolver reads
# the arm64 and x64 .deb feeds directly. Each feed names the current release and
# its files (the .deb plus certificate.pem and signature.bin); the .deb's path
# carries the version (/releases/stable/linux-<arch>/signed/<version>/deb/...).
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

feed_base="https://prod.download.desktop.kiro.dev/stable"

# Prints the .deb URL of the current release in one architecture's feed.
deb_url() {
  local feed="$feed_base/metadata-linux-$1-deb-stable.json"
  curl -fsSL "$feed" | jq -r '
    .currentRelease as $v
    | [.releases[] | select(.version == $v) | .updateTo.url | select(endswith(".deb"))]
    | first // empty' || true
}

url="$(deb_url x64)"
url_arm="$(deb_url arm64)"

[ -n "$url" ] && [ -n "$url_arm" ] || {
  echo "failed to resolve Kiro Linux .deb URLs from $feed_base/metadata-linux-*-deb-stable.json" >&2
  exit 1
}

version="$(printf '%s\n' "$url" | sed -n 's#.*/signed/\([^/]*\)/deb/.*#\1#p')"
version_arm="$(printf '%s\n' "$url_arm" | sed -n 's#.*/signed/\([^/]*\)/deb/.*#\1#p')"
[ -n "$version" ] && [ "$version" = "$version_arm" ] || {
  echo "Kiro feeds disagree on the version: x64=$version arm64=$version_arm" >&2
  exit 1
}

# Whatever these feeds answer is pinned into the manifest unattended by the
# daily update job, so constrain it to Kiro's own download host here: a feed
# that ever starts pointing somewhere else must fail loudly instead of
# re-pinning the app at another host.
case "$url" in
  https://prod.download.desktop.kiro.dev/releases/stable/*) ;;
  *) echo "refusing a download URL outside Kiro's download host: $url" >&2; exit 1 ;;
esac
case "$url_arm" in
  https://prod.download.desktop.kiro.dev/releases/stable/*) ;;
  *) echo "refusing a download URL outside Kiro's download host: $url_arm" >&2; exit 1 ;;
esac

# Last-Modified supplies the <release> date. Keep the fetch out of the `date -d`
# argument so a HEAD that fails falls back to today rather than aborting under
# `set -e` before the fallback can run.
last_modified="$(curl -fsSI "$url" | sed -n 's/^[Ll]ast-[Mm]odified:[[:space:]]*//p' | tr -d '\r' | tail -n 1 || true)"
date="$(date -u -d "$last_modified" +%Y-%m-%d 2>/dev/null || date -u +%Y-%m-%d)"

echo "resolved Kiro $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg ua "$url_arm" \
  '{version:$v, releaseDate:$d, sources:[
     {filename:"kiro.deb", arch:"x86_64",  url:$u},
     {filename:"kiro.deb", arch:"aarch64", url:$ua}
   ]}'
