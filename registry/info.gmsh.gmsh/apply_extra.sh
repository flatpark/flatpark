#!/bin/sh
set -eu

# Flatpak runs this offline in /app/extra, with only the runtime available.
cd "${EXTRA_ROOT:-/app/extra}"
for archive in gmsh.tgz libglu1-mesa.deb; do
    [ -f "$archive" ] || { echo "missing extra-data: $archive" >&2; exit 1; }
done

rm -rf stage gmsh glu
mkdir -p stage/gmsh stage/glu
# System installs run as root without capabilities; never restore owners.
bsdtar --no-same-owner -xf gmsh.tgz -C stage/gmsh
set -- stage/gmsh/*
[ "$#" -eq 1 ] && [ -d "$1" ] || {
    echo "expected one Gmsh directory in the tarball" >&2; exit 1;
}
mv "$1" gmsh
[ -x gmsh/bin/gmsh ] || { echo "Gmsh executable missing from tarball" >&2; exit 1; }

# Extract Debian's GLU library, retaining its soname symlink. This support
# library is kept beside the unmodified upstream tree, outside the app pin.
bsdtar --no-same-owner -xf libglu1-mesa.deb -C stage/glu
set -- stage/glu/data.tar.*
[ "$#" -eq 1 ] && [ -f "$1" ] || {
    echo "expected one Debian data archive" >&2; exit 1;
}
mkdir glu
bsdtar --no-same-owner -xf "$1" -C glu
[ -f glu/usr/lib/x86_64-linux-gnu/libGLU.so.1 ] || {
    echo "GLU library missing from Debian package" >&2; exit 1;
}
rm -rf stage gmsh.tgz libglu1-mesa.deb
