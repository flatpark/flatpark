#!/bin/sh
set -eu

# The unpack below is a pipeline. Enable pipefail when the runtime shell supports
# it so a failure in either bsdtar process cannot leave a partial installation.
# shellcheck disable=SC3040
(set -o pipefail) 2> /dev/null && set -o pipefail || true

# Runs offline at install time inside org.gnome.Platform. Keep only Kanri's
# self-contained Tauri binary at the stable path used by the wrapper.
LC_ALL=C
export LC_ALL

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f kanri.deb ] || {
  echo "missing extra-data: kanri.deb" >&2
  exit 1
}

# org.gnome.Platform has no ar/dpkg, but bsdtar reads the .deb ar container;
# pipe its data member into a second bsdtar for the inner archive.
rm -rf stage kanri
mkdir stage
# --no-same-owner is required because system-wide apply_extra runs as root with
# all capabilities dropped and cannot restore archive ownership.
bsdtar -xOf kanri.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

[ -x stage/usr/bin/kanri ] || {
  echo "kanri binary not found in .deb" >&2
  exit 1
}

mv stage/usr/bin/kanri kanri
rm -rf stage kanri.deb
chmod +x kanri
