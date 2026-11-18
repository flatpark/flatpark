#!/bin/sh
# Unpacks the official Linux release on the user's machine at install time.
# The archive has no top-level directory: a Godot binary, its .pck and the
# NativeAOT helper sit at the root. They are unpacked into a fixed directory so
# the wrapper keeps working across updates.
set -eu

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f gdre_tools.zip ] || { echo "missing extra-data: gdre_tools.zip" >&2; exit 1; }

# --no-same-owner: a system-wide install runs apply_extra as root with every
# capability dropped, so restoring recorded owners would fail.
rm -rf gdre
mkdir gdre
bsdtar --no-same-owner -xf gdre_tools.zip -C gdre

# Fail the update check instead of shipping an app whose layout changed.
[ -f gdre/gdre_tools.x86_64 ]                || { echo "gdre_tools.x86_64 missing after unpack" >&2; exit 1; }
[ -f gdre/gdre_tools.pck ]                   || { echo "gdre_tools.pck missing after unpack" >&2; exit 1; }
[ -f gdre/libGodotMonoDecompNativeAOT.so ]   || { echo "libGodotMonoDecompNativeAOT.so missing after unpack" >&2; exit 1; }

chmod 755 gdre/gdre_tools.x86_64
rm -f gdre_tools.zip
