#!/bin/sh
set -eu

# The unpack below is a pipeline. Enable pipefail when the runtime shell supports
# it so a failure in either bsdtar process cannot leave a partial installation.
# shellcheck disable=SC3040
(set -o pipefail) 2> /dev/null && set -o pipefail || true

# Runs offline at install time inside org.gnome.Platform. Upstream's Tauri .deb
# is a plain FHS tree whose payload is one self-contained binary under usr/bin
# (the frontend is embedded in it). Keep only that binary, at a stable path the
# wrapper execs: /app/extra/wealthfolio. Its name is read from the vendor's own
# .desktop Exec line rather than written down here.
LC_ALL=C
export LC_ALL

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f app.deb ] || { echo "missing extra-data: app.deb" >&2; exit 1; }

rm -rf stage wealthfolio
mkdir stage
# --no-same-owner is required because a system-wide apply_extra runs as root with
# every capability dropped and cannot restore archive ownership.
bsdtar -xOf app.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

desktop=$(find stage/usr/share/applications -name '*.desktop' | head -n 1)
[ -n "$desktop" ] || { echo "no .desktop in .deb" >&2; exit 1; }
binary=$(sed -n 's/^Exec=//p' "$desktop" | head -n 1 | sed 's/ %[A-Za-z]*$//; s:.*/::')
[ -n "$binary" ] && [ -x "stage/usr/bin/$binary" ] || {
  echo "launcher '$binary' from $desktop not found in usr/bin" >&2
  exit 1
}
mv "stage/usr/bin/$binary" wealthfolio
rm -rf stage app.deb
