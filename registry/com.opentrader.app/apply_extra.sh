#!/bin/sh
set -eu

# Runs offline in the runtime and extracts the official .deb into /app/extra.
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f opentrader.deb ] || { echo "missing extra-data: opentrader.deb" >&2; exit 1; }

# bsdtar reads the .deb ar container and its data.tar.gz member. Keep only the
# app binary: the desktop entry and icon must be exported at build time.
rm -rf stage opentrader
mkdir stage
bsdtar -xOf opentrader.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/usr/bin/opentrader ] || { echo "opentrader binary not found in .deb" >&2; exit 1; }
mv stage/usr/bin/opentrader opentrader
rm -rf stage opentrader.deb
chmod +x opentrader
