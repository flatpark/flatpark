#!/usr/bin/env bash
# Update resolver for OpenMarket.
#
# The download page links fixed "latest" paths, but the app's own
# electron-updater feed (resources/app-update.yml: provider generic,
# https://assets.openmarket.xyz/desktop/stable/) names the versioned files that
# sit beside it, so the pin is a versioned URL:
#
#   https://assets.openmarket.xyz/desktop/stable/latest-linux.yml
#     version: 0.1.10
#     files:
#       - url: OpenMarket-0.1.10-linux-x86_64.AppImage
#       - url: OpenMarket-0.1.10-linux-amd64.deb
#     releaseDate: '2026-11-07T20:03:38.268Z'
#
# Only x86_64 Linux builds are published, so only x86_64 is packaged.
# Prints the version, the release date and the AppImage URL as JSON on stdout;
# logs go to stderr.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

base="https://assets.openmarket.xyz/desktop/stable"
feed="$base/latest-linux.yml"

yml="$(curl -fsSL "$feed")"

# Plain top-level `key: value` scalars; strip the quotes electron-updater puts
# around the date.
version="$(printf '%s\n' "$yml" | sed -nE "s/^version:[[:space:]]*['\"]?([^'\"[:space:]]+)['\"]?[[:space:]]*$/\1/p" | head -n1)"
release_date="$(printf '%s\n' "$yml" | sed -nE "s/^releaseDate:[[:space:]]*['\"]?([0-9]{4}-[0-9]{2}-[0-9]{2}).*$/\1/p" | head -n1)"
[ -n "$version" ] || { echo "no version in $feed" >&2; exit 1; }

# Exactly one x86_64 AppImage for this version must be listed in the feed.
names="$(printf '%s\n' "$yml" | sed -nE 's#^[[:space:]]*-[[:space:]]*url:[[:space:]]*([^[:space:]]+)[[:space:]]*$#\1#p' \
          | grep -xF "OpenMarket-$version-linux-x86_64.AppImage" || true)"
[ "$(printf '%s' "$names" | grep -c .)" = 1 ] \
  || { echo "expected one OpenMarket-$version-linux-x86_64.AppImage in $feed" >&2; exit 1; }

echo "resolved OpenMarket $version (${release_date:-no date}): $base/$names" >&2

jq -n --arg v "$version" --arg d "$release_date" --arg u "$base/$names" \
  '{version:$v} + (if $d == "" then {} else {releaseDate:$d} end) + {sources:[{filename:"app.AppImage", url:$u}]}'
