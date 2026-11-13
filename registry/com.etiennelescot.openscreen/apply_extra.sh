#!/bin/sh
set -eu

# Runs offline at install time inside the freedesktop runtime. AppImage support
# comes from FlatPark's pinned appimage-tools extra-data; neither the AppImage
# nor this extraction process needs FUSE.
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for file in openscreen.AppImage appimage-tools.tar.xz; do
    [ -f "$file" ] || { echo "missing extra-data: $file" >&2; exit 1; }
done

rm -rf openscreen squashfs-root appimage-tools launcher
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" openscreen.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac
"$tools/unsquashfs" -q -no-xattrs -o "$offset" -d squashfs-root openscreen.AppImage >/dev/null

# AppRun names the Electron binary. Resolve it from the vendor's own launcher
# so a future upstream rename fails only if the AppImage layout is ambiguous.
[ -f squashfs-root/AppRun ] || { echo "AppRun missing from the AppDir" >&2; exit 1; }
name="$(sed -n 's|^BIN="\$APPDIR/\([^"]*\)".*|\1|p' squashfs-root/AppRun | head -n1)"
[ -n "$name" ] || { echo "could not read the launcher name from AppRun" >&2; exit 1; }
[ -x "squashfs-root/$name" ] || { echo "launcher '$name' from AppRun is not executable" >&2; exit 1; }
[ -f squashfs-root/resources/app.asar ] || { echo "resources/app.asar missing from the AppDir" >&2; exit 1; }
[ -f squashfs-root/usr/share/icons/hicolor/512x512/apps/openscreen.png ] \
    || { echo "OpenScreen icon missing from the AppDir" >&2; exit 1; }

mv squashfs-root openscreen
printf '%s\n' "$name" > launcher

# The 259 MiB release AppImage and extractor are no longer needed once unpacked.
rm -f openscreen.AppImage appimage-tools.tar.xz
rm -rf appimage-tools
