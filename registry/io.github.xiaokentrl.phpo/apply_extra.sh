#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package is a plain FHS tree whose payload is a single self-contained Wails v3
# binary at usr/bin/phpo (Go, with the web assets embedded); the only other
# members are the .desktop file and the icons. We stage the binary at a stable
# path the wrapper expects: /app/extra/phpo/bin/phpo. The desktop file, icon and
# AppStream metainfo are shipped by the manifest at *build* time — extra-data is
# fetched later on the user's machine, so anything Flatpak must export cannot
# come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f phpo.deb ] || { echo "missing extra-data: phpo.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb
# ar container directly; pipe its data member into a second bsdtar to unpack the
# FHS tree (the inner data.tar compression is auto-detected).
rm -rf stage phpo
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf phpo.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -f stage/usr/bin/phpo ] || { echo "phpo not found in .deb" >&2; exit 1; }

mkdir -p phpo/bin
mv stage/usr/bin/phpo phpo/bin/phpo
rm -rf stage phpo.deb
chmod +x phpo/bin/phpo
