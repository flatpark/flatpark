#!/bin/sh
set -eu

# Extract the official AppImage offline and retain its AppDir unchanged.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in app.AppImage appimage-tools.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
rm -rf app squashfs-root appimage-tools launcher

# --no-same-owner: a system-wide apply_extra runs as root with every capability
# dropped and cannot restore archive ownership. -no-xattrs keeps unsquashfs from
# trying to set xattrs the sandbox does not allow.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" app.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac
"$tools/unsquashfs" -q -no-xattrs -o "$offset" -d squashfs-root app.AppImage >/dev/null

# electron-builder names the launcher after executableName, which upstream can
# change; read it from the AppDir's AppRun rather than writing it here:
#   BIN="$APPDIR/wickline"
[ -f squashfs-root/AppRun ] || { echo "AppRun missing from the AppDir" >&2; exit 1; }
name="$(sed -n 's|^BIN="\$APPDIR/\([^"]*\)".*|\1|p' squashfs-root/AppRun | head -n1)"
case "$name" in
    ''|.|..|*/*) echo "invalid launcher name in AppRun: $name" >&2; exit 1 ;;
esac
[ -x "squashfs-root/$name" ] || { echo "launcher '$name' from AppRun not executable in the AppDir" >&2; exit 1; }
[ -f squashfs-root/resources/app.asar ] || { echo "resources/app.asar missing in the AppDir" >&2; exit 1; }

mv squashfs-root app
# Recorded beside the app tree, not inside it, so the vendor's tree stays as
# shipped.
printf '%s\n' "$name" > launcher

# Drop the AppImage and the extractor now that the tree is staged.
rm -rf app.AppImage appimage-tools.tar.xz appimage-tools
