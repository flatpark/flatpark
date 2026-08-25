#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package is a plain FHS tree whose payload is a single self-contained binary
# (usr/bin/navop - the UI assets and themes are embedded in it). The whole usr
# tree is kept at /app/extra/usr so the binary keeps its own relative layout;
# the wrapper launches /app/extra/usr/bin/navop.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time - extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f navop.deb ] || { echo "missing extra-data: navop.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb
# ar container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage usr
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf navop.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/usr/bin/navop ] || { echo "navop binary not found in .deb" >&2; exit 1; }
mv stage/usr usr
rm -rf stage navop.deb
chmod +x usr/bin/navop

# The bundled Noto Sans CJK face (extra-data too) only has to be moved into the
# directory /app/etc/fonts/fonts.conf points fontconfig at.
mkdir -p fonts
mv NotoSansCJK-Regular.ttc fonts/NotoSansCJK-Regular.ttc
