#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
[ -f llama.tar.gz ] || { echo 'missing extra-data: llama.tar.gz' >&2; exit 1; }
rm -rf stage llama
mkdir stage
# System installs run as root without ownership-restoration capabilities.
bsdtar --no-same-owner -xf llama.tar.gz -C stage
top="$(find stage -mindepth 1 -maxdepth 1 -type d)"
[ "$(printf '%s\n' "$top" | wc -l)" -eq 1 ] && [ -n "$top" ] || {
    echo 'expected one upstream llama directory' >&2; exit 1;
}
mv "$top" llama
for binary in llama llama-server llama-cli llama-bench llama-quantize; do
    [ -x "llama/$binary" ] || { echo "missing upstream executable: $binary" >&2; exit 1; }
done
# Fail an update if the selected asset no longer carries the OpenVINO backend.
[ -f llama/libggml-openvino.so ] && [ -f llama/libopenvino_intel_cpu_plugin.so ] || {
    echo 'missing upstream OpenVINO backend or CPU plugin' >&2; exit 1;
}
rm -rf stage llama.tar.gz
