#!/usr/bin/env bash
# Update resolver for PJeOffice Pro.
#
# PJeOffice Pro checks for its own updates against a properties file the CNJ
# publishes next to the downloads, and that file is the version anchor here:
#
#   https://pje-office.pje.jus.br/pro/update.properties
#     app.version=2.5.16
#
# The Linux zip for a version sits beside it, named with a "u" build suffix:
#
#   https://pje-office.pje.jus.br/pro/pjeoffice-pro-v2.5.16u-linux_x64.zip
#
# The URL is checked before it is printed, so a change to that naming fails
# here rather than as a broken pin. The date is the zip's Last-Modified.
#
# Prints:
#   { "version": "2.5.16", "releaseDate": "2024-07-23", "sources": [
#       { "filename": "pjeoffice-pro.zip", "url": "..." }
#   ] }
# Only an x86_64 Linux build is published, so only x86_64 is packaged.
#
# Logs go to stderr. No hashing, no manifest rewriting - FlatPark downloads the
# URL and computes the extra-data sha256/size at build time.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

base="https://pje-office.pje.jus.br/pro"

version="$(curl -fsSL "$base/update.properties" \
  | sed -nE 's/^app\.version[[:space:]]*=[[:space:]]*([0-9]+(\.[0-9]+)+)[[:space:]]*$/\1/p' | head -n1)"
[ -n "$version" ] || { echo "no app.version in $base/update.properties" >&2; exit 1; }

url="$base/pjeoffice-pro-v${version}u-linux_x64.zip"
headers="$(curl -fsSI "$url")" || { echo "Linux zip for $version not found at $url" >&2; exit 1; }

# The date is a nicety; a missing header must not block an update.
release_date="$(printf '%s\n' "$headers" | tr -d '\r' \
  | sed -nE 's/^[Ll]ast-[Mm]odified: *(.*)$/\1/p' | head -n1)"
[ -z "$release_date" ] || release_date="$(date -u -d "$release_date" +%F 2>/dev/null || true)"

echo "resolved PJeOffice Pro $version (${release_date:-no date}): $url" >&2

jq -n \
  --arg v "$version" \
  --arg d "$release_date" \
  --arg u "$url" \
  '{version:$v} + (if $d == "" then {} else {releaseDate:$d} end) + {sources:[{filename:"pjeoffice-pro.zip", url:$u}]}'
