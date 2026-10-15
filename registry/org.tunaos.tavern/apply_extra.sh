#!/bin/sh
set -eu

# Runs offline at install time. Tavern's Linux download is an AppImage: an ELF
# stub with a SquashFS filesystem appended. It is never executed or mounted;
# the appended filesystem is unpacked with the appimage-tools stack fetched
# alongside it (appimage-offset finds where the SquashFS starts, unsquashfs
# unpacks from there).
#
# The result is Tavern's AppDir at /app/extra/tavern. The wrapper runs the
# vendor's own Python program from it, usr/bin/tavern, with its data in
# usr/share/tavern. The desktop file, icon, MIME type, D-Bus services and
# AppStream metainfo are installed by the manifest at build time, since
# extra-data only arrives on the user's machine.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f tavern.AppImage ]       || { echo "missing extra-data: tavern.AppImage" >&2; exit 1; }
[ -f appimage-tools.tar.xz ] || { echo "missing extra-data: appimage-tools.tar.xz" >&2; exit 1; }

# --no-same-owner: a system-wide install runs apply_extra as root with every
# capability dropped, so restoring recorded owners would fail.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" tavern.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac

rm -rf tavern
"$tools/unsquashfs" -no-xattrs -o "$offset" -d tavern tavern.AppImage

[ -f tavern/usr/bin/tavern ]                       || { echo "usr/bin/tavern missing after unpack" >&2; exit 1; }
[ -f tavern/usr/bin/tavern-search-provider ]       || { echo "usr/bin/tavern-search-provider missing after unpack" >&2; exit 1; }
[ -f tavern/usr/share/tavern/tavern.gresource ]    || { echo "tavern.gresource missing after unpack" >&2; exit 1; }
[ -f tavern/usr/share/glib-2.0/schemas/gschemas.compiled ] || { echo "compiled GSettings schemas missing after unpack" >&2; exit 1; }

rm -rf tavern.AppImage appimage-tools.tar.xz appimage-tools
