#!/usr/bin/env bash
set -euo pipefail
release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} https://api.github.com/repos/0xShug0/audio.cpp/releases/latest)"
jq -e '
  . as $r
  | [.assets[] | select(.name == ("audio-" + $r.tag_name + "-bin-ubuntu-x64-cuda12.8-colab.tar.gz"))] as $app
  | [.assets[] | select(.name == ("audio-" + $r.tag_name + "-cudart-ubuntu-x64-cuda12.8.tar.gz"))] as $cuda
  | if ($app | length) != 1 or ($cuda | length) != 1 then
      error("expected one CUDA 12.8 Linux server and its matching runtime")
    else
      {version: (.tag_name | ltrimstr("v")), releaseDate: .published_at[0:10],
       sources: [{filename: "audio.tar.gz", arch: "x86_64", url: $app[0].browser_download_url},
                 {filename: "cudart.tar.gz", arch: "x86_64", url: $cuda[0].browser_download_url}]}
    end' <<<"$release"
