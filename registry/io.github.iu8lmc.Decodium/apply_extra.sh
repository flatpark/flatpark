#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# Decodium for Linux as an AppImage only, so this repackages the AppImage. A
# type-2 AppImage is an ELF stub with a SquashFS filesystem appended; it is read
# directly here, never executed and never FUSE-mounted, with the two tools from
# the appimage-tools extra-data:
#   appimage-offset  prints the byte offset where the SquashFS begins
#   unsquashfs       unpacks from that offset
#
# The result is the AppDir, staged whole at /app/extra/decodium: AppRun (the
# bundle's own launcher, which sets its Qt platform, media backend, QML paths
# and style), usr/bin with decodium and the Hamlib/WSPR helpers, usr/lib with
# the Qt 6 stack it resolves through its RUNPATH, and usr/plugins.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f decodium.AppImage ]     || { echo "missing extra-data: decodium.AppImage" >&2; exit 1; }
[ -f appimage-tools.tar.xz ] || { echo "missing extra-data: appimage-tools.tar.xz" >&2; exit 1; }

# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring an archive's recorded uid/gid
# fails and aborts the unpack even though every member extracted fine.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" decodium.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac

rm -rf decodium
# -no-xattrs: the apply_extra sandbox has all capabilities dropped and cannot
# set security xattrs.
"$tools/unsquashfs" -no-xattrs -o "$offset" -d decodium decodium.AppImage

# Check the entry point and the binary it resolves to, so a bundle that
# unpacked but lost either fails here rather than at launch.
[ -x decodium/AppRun ]           || { echo "AppRun missing after unpack" >&2; exit 1; }
[ -x decodium/usr/bin/decodium ] || { echo "decodium binary missing after unpack" >&2; exit 1; }

rm -rf decodium.AppImage appimage-tools.tar.xz appimage-tools
