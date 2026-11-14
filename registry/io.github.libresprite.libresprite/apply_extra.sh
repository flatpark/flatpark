#!/bin/sh
set -eu

# Runs offline at install time. LibreSprite's Linux download is an AppImage: an
# ELF stub (the uruntime launcher) with a SquashFS filesystem appended. It is
# never executed or mounted; the appended filesystem is unpacked with the
# appimage-tools stack fetched alongside it (appimage-offset finds where the
# SquashFS starts, unsquashfs unpacks from there).
#
# The result is upstream's AppDir at /app/extra/libresprite. It is a sharun
# build: bin/libresprite is the sharun launcher (one binary hardlinked under
# bin/), which resolves the entry name it was started as, points the loader at
# the bundled libraries in shared/lib, and runs the real executable in
# shared/bin. The wrapper execs that launcher; no byte of the vendor payload
# is touched. The desktop file, icon and AppStream metainfo are installed by
# the manifest at build time, since extra-data only arrives on the user's
# machine.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f libresprite.AppImage ]   || { echo "missing extra-data: libresprite.AppImage" >&2; exit 1; }
[ -f appimage-tools.tar.xz ]  || { echo "missing extra-data: appimage-tools.tar.xz" >&2; exit 1; }

# --no-same-owner: a system-wide install runs apply_extra as root with every
# capability dropped, so restoring recorded owners would fail.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" libresprite.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac

rm -rf libresprite
"$tools/unsquashfs" -q -no-xattrs -o "$offset" -d libresprite libresprite.AppImage >/dev/null

# Fail with a clear message when upstream changes its layout, instead of
# shipping an app that cannot start. The launcher and its data directory are
# the two things the wrapper needs.
[ -x libresprite/bin/libresprite ] || { echo "bin/libresprite missing after unpack" >&2; exit 1; }
[ -d libresprite/bin/data ]        || { echo "bin/data missing after unpack" >&2; exit 1; }
[ -x libresprite/shared/bin/libresprite ] || { echo "shared/bin/libresprite missing after unpack" >&2; exit 1; }

rm -rf libresprite.AppImage appimage-tools.tar.xz appimage-tools
