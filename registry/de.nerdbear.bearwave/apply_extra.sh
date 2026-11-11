#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
[ -f bearwave.tar.xz ] || { echo "missing extra-data: bearwave.tar.xz" >&2; exit 1; }
rm -rf stage bearwave
mkdir stage
bsdtar --no-same-owner -xJf bearwave.tar.xz -C stage
[ -x stage/bin/bearwave ] || { echo "BearWave binary not found" >&2; exit 1; }
mv stage bearwave
rm -f bearwave.tar.xz
