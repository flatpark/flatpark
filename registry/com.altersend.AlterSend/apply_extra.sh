#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream's Linux
# build is an electron-builder AppImage — there is no .deb, .rpm or tarball — so
# this repackages that. An AppImage is not a special format: a type-2 one is an
# ELF stub with a SquashFS filesystem concatenated after it. It never has to be
# executed or FUSE-mounted to read it; the appended filesystem is unpacked
# directly.
#
# Two tools do that, both from the appimage-tools extra-data fetched alongside
# the AppImage:
#   appimage-offset  prints the byte offset where the SquashFS begins
#   unsquashfs       unpacks from that offset
#
# The result is the AppDir, staged whole at a stable path the wrapper execs:
# /app/extra/altersend. Its layout is the usual electron-builder one — the
# Chromium launcher and its .bin, resources/app, the .pak/.dat resources, the
# bundled libffmpeg/libEGL/libGLESv2/SwiftShader, and usr/lib with the tray and
# libnotify libraries the AppImage carries for older hosts.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f altersend.AppImage ]    || { echo "missing extra-data: altersend.AppImage" >&2; exit 1; }
[ -f appimage-tools.tar.xz ] || { echo "missing extra-data: appimage-tools.tar.xz" >&2; exit 1; }

# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring an archive's recorded uid/gid
# fails and aborts the unpack even though every member extracted fine. This
# AppImage's SquashFS does record uid 1000; unsquashfs never chowns, and
# -no-xattrs keeps it from trying to set security xattrs it may not set either.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" altersend.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac

rm -rf altersend
"$tools/unsquashfs" -no-xattrs -o "$offset" -d altersend altersend.AppImage

# Which file is the Electron launcher? electron-builder names it after
# executableName, which upstream can change between releases, so read it out of
# the AppDir rather than writing it into this script — pin refreshes are
# automated and a rename would otherwise reach users as a failed install
# (com.tldraw.Offline hit exactly that, issue #130). The AppDir's own AppRun
# names it in a single line:
#
#   BIN="$APPDIR/altersend"
#
# and beside that shell shim sits the real ELF, "<name>.bin". The wrapper execs
# the ELF directly under zypak-wrapper instead of the shim, so Chromium keeps
# its internal sandbox; the executable itself is untouched.
[ -f altersend/AppRun ] || { echo "AppRun missing from the AppDir" >&2; exit 1; }
name="$(sed -n 's|^BIN="\$APPDIR/\([^"]*\)".*|\1|p' altersend/AppRun | head -n1)"
[ -n "$name" ] || { echo "could not read the launcher name from the AppDir's AppRun" >&2; exit 1; }

if [ -x "altersend/$name.bin" ]; then
    launcher="$name.bin"
elif [ -x "altersend/$name" ]; then
    launcher="$name"
else
    echo "launcher '$name' from AppRun not executable in the AppDir" >&2
    exit 1
fi
[ -f altersend/resources/app/package.json ] || { echo "resources/app missing in the AppDir" >&2; exit 1; }

# The wrapper reads the resolved name from here rather than hardcoding it. It
# lives beside the app tree, not inside it, so the upstream tree stays as
# shipped.
printf '%s\n' "$launcher" > launcher

# Drop the 188 MiB AppImage and the extractor now that the tree is staged —
# otherwise both sit on the user's disk for the life of the install.
rm -rf altersend.AppImage appimage-tools.tar.xz appimage-tools
