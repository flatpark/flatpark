#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Four archives have
# already been fetched here by extra-data: upstream's own Linux tarball, and
# Debian's libc++, libc++abi and libunwind - the C++ runtime Gyroflow and its
# bundled FFmpeg/mdk libraries link against, which the Flatpak runtime does not
# ship. The vendor's bytes run unmodified; nothing is patched.
#
# The desktop entry, icon and AppStream metainfo are shipped by the manifest at
# *build* time - extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

debs="libc++1-19.deb libc++abi1-19.deb libunwind-19.deb"
for f in gyroflow.tar.gz $debs; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done

rm -rf stage gyroflow lib
mkdir stage lib

# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring an archive's recorded uid/gid
# fails and aborts the unpack even though every member extracted fine.
bsdtar --no-same-owner -xf gyroflow.tar.gz -C stage
# The tarball holds a single top-level directory (Gyroflow/ today); take it
# from the archive rather than hardcoding it, and stage it at a stable path.
set -- stage/*
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo "expected one top-level directory in the tarball, got: $*" >&2; exit 1; }
mv "$1" gyroflow
[ -x gyroflow/gyroflow ] || { echo "gyroflow binary missing after unpack" >&2; exit 1; }

# The runtime has no ar or dpkg, but bsdtar reads the .deb ar container
# directly.
for deb in $debs; do
    bsdtar -xOf "$deb" 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
done
# The libraries live in usr/lib/llvm-<N>/lib; the copies under
# usr/lib/x86_64-linux-gnu are only relative symlinks into that tree, which
# would dangle once copied. -o -type l, because the loader looks up the SONAME
# link (libc++.so.1 -> libc++.so.1.0), not the regular file behind it.
set -- stage/usr/lib/llvm-*/lib
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo "expected exactly one usr/lib/llvm-*/lib directory, got: $*" >&2; exit 1; }
find "$1" -maxdepth 1 \( -type f -o -type l \) \
    \( -name 'libc++.so.*' -o -name 'libc++abi.so.*' -o -name 'libunwind.so.*' \) \
    -exec cp -a {} lib/ \;
for so in libc++.so.1 libc++abi.so.1 libunwind.so.1; do
    [ -e "lib/$so" ] || { echo "$so not found in the Debian packages" >&2; exit 1; }
done

rm -rf stage gyroflow.tar.gz $debs
