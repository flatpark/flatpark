#!/bin/sh
set -eu

[ -f tables.tar.gz ] || { echo "missing extra-data: tables.tar.gz" >&2; exit 1; }

rm -rf tables
mkdir -p tables
bsdtar --no-same-owner -xf tables.tar.gz -C tables

[ -x tables/bin/tables ] || { echo "bin/tables missing after unpack" >&2; exit 1; }

rm -f tables.tar.gz
