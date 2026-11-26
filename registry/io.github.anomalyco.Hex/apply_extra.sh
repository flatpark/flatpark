#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"

[ -f hex.deb ] || { echo "missing extra-data: hex.deb" >&2; exit 1; }
rm -rf stage bin
mkdir -p stage bin
# Flatpak runs this offline and may run it as root with no capabilities.
bsdtar -xOf hex.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/usr/bin/hex ] || { echo "Hex executable missing from .deb" >&2; exit 1; }
mv stage/usr/bin/hex bin/
rm -rf stage hex.deb
