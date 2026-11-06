#!/bin/sh
set -eu
# Runs offline at install time inside org.gnome.Platform. The tarball is
# PDFsam's official portable Linux build: one versioned top directory with the
# launcher script (bin/pdfsam.sh), the application's modules (lib/) and a
# jlinked Java runtime with JavaFX (runtime/). It is moved to a fixed path so
# the wrapper finds it across updates; nothing in it is changed.
#
# The desktop entry, icon and AppStream metainfo are shipped by the manifest at
# *build* time - extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"
[ -f pdfsam.tar.gz ] || { echo "missing extra-data: pdfsam.tar.gz" >&2; exit 1; }
rm -rf stage pdfsam
mkdir stage
# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, and the archive records uid/gid 1001 (runner).
bsdtar --no-same-owner -xf pdfsam.tar.gz -C stage
# The top directory carries the version (pdfsam-basic-6.0.6-linux-x64); match
# it by pattern and require exactly one.
set -- stage/pdfsam-basic-*
if [ "$#" -ne 1 ] || [ ! -d "$1" ]; then
    echo "expected one pdfsam-basic-* directory in the tarball" >&2
    exit 1
fi
mv "$1" pdfsam
[ -x pdfsam/bin/pdfsam.sh ] || { echo "launcher bin/pdfsam.sh not found in the tarball" >&2; exit 1; }
[ -x pdfsam/runtime/bin/java ] || { echo "bundled Java runtime not found in the tarball" >&2; exit 1; }
[ -f pdfsam/runtime/lib/libglassgtk3.so ] || { echo "bundled JavaFX (GTK 3 glass) not found in the tarball" >&2; exit 1; }
rm -rf stage pdfsam.tar.gz
