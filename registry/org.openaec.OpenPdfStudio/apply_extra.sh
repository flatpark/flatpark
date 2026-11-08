#!/bin/sh
set -eu

# Runs offline at install time. The upstream package is a Debian archive.
# Tauri resolves resources as "<exe>/../lib/Open PDF Studio", so the usr/
# layout has to survive the move into /app/extra.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f open-pdf-studio.deb ] || { echo "missing extra-data: open-pdf-studio.deb" >&2; exit 1; }

rm -rf stage openpdf
mkdir stage
# The Platform runtime has no ar/dpkg. bsdtar reads the .deb and the inner
# data.tar*. --no-same-owner: a system install runs apply_extra as root with
# every capability dropped.
bsdtar -xOf open-pdf-studio.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/usr/bin/open-pdf-studio ] || { echo "open-pdf-studio not found in .deb" >&2; exit 1; }
[ -f "stage/usr/lib/Open PDF Studio/libpdfium.so" ] || { echo "libpdfium.so not found in .deb" >&2; exit 1; }

mkdir -p openpdf
mv stage/usr openpdf/usr
rm -rf stage open-pdf-studio.deb
chmod +x openpdf/usr/bin/open-pdf-studio openpdf/usr/bin/pdfium-worker
