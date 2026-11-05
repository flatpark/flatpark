#!/usr/bin/env bash
set -euo pipefail
repo=m-obeid/Mixtapes
# All app releases are prereleases; /latest excludes them. Ignore dependency tags.
releases="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases?per_page=100")"
release="$(jq -ce '[.[] | select(.draft == false) | select(.tag_name | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}\\.[0-9]+$"))] | sort_by(.published_at) | last // error("no Mixtapes release")' <<<"$releases")"
version="$(jq -er '.tag_name' <<<"$release")"
asset="mixtapes-$version-x86_64.tar.zst"
url="$(jq -er --arg name "$asset" '[.assets[] | select(.name == $name)] | if length == 1 then .[0].browser_download_url else error("expected one x86_64 Linux tarball") end' <<<"$release")"
[[ "$url" == "https://github.com/$repo/releases/download/$version/$asset" ]] || { echo "unexpected artifact URL: $url" >&2; exit 1; }
date="$(jq -er '.published_at | split("T")[0]' <<<"$release")"
jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"mixtapes.tar.zst", url:$u}]}'
