#!/usr/bin/env bash
# Stable releases only; the draft nightly pin must be replaced before publishing.
set -euo pipefail
repo=tangency-labs/pcbcraft
headers=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then headers=(-H "Authorization: Bearer $GITHUB_TOKEN"); fi
release=$(curl -fsSL "${headers[@]}" "https://api.github.com/repos/$repo/releases/latest")
version=$(jq -er '.tag_name | ltrimstr("v") | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))' <<<"$release")
date=$(jq -er '.published_at | .[0:10]' <<<"$release")
url=$(jq -er --arg name "pcbcraft-$version-linux-x86_64.tar.gz" '[.assets[] | select(.name == $name) | .browser_download_url] | if length == 1 then .[0] else error("expected one Linux tarball") end' <<<"$release")
jq -n --arg v "$version" --arg d "$date" --arg url "$url" '{version:$v,releaseDate:$d,sources:[{filename:"pcbcraft.tar.gz",arch:"x86_64",url:$url}]}'
