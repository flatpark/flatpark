#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream's Linux
# build is an electron-builder AppImage, the only Linux format Beeper publishes,
# so this repackages that. A type-2 AppImage is an ELF stub with a SquashFS
# filesystem appended; it is unpacked directly, never executed or mounted.
#
# Two tools do that, both from the appimage-tools extra-data fetched alongside
# the AppImage:
#   appimage-offset  prints the byte offset where the SquashFS begins
#   unsquashfs       unpacks from that offset
#
# The result is the AppDir, staged whole at a stable path the wrapper execs:
# /app/extra/beeper. The desktop file, icon and AppStream metainfo are shipped
# by the manifest at build time — extra-data is fetched later on the user's
# machine, so anything Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f beeper.AppImage ]       || { echo "missing extra-data: beeper.AppImage" >&2; exit 1; }
[ -f appimage-tools.tar.xz ] || { echo "missing extra-data: appimage-tools.tar.xz" >&2; exit 1; }

# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring an archive's recorded uid/gid
# fails and aborts the unpack. unsquashfs never chowns as non-root, and
# -no-xattrs keeps it from setting xattrs it may not set either.
rm -rf appimage-tools
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" beeper.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac

rm -rf beeper
"$tools/unsquashfs" -q -no-xattrs -o "$offset" -d beeper beeper.AppImage >/dev/null

# Which file is the Electron launcher? electron-builder names it after
# executableName, which upstream can change between releases, so read it out of
# the AppDir rather than writing it into this script — pin refreshes are
# automated and a rename would otherwise reach users as a failed install. The
# AppDir's own AppRun names it in a single line:
#
#   BIN="$APPDIR/beepertexts"
[ -f beeper/AppRun ] || { echo "AppRun missing from the AppDir" >&2; exit 1; }
name="$(sed -n 's|^BIN="\$APPDIR/\([^"]*\)".*|\1|p' beeper/AppRun | head -n1)"
[ -n "$name" ] || { echo "could not read the launcher name from the AppDir's AppRun" >&2; exit 1; }

if [ -x "beeper/$name.bin" ]; then
    launcher="$name.bin"
elif [ -x "beeper/$name" ]; then
    launcher="$name"
else
    echo "launcher '$name' from AppRun not executable in the AppDir" >&2
    exit 1
fi
[ -f beeper/resources/app.asar ] || { echo "resources/app.asar missing in the AppDir" >&2; exit 1; }

# The wrapper reads the resolved name from here rather than hardcoding it. It
# lives beside the app tree, not inside it, so the upstream tree stays as
# shipped.
printf '%s\n' "$launcher" > launcher

# Drop the ~280 MiB AppImage and the extractor now that the tree is staged.
rm -rf beeper.AppImage appimage-tools.tar.xz appimage-tools
