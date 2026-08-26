#!/bin/sh
set -eu

# The official Debian package contains one self-contained Tauri binary. Keep it
# at the stable path used by the launcher; package metadata is installed by the
# manifest at build time.
# shellcheck disable=SC3040
(set -o pipefail) 2> /dev/null && set -o pipefail || true

LC_ALL=C
export LC_ALL

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f elasticvue.deb ] || {
  echo "missing extra-data: elasticvue.deb" >&2
  exit 1
}

rm -rf stage elasticvue
mkdir stage
# System-wide apply_extra runs as root with all capabilities dropped, so archive
# ownership must not be restored during extraction.
bsdtar -xOf elasticvue.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

[ -x stage/usr/bin/elasticvue ] || {
  echo "elasticvue binary not found in .deb" >&2
  exit 1
}

mv stage/usr/bin/elasticvue elasticvue
rm -rf stage elasticvue.deb
chmod +x elasticvue
