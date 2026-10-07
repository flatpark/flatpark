#!/usr/bin/env bash
# Update resolver for DashBeam.
#
# Prints the latest version, release date and the official Linux amd64 .deb as
# JSON on stdout; logs go to stderr. Hashing and manifest rewriting are handled
# by FlatPark's update automation.
#
# The release ships amd64 and arm64 .debs, each with a detached .sig, next to
# rpms, AppImages, updater tarballs and the macOS/Windows/Android builds. The
# amd64 .deb is matched on its name, never assembled from the tag, and an
# ambiguous match is an error rather than a silent first-match. releases/latest
# skips the pre-releases upstream cuts between stable versions.
set -euo pipefail

repo="tonyantony300/dashbeam"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r '[.assets[] | select(.name | test("^DashBeam_[^/]*_amd64\\.deb$")) | .browser_download_url]
              | if length == 1 then .[0] else empty end' <<<"$rel")"

[ -n "$version" ] && [ -n "$date" ] && [ -n "$url" ] || {
  echo "failed to resolve DashBeam release" >&2
  exit 1
}
echo "resolved DashBeam $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"dashbeam.deb", url:$u}]}'
