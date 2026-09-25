#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# ChimpStackr for Linux only as an AppImage wrapping a PyInstaller bundle
# (usr/bin/chimpstackr, usr/bin/chimpstackr-cli and their _internal/ tree with
# Python, PySide6/Qt 6, OpenCV and the rest). The AppImage is unpacked, never
# executed and never FUSE-mounted, with the two tools from the appimage-tools
# extra-data (appimage-offset finds the SquashFS, unsquashfs unpacks it).
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f chimpstackr.AppImage ]  || { echo "missing extra-data: chimpstackr.AppImage" >&2; exit 1; }
[ -f appimage-tools.tar.xz ] || { echo "missing extra-data: appimage-tools.tar.xz" >&2; exit 1; }

# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring an archive's recorded uid/gid
# fails and aborts the unpack even though every member extracted fine.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" chimpstackr.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac

rm -rf chimpstackr
# -no-xattrs: the apply_extra sandbox cannot set security xattrs.
"$tools/unsquashfs" -no-xattrs -o "$offset" -d chimpstackr chimpstackr.AppImage
[ -x chimpstackr/usr/bin/chimpstackr ]     || { echo "chimpstackr binary missing after unpack" >&2; exit 1; }
[ -x chimpstackr/usr/bin/chimpstackr-cli ] || { echo "chimpstackr-cli binary missing after unpack" >&2; exit 1; }
rm -rf chimpstackr.AppImage appimage-tools.tar.xz appimage-tools
