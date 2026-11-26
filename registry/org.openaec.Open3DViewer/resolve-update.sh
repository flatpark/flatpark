#!/usr/bin/env bash
# Update resolver for Open BIM Suite (formerly Open 3D Viewer Studio).
#
# Each GitHub release ships the viewer for Linux as a deb, an rpm, an AppImage
# and a portable tarball, per arch, plus Windows and macOS builds and .asc
# signatures. This package takes the portable tarballs only:
#   open-3d-viewer_<version>_linux-x64.tar.gz    (x86_64)
#   open-3d-viewer_<version>_linux-arm64.tar.gz  (aarch64)
# Both come from releases/latest (which skips the video/* prerelease): every
# release since v2026.44.17 carries both, so a missing one fails instead of
# settling on an older release.
# Prints JSON on stdout:
#   { "version": "2026.47.5", "releaseDate": "YYYY-MM-DD", "releaseUrl": "...",
#     "sources": [ { "filename": "open-3d-viewer.tar.gz", "arch": "x86_64", "url": "..." }, ... ] }
# Logs go to stderr. No hashing, no manifest rewriting.
set -euo pipefail

repo="OpenAEC-Foundation/open-bim-suite"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

best="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases/latest" | jq '
  def asset($rel; $arch):
    [ $rel.assets[]
      | select(.name | test("^open-3d-viewer_[0-9][0-9.]*_linux-" + $arch + "\\.tar\\.gz$")) ][0];
  [ . as $r
    | asset($r; "x64") as $x | asset($r; "arm64") as $a
    | select($x != null and $a != null)
    | ($x.name | capture("^open-3d-viewer_(?<v>[0-9][0-9.]*)_linux-x64\\.tar\\.gz$").v) as $v
    | select($a.name == "open-3d-viewer_" + $v + "_linux-arm64.tar.gz")
    | { published: $r.published_at,
        html: $r.html_url,
        x64: $x.browser_download_url,
        arm64: $a.browser_download_url,
        ver: $v } ]
  | if length == 1 then .[0] else null end')"

version="$(jq -r '.ver // empty' <<<"$best")"
date="$(jq -r '.published // empty' <<<"$best" | cut -c1-10)"
release_url="$(jq -r '.html // empty' <<<"$best")"
x64="$(jq -r '.x64 // empty' <<<"$best")"
arm64="$(jq -r '.arm64 // empty' <<<"$best")"

[ -n "$version" ] && [ -n "$x64" ] && [ -n "$arm64" ] || { echo "failed to resolve Open BIM Suite release" >&2; exit 1; }
echo "resolved Open BIM Suite $version ($date): $x64 $arm64" >&2

jq -n --arg v "$version" --arg d "$date" --arg r "$release_url" --arg x "$x64" --arg a "$arm64" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[
     {filename:"open-3d-viewer.tar.gz", arch:"x86_64", url:$x},
     {filename:"open-3d-viewer.tar.gz", arch:"aarch64", url:$a}
   ]}'
