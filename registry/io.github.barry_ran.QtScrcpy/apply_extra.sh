#!/bin/sh
set -eu
# Unpack the official AppImage offline; never execute its ELF runtime.
cd "${EXTRA_ROOT:-/app/extra}"
for f in qtscrcpy.AppImage appimage-tools.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
rm -rf qtscrcpy squashfs-root appimage-tools
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools=appimage-tools/bin
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] || {
    echo "appimage-tools stack incomplete" >&2; exit 1;
}
offset="$("$tools/appimage-offset" qtscrcpy.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "invalid AppImage offset: '$offset'" >&2; exit 1 ;;
esac
"$tools/unsquashfs" -q -no-xattrs -d squashfs-root -o "$offset" qtscrcpy.AppImage >/dev/null
# AppRun is the format's fixed entry point. Keep the complete AppDir so its
# launcher can locate Qt, ADB, the Android server, config and keymap defaults.
[ -x squashfs-root/AppRun ] && [ -x squashfs-root/usr/bin/QtScrcpy ] \
    && [ -x squashfs-root/usr/lib/qtscrcpy/adb ] \
    && [ -s squashfs-root/usr/lib/qtscrcpy/scrcpy-server ] \
    && [ -s squashfs-root/usr/share/config/config.ini ] \
    && [ -d squashfs-root/usr/share/keymap ] || {
    echo "QtScrcpy launcher, ADB, server or defaults missing from AppImage" >&2; exit 1;
}
mv squashfs-root qtscrcpy
rm -rf appimage-tools qtscrcpy.AppImage appimage-tools.tar.xz
