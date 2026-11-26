#!/bin/sh
set -eu
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in tether.deb libgtk-layer-shell0.deb bluez.deb; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
rm -rf stage tether support
mkdir stage

# Upstream's package, unchanged, under /app/extra/tether/usr.
bsdtar -xOf tether.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
for b in tether-gtk tether tetherd tether-dialog; do
    [ -x "stage/usr/bin/$b" ] || { echo "no usr/bin/$b in the Tether package" >&2; exit 1; }
done
mkdir tether
mv stage/usr tether/usr
rm -rf stage

# Support pieces from Debian, kept apart from upstream's files.
mkdir -p stage support/bin support/lib
for archive in libgtk-layer-shell0.deb bluez.deb; do
    bsdtar -xOf "$archive" 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
done
find stage/usr/lib \( -type f -o -type l \) -name 'libgtk-layer-shell.so.0*' -exec mv {} support/lib/ \;
[ -e support/lib/libgtk-layer-shell.so.0 ] || { echo "libgtk-layer-shell.so.0 missing" >&2; exit 1; }
[ -x stage/usr/bin/btmgmt ] || { echo "btmgmt missing from bluez.deb" >&2; exit 1; }
mv stage/usr/bin/btmgmt support/bin/btmgmt

rm -rf stage tether.deb libgtk-layer-shell0.deb bluez.deb
