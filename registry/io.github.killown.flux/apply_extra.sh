#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream ships Flux
# as a plain release tarball: one top-level directory holding the binary next
# to its GResource icons, LICENSE and README. Only the binary is needed at run
# time - the desktop entry, icon and AppStream metainfo are shipped by the
# manifest at build time.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in flux.tar.gz poppler-glib.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done

rm -rf stage flux
mkdir stage
# --no-same-owner: on a system-wide install apply_extra runs as root with every
# capability dropped, so restoring the recorded runner uid/gid would fail.
bsdtar --no-same-owner -xf flux.tar.gz -C stage

# The binary is built as flux-fm; accept a later rename to flux as well.
bin="$(find stage -mindepth 2 -maxdepth 2 -type f \( -name flux-fm -o -name flux \) -print | head -n1)"
[ -n "$bin" ] && [ -x "$bin" ] || { echo "no flux binary in release tarball" >&2; exit 1; }

mkdir -p flux
mv "$bin" flux/flux-fm
rm -rf stage flux.tar.gz

# The prebuilt archive has one top-level poppler-glib/ directory holding lib/.
rm -rf poppler-glib
bsdtar --no-same-owner -xf poppler-glib.tar.xz
[ -e poppler-glib/lib/libpoppler-glib.so.8 ] || { echo "libpoppler-glib.so.8 not found in poppler-glib.tar.xz" >&2; exit 1; }
rm -f poppler-glib.tar.xz
