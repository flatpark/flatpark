#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
for archive in audio.tar.gz cudart.tar.gz nccl.deb; do
    [ -f "$archive" ] || { echo "Missing extra-data: $archive" >&2; exit 1; }
done
rm -rf audio cudart nccl
mkdir audio cudart nccl
# System installs run as root without ownership-restoration capabilities.
bsdtar --no-same-owner -xf audio.tar.gz -C audio
[ -x audio/audiocpp_server ] || { echo "Missing executable: audiocpp_server" >&2; exit 1; }
[ -d audio/model_specs ] || { echo "Missing model_specs" >&2; exit 1; }
bsdtar --no-same-owner -xf cudart.tar.gz -C cudart
for library in libcudart.so.12 libcublas.so.12 libcublasLt.so.12 libcufft.so.11; do
    [ -f "cudart/$library" ] || { echo "Missing CUDA runtime: $library" >&2; exit 1; }
done
bsdtar -xOf nccl.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C nccl
[ -f nccl/usr/lib/x86_64-linux-gnu/libnccl.so.2 ] || { echo "Missing NCCL runtime" >&2; exit 1; }
rm audio.tar.gz cudart.tar.gz nccl.deb
