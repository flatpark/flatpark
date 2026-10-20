#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream's Linux
# downloads are an electron-builder AppImage, .deb and .rpm (plus their own
# .flatpak bundle). The AppImage is used because its tree matches what upstream's
# own Flatpak build ships: the .deb carries a resources/package-type marker that
# switches the app's built-in updater to installing .deb files, which cannot
# work here, while the AppImage tree has none and its updater stays inactive
# unless the AppImage runtime starts it. Nothing in the tree is changed.
#
# A type-2 AppImage is an ELF stub with a SquashFS image appended. It is never
# executed or FUSE-mounted; the appimage-tools extra-data supplies
#   appimage-offset  prints the byte offset where the SquashFS begins
#   unsquashfs       unpacks from that offset
# and the AppDir is staged whole at /app/extra/app.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in app.AppImage appimage-tools.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
rm -rf app squashfs-root appimage-tools launcher

# --no-same-owner: a system-wide apply_extra runs as root with every capability
# dropped and cannot restore archive ownership. -no-xattrs keeps unsquashfs from
# trying to set xattrs the sandbox does not allow.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" app.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac
"$tools/unsquashfs" -q -no-xattrs -o "$offset" -d squashfs-root app.AppImage >/dev/null

# electron-builder names the launcher after executableName, which upstream can
# change; read it from the AppDir's AppRun rather than writing it here:
#   BIN="$APPDIR/p3x-onenote"
[ -f squashfs-root/AppRun ] || { echo "AppRun missing from the AppDir" >&2; exit 1; }
name="$(sed -n 's|^BIN="\$APPDIR/\([^"]*\)".*|\1|p' squashfs-root/AppRun | head -n1)"
[ -n "$name" ] || { echo "could not read the launcher name from the AppDir's AppRun" >&2; exit 1; }
[ -x "squashfs-root/$name" ] || { echo "launcher '$name' from AppRun not executable in the AppDir" >&2; exit 1; }
[ -f squashfs-root/resources/app.asar ] || { echo "resources/app.asar missing in the AppDir" >&2; exit 1; }

mv squashfs-root app
# Recorded beside the app tree, not inside it, so the vendor's tree stays as
# shipped.
printf '%s\n' "$name" > launcher

# Drop the AppImage and the extractor now that the tree is staged.
rm -rf app.AppImage appimage-tools.tar.xz appimage-tools
