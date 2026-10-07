#!/bin/sh
set -eu

# The unpack below is a pipeline. Enable pipefail when the runtime shell supports
# it so a failure in either bsdtar process cannot leave a partial installation.
# shellcheck disable=SC3040
(set -o pipefail) 2> /dev/null && set -o pipefail || true

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package is a plain FHS tree: the Tauri binary at usr/bin/DashBeam and its
# resource tree (tray icons) at usr/lib/DashBeam. Tauri resolves resources as
# <exe dir>/../lib/<product name>, so bin/ + lib/ are staged together and keep
# their relative layout — usr/ is moved wholesale to /app/extra/dashbeam rather
# than reduced to a single binary.
#
# usr/share is dropped: the desktop file, icon and AppStream metainfo are shipped
# by the manifest at *build* time, because extra-data is fetched later on the
# user's machine and anything Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f dashbeam.deb ] || { echo "missing extra-data: dashbeam.deb" >&2; exit 1; }

rm -rf stage dashbeam
mkdir stage
# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid (this
# .deb records 1001) fails and aborts the unpack even though every member
# extracted fine.
bsdtar -xOf dashbeam.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

[ -x stage/usr/bin/DashBeam ] || { echo "DashBeam binary not found in .deb" >&2; exit 1; }
[ -d stage/usr/lib/DashBeam ] || { echo "resource tree not found in .deb" >&2; exit 1; }

mv stage/usr dashbeam
rm -rf stage dashbeam.deb dashbeam/share
