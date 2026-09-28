#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. The upstream
# Debian package installs the editor under /opt/concat: the `concat` binary next
# to lib/, which holds its own FFmpeg libraries and onnxruntime and is found
# through the binary's RPATH ($ORIGIN/lib). The whole opt/concat tree is kept
# together at /app/extra/concat so that relative layout survives; the wrapper
# launches /app/extra/concat/concat.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time - extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f concat.deb ] || { echo "missing extra-data: concat.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb
# ar container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage concat
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf concat.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/opt/concat/concat ] || { echo "concat binary not found in .deb" >&2; exit 1; }
mv stage/opt/concat concat
rm -rf stage concat.deb

# The bundled Noto Sans CJK face (extra-data too) only has to be moved into the
# directory concat-wrapper points SLINT_FONT_PATH at.
mkdir -p fonts
mv NotoSansCJK-Regular.ttc fonts/NotoSansCJK-Regular.ttc
