#!/bin/sh
set -eu

# Extract the official AppImage offline; keep the vendor's AppDir unchanged.
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"
for f in openplc.AppImage appimage-tools.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
rm -rf app squashfs-root appimage-tools launcher
# System installs run as root without capabilities and cannot restore owners.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
offset="$("$tools/appimage-offset" openplc.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "invalid AppImage offset: '$offset'" >&2; exit 1 ;;
esac
"$tools/unsquashfs" -q -no-xattrs -o "$offset" -d squashfs-root openplc.AppImage >/dev/null
# Read electron-builder's launcher from AppRun so upstream can rename it.
[ -f squashfs-root/AppRun ] || { echo "AppRun missing" >&2; exit 1; }
name="$(sed -n 's|^BIN="\$APPDIR/\([^"/]*\)"$|\1|p' squashfs-root/AppRun)"
[ -n "$name" ] && [ -x "squashfs-root/$name" ] \
    || { echo "no unique executable launcher in AppRun" >&2; exit 1; }
[ -f squashfs-root/resources/app.asar ] \
    || { echo "resources/app.asar missing" >&2; exit 1; }
mv squashfs-root app
# Record outside the vendor tree for the wrapper.
printf '%s\n' "$name" > launcher
rm -rf openplc.AppImage appimage-tools.tar.xz appimage-tools
