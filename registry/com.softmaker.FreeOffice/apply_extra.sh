#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Two .debs have
# already been fetched here by extra-data: SoftMaker's own FreeOffice package,
# and Debian's libxmu6 - the one library the programs link against that the
# runtime does not ship. The vendor's bytes run unmodified; nothing is patched.
#
# The desktop entries, icons, MIME definitions and AppStream metainfo are
# shipped by the manifest at *build* time - extra-data is fetched later on the
# user's machine, so anything Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in freeoffice.deb libxmu6.deb; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done

rm -rf stage freeoffice lib
mkdir stage lib

# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring the archive's recorded uid/gid
# (the FreeOffice .deb records uid 1000 on part of its tree) fails and aborts
# the unpack even though every member extracted fine. The runtime has no ar or
# dpkg, but bsdtar reads the .deb ar container directly.
for deb in freeoffice.deb libxmu6.deb; do
    bsdtar -xOf "$deb" 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
done

# The suite lives in a directory named for its edition year
# (/usr/share/freeoffice2024); take it from the package rather than hardcoding
# it, and stage it at a stable path for the wrapper.
set -- stage/usr/share/freeoffice20*
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo "expected exactly one usr/share/freeoffice20* directory, got: $*" >&2; exit 1; }
mv "$1" freeoffice
for bin in textmaker planmaker presentations; do
    [ -x "freeoffice/$bin" ] || { echo "$bin missing from the FreeOffice package" >&2; exit 1; }
done

# -o -type l, because the loader looks up the SONAME link
# (libXmu.so.6 -> libXmu.so.6.2.0), not the regular file behind it.
find stage/usr/lib -maxdepth 3 \( -type f -o -type l \) -name 'libXmu.so.*' \
    -exec cp -a {} lib/ \;
[ -e lib/libXmu.so.6 ] || { echo "libXmu.so.6 not found in libxmu6.deb" >&2; exit 1; }

rm -rf stage freeoffice.deb libxmu6.deb
