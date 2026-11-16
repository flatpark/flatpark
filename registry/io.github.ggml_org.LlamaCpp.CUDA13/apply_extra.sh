#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
[ -f llama.tar.gz ] || { echo 'missing extra-data: llama.tar.gz' >&2; exit 1; }
[ -f cudart.tar.gz ] || { echo 'missing extra-data: cudart.tar.gz' >&2; exit 1; }
rm -rf stage llama cudart
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
bsdtar --no-same-owner -xf cudart.tar.gz -C stage
top="$(find stage -mindepth 1 -maxdepth 1 -type d)"
[ "$(printf '%s\n' "$top" | wc -l)" -eq 1 ] && [ -n "$top" ] || {
    echo 'expected one upstream CUDA runtime directory' >&2; exit 1;
}
mv "$top" cudart
for library in libcudart.so.13 libcublas.so.13 libcublasLt.so.13; do
    [ -f "cudart/$library" ] || { echo "missing upstream CUDA runtime: $library" >&2; exit 1; }
done
[ -f llama/libggml-cuda.so ] || { echo 'missing upstream CUDA backend' >&2; exit 1; }
rm -rf stage llama.tar.gz cudart.tar.gz
