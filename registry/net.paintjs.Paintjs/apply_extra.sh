#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream's
# Linux download is an electron-builder AppImage: an ELF stub with a SquashFS
# appended. It is never executed or FUSE-mounted; appimage-offset (from the
# appimage-tools extra-data) finds where the SquashFS starts and unsquashfs
# unpacks the AppDir from there, whole, to /app/extra/paintdotjs.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in paintdotjs.AppImage appimage-tools.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
rm -rf paintdotjs appimage-tools launcher

# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, so restoring an archive's owner would fail.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" paintdotjs.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac
"$tools/unsquashfs" -q -no-xattrs -o "$offset" -d paintdotjs paintdotjs.AppImage >/dev/null

# The Electron launcher is named after electron-builder's executableName, which
# upstream can change; read it from the AppDir's AppRun (BIN="$APPDIR/<name>")
# rather than hardcoding it, and record it for the wrapper.
[ -f paintdotjs/AppRun ] || { echo "AppRun missing from the AppDir" >&2; exit 1; }
name="$(sed -n 's|^BIN="\$APPDIR/\([^"]*\)".*|\1|p' paintdotjs/AppRun | head -n1)"
[ -n "$name" ] || { echo "could not read the launcher name from AppRun" >&2; exit 1; }
[ -x "paintdotjs/$name" ] || { echo "launcher '$name' from AppRun not executable" >&2; exit 1; }
[ -f paintdotjs/resources/app.asar ] || { echo "resources/app.asar missing in the AppDir" >&2; exit 1; }
printf '%s\n' "$name" > launcher

rm -rf paintdotjs.AppImage appimage-tools.tar.xz appimage-tools
