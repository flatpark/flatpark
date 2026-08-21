#!/usr/bin/env bash
# Update resolver for LeePanel.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "1.0.21", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "leepanel.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="gna1280072/LeePanel"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The Linux x86_64 build is the `LeePanel_<version>_amd64.deb` asset. The
# release also carries a detached `.deb.sig`, an .rpm, an AppImage and the
# macOS/Windows bundles — the anchored suffix match keeps all of those out.
mapfile -t urls < <(jq -r '.assets[] | select(.name | test("_amd64\\.deb$")) | .browser_download_url' <<<"$rel")

[ -n "$version" ] || { echo "failed to resolve the LeePanel version" >&2; exit 1; }
[ "${#urls[@]}" -eq 1 ] || {
  echo "expected exactly one _amd64.deb asset, got ${#urls[@]}: ${urls[*]-none}" >&2
  exit 1
}
echo "resolved leepanel $version ($date): ${urls[0]}" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "${urls[0]}" \
  '{version:$v, releaseDate:$d, sources:[{filename:"leepanel.deb", url:$u}]}'
