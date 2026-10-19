#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream's Linux
# build is an electron-builder AppImage (the release's "Unpacked x64" zip is the
# Windows build), so this repackages that. A type-2 AppImage is an ELF stub with
# a SquashFS filesystem appended; it is never executed or FUSE-mounted, the
# filesystem is unpacked directly with the appimage-tools extra-data:
#   appimage-offset  prints the byte offset where the SquashFS begins
#   unsquashfs       unpacks from that offset
#
# The result is the AppDir, staged whole at a stable path the wrapper execs:
# /app/extra/fluent-reader. Its layout is the usual electron-builder one: the
# Chromium launcher, resources/app.asar (+ the unpacked better-sqlite3 module),
# the .pak/.dat resources, the bundled libffmpeg/SwiftShader, and usr/lib with
# the tray and libnotify libraries the AppImage carries for older hosts.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# build time; anything Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f fluent-reader.AppImage ] || { echo "missing extra-data: fluent-reader.AppImage" >&2; exit 1; }
[ -f appimage-tools.tar.xz ]  || { echo "missing extra-data: appimage-tools.tar.xz" >&2; exit 1; }

rm -rf fluent-reader appimage-tools launcher

# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring an archive's recorded owner would
# fail. unsquashfs never chowns, and -no-xattrs keeps it from setting xattrs.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" fluent-reader.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac
"$tools/unsquashfs" -q -no-xattrs -o "$offset" -d fluent-reader fluent-reader.AppImage >/dev/null

# The launcher is named after electron-builder's executableName, which upstream
# can change between releases, and pin refreshes are automated. So read it out
# of the AppDir's AppRun (`BIN="$APPDIR/fluent-reader"`) instead of writing it
# here. Some electron-builder versions put a shell shim at that name with the
# real ELF beside it as "<name>.bin"; prefer the ELF so the wrapper can start it
# under zypak directly.
[ -f fluent-reader/AppRun ] || { echo "AppRun missing from the AppDir" >&2; exit 1; }
name="$(sed -n 's|^BIN="\$APPDIR/\([^"]*\)".*|\1|p' fluent-reader/AppRun | head -n1)"
[ -n "$name" ] || { echo "could not read the launcher name from the AppDir's AppRun" >&2; exit 1; }

if [ -x "fluent-reader/$name.bin" ]; then
    launcher="$name.bin"
elif [ -x "fluent-reader/$name" ]; then
    launcher="$name"
else
    echo "launcher '$name' from AppRun not executable in the AppDir" >&2
    exit 1
fi
[ -f fluent-reader/resources/app.asar ] || { echo "resources/app.asar missing in the AppDir" >&2; exit 1; }

# The wrapper reads the resolved name from here. It lives beside the app tree,
# not inside it, so the upstream tree stays as shipped.
printf '%s\n' "$launcher" > launcher

# Drop the AppImage and the extractor now that the tree is staged.
rm -rf fluent-reader.AppImage appimage-tools.tar.xz appimage-tools
