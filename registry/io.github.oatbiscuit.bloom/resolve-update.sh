#!/usr/bin/env bash
set -euo pipefail
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} https://api.github.com/repos/oatbiscuit/bloom/releases/latest)"
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at[:10]' <<<"$rel")"
url="$(jq -r '.assets[] | select(.name | test("^bloom-[0-9].*\\.x86_64\\.rpm$")) | .browser_download_url' <<<"$rel")"
url_arm="$(jq -r '.assets[] | select(.name | test("^bloom-[0-9].*\\.aarch64\\.rpm$")) | .browser_download_url' <<<"$rel")"
[[ -n "$version" && "$version" != null && -n "$url" && -n "$url_arm" && "$url" != *$'\n'* && "$url_arm" != *$'\n'* ]] || { echo 'release is missing unambiguous RPMs' >&2; exit 1; }
jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg a "$url_arm" '{version:$v, releaseDate:$d, sources:[{filename:"bloom.rpm", arch:"x86_64", url:$u}, {filename:"bloom.rpm", arch:"aarch64", url:$a}]}'
