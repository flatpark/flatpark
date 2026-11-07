#!/bin/sh
set -eu
# Catch failures in either archive reader on runtimes with pipefail support.
(set -o pipefail) 2>/dev/null && set -o pipefail || true
cd "${EXTRA_ROOT:-/app/extra}"
[ -f chiri.deb ] || { echo "missing extra-data: chiri.deb" >&2; exit 1; }
rm -rf stage chiri
mkdir stage
# System installs run as root without capabilities; never restore ownership.
bsdtar -xOf chiri.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
# Read the launcher from the single upstream desktop entry; fail on ambiguity.
set -- stage/usr/share/applications/*.desktop
[ "$#" -eq 1 ] && [ -f "$1" ] || { echo "expected one desktop entry" >&2; exit 1; }
binary=$(sed -n 's/^Exec=//p' "$1" | sed 's/ %[A-Za-z]$//')
case "$binary" in ''|*[!A-Za-z0-9._-]*) echo "unsupported launcher: $binary" >&2; exit 1;; esac
[ -x "stage/usr/bin/$binary" ] || { echo "launcher missing: $binary" >&2; exit 1; }
mkdir chiri
# Preserve the FHS tree for any resources upstream ships beside its executable.
mv stage/usr chiri/usr
ln -s "$binary" chiri/usr/bin/garden.chiri.Chiri
rm -rf stage chiri.deb
