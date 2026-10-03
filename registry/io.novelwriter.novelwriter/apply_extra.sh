#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream ships
# novelWriter for Linux as an AppImage built with python-appimage: a type-2
# AppImage, i.e. an ELF stub with a SquashFS filesystem appended. It is never
# executed or FUSE-mounted; the appended filesystem is unpacked directly with
# the appimage-tools extra-data fetched alongside it:
#   appimage-offset  prints the byte offset where the SquashFS begins
#   unsquashfs       unpacks from that offset
#
# The result is the AppDir, staged whole at /app/extra/novelwriter: AppRun (a
# shell script that runs the bundled Python against the bundled novelwriter
# entry point, relative to $APPDIR), usr/ with the Python interpreter and its
# libraries, and opt/python3.x with site-packages (PyQt6 and Qt 6 included).
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f app.AppImage ]          || { echo "missing extra-data: app.AppImage" >&2; exit 1; }
[ -f appimage-tools.tar.xz ] || { echo "missing extra-data: appimage-tools.tar.xz" >&2; exit 1; }

# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring an archive's recorded uid/gid
# fails and aborts the unpack. unsquashfs never chowns.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" app.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac

rm -rf novelwriter
# -no-xattrs: the apply_extra sandbox has all capabilities dropped and cannot
# set security xattrs.
"$tools/unsquashfs" -no-xattrs -o "$offset" -d novelwriter app.AppImage

[ -f novelwriter/AppRun ] || { echo "AppRun missing after unpack" >&2; exit 1; }

# Drop the AppImage and the extractor now that the tree is staged.
rm -rf app.AppImage appimage-tools.tar.xz appimage-tools
