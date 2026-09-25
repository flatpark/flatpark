#!/usr/bin/env bash
# Update resolver for Shutter Encoder.
#
# Shutter Encoder's Linux builds are not attached to the GitHub releases; they
# are published on shutterencoder.com behind a download-manager link that stays
# the same across releases, while the page lists the current file names:
#
#   https://www.shutterencoder.com/
#     <a id="donateDEB" href="https://www.shutterencoder.com/sdc_download/496/?key=...">
#     <a href="Shutter Encoder 20.3 Linux 64bits.deb"></a>
#
# The version comes from that file name and the date from the matching GitHub
# release tag (20.3), which is published alongside.
#
# Prints:
#   { "version": "20.3", "releaseDate": "2026-08-31", "sources": [
#       { "filename": "shutter-encoder.deb", "url": "..." }
#   ] }
# Only an amd64 build is published, so only x86_64 is packaged.
#
# Logs go to stderr. No hashing, no manifest rewriting - FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. Because the URL is
# the same for every release, a re-pin is what keeps the pinned sha256 matching
# the bytes the URL serves.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

page="https://www.shutterencoder.com/"
# tr: the page carries a stray NUL byte, which bash would warn about.
html="$(curl -fsSL --compressed -A 'Mozilla/5.0' "$page" | tr -d '\000')"

# Anchored on the link's own id, not on its position among the download
# buttons, so a new platform added to the page cannot shift it.
url="$(printf '%s\n' "$html" \
  | grep -oE 'id="donateDEB" href="https://www\.shutterencoder\.com/sdc_download/[0-9]+/\?key=[A-Za-z0-9]+"' \
  | sed -E 's/.*href="([^"]+)"/\1/' | sort -u || true)"
[ -n "$url" ] || { echo "no Linux .deb download link on $page" >&2; exit 1; }
[ "$(wc -l <<<"$url")" -eq 1 ] || { echo "expected exactly one Linux .deb link, got:" >&2; echo "$url" >&2; exit 1; }

version="$(printf '%s\n' "$html" \
  | grep -oE 'Shutter Encoder [0-9]+(\.[0-9]+)+ Linux 64bits\.deb' \
  | sed -E 's/^Shutter Encoder ([0-9.]+) .*/\1/' | sort -uV || true)"
[ -n "$version" ] || { echo "no Linux .deb file name on $page" >&2; exit 1; }
[ "$(wc -l <<<"$version")" -eq 1 ] || { echo "expected one Linux .deb version, got:" >&2; echo "$version" >&2; exit 1; }

# The date is a nicety; a missing release there must not block an update.
release_date="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/paulpacifico/shutter-encoder/releases/tags/$version" 2>/dev/null \
  | jq -r '.published_at // empty' | cut -c1-10 || true)"

echo "resolved Shutter Encoder $version (${release_date:-no date}): $url" >&2

jq -n \
  --arg v "$version" \
  --arg d "$release_date" \
  --arg u "$url" \
  '{version:$v} + (if $d == "" then {} else {releaseDate:$d} end) + {sources:[{filename:"shutter-encoder.deb", url:$u}]}'
