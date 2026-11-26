#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream's
# Linux download is a type-2 AppImage: an ELF stub with a SquashFS image
# appended. It is never executed or mounted; the appended filesystem is
# unpacked with the appimage-tools stack fetched next to it, and the whole
# AppDir is kept because usr/bin/Hypersomnia finds its libraries through
# $ORIGIN/../lib and its game files in usr/share/hypersomnia.
#
# The desktop entry, icon and AppStream metainfo are installed by the manifest
# at build time: extra-data only arrives on the user's machine, after Flatpak
# has exported the app.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f Hypersomnia.AppImage ]   || { echo "missing extra-data: Hypersomnia.AppImage" >&2; exit 1; }
[ -f appimage-tools.tar.xz ]  || { echo "missing extra-data: appimage-tools.tar.xz" >&2; exit 1; }

# --no-same-owner: a system-wide install runs apply_extra as root with every
# capability dropped, so restoring recorded owners would fail.
rm -rf appimage-tools hypersomnia
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" Hypersomnia.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac

"$tools/unsquashfs" -q -no-xattrs -d hypersomnia -o "$offset" Hypersomnia.AppImage >/dev/null

[ -x hypersomnia/usr/bin/Hypersomnia ] \
    || { echo "no usr/bin/Hypersomnia in the AppImage" >&2; exit 1; }
[ -d hypersomnia/usr/share/hypersomnia/content ] \
    || { echo "no usr/share/hypersomnia/content in the AppImage" >&2; exit 1; }
[ -f hypersomnia/usr/share/hypersomnia/default_config.json ] \
    || { echo "no default_config.json in the AppImage" >&2; exit 1; }

rm -rf appimage-tools appimage-tools.tar.xz Hypersomnia.AppImage
