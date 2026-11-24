#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. The vendor .deb
# is a plain FHS tree whose only executable is usr/bin/kraken_desktop (a single
# Rust binary; the rest is its desktop entry, icon and copyright file), so that
# one file is kept at a fixed path the wrapper expects.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f kraken.deb ] || { echo "missing extra-data: kraken.deb" >&2; exit 1; }

rm -rf stage kraken_desktop
mkdir stage
# The runtime has no ar/dpkg; bsdtar reads the .deb's ar container directly.
# --no-same-owner: a system-wide install runs this as root with no capabilities.
bsdtar -xOf kraken.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -f stage/usr/bin/kraken_desktop ] || { echo "kraken_desktop not found in .deb" >&2; exit 1; }
mv stage/usr/bin/kraken_desktop kraken_desktop
chmod 755 kraken_desktop
rm -rf stage kraken.deb
