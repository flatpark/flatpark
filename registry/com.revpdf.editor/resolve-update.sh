#!/usr/bin/env bash
# Update resolver for RevPDF.
#
# Prints the current version + the Linux x86_64 AppImage as JSON on stdout:
#   { "version": "5.0.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "revpdf.AppImage", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting - FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="Pawandeep-prog/revpdf-release"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

# Tags are `v<version>`.
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The release asset rather than the rolling copy the website links to under
# raw/refs/heads/main/linux/: that one is overwritten in place on every release,
# so a pin to it would break the sha256 the moment upstream ships. Matched by
# exact name so the aarch64 AppImage can never be picked.
url="$(jq -r '.assets[] | select(.name == "revpdf_editor-x86_64.AppImage") | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ "$version" != "null" ] && [ -n "$url" ] && [ "$url" != "null" ] || {
  echo "failed to resolve RevPDF release" >&2
  exit 1
}
echo "resolved RevPDF $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"revpdf.AppImage", url:$u}]}'
