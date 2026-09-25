#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# Open CAD Studio for Linux as an AppImage (and a snap). A type-2 AppImage is an
# ELF stub with a SquashFS filesystem appended; it is read directly here, never
# executed and never FUSE-mounted, with the two tools from the appimage-tools
# extra-data (appimage-offset finds the SquashFS, unsquashfs unpacks it).
#
# The AppDir holds one self-contained binary, usr/bin/OpenCADStudio (AppRun is a
# plain symlink to it), plus its icons and desktop file. It is staged whole at
# /app/extra/opencadstudio.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f opencadstudio.AppImage ] || { echo "missing extra-data: opencadstudio.AppImage" >&2; exit 1; }
[ -f appimage-tools.tar.xz ]  || { echo "missing extra-data: appimage-tools.tar.xz" >&2; exit 1; }

# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring an archive's recorded uid/gid
# fails and aborts the unpack even though every member extracted fine.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" opencadstudio.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac

rm -rf opencadstudio
# -no-xattrs: the apply_extra sandbox cannot set security xattrs.
"$tools/unsquashfs" -no-xattrs -o "$offset" -d opencadstudio opencadstudio.AppImage

# Resolve the binary through AppRun (the AppImage entry point) rather than
# hardcoding its name, so a rename between releases fails here, loudly.
target="$(readlink opencadstudio/AppRun 2>/dev/null || true)"
[ -n "$target" ] && [ -x "opencadstudio/$target" ] \
    || { echo "AppRun does not point at an executable: '$target'" >&2; exit 1; }
[ "$target" = usr/bin/OpenCADStudio ] || ln -sf "../../$target" opencadstudio/usr/bin/OpenCADStudio

rm -rf opencadstudio.AppImage appimage-tools.tar.xz appimage-tools
