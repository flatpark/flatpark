#!/bin/sh
set -eu
test -s croc.tar.gz
mkdir payload
bsdtar --no-same-owner -xf croc.tar.gz -C payload
test -x payload/croc
test -x payload/croc-update
rm croc.tar.gz
