#!/bin/sh
set -eu

# Runs offline at install time. Upstream ships the Linux desktop build as a
# type-2 AppImage. The same release also ships a separate browser archive;
# this package does not use it. The AppImage is read here, never executed
# and never FUSE-mounted.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in mitcad.AppImage appimage-tools.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
rm -rf mitcad squashfs-root appimage-tools

bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" mitcad.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac

"$tools/unsquashfs" -q -no-xattrs -o "$offset" -d squashfs-root mitcad.AppImage >/dev/null
[ -x squashfs-root/AppRun ] || { echo "AppRun not found in the AppImage" >&2; exit 1; }
[ -x squashfs-root/usr/bin/mitcad ] || { echo "mitcad not found in the AppImage" >&2; exit 1; }
[ -x squashfs-root/usr/bin/mitcad-cli ] || { echo "mitcad-cli not found in the AppImage" >&2; exit 1; }
mv squashfs-root mitcad

rm -rf mitcad.AppImage appimage-tools.tar.xz appimage-tools
chmod +x mitcad/AppRun mitcad/usr/bin/mitcad mitcad/usr/bin/mitcad-cli
