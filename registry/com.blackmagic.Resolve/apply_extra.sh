#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Three pinned
# extra-data files arrive alongside this script in /app/extra:
#
#   resolve-flatpak.tar.gz  the installer/launcher, a self-contained PyInstaller
#                           tree (Python + PySide6) built by the resolve-flatpak
#                           project — the app that fetches and installs Resolve
#   appimage-tools.tar.xz   flatpark/prebuilt's appimage-tools, for unsquashfs
#   libglu1-mesa.deb        libGLU.so.1, which the runtime does not ship
#
# The desktop entry, icon, MIME definition and AppStream metainfo are shipped by
# the manifest at *build* time. extra-data is fetched later, on the user's
# machine, so anything Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in resolve-flatpak.tar.gz appimage-tools.tar.xz libglu1-mesa.deb; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done

# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring an archive's recorded owner fails and
# aborts the unpack even though every member extracted fine.

# 1. The installer/launcher bundle -> /app/extra/resolve-app.
rm -rf resolve-app .resolve-unpack
mkdir .resolve-unpack
bsdtar --no-same-owner -xzf resolve-flatpak.tar.gz -C .resolve-unpack
top="$(find .resolve-unpack -maxdepth 1 -mindepth 1 -type d | head -n 1)"
[ -n "$top" ] || { echo "resolve bundle has no top directory" >&2; exit 1; }
mv "$top" resolve-app
rm -rf .resolve-unpack
[ -x resolve-app/resolve-flatpak ] || { echo "resolve launcher missing after unpack" >&2; exit 1; }

# 2. appimage-tools -> /app/extra/appimage-tools (unsquashfs).
rm -rf appimage-tools
bsdtar --no-same-owner -xf appimage-tools.tar.xz
[ -x appimage-tools/bin/unsquashfs ] || { echo "appimage-tools stack incomplete" >&2; exit 1; }

# 3. libGLU.so.1 -> /app/extra/libglu/usr/lib/x86_64-linux-gnu. A .deb is an ar
# archive holding data.tar.*, which is itself a tarball.
rm -rf libglu
mkdir libglu
bsdtar --no-same-owner -xf libglu1-mesa.deb -C libglu
data="$(find libglu -maxdepth 1 -name 'data.tar.*' | head -n 1)"
[ -n "$data" ] || { echo "no data.tar.* in libglu1-mesa.deb" >&2; exit 1; }
bsdtar --no-same-owner -xf "$data" -C libglu
[ -e libglu/usr/lib/x86_64-linux-gnu/libGLU.so.1 ] \
    || { echo "libGLU.so.1 missing after unpack" >&2; exit 1; }

# Drop the downloaded archives now that the trees are staged.
rm -f resolve-flatpak.tar.gz appimage-tools.tar.xz libglu1-mesa.deb
