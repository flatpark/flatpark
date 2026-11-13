#!/bin/sh
set -eu

# Runs offline at install time. Use the portable binary from the vendor's
# archive; do not run its host installer or create host desktop files.
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f flowsurface-linux.tar.gz ] || {
    echo "missing extra-data: flowsurface-linux.tar.gz" >&2
    exit 1
}

rm -rf stage flowsurface
mkdir stage
# A system-wide install runs this as root with capabilities dropped, so never
# restore owners recorded in the archive.
bsdtar --no-same-owner -xf flowsurface-linux.tar.gz -C stage

binary="$(find stage -type f -path '*/bin/flowsurface' -print)"
[ -n "$binary" ] || {
    echo "bin/flowsurface was not found in the Linux archive" >&2
    exit 1
}
[ "$(printf '%s\n' "$binary" | wc -l)" -eq 1 ] || {
    echo "expected exactly one bin/flowsurface in the Linux archive" >&2
    exit 1
}
[ -x "$binary" ] || {
    echo "bin/flowsurface is not executable in the Linux archive" >&2
    exit 1
}

install_root="${binary%/bin/flowsurface}"
mv "$install_root" flowsurface
[ -x flowsurface/bin/flowsurface ] || {
    echo "failed to install the portable Flowsurface tree" >&2
    exit 1
}

rm -rf stage flowsurface-linux.tar.gz
