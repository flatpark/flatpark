#!/usr/bin/env bash
# Update resolver for foobar2000.
#
# Prints the current version + the Windows x64 installer as JSON on stdout:
#   { "version": "2.26.1", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "foobar2000-setup.exe", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

base="https://www.foobar2000.org"
# The download page links one stable x64 installer, /downloads/foobar2000-x64_v<ver>.exe
# (betas are on a separate page). The 32-bit and ARM64 builds use other prefixes.
path="$(curl -fsSL "$base/download" | grep -oE '/downloads/foobar2000-x64_v[0-9][0-9.]*\.exe' | head -n1)"
[ -n "$path" ] || { echo "no x64 installer link on $base/download" >&2; exit 1; }
version="$(sed -E 's/.*_v([0-9.]*)\.exe$/\1/' <<<"$path")"
url="$base$path"
last_modified="$(curl -fsSI "$url" | sed -n 's/^[Ll]ast-[Mm]odified:[[:space:]]*//p' | tr -d '\r')"
date="$(date -u -d "$last_modified" +%Y-%m-%d 2>/dev/null || date -u +%Y-%m-%d)"
echo "resolved foobar2000 $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"foobar2000-setup.exe", url:$u}]}'
