#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Letters's
# Linux download is an AppImage: an ELF stub with a SquashFS filesystem
# appended. It is never executed or mounted; the appended filesystem is
# unpacked with the appimage-tools stack fetched alongside it
# (appimage-offset finds where the SquashFS starts, unsquashfs unpacks it).
#
# The AppDir is staged whole at /app/extra/letters. It holds one static-ish
# Rust binary (it links only glibc and libgcc_s) in usr/bin, a few X11 and
# xkbcommon libraries in usr/lib that the runtime also has, and an AppRun
# script that puts usr/lib on LD_LIBRARY_PATH and execs the binary. The
# wrapper runs the binary directly, as upstream's own Flatpak bundle does.
#
# The desktop file, icon and AppStream metainfo are installed by the manifest
# at build time, since extra-data only arrives on the user's machine.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in letters.AppImage appimage-tools.tar.xz cups-client.tar.xz; do
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

offset="$("$tools/appimage-offset" letters.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac

rm -rf letters
# -no-xattrs: the apply_extra sandbox cannot set security xattrs.
"$tools/unsquashfs" -q -no-xattrs -o "$offset" -d letters letters.AppImage >/dev/null

# Take the binary from AppRun's exec line rather than assuming its name, so a
# renamed binary still starts, and a changed AppRun fails here, loudly.
target="$(sed -n 's|^exec "$HERE/\(usr/bin/[^"]*\)".*|\1|p' letters/AppRun)"
[ -n "$target" ] && [ -x "letters/$target" ] \
    || { echo "AppRun does not exec a binary in usr/bin: '$target'" >&2; exit 1; }
[ "$target" = usr/bin/letters ] || ln -sf "${target#usr/bin/}" letters/usr/bin/letters

rm -rf letters.AppImage appimage-tools.tar.xz appimage-tools

# lp, lpstat and lpoptions from FlatPark's prebuilt cups-client stack, for
# File > Print. The archive has one top-level cups-client/ directory; /app/bin
# links into it.
rm -rf cups-client
bsdtar --no-same-owner -xf cups-client.tar.xz
for t in lp lpoptions lpstat; do
    [ -x "cups-client/bin/$t" ] && [ -x "cups-client/libexec/cups/$t" ] \
        || { echo "cups-client/$t not found in cups-client.tar.xz" >&2; exit 1; }
done
rm -f cups-client.tar.xz
