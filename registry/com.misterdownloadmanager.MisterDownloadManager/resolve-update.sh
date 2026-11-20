#!/usr/bin/env bash
# Update resolver for Mister Download Manager.
#
# Prints the latest release and its Linux x86_64 tarball as JSON on stdout;
# logs go to stderr. Releases are tagged vX.Y.Z and carry, besides the
# tarball, a .deb, .rpm, AppImage (+ .zsync), a symbols-linux-x86_64.zip and
# the browser extensions, so the asset name is anchored on the version and
# "-linux-x86_64.tar.gz".
set -euo pipefail

repo="anefzaoui/misterdownloadmanager"

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at | .[0:10]' <<<"$rel")"
url="$(jq -r --arg v "$version" \
  '.assets[] | select(.name == ("MisterDownloadManager-" + $v + "-linux-x86_64.tar.gz")) | .browser_download_url' \
  <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve Mister Download Manager release" >&2; exit 1; }
echo "resolved Mister Download Manager $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"mdm.tar.gz", url:$u}]}'
