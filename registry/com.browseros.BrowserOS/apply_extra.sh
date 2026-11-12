#!/bin/sh
set -eu
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"
[ -f browseros.deb ] || { echo "missing browseros.deb" >&2; exit 1; }
rm -rf stage browseros
mkdir stage
# Do not restore archive ownership: system installs run as root without caps.
bsdtar -xOf browseros.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
# The neo Debian package includes the browser, extensions and agent server here.
[ -x stage/usr/lib/browserclaw/browserclaw ] || { echo "missing browserclaw executable" >&2; exit 1; }
[ -x stage/usr/lib/browserclaw/BrowserClawServer/default/resources/bin/browseros-claw-server ] || { echo "missing bundled agent server" >&2; exit 1; }
mv stage/usr/lib/browserclaw browseros
# The namespace sandbox is supplied by zypak; never export setuid files.
chmod -R a-s browseros
rm -rf stage browseros.deb
