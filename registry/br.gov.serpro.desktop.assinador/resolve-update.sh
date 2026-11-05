#!/usr/bin/env bash
# Update resolver for Assinador Serpro.
#
# The version anchor is this package's own GitHub releases, not Serpro's site:
# a version is released there after it has been tested with a physical A3 token,
# so a new installer on Serpro's site does not reach users untested. A tag names
# Serpro's version plus a packaging revision, and only the version matters here:
#
#   v4.6.0-1 -> 4.6.0
#
# The bytes still come from Serpro. The installer's URL has the version in both
# the path and the name:
#
#   https://artefatos-assinador.serpro.gov.br/downloads/4.6.0/Assinador-Serpro-4.6.0-Linux-x86_64.bin
#
# The URL is checked before it is printed, so a change to that naming fails here
# rather than as a broken pin. The date is the installer's Last-Modified.
#
# Prints:
#   { "version": "4.6.0", "releaseDate": "2026-10-29", "sources": [
#       { "filename": "assinador.bin", "url": "..." }
#   ] }
# Only an x86_64 Linux build is published, so only x86_64 is packaged.
#
# Logs go to stderr. No hashing, no manifest rewriting - FlatPark downloads the
# URL and computes the extra-data sha256/size at build time.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

repo="LLawli/assinador-serpro-flatpak"
base="https://artefatos-assinador.serpro.gov.br/downloads"

tag="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases/latest" | jq -r '.tag_name // empty')"
version="$(sed -nE 's/^v([0-9]+(\.[0-9]+)+)(-[0-9]+)?$/\1/p' <<<"$tag")"
[ -n "$version" ] || { echo "no version in the latest release of $repo: '$tag'" >&2; exit 1; }

url="$base/$version/Assinador-Serpro-$version-Linux-x86_64.bin"
headers="$(curl -fsSI "$url")" || { echo "Linux installer for $version not found at $url" >&2; exit 1; }

# The date is a nicety; a missing header must not block an update.
release_date="$(printf '%s\n' "$headers" | tr -d '\r' \
  | sed -nE 's/^[Ll]ast-[Mm]odified: *(.*)$/\1/p' | head -n1)"
[ -z "$release_date" ] || release_date="$(date -u -d "$release_date" +%F 2>/dev/null || true)"

echo "resolved Assinador Serpro $version (${release_date:-no date}): $url" >&2

jq -n \
  --arg v "$version" \
  --arg d "$release_date" \
  --arg u "$url" \
  '{version:$v} + (if $d == "" then {} else {releaseDate:$d} end) + {sources:[{filename:"assinador.bin", url:$u}]}'
