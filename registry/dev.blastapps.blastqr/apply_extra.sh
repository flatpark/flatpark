#!/bin/sh
set -eu
# Flatpak runs this offline in /app/extra, including as root without capabilities.
cd "${EXTRA_ROOT:-/app/extra}"
[ -f blastqr.tar.gz ] || { echo "missing extra-data: blastqr.tar.gz" >&2; exit 1; }
rm -rf stage blastqr launch
mkdir stage
bsdtar --no-same-owner -xf blastqr.tar.gz -C stage
# Discover the portable tree independently of its top-level directory name.
set -- stage/*
[ "$#" -eq 1 ] && [ -d "$1/lib" ] && [ -d "$1/data" ] || {
    echo "expected one Flutter bundle with lib and data directories" >&2; exit 1;
}
mv "$1" blastqr
# The bundle has one top-level executable. Keep a stable launcher even if its
# upstream name changes, without modifying any vendor files.
launcher=
for file in blastqr/*; do
    if [ -f "$file" ] && [ -x "$file" ]; then
        [ -z "$launcher" ] || { echo "ambiguous bundle launcher" >&2; exit 1; }
        launcher="${file#blastqr/}"
    fi
done
[ -n "$launcher" ] || { echo "bundle launcher missing" >&2; exit 1; }
ln -s "blastqr/$launcher" launch
rm -rf stage blastqr.tar.gz
