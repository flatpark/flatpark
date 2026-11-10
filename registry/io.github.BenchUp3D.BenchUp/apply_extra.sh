#!/bin/sh
set -eu

# Runs offline at install time. Upstream ships the Linux desktop build as a
# type-2 AppImage (an ELF stub with a SquashFS appended). The .nupkg of the
# same release only wraps that AppImage. It is read here, never executed and
# never FUSE-mounted.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in benchup.AppImage appimage-tools.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
rm -rf benchup squashfs-root appimage-tools

bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" benchup.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac

"$tools/unsquashfs" -q -no-xattrs -o "$offset" -d squashfs-root benchup.AppImage >/dev/null
[ -x squashfs-root/usr/bin/benchup-app ] || { echo "benchup-app not found in the AppImage" >&2; exit 1; }
mv squashfs-root benchup

rm -rf benchup.AppImage appimage-tools.tar.xz appimage-tools
