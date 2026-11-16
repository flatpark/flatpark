#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. DinoX's
# AppImage is a complete AppDir: GTK 4, libadwaita, GLib, GStreamer, ffmpeg,
# gpg, tor and DinoX's own libraries. Upstream builds it for every distribution
# that is not Ubuntu 24.04, and this runtime brings only the display, GL, font
# and C libraries it leaves to the host. The AppImage is never run: appimage-tools
# (a second extra-data download, see the manifest) finds where the SquashFS
# starts and unpacks it. The tree is kept whole under a fixed path; its
# RUNPATHs and plugin directories only work while usr/bin, usr/lib and
# usr/share stay siblings.
#
# The launcher's name is read from the AppDir's own .desktop file rather than
# written down here, so an upstream rename fails the update check instead of
# shipping an app that cannot start.
#
# One thing is made next to the tree, not inside it: a bin/dinox symlink to the
# launcher. Nothing from the AppImage is run here; the GdkPixbuf loader cache
# AppRun rebuilds at every launch is built by the wrapper, inside the sandbox.
#
# The desktop entry, icon and AppStream metainfo are shipped by the manifest at
# *build* time: extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.
LC_ALL=C
export LC_ALL

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in dinox.AppImage appimage-tools.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
rm -rf dinox bin squashfs-root appimage-tools

# --no-same-owner: a system-wide install runs this as root with every capability
# dropped, and restoring the archive's recorded uid/gid would abort the unpack.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools=appimage-tools/bin

# Find where the appended SquashFS starts, then unpack from there.
offset="$("$tools/appimage-offset" dinox.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac
# -no-xattrs: the sandbox can't set them, and the app doesn't need them.
"$tools/unsquashfs" -q -no-xattrs -d squashfs-root -o "$offset" dinox.AppImage >/dev/null

desktop="$(find squashfs-root -maxdepth 1 -name '*.desktop')"
[ -n "$desktop" ] && [ "$(printf '%s\n' "$desktop" | wc -l)" -eq 1 ] || {
    echo "expected exactly one .desktop file in the AppImage" >&2
    exit 1
}
binary="$(sed -n 's/^Exec=//p' "$desktop" | head -n 1 | sed 's/ %[A-Za-z]*$//; s:.*/::')"
[ -n "$binary" ] && [ -x "squashfs-root/usr/bin/$binary" ] || {
    echo "launcher '$binary' from $desktop not found in usr/bin" >&2
    exit 1
}
[ -x squashfs-root/usr/bin/gdk-pixbuf-query-loaders ] || {
    echo "gdk-pixbuf-query-loaders not found in the AppImage" >&2
    exit 1
}
[ -d squashfs-root/usr/lib/gdk-pixbuf-2.0/2.10.0/loaders ] || {
    echo "no gdk-pixbuf loaders in the AppImage" >&2
    exit 1
}

mv squashfs-root dinox

# A fixed entry point for the wrapper, whatever upstream calls the launcher. The
# name of the link is the program name the toolkit derives the window class
# from, so it stays `dinox`, which StartupWMClass in the desktop file names.
# The binary finds its libraries through $ORIGIN, which resolves through the
# link to usr/bin.
mkdir bin
ln -s "../dinox/usr/bin/$binary" bin/dinox
rm -rf appimage-tools dinox.AppImage appimage-tools.tar.xz
