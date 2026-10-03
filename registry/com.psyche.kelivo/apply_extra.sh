#!/bin/sh
set -eu

# The unpacks below are pipelines. Enable pipefail when the runtime shell
# supports it so a failure in either bsdtar process cannot leave a partial
# installation.
# shellcheck disable=SC3040
(set -o pipefail) 2> /dev/null && set -o pipefail || true

# Runs offline at install time inside org.gnome.Platform.
#
# Upstream's .deb carries the whole Flutter bundle under opt/kelivo: the kelivo
# binary (RUNPATH $ORIGIN/lib), data/ with the Flutter assets, and lib/ with the
# engine, the plugins and the bundled ONNX/sherpa-onnx libraries. Stage that
# directory as is at /app/extra/kelivo.
#
# Debian's libkeybinder-3.0-0 provides the one library the global-hotkey plugin
# links that neither the runtime nor the bundle has. Only its shared object and
# SONAME link are kept, in /app/extra/deps/lib, which the wrapper adds to the
# loader path.
LC_ALL=C
export LC_ALL

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f app.deb ] || { echo "missing extra-data: app.deb" >&2; exit 1; }
[ -f libkeybinder-3.0-0.deb ] || { echo "missing extra-data: libkeybinder-3.0-0.deb" >&2; exit 1; }

rm -rf stage kelivo deps
mkdir stage
# --no-same-owner is required: the .deb records uid/gid 1001, and a system-wide
# apply_extra runs as root with every capability dropped, so restoring that
# ownership would fail and abort the unpack.
bsdtar -xOf app.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/opt/kelivo/kelivo ] || { echo "opt/kelivo/kelivo not found in .deb" >&2; exit 1; }
mv stage/opt/kelivo kelivo
rm -rf stage app.deb

mkdir stage
bsdtar -xOf libkeybinder-3.0-0.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
mkdir -p deps/lib
# Copy the SONAME symlink together with the file it points at; the loader looks
# up the link name.
find stage/usr/lib -name 'libkeybinder-3.0.so*' \( -type f -o -type l \) -exec cp -P {} deps/lib/ \;
[ -e deps/lib/libkeybinder-3.0.so.0 ] || { echo "libkeybinder-3.0.so.0 not found" >&2; exit 1; }
rm -rf stage libkeybinder-3.0-0.deb
