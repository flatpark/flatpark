#!/bin/sh
set -eu

[ -f decks.tar.gz ] || { echo "missing extra-data: decks.tar.gz" >&2; exit 1; }

rm -rf decks
mkdir -p decks
bsdtar --no-same-owner -xf decks.tar.gz -C decks

[ -x decks/bin/decks ] || { echo "bin/decks missing after unpack" >&2; exit 1; }

rm -f decks.tar.gz
