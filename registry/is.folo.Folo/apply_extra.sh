#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Folo ships its
# Linux build ONLY as an AppImage (electron-builder), so this repackages that.
# A type-2 AppImage is an ELF stub with a SquashFS image appended; it is
# unpacked directly, without ever being executed or FUSE-mounted.
#
# Two tools do that, from the appimage-tools extra-data fetched alongside it:
#   appimage-offset  prints the byte offset where the SquashFS begins
#   unsquashfs       unpacks from that offset
#
# The result is the electron-builder AppDir, staged whole at a stable path the
# wrapper execs: /app/extra/folo. It holds the Electron binary (named after the
# product), resources/app.asar, the Chromium .pak/.dat/.bin data, locales/, the
# bundled libffmpeg/libEGL/libGLESv2/SwiftShader, and usr/lib/ with the tray
# libs. The desktop file, icon and AppStream metainfo are shipped by the
# manifest at build time — extra-data is fetched later on the user's machine, so
# anything Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f folo.AppImage ]         || { echo "missing extra-data: folo.AppImage" >&2; exit 1; }
[ -f appimage-tools.tar.xz ] || { echo "missing extra-data: appimage-tools.tar.xz" >&2; exit 1; }

# --no-same-owner: a system-wide install runs apply_extra as root with all
# capabilities dropped, so restoring an archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" folo.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac

rm -rf folo
"$tools/unsquashfs" -no-xattrs -o "$offset" -d folo folo.AppImage

# electron-builder names the launcher after the app's productName ("Folo"),
# which upstream could change between releases. The bundled Folo.desktop is the
# authoritative source for it — Exec=<binary> [flags]. Resolve it and drop a
# stable-named symlink the wrapper always calls.
bin="$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' folo/Folo.desktop | head -n1)"
[ -n "$bin" ] && [ -x "folo/$bin" ] || { echo "launcher '$bin' from Folo.desktop not found in AppDir" >&2; exit 1; }
[ "$bin" = folo ] || ln -sf "$bin" folo/folo
[ -f folo/resources/app.asar ] || { echo "resources/app.asar missing after unpack" >&2; exit 1; }

# Drop the AppImage and the extractor now that the tree is staged.
rm -rf folo.AppImage appimage-tools.tar.xz appimage-tools
