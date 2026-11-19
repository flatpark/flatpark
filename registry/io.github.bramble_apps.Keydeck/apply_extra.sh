#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Keydeck's
# Linux download is an AppImage: an ELF stub with a SquashFS filesystem
# appended. It is never executed or mounted; the appended filesystem is
# unpacked with the appimage-tools stack fetched alongside it
# (appimage-offset finds where the SquashFS starts, unsquashfs unpacks it).
#
# The AppDir is staged whole at /app/extra/keydeck. It holds one static-ish
# Rust binary (it links only glibc and libgcc_s) in usr/bin, a few X11 and
# xkbcommon libraries in usr/lib that the runtime also has, and an AppRun
# script that puts usr/lib on LD_LIBRARY_PATH and execs the binary. The
# wrapper runs the binary directly, as upstream's own Flatpak bundle does.
#
# The desktop file, icon and AppStream metainfo are installed by the manifest
# at build time, since extra-data only arrives on the user's machine.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in keydeck.AppImage appimage-tools.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done

# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring an archive's recorded owner
# fails and aborts the unpack.
rm -rf appimage-tools
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" keydeck.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac

rm -rf keydeck
# -no-xattrs: the apply_extra sandbox cannot set security xattrs.
"$tools/unsquashfs" -q -no-xattrs -o "$offset" -d keydeck keydeck.AppImage >/dev/null

# Take the binary from AppRun's exec line rather than assuming its name, so a
# renamed binary still starts, and a changed AppRun fails here, loudly.
target="$(sed -n 's|^exec "$HERE/\(usr/bin/[^"]*\)".*|\1|p' keydeck/AppRun)"
[ -n "$target" ] && [ -x "keydeck/$target" ] \
    || { echo "AppRun does not exec a binary in usr/bin: '$target'" >&2; exit 1; }
[ "$target" = usr/bin/keydeck ] || ln -sf "${target#usr/bin/}" keydeck/usr/bin/keydeck

rm -rf keydeck.AppImage appimage-tools.tar.xz appimage-tools
