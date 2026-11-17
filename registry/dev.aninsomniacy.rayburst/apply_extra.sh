#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. The download is
# upstream's x86_64 AppImage: an ELF stub with a SquashFS filesystem appended.
# It is never executed or mounted; appimage-offset (from the appimage-tools
# extra-data) finds where the SquashFS starts and unsquashfs unpacks it.
#
# The result is upstream's linuxdeploy AppDir, kept whole at a stable path,
# /app/extra/rayburst, because every part of it finds the next by relative
# path:
#   AppRun, apprun-hooks/  the entry point the wrapper execs; the GTK hook
#                          points GTK, GIO, GSettings and GdkPixbuf at usr/
#   usr/bin/               the Tauri GUI, the Aria2 Next engine sidecar and the
#                          browser-activation helper; RUNPATH $ORIGIN/../lib
#   usr/lib/               the bundled glib, GTK 3, libsoup 3 and WebKitGTK,
#                          plus usr/lib/Rayburst, the resource tree the engine
#                          reads (peer blocklist, GeoIP, ED2K bootstrap caches)
#   usr/lib/x86_64-linux-gnu/webkit2gtk-4.1/
#                          WebKitWebProcess and WebKitNetworkProcess, which the
#                          bundled libwebkit2gtk finds relative to usr/
#
# The desktop file, app icon and AppStream metainfo are shipped by the manifest
# at *build* time — extra-data is fetched later on the user's machine, so
# anything Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in rayburst.AppImage appimage-tools.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
rm -rf rayburst squashfs-root appimage-tools

# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring the archive's recorded uid/gid
# would fail and abort the unpack.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" rayburst.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac
# -no-xattrs: the sandbox can't set them, and the app doesn't need them.
"$tools/unsquashfs" -q -no-xattrs -d squashfs-root -o "$offset" rayburst.AppImage >/dev/null

app=squashfs-root
[ -x "$app/AppRun" ]                 || { echo "AppRun missing from the AppDir" >&2; exit 1; }
[ -f "$app/apprun-hooks/linuxdeploy-plugin-gtk.sh" ] \
    || { echo "linuxdeploy GTK hook missing from the AppDir" >&2; exit 1; }

# AppRun.wrapped starts the binary named by Exec= in the AppDir's own desktop
# entry, so that entry is what a rename upstream would change. Pin refreshes
# are merged without a human: check it names exactly one launcher that exists,
# rather than hardcoding usr/bin/rayburst here.
set -- "$app"/*.desktop
[ "$#" -eq 1 ] && [ -e "$1" ] || { echo "expected one .desktop in the AppDir root" >&2; exit 1; }
exec_line="$(sed -n 's/^Exec=//p' "$1" | head -n1)"
launcher="$(basename "${exec_line%% *}")"
[ -n "$launcher" ] && [ -x "$app/usr/bin/$launcher" ] \
    || { echo "launcher '$launcher' from the AppDir's desktop entry not in usr/bin" >&2; exit 1; }

[ -f "$app/usr/lib/libwebkit2gtk-4.1.so.0" ] \
    || { echo "bundled libwebkit2gtk-4.1 missing from the AppDir" >&2; exit 1; }
[ -x "$app/usr/lib/x86_64-linux-gnu/webkit2gtk-4.1/WebKitWebProcess" ] \
    && [ -x "$app/usr/lib/x86_64-linux-gnu/webkit2gtk-4.1/WebKitNetworkProcess" ] \
    || { echo "bundled WebKit helper processes missing from the AppDir" >&2; exit 1; }
[ -x "$app/usr/bin/aria2-next" ] || { echo "Aria2 Next engine missing from the AppDir" >&2; exit 1; }
[ -d "$app/usr/lib/Rayburst" ]   || { echo "resource tree usr/lib/Rayburst missing from the AppDir" >&2; exit 1; }

mv "$app" rayburst

# Drop the 100 MiB AppImage and the extractor now that the tree is staged;
# whatever is left in /app/extra stays on the user's disk.
rm -rf rayburst.AppImage appimage-tools.tar.xz appimage-tools
