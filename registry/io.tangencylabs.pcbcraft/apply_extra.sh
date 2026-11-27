#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
[ -f pcbcraft.tar.gz ] || { echo 'missing pcbcraft.tar.gz' >&2; exit 1; }
rm -rf stage pcbcraft
mkdir stage
tar --no-same-owner -xzf pcbcraft.tar.gz -C stage
set -- stage/*
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo 'expected one directory in PCBCraft archive' >&2; exit 1; }
mv "$1" pcbcraft
for binary in pcbcraft pcbcraft-cli; do
  [ -x "pcbcraft/$binary" ] || { echo "missing executable: $binary" >&2; exit 1; }
done
rm -rf stage pcbcraft.tar.gz
