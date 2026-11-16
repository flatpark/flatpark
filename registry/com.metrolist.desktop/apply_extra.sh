#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream's Linux
# build is an AppImage holding a jpackage image: AppRun, the launcher script
# bin/<name> and its native bin/<name>.bin, the app jars and the bundled Java
# runtime under lib/. A type-2 AppImage is an ELF stub with a SquashFS appended;
# it is unpacked directly, never executed or mounted, and the AppDir is kept
# whole at /app/extra/metrolist. The desktop entry, icon and metainfo are
# installed by the manifest at build time.
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in metrolist.AppImage appimage-tools.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
rm -rf metrolist squashfs-root appimage-tools

# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, so restoring recorded ownership would abort the unpack.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools=appimage-tools/bin
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" metrolist.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac
"$tools/unsquashfs" -q -no-xattrs -d squashfs-root -o "$offset" metrolist.AppImage >/dev/null

# AppRun is the format's fixed entry point; it execs "$APPDIR/bin/<name>",
# whose name upstream could change. Check the launcher it names, the bundled
# Java runtime and the jpackage configuration, so a changed layout fails the
# update check instead of shipping an app that can't start.
[ -f squashfs-root/AppRun ] || { echo "AppRun missing from the AppImage" >&2; exit 1; }
name="$(sed -n 's|^exec "\$APPDIR/bin/\([^"/]*\)".*|\1|p' squashfs-root/AppRun | head -n1)"
[ -n "$name" ] || { echo "could not read the launcher name from AppRun" >&2; exit 1; }
[ -x "squashfs-root/bin/$name" ] || { echo "launcher bin/$name from AppRun not executable" >&2; exit 1; }
[ -f squashfs-root/lib/runtime/lib/server/libjvm.so ] || { echo "bundled Java runtime not found" >&2; exit 1; }
ls squashfs-root/lib/app/*.cfg >/dev/null 2>&1 || { echo "jpackage app configuration not found" >&2; exit 1; }

mv squashfs-root metrolist
rm -rf appimage-tools metrolist.AppImage appimage-tools.tar.xz
