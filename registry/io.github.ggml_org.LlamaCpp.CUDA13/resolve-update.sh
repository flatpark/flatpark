#!/usr/bin/env bash
set -euo pipefail
api=https://api.github.com/repos/ggml-org/llama.cpp/releases
release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} "$api/latest")"
# Stable releases can select a binary build through upstream's nightly-tag.txt.
# Follow that pointer rather than choosing an arbitrary newer prerelease.
pointer="$(jq -r '[.assets[] | select(.name == "nightly-tag.txt")] | if length == 1 then .[0].browser_download_url elif length == 0 then "" else error("ambiguous binary release pointer") end' <<<"$release")"
if [ -n "$pointer" ]; then
    case "$pointer" in
        https://github.com/ggml-org/llama.cpp/releases/download/*/nightly-tag.txt) ;;
        *) echo 'unexpected upstream pointer URL' >&2; exit 1 ;;
    esac
    tag="$(curl -fsSL "$pointer")"
    [[ "$tag" =~ ^b[0-9]+$ ]] || { echo 'invalid binary release tag' >&2; exit 1; }
    release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} "$api/tags/$tag")"
fi
jq -e '
    . as $r
    | [.assets[] | select(.name | test("^llama-" + $r.tag_name + "-bin-ubuntu-cuda-13\\.[0-9]+-x64\\.tar\\.gz$"))] as $assets
    | if ($assets | length) != 1 then error("expected exactly one Linux CUDA 13 asset") else
      [.assets[] | select(.name == ("cudart-" + $assets[0].name))] as $runtime
    | if ($runtime | length) != 1 then error("expected exactly one matching CUDA 13 runtime asset") else
      {version: .tag_name, releaseDate: .published_at[0:10],
       sources: [{filename: "llama.tar.gz", arch: "x86_64", url: $assets[0].browser_download_url},
                 {filename: "cudart.tar.gz", arch: "x86_64", url: $runtime[0].browser_download_url}]}
      end end' <<<"$release"
