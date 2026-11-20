#!/bin/sh
set -eu

# Runs offline at install time. The official .deb is one binary with the
# web app embedded. The runtime has no ar or dpkg; bsdtar reads the deb.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f hestia.deb ] || { echo "missing extra-data: hestia.deb" >&2; exit 1; }
rm -rf stage usr
mkdir stage
bsdtar -xOf hestia.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/usr/bin/hestia-desktop ] || { echo "hestia-desktop not found in the .deb" >&2; exit 1; }
mv stage/usr usr
rm -rf stage hestia.deb
chmod +x usr/bin/hestia-desktop
