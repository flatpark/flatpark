#!/bin/sh
set -eu

# Runs offline at install time. This package pins the Vulkan/CPU AppImage.
# The CUDA AppImage of the same release is a different build and is rejected
# here. The image is read directly, never executed and never FUSE-mounted.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in music-generator.AppImage appimage-tools.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
rm -rf music squashfs-root appimage-tools

bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" music-generator.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac

"$tools/unsquashfs" -q -no-xattrs -o "$offset" -d squashfs-root music-generator.AppImage >/dev/null
[ -x squashfs-root/usr/bin/music-generator ] || { echo "music-generator not found in the AppImage" >&2; exit 1; }
[ -f "squashfs-root/usr/lib/Music Generator/engine/libggml-vulkan.so" ] \
    || { echo "Vulkan engine not found in the AppImage" >&2; exit 1; }
if [ -e "squashfs-root/usr/lib/Music Generator/engine/libggml-cuda.so" ]; then
    echo "this AppImage is the CUDA build, not the Vulkan/CPU build" >&2
    exit 1
fi
mv squashfs-root music

rm -rf music-generator.AppImage appimage-tools.tar.xz appimage-tools
