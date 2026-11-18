#!/usr/bin/env bash
set -euo pipefail
# Upstream attaches the same-named FlatPark archive to every release.
release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  https://api.github.com/repos/ada-h00k/Corvus/releases/latest)"
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$release")"
date="$(jq -r '.published_at' <<<"$release" | cut -c1-10)"
url="$(jq -r '.assets[] | select(.name == "corvus-linux-x86_64-flatpark.tar.gz") | .browser_download_url' <<<"$release")"
[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve Corvus release" >&2; exit 1; }
jq -n --arg version "$version" --arg releaseDate "$date" --arg url "$url" \
  '{version:$version, releaseDate:$releaseDate, releaseUrl:("https://github.com/ada-h00k/Corvus/releases/tag/v"+$version), sources:[{filename:"corvus.tar.gz", arch:"x86_64", url:$url}]}'
