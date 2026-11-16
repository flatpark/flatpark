#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
[ -f ollama.tar.zst ] || { echo "Missing extra-data: ollama.tar.zst" >&2; exit 1; }
rm -rf stage ollama
mkdir stage
# System installs run as root without capabilities to restore archive owners.
bsdtar --no-same-owner -xf ollama.tar.zst -C stage
[ -x stage/bin/ollama ] || { echo "Missing executable: bin/ollama" >&2; exit 1; }
[ -d stage/lib/ollama ] || { echo "Missing bundled runtime: lib/ollama" >&2; exit 1; }
# Reject a future asset that drops the CUDA backend instead of silently shipping it.
find stage/lib/ollama -name 'libggml-cuda.so*' -print | grep -q . || {
    echo "Missing bundled CUDA backend" >&2; exit 1;
}
mv stage ollama
rm ollama.tar.zst
