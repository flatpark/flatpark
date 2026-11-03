#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package is a plain FHS tree whose only payload is usr/bin/drawx — a single
# self-contained Tauri binary with its web assets embedded (no vendored lib/
# tree). We stage just that binary at a stable path the wrapper expects:
# /app/extra/drawx/drawx. The desktop file, icon and AppStream metainfo are
# shipped by the manifest at *build* time — extra-data is fetched later on the
# user's machine, so anything Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f drawx.deb ] || { echo "missing extra-data: drawx.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb
# ar container directly; pipe its data member into a second bsdtar to unpack the
# FHS tree (the inner data.tar compression is auto-detected).
rm -rf stage drawx
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf drawx.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/usr/bin/drawx ] || { echo "drawx binary not found in .deb" >&2; exit 1; }
mkdir drawx
mv stage/usr/bin/drawx drawx/drawx
rm -rf stage drawx.deb
chmod +x drawx/drawx
