#!/usr/bin/env bash
# Update resolver for ZFileSync.
#
# Prints the latest version and its Linux .deb as JSON on stdout:
#   { "version": "0.1.1", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "zfilesync.deb", "url": "..." } ] }
# Logs go to stderr. The installers are published on the project's own
# download page; the GitHub releases carry no Linux files.
set -euo pipefail

page="https://zsync.eu/zfilesync/"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq; need sort

html="$(curl -fsSL --retry 3 "$page")"
# Links look like ./release/ZFileSync_0.1.1_amd64.deb; take the highest version.
file="$(grep -oE 'release/ZFileSync_[0-9]+(\.[0-9]+)+_amd64\.deb' <<<"$html" | sort -u -V | tail -n1)"
[ -n "$file" ] || { echo "no ZFileSync .deb link on $page" >&2; exit 1; }

version="$(sed -E 's/.*ZFileSync_([0-9.]+)_amd64\.deb/\1/' <<<"$file")"
url="${page}${file}"

# The page carries no dates; the file's Last-Modified is the release day.
lm="$(curl -fsSIL --retry 3 "$url" | tr -d '\r' | awk -F': ' 'tolower($1)=="last-modified"{v=$2} END{print v}')"
date="$(date -u -d "$lm" +%F 2>/dev/null || date -u +%F)"

echo "resolved zfilesync $version ($date): $url" >&2
jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"zfilesync.deb", url:$u}]}'
