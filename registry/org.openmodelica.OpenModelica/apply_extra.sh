#!/bin/sh
set -eu

# One verified release archive contains the official OpenModelica binaries,
# dependency libraries and Qt WebEngine. Nothing large is built into our ref.
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"
[ -f omedit.tar.gz ] || { echo "missing extra-data: omedit.tar.gz" >&2; exit 1; }
rm -rf omedit
bsdtar --no-same-owner -xf omedit.tar.gz
[ -x omedit/bin/omedit ] || { echo "OMEdit launcher missing from bundle" >&2; exit 1; }
[ -x omedit/usr/bin/omc ] || { echo "OpenModelica compiler missing from bundle" >&2; exit 1; }
[ -x omedit/qt/libexec/QtWebEngineProcess ] || { echo "Qt WebEngine helper missing from bundle" >&2; exit 1; }
[ -f omedit/SOURCES.lock.json ] || { echo "bundle provenance missing" >&2; exit 1; }
rm -f omedit.tar.gz
