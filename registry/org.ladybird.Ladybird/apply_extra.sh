#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Ladybird's
# .deb keeps the whole browser (binaries, helper processes, bundled Qt and
# libraries) under opt/ladybird; move that tree to /app/extra/ladybird,
# unmodified. Its desktop entry, icon, metainfo and D-Bus service file are
# shipped by the manifest at build time instead.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f ladybird.deb ] || { echo "missing extra-data: ladybird.deb" >&2; exit 1; }

rm -rf stage ladybird
mkdir stage
# The runtime has no ar/dpkg; bsdtar reads the .deb's ar container directly.
# --no-same-owner: a system-wide install runs this as root with no capabilities.
bsdtar -xOf ladybird.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage ./opt/ladybird
[ -x stage/opt/ladybird/bin/Ladybird ] || { echo "opt/ladybird/bin/Ladybird not found in .deb" >&2; exit 1; }
[ -x stage/opt/ladybird/libexec/WebContent ] || { echo "opt/ladybird/libexec/WebContent not found in .deb" >&2; exit 1; }
mv stage/opt/ladybird ladybird
rm -rf stage ladybird.deb
