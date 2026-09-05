#!/usr/bin/env bash
# Update resolver for Notepad3.
#
# Prints the current version + the official x64 portable zip as JSON on stdout:
#   { "version": "7.26.602.1", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "notepad3.zip", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting - FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# releases/latest (no prereleases) is deliberate: upstream cuts frequent beta
# builds (RELEASE_<version> tags marked prerelease) between stable releases,
# and this package tracks the stable channel.
set -euo pipefail

repo="rizonesoft/Notepad3"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

# Tags are RELEASE_<version>; the version itself is what the metainfo carries.
version="$(jq -r '.tag_name | ltrimstr("RELEASE_")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Assets per release: Notepad3_<ver>_x64_Portable.zip (packaged here),
# Notepad3_<ver>_x86_Portable.zip, Notepad3_<ver>_x64_Setup.exe and
# Notepad3Portable_<ver>.paf.exe. Anchor on the exact x64 Portable zip so the
# x86 build and the installers stay out.
url="$(jq -r '.assets[] | select(.name | test("^Notepad3_[0-9][0-9.]*_x64_Portable\\.zip$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve notepad3 release" >&2; exit 1; }
echo "resolved notepad3 $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"notepad3.zip", url:$u}]}'
