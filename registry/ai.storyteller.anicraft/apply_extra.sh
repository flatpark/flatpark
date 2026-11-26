#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
[ -f anicraft.tar.gz ] || { echo "missing archive" >&2; exit 1; }
rm -rf stage anicraft
mkdir stage
tar --no-same-owner -xzf anicraft.tar.gz -C stage
set -- stage/*
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo "expected one directory" >&2; exit 1; }
mv "$1" anicraft
for b in anicraft anicraft-cli; do
  [ -x "anicraft/bin/$b" ] || { echo "missing $b" >&2; exit 1; }
done
rm -rf stage anicraft.tar.gz
