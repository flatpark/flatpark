#!/usr/bin/env bash
set -euo pipefail
# Codeberg is the upstream release authority. Its assets link to the official
# GitHub downloads; require both GUI tarballs from the same stable release.
release="$(curl -fsSL --retry 3 https://codeberg.org/api/v1/repos/blast/blastqr/releases/latest)"
tag="$(jq -er '.tag_name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))' <<<"$release")"
jq -e '.draft == false and .prerelease == false' <<<"$release" >/dev/null
sources='[]'
for pair in x86_64:x64 aarch64:arm64; do
    arch="${pair%:*}"
    name="blastqr-${tag}-linux-${pair#*:}.tar.gz"
    url="$(jq -er --arg name "$name" '[.assets[] | select(.name == $name)] | if length == 1 then .[0].browser_download_url else error("expected exactly one GUI tarball") end' <<<"$release")"
    [[ "$url" == "https://github.com/blastapps/blastqr/releases/download/$tag/$name" ]] || {
        echo "unexpected release asset URL: $url" >&2; exit 1;
    }
    sources="$(jq -c --arg a "$arch" --arg u "$url" '. + [{filename:"blastqr.tar.gz", arch:$a, url:$u}]' <<<"$sources")"
done
jq -n --arg v "${tag#v}" --arg d "$(jq -er '.published_at | split("T")[0]' <<<"$release")" --argjson s "$sources" '{version:$v, releaseDate:$d, sources:$s}'
