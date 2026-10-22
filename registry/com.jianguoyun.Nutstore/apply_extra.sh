#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform.
#
# Upstream's tarball has no top-level directory: bin/ (the Python launcher and
# tray), jre/ (a bundled Java 21 whose java binary is named nutstore), lib/
# (the client jar and its JNI libraries), conf/, res/ and webui/. The launcher
# finds everything relative to its own bin/ directory, so the tree is kept whole
# at /app/extra/nutstore.

# The apply_extra sandbox has no locale; without this bsdtar warns on every install.
LC_ALL=C
export LC_ALL

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f nutstore.tar.gz ] || { echo "missing extra-data: nutstore.tar.gz" >&2; exit 1; }

rm -rf stage nutstore
mkdir stage
# --no-same-owner: a system-wide install runs this as root without capabilities.
bsdtar --no-same-owner -xf nutstore.tar.gz -C stage

[ -x stage/bin/nutstore-pydaemon.py ] || { echo "nutstore-pydaemon.py not found in tarball" >&2; exit 1; }
[ -x stage/jre/bin/nutstore ] || { echo "bundled Java runtime not found in tarball" >&2; exit 1; }
ls stage/lib/nutstore_client-*.jar > /dev/null 2>&1 || { echo "client jar not found in tarball" >&2; exit 1; }

mv stage nutstore
rm -f nutstore.tar.gz
