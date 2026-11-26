#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
[ -f hyprism.tar.xz ] || { echo "missing Hyprism archive" >&2; exit 1; }
rm -rf stage app
mkdir stage
bsdtar --no-same-owner -xf hyprism.tar.xz -C stage
[ -x 'stage/Hyprism Launcher' ] || { echo "Hyprism Launcher missing from archive" >&2; exit 1; }
mv stage app
rm hyprism.tar.xz
