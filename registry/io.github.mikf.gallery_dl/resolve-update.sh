#!/usr/bin/env bash
set -euo pipefail
release="$(curl -fsSL --retry 3 https://codeberg.org/api/v1/repos/mikf/gallery-dl/releases/latest)"
tag="$(jq -er '.tag_name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))' <<<"$release")"
jq -e '.draft == false and .prerelease == false' <<<"$release" >/dev/null
url="$(jq -er '[.assets[] | select(.name == "gallery-dl.bin")] | if length == 1 then .[0].browser_download_url else error("expected gallery-dl.bin") end' <<<"$release")"
[[ "$url" == "https://codeberg.org/mikf/gallery-dl/releases/download/$tag/gallery-dl.bin" ]]
jq -n --arg v "${tag#v}" --arg d "$(jq -er '.published_at | split("T")[0]' <<<"$release")" --arg u "$url" '{version:$v, releaseDate:$d, sources:[{filename:"gallery-dl.bin",url:$u}]}'
