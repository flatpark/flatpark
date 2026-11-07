#!/bin/sh
# Unpacks the release tarball: bin/remoteid (the window and the command line)
# and lib/libremoteid.so (the PKCS#11 module Tessera loads).
set -eu
export LC_ALL=C
bsdtar --no-same-owner -xf remoteid.tar.gz
rm -f remoteid.tar.gz
test -x bin/remoteid
test -f lib/libremoteid.so
