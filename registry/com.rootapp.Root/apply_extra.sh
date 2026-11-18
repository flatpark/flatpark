#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Root's Linux
# build is a type-2 AppImage (an ELF stub with a SquashFS appended). The pinned
# download is the Velopack full package of the same release, a zip whose only
# payload is that AppImage at lib/app/Root.AppImage. The AppImage is unpacked
# with appimage-offset + unsquashfs from the appimage-tools extra-data; it is
# never executed or FUSE-mounted.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in root.nupkg appimage-tools.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
rm -rf root squashfs-root appimage-tools lib

# --no-same-owner: on a system-wide install this runs as root with every
# capability dropped, and restoring a recorded owner would abort the unpack.
bsdtar --no-same-owner -xf root.nupkg lib/app/Root.AppImage
[ -f lib/app/Root.AppImage ] || { echo "lib/app/Root.AppImage not in the package" >&2; exit 1; }
rm -f root.nupkg

bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" lib/app/Root.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac

"$tools/unsquashfs" -q -no-xattrs -o "$offset" -d squashfs-root lib/app/Root.AppImage >/dev/null

# The binary the AppImage's own desktop entry names (Exec=Root). Checked here
# so a layout change fails the update check instead of shipping a broken app.
[ -x squashfs-root/usr/bin/Root ] || { echo "usr/bin/Root not found in the AppImage" >&2; exit 1; }
[ -d squashfs-root/usr/bin/chromium ] || { echo "embedded Chromium not found in the AppImage" >&2; exit 1; }
mv squashfs-root root

rm -rf lib appimage-tools.tar.xz appimage-tools
