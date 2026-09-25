#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Two .debs have
# already been fetched here by extra-data. Shutter Encoder's own package is a
# self-contained jpackage build: the launcher, a Java runtime, the application
# jar and the tools it drives (FFmpeg, MediaInfo, dcraw, tsMuxeR and more)
# under /opt/shutter-encoder. Debian's libxml2 supplies libxml2.so.2, the one
# library a bundled tool (dvdauthor) needs that the runtime does not ship. The
# vendor's bytes run unmodified; nothing is patched.
#
# The desktop entries, icon and AppStream metainfo are shipped by the manifest
# at *build* time - extra-data is fetched later on the user's machine, so
# anything Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in shutter-encoder.deb libxml2.deb; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done

rm -rf stage shutter-encoder lib
mkdir stage lib

# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring an archive's recorded uid/gid
# fails and aborts the unpack even though every member extracted fine. The
# runtime has no ar or dpkg, but bsdtar reads the .deb ar container directly.
for deb in shutter-encoder.deb libxml2.deb; do
    bsdtar -xOf "$deb" 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
done

[ -d stage/opt/shutter-encoder ] || { echo "opt/shutter-encoder missing from the package" >&2; exit 1; }
mv stage/opt/shutter-encoder shutter-encoder
for launcher in "Shutter Encoder" "Shutter Encoder High-DPI"; do
    [ -x "shutter-encoder/bin/$launcher" ] || { echo "launcher '$launcher' missing from the package" >&2; exit 1; }
done

# -o -type l, because the loader looks up the SONAME link
# (libxml2.so.2 -> libxml2.so.2.9.14), not the regular file behind it.
find stage/usr/lib -maxdepth 3 \( -type f -o -type l \) -name 'libxml2.so.2*' \
    -exec cp -a {} lib/ \;
[ -e lib/libxml2.so.2 ] || { echo "libxml2.so.2 not found in libxml2.deb" >&2; exit 1; }

rm -rf stage shutter-encoder.deb libxml2.deb
