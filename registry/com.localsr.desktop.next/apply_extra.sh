#!/bin/sh
set -eu

# Runs offline at install time. This package pins the CPU AppImage. The CUDA
# and ROCm AppImages of the same release are separate builds, published in
# parts, and are not part of this package. The image is read directly, never
# executed and never FUSE-mounted.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in localsr.AppImage appimage-tools.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
rm -rf localsr squashfs-root appimage-tools

bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" localsr.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac

# The image records uid/gid 1001 (the build runner's user). On a system-wide
# install this runs as root with every capability dropped, and unsquashfs,
# which has no switch to skip it, tries to chown each entry to that uid and
# exits 2. Content and modes are still written. Tolerate exactly that error,
# fail on any other, and check every entry of the image was extracted.
if ! "$tools/unsquashfs" -q -no-xattrs -o "$offset" -d squashfs-root localsr.AppImage \
        >/dev/null 2>unsquashfs.err; then
    if grep -v -e 'failed to change uid and gids' -e '^[[:space:]]*$' unsquashfs.err | grep -q .; then
        cat unsquashfs.err >&2
        exit 1
    fi
fi
rm -f unsquashfs.err
want="$("$tools/unsquashfs" -lc -o "$offset" localsr.AppImage 2>/dev/null | grep -c '^squashfs-root/' || true)"
# -lc lists files, symlinks and empty directories.
got="$(find squashfs-root -mindepth 1 \( ! -type d -o -type d -empty \) | wc -l)"
[ "$want" -gt 0 ] && [ "$want" -eq "$got" ] \
    || { echo "unpacked $got of $want entries from the AppImage" >&2; exit 1; }
[ -x squashfs-root/AppRun ] || { echo "no AppRun in the AppImage" >&2; exit 1; }
[ -x squashfs-root/usr/bin/localsr-next ] || { echo "localsr-next not found in the AppImage" >&2; exit 1; }
[ -x squashfs-root/usr/lib/LocalSR/engine/localsr-worker ] \
    || { echo "engine worker not found in the AppImage" >&2; exit 1; }
mv squashfs-root localsr

rm -rf localsr.AppImage appimage-tools.tar.xz appimage-tools
