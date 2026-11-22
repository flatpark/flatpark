#!/bin/sh
set -eu

# The unpack below is a pipeline. Enable pipefail when the runtime shell supports
# it so a failure in either bsdtar process cannot leave a partial installation.
# shellcheck disable=SC3040
(set -o pipefail) 2> /dev/null && set -o pipefail || true

# Runs offline at install time. The upstream package is a Debian archive with
# the app binary in usr/bin and its resources (report template, bundled MCP
# server, licence notices) in usr/lib/Open Calc Studio. Tauri looks for those
# at <exe dir>/../lib/<product name>, so the usr/ tree is kept whole.
#
# The binary's name ("Open Calc Studio", from mainBinaryName) is read from the
# .deb's own desktop entry instead of being hardcoded. A symlink named after the
# app id is the entry point: its name becomes the program name and with it the
# window class, which the desktop file's StartupWMClass matches.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f open-calc-studio.deb ] || { echo "missing extra-data: open-calc-studio.deb" >&2; exit 1; }

rm -rf stage calc
mkdir stage
# The Platform runtime has no ar/dpkg. bsdtar reads the .deb and the inner
# data.tar*. --no-same-owner: a system install runs apply_extra as root with
# every capability dropped.
bsdtar -xOf open-calc-studio.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

set -- stage/usr/share/applications/*.desktop
[ "$#" -eq 1 ] && [ -f "$1" ] || { echo "expected exactly one desktop entry in the .deb" >&2; exit 1; }
# Exec="Open Calc Studio" (quoted, possibly with field codes after it).
bin="$(sed -n 's/^Exec=//p' "$1" | head -n1 | sed -e 's/^"\([^"]*\)".*/\1/' -e 's/ %[a-zA-Z]$//')"
case "$bin" in
    "" | */*) echo "unexpected Exec= in the .deb's desktop entry: $bin" >&2; exit 1 ;;
esac
[ -x "stage/usr/bin/$bin" ] || { echo "$bin not found in .deb" >&2; exit 1; }
[ -d stage/usr/lib ] || { echo "usr/lib resource tree not found in .deb" >&2; exit 1; }

mkdir calc
mv stage/usr calc/usr
ln -s "$bin" calc/usr/bin/org.openaec.OpenCalcStudio
rm -rf stage open-calc-studio.deb
