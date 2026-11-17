#!/bin/sh
set -eu
# Flatpak runs this offline in /app/extra on either supported architecture.
cd "${EXTRA_ROOT:-/app/extra}"
[ -f sevenzip.tar.xz ] || { echo "missing extra-data: sevenzip.tar.xz" >&2; exit 1; }
rm -rf stage sevenzip
mkdir stage
# Root in a system install has no capabilities to restore archive ownership.
bsdtar --no-same-owner -xf sevenzip.tar.xz -C stage
[ -x stage/7zz ] || { echo "7zz executable not found in upstream archive" >&2; exit 1; }
[ -f stage/License.txt ] || { echo "upstream license not found in archive" >&2; exit 1; }
# Keep the official console binaries, manual and license together, unchanged.
mv stage sevenzip
rm sevenzip.tar.xz
