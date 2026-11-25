#!/bin/sh
# Runs at install time in the extension's extra/ folder, after Flatpak has
# downloaded the release tarball and checked its sha256, on the runtime
# named by [ExtensionOf] (freedesktop 26.08). The tarball holds bin/,
# lib/, enable.sh and LICENSE; the extension's own symlinks point into it.
set -eu
tar --no-same-owner -xzf flatpark-spawn.tar.gz
rm -f flatpark-spawn.tar.gz
test -x bin/flatpark-spawn
test -r lib/libflatpark-spawn.so
test -r enable.sh
