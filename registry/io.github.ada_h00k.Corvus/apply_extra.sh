#!/bin/sh
set -eu

# Runs offline at install time inside org.kde.Platform. The archive is the /app
# tree of upstream's own Flatpak build on the same runtime: bin/ holds corvus,
# corvus-cli and qrencode, lib/ the qtkeychain it links against. Its headers,
# debug info and other build leftovers aren't needed to run, so only bin/ and
# the shared libraries in lib/ are kept.

cd "${EXTRA_ROOT:-/app/extra}"

[ -f corvus.tar.gz ] || { echo "missing extra-data: corvus.tar.gz" >&2; exit 1; }

rm -rf stage corvus
mkdir stage
# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, and restoring the archive's uid/gid would abort it.
bsdtar --no-same-owner -xf corvus.tar.gz -C stage

for f in corvus corvus-cli qrencode; do
  [ -x "stage/bin/$f" ] || { echo "bin/$f not found in the archive" >&2; exit 1; }
done

mkdir -p corvus/lib
mv stage/bin corvus/bin
find stage/lib -maxdepth 1 -name '*.so*' -exec mv {} corvus/lib/ \;

rm -rf stage corvus.tar.gz
