#!/usr/bin/env bash
# Update resolver for FreeOffice.
#
# SoftMaker links the current Linux packages from its installation page, with
# the edition year and the public revision in the file name:
#
#   https://www.freeoffice.com/en/support/installation/linux
#     https://www.softmaker.net/down/softmaker-freeoffice-2024_1234-01_amd64.deb
#
# and dates each revision on the download page ("Revision 1234 | 2026-04-28").
# The version is <edition>.<revision> - "2024.1234", the revision the About box
# shows - with the package's -NN suffix appended only when it is not -01, so a
# re-cut of the same revision still moves the version and gets re-pinned.
#
# Prints:
#   { "version": "2024.1234", "releaseDate": "2026-04-28", "sources": [
#       { "filename": "freeoffice.deb", "url": "..." }
#   ] }
# Only an amd64 build is published, so only x86_64 is packaged.
#
# Logs go to stderr. No hashing, no manifest rewriting - FlatPark downloads the
# URL and computes the extra-data sha256/size at build time.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

install_page="https://www.freeoffice.com/en/support/installation/linux"
download_page="https://www.freeoffice.com/en/download/applications"

html="$(curl -fsSL "$install_page")"

# Every edition linked from the page, newest edition then newest revision
# first, so a new edition year is picked up as soon as SoftMaker links it.
url="$(printf '%s\n' "$html" \
  | grep -oE 'https://www\.softmaker\.net/down/softmaker-freeoffice-[0-9]{4}_[0-9]+-[0-9]+_amd64\.deb' \
  | sort -u -t_ -k1,1V -k2,2V | tail -n1 || true)"
[ -n "$url" ] || { echo "no FreeOffice amd64 .deb linked from $install_page" >&2; exit 1; }

file="${url##*/}"
if [[ "$file" =~ ^softmaker-freeoffice-([0-9]{4})_([0-9]+)-([0-9]+)_amd64\.deb$ ]]; then
  edition="${BASH_REMATCH[1]}"
  revision="${BASH_REMATCH[2]}"
  build="${BASH_REMATCH[3]}"
else
  echo "unexpected FreeOffice package name: $file" >&2
  exit 1
fi

version="$edition.$revision"
[ "$build" = "01" ] || version="$version-$build"

# The date is a nicety; a page change there must not block an update.
release_date="$(curl -fsSL "$download_page" 2>/dev/null \
  | grep -oE "Revision $revision \\| [0-9]{4}-[0-9]{2}-[0-9]{2}" \
  | head -n1 | sed -E 's/.*\| //' || true)"

echo "resolved FreeOffice $version (${release_date:-no date}): $url" >&2

jq -n \
  --arg v "$version" \
  --arg d "$release_date" \
  --arg u "$url" \
  '{version:$v} + (if $d == "" then {} else {releaseDate:$d} end) + {sources:[{filename:"freeoffice.deb", url:$u}]}'
