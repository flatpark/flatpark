#!/bin/sh
set -eu
# The official OSS tarball includes JetBrains Runtime. Keep its tree intact.
cd "${EXTRA_ROOT:-/app/extra}"
[ -f pycharm.tar.gz ] || { echo "missing extra-data: pycharm.tar.gz" >&2; exit 1; }
rm -rf stage pycharm
mkdir stage
bsdtar --no-same-owner -xf pycharm.tar.gz -C stage
set -- stage/*
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo "expected one PyCharm directory" >&2; exit 1; }
mv "$1" pycharm
[ -x pycharm/bin/pycharm ] && [ -x pycharm/jbr/bin/java ] || {
    echo "PyCharm launcher or bundled Java runtime missing" >&2; exit 1;
}
# PC identifies the Community product; never accept the unified PY build.
grep -Eq '"productCode"[[:space:]]*:[[:space:]]*"PC"' pycharm/product-info.json || {
    echo "expected the PyCharm Community (PC) product" >&2; exit 1;
}
rm -rf stage pycharm.tar.gz
