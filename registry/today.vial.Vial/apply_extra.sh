#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# Vial for Linux as a type-2 AppImage: an ELF stub with a SquashFS appended. It
# is read directly here, never executed and never FUSE-mounted, with the two
# tools from the appimage-tools extra-data (appimage-offset finds the SquashFS,
# unsquashfs unpacks it).
#
# The AppDir holds a PyInstaller one-dir bundle under opt/Vial and an AppRun
# script that sets QT_QPA_PLATFORM=xcb and execs it. The tree is staged whole at
# /app/extra/vial and the wrapper execs AppRun, so a renamed bundle directory
# needs no change here; the check below only makes sure AppRun is there.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time; extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in vial.AppImage appimage-tools.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
rm -rf vial squashfs-root appimage-tools

# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring an archive's recorded uid/gid
# fails and aborts the unpack even though every member extracted fine.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" vial.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac

# -no-xattrs: the apply_extra sandbox cannot set security xattrs.
"$tools/unsquashfs" -q -no-xattrs -o "$offset" -d squashfs-root vial.AppImage >/dev/null

[ -x squashfs-root/AppRun ] || { echo "no executable AppRun in the AppImage" >&2; exit 1; }
mv squashfs-root vial

rm -rf vial.AppImage appimage-tools.tar.xz appimage-tools
