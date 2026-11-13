#!/bin/sh
set -eu

# Flatpak runs this offline in /app/extra. Extract rotki's official portable
# Electron build without running or changing it.
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f rotki.tar.xz ] || { echo "missing extra-data: rotki.tar.xz" >&2; exit 1; }
rm -rf stage rotki
mkdir stage
bsdtar --no-same-owner -xf rotki.tar.xz -C stage

# The release directory includes its version; accept exactly one Linux x64 tree.
set -- stage/rotki-linux_x64-v*
[ -d "$1" ] && [ "$#" -eq 1 ] || {
    echo "expected one rotki-linux_x64-v* directory in the release tarball" >&2
    exit 1
}
mv "$1" rotki
[ -x rotki/rotki ] || { echo "rotki launcher not found in the release tarball" >&2; exit 1; }

rm -rf stage rotki.tar.xz
