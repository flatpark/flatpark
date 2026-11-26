#!/usr/bin/env bash
# Update resolver for Euro-Office Desktop Editors.
#
# Prints the current version + the official x86_64 archive as JSON on stdout:
#   { "version": "9.3.5-2", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "euro-office.tar.xz", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# Upstream publishes the Linux build as .tar.xz, not .tar.gz, beside Windows
# zips, the .deb, the help archive and the aarch64 archive. Every stable
# release carries euro-office-euro-office-<version>-x86_64.tar.xz, so this
# reads releases/latest (which skips the -rc.N prereleases) and fails when the
# archive is missing instead of settling on an older release. The version is
# the one in the archive name (9.3.8-0), not the tag.
# aarch64 is not published: the Kerberos libraries this build needs are
# re-pinned from Debian's amd64 index, which cannot describe an arm64 package.
set -euo pipefail

repo="Euro-Office/DesktopEditors"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

picked="$(jq -c '
  [ .published_at as $p
    | .assets[]
    | select(.name | test("^euro-office-euro-office-[0-9].*-x86_64\\.tar\\.xz$"))
    | {name: .name, url: .browser_download_url, published: $p}
  ] | if length == 1 then .[0] else empty end
' <<<"$rel")"

[ -n "$picked" ] || { echo "failed to resolve Euro-Office release" >&2; exit 1; }

asset="$(jq -r '.name' <<<"$picked")"
url="$(jq -r '.url' <<<"$picked")"
date="$(jq -r '.published' <<<"$picked" | cut -c1-10)"
version="$(sed -n 's/^euro-office-euro-office-\(.*\)-x86_64\.tar\.xz$/\1/p' <<<"$asset")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve Euro-Office release" >&2; exit 1; }
echo "resolved Euro-Office $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"euro-office.tar.xz", url:$u}]}'
