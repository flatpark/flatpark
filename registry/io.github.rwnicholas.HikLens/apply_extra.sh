#!/bin/sh
set -eu

# Runs offline at install time. HikLens's Linux release is an AppImage: an ELF
# stub with a SquashFS filesystem appended. It is never executed or mounted;
# the appended filesystem is unpacked with the appimage-tools stack fetched
# alongside it (appimage-offset finds where the SquashFS starts, unsquashfs
# unpacks from there).
#
# The result is HikLens's AppDir at /app/extra/hiklens. The wrapper runs the
# vendor's own AppRun from it, which starts usr/lib/hiklens/HikLens. The
# desktop file, icon and AppStream metainfo are installed by the manifest at
# build time, since extra-data only arrives on the user's machine.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f hiklens.AppImage ]      || { echo "missing extra-data: hiklens.AppImage" >&2; exit 1; }
[ -f appimage-tools.tar.xz ] || { echo "missing extra-data: appimage-tools.tar.xz" >&2; exit 1; }

# --no-same-owner: a system-wide install runs apply_extra as root with every
# capability dropped, so restoring recorded owners would fail.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" hiklens.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac

rm -rf hiklens
"$tools/unsquashfs" -q -no-xattrs -o "$offset" -d hiklens hiklens.AppImage >/dev/null

[ -x hiklens/AppRun ] || { echo "AppRun missing after unpack" >&2; exit 1; }
[ -x hiklens/usr/lib/hiklens/HikLens ] || { echo "usr/lib/hiklens/HikLens missing after unpack" >&2; exit 1; }
[ -x hiklens/usr/lib/hiklens/hikvision_stream_helper ] || { echo "hikvision_stream_helper missing after unpack" >&2; exit 1; }

rm -rf hiklens.AppImage appimage-tools.tar.xz appimage-tools
