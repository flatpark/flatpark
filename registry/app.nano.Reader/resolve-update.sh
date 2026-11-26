#!/usr/bin/env bash
set -euo pipefail
repo=SELECT-stupidity-FROM-discord/NanoYomi
args=(-fsSL)
if [ -n "${GITHUB_TOKEN:-}" ]; then args+=(-H "Authorization: Bearer $GITHUB_TOKEN"); fi
rel=$(curl "${args[@]}" "https://api.github.com/repos/$repo/releases/latest")
version=$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")
date=$(jq -r '.published_at[0:10]' <<<"$rel")
x64=$(jq -r '[.assets[] | select(.name == "nano-linux-x64.tar.gz") | .browser_download_url] | if length == 1 then .[0] else empty end' <<<"$rel")
arm=$(jq -r '[.assets[] | select(.name == "nano-linux-arm64.tar.gz") | .browser_download_url] | if length == 1 then .[0] else empty end' <<<"$rel")
[ -n "$version" ] && [ "$version" != null ] && [ -n "$date" ] && [ -n "$x64" ] && [ -n "$arm" ] || { echo 'could not resolve NanoYomi release' >&2; exit 1; }
jq -n --arg v "$version" --arg d "$date" --arg x "$x64" --arg a "$arm" '{version:$v,releaseDate:$d,sources:[{filename:"nano.tar.gz",arch:"x86_64",url:$x},{filename:"nano.tar.gz",arch:"aarch64",url:$a}]}'
