#!/usr/bin/env bash
# Update resolver for Open Pointcloud Studio.
#
# Each GitHub release also carries the source of Open CAD Studio
# (open-cad-studio-source_*, open-cad-studio-vendor_*), the SDK libraries
# (open-pointcloud-studio-sdk_<version>_linux-amd64-so.tar.gz, ...), a deb, an
# AppImage, Windows and macOS builds, checksums and reports. This package takes
# the app's portable tarballs only:
#   open-pointcloud-studio_<version>_linux-amd64.tar.gz  (x86_64)
#   open-pointcloud-studio_<version>_linux-arm64.tar.gz  (aarch64)
# Among the non-draft, non-prerelease releases that carry both, pick the
# highest version number, not the newest publish date.
# Prints JSON on stdout:
#   { "version": "2026.45.1", "releaseDate": "YYYY-MM-DD", "releaseUrl": "...",
#     "sources": [ { "filename": "open-pointcloud-studio.tar.gz", "arch": "x86_64", "url": "..." }, ... ] }
# Logs go to stderr. No hashing, no manifest rewriting.
set -euo pipefail

repo="OpenAEC-Foundation/open-pointcloud-studio"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

best="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases?per_page=30" | jq '
  def asset($rel; $arch):
    [ $rel.assets[]
      | select(.name | test("^open-pointcloud-studio_[0-9][0-9.]*_linux-" + $arch + "\\.tar\\.gz$")) ][0];
  [ .[] | select((.draft or .prerelease) | not) | . as $r
    | asset($r; "amd64") as $x | asset($r; "arm64") as $a
    | select($x != null and $a != null)
    | ($x.name | capture("^open-pointcloud-studio_(?<v>[0-9][0-9.]*)_linux-amd64\\.tar\\.gz$").v) as $v
    | select($a.name == "open-pointcloud-studio_" + $v + "_linux-arm64.tar.gz")
    | { published: $r.published_at,
        html: $r.html_url,
        amd64: $x.browser_download_url,
        arm64: $a.browser_download_url,
        ver: $v } ]
  | max_by(.ver | split(".") | map(tonumber))')"

version="$(jq -r '.ver // empty' <<<"$best")"
date="$(jq -r '.published // empty' <<<"$best" | cut -c1-10)"
release_url="$(jq -r '.html // empty' <<<"$best")"
amd64="$(jq -r '.amd64 // empty' <<<"$best")"
arm64="$(jq -r '.arm64 // empty' <<<"$best")"

[ -n "$version" ] && [ -n "$amd64" ] && [ -n "$arm64" ] || { echo "failed to resolve Open Pointcloud Studio release" >&2; exit 1; }
echo "resolved Open Pointcloud Studio $version ($date): $amd64 $arm64" >&2

jq -n --arg v "$version" --arg d "$date" --arg r "$release_url" --arg x "$amd64" --arg a "$arm64" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[
     {filename:"open-pointcloud-studio.tar.gz", arch:"x86_64", url:$x},
     {filename:"open-pointcloud-studio.tar.gz", arch:"aarch64", url:$a}
   ]}'
