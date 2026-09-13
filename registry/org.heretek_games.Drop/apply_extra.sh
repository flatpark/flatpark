#!/bin/sh
set -eu

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f drop.deb ] || { echo "missing extra-data: drop.deb" >&2; exit 1; }

rm -rf stage drop-app
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring recorded uid/gid fails without this flag.
bsdtar -xOf drop.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/usr/bin/drop-app ] || { echo "drop-app binary not found in .deb" >&2; exit 1; }
mv stage/usr/bin/drop-app drop-app
rm -rf stage drop.deb
chmod +x drop-app
