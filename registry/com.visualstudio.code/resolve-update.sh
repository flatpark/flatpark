#!/usr/bin/env bash
# Update resolver for Visual Studio Code.
#
# Microsoft's update service reports the latest stable build per platform,
# with a versioned, commit-addressed .deb URL:
#   https://update.code.visualstudio.com/api/update/linux-deb-x64/stable/latest
#
# Prints the version + both .deb URLs as JSON on stdout. Logs go to stderr.
# No hashing, no manifest rewriting — FlatPark downloads the URLs and computes
# the extra-data sha256/size at build time.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

api="https://update.code.visualstudio.com/api/update"

x64="$(curl -fsSL "$api/linux-deb-x64/stable/latest")"
arm64="$(curl -fsSL "$api/linux-deb-arm64/stable/latest")"

version="$(jq -r '.productVersion' <<<"$x64")"
version_arm64="$(jq -r '.productVersion' <<<"$arm64")"
url_amd64="$(jq -r '.url' <<<"$x64")"
url_arm64="$(jq -r '.url' <<<"$arm64")"
date="$(jq -r '.timestamp / 1000 | floor | strftime("%Y-%m-%d")' <<<"$x64")"

[ -n "$version" ] && [ "$version" != null ] || { echo "failed to resolve the VS Code release" >&2; exit 1; }
[ "$version" = "$version_arm64" ] || {
  echo "x64 and arm64 disagree: x64=$version arm64=$version_arm64" >&2
  exit 1
}
[[ "$url_amd64" == *"/code_${version}-"*"_amd64.deb" ]] || { echo "unexpected x64 URL: $url_amd64" >&2; exit 1; }
[[ "$url_arm64" == *"/code_${version}-"*"_arm64.deb" ]] || { echo "unexpected arm64 URL: $url_arm64" >&2; exit 1; }

echo "resolved VS Code $version ($date)" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url_amd64" --arg ua "$url_arm64" \
  '{version:$v, releaseDate:$d, releaseUrl:"https://code.visualstudio.com/updates", sources:[
     {filename:"code.deb", arch:"x86_64",  url:$u},
     {filename:"code.deb", arch:"aarch64", url:$ua}
   ]}'
