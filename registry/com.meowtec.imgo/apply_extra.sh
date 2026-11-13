#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package keeps the Tauri resources beside the binary (usr/lib/imgo/i18n), and
# Tauri looks for them at <exe dir>/../lib/imgo — so we keep the whole usr tree
# at a stable path (/app/extra/app) and run app/usr/bin/imgo from the wrapper.
# The desktop file, icon and AppStream metainfo are installed by the manifest
# at *build* time — extra-data is fetched later on the user's machine, so
# anything Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f imgo.deb ] || { echo "missing extra-data: imgo.deb" >&2; exit 1; }

# The Platform runtime has no `ar`/`dpkg`, but bsdtar (libarchive) reads the
# .deb's ar container directly; pipe its data member into a second bsdtar to
# unpack the tree (the inner data.tar compression is auto-detected).
rm -rf stage app
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring the archive's recorded uid/gid
# fails and aborts the unpack even though every member extracted fine.
bsdtar -xOf imgo.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/usr/bin/imgo ] || { echo "imgo binary not found in .deb" >&2; exit 1; }
[ -d stage/usr/lib/imgo/i18n ] || { echo "imgo resources (usr/lib/imgo/i18n) not found in .deb" >&2; exit 1; }
mv stage/usr app
rm -rf stage imgo.deb
chmod +x app/bin/imgo
