#!/usr/bin/env bash
# Update resolver for Kiro.
#
# Prints the current version + the Linux .deb builds as JSON on stdout:
#   { "version": "1.3.11", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "kiro.deb", "arch": "x86_64", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# Upstream publishes no release index or JSON API; the download page HTML is the
# only place that names the current build, and it carries every platform
# artifact for it. The page is parsed for the Linux .deb URLs, whose path
# carries the version (/releases/stable/linux-<arch>/signed/<version>/deb/...).
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

page="https://kiro.dev/download"
html="$(curl -fsSL "$page")"

# Both Linux debs are named kiro-ide-<version>-stable-linux-<arch>.deb; take the
# one per architecture and keep the two versions consistent.
url="$(printf '%s\n' "$html" | grep -oE 'https://prod\.download\.desktop\.kiro\.dev/releases/stable/linux-x64/signed/[^/]+/deb/kiro-ide-[^"'"'"' ]+\.deb' | head -n 1 || true)"
url_arm="$(printf '%s\n' "$html" | grep -oE 'https://prod\.download\.desktop\.kiro\.dev/releases/stable/linux-arm64/signed/[^/]+/deb/kiro-ide-[^"'"'"' ]+\.deb' | head -n 1 || true)"

[ -n "$url" ] && [ -n "$url_arm" ] || {
  echo "failed to resolve Kiro Linux .deb URLs from $page" >&2
  exit 1
}

version="$(printf '%s\n' "$url" | sed -n 's#.*/signed/\([^/]*\)/deb/.*#\1#p')"
version_arm="$(printf '%s\n' "$url_arm" | sed -n 's#.*/signed/\([^/]*\)/deb/.*#\1#p')"
[ -n "$version" ] && [ "$version" = "$version_arm" ] || {
  echo "Kiro download page disagrees on the version: x64=$version arm64=$version_arm" >&2
  exit 1
}

# Whatever this page answers is pinned into the manifest unattended by the
# daily update job, so constrain it to Kiro's own download host here: a page
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
