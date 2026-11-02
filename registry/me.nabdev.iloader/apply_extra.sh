#!/bin/sh
set -eu
# Unpack the official Debian payload offline, including any future resources.
cd "${EXTRA_ROOT:-/app/extra}"
[ -f iloader.deb ] || { echo "missing extra-data: iloader.deb" >&2; exit 1; }
mkdir -p stage
bsdtar -xOf iloader.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/usr/bin/iloader ] || { echo "iloader binary not found in .deb" >&2; exit 1; }
mv stage/usr iloader
# The executable name controls GTK's window class under X11.
ln -s iloader/bin/iloader me.nabdev.iloader
rm -rf stage iloader.deb
