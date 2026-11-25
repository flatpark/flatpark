#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
[ -f prism.deb ] || { echo "missing prism.deb" >&2; exit 1; }
rm -rf stage prism
mkdir stage
bsdtar -xOf prism.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/usr/bin/prism ] && [ -d stage/usr/lib/Prism ] || { echo "Prism files missing" >&2; exit 1; }
mkdir prism
mv stage/usr prism/usr
rm -rf stage prism.deb
