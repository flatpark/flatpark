#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# Animeko as a type-2 AppImage: a small ELF stub with a SquashFS AppDir
# appended. The AppDir holds usr/bin/Ani (a jpackage launcher), a bundled JRE
# with JCEF, the app's jars and its mpv/FFmpeg libraries, plus AppRun. Unpack it
# into a stable directory the wrapper starts; never execute the AppImage.
#
# The runtime has no SquashFS tool, so a second extra-data download supplies
# appimage-offset and unsquashfs. The desktop file, icon and AppStream metainfo
# are shipped by the manifest at build time — extra-data is fetched later on the
# user's machine, so anything Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in animeko.AppImage appimage-tools.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done

rm -rf app squashfs-root appimage-tools

# --no-same-owner: a system-wide install runs apply_extra as root with every
# capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools=appimage-tools/bin
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" animeko.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac
"$tools/unsquashfs" -q -no-xattrs -d squashfs-root -o "$offset" animeko.AppImage >/dev/null

# Keep the AppDir's tree whole: Ani finds its runtime through
# usr/lib/libapplauncher.so and the relative layout; jcef_helper and cef_server
# find libcef.so through their $ORIGIN; libmediampv finds mpv and FFmpeg through
# $ORIGIN/native. Moving pieces apart breaks all of them.
[ -x squashfs-root/usr/bin/Ani ] || { echo "no usr/bin/Ani in the AppImage" >&2; exit 1; }
[ -x squashfs-root/AppRun ] || { echo "no AppRun in the AppImage" >&2; exit 1; }
[ -f squashfs-root/usr/lib/runtime/lib/libcef.so ] \
    || { echo "JCEF runtime missing from the AppImage" >&2; exit 1; }

mv squashfs-root app
# jpackage records the build machine's umask, so hundreds of the app's jars and
# resources are mode 600. A system install unpacks them as root but runs the app
# as the user, who then cannot read them; make the tree readable and keep the
# executable bits. `X` only adds execute to directories and already-executable
# files, so chrome-sandbox does not become executable.
chmod -R a+rX app

rm -rf appimage-tools animeko.AppImage appimage-tools.tar.xz
