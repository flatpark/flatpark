#!/bin/sh
set -eu

# The unpack below is a pipeline. Enable pipefail when the runtime shell supports
# it so a failure in either bsdtar process cannot leave a partial installation.
# shellcheck disable=SC3040
(set -o pipefail) 2> /dev/null && set -o pipefail || true

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships an
# electron-builder .deb whose payload is one directory under /opt holding the
# Electron app (the launcher, app.asar, libffmpeg.so, ANGLE/SwiftShader, and the
# embedded-mpv helper under resources/app.asar.unpacked).
# Keep that directory at a stable path the wrapper execs: /app/extra/app.
#
# Neither the directory name nor the launcher name is written down here: pin
# refreshes are automated, and both are names upstream can change between
# releases, so they are read out of the artifact instead. The .deb's own .desktop Exec line is the
# authoritative launcher name; a `launch` symlink next to it gives the wrapper a
# fixed entry point.
LC_ALL=C
export LC_ALL

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f app.deb ] || {
  echo "missing extra-data: app.deb" >&2
  exit 1
}

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container; pipe its data member into a second bsdtar for the inner archive.
rm -rf stage app
mkdir stage
# --no-same-owner is required because a system-wide apply_extra runs as root with
# every capability dropped and cannot restore archive ownership.
bsdtar -xOf app.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# Exactly one application directory is expected under /opt.
count=$(find stage/opt -mindepth 1 -maxdepth 1 -type d | wc -l)
[ "$count" -eq 1 ] || {
  echo "expected exactly one directory under opt/, found $count" >&2
  exit 1
}
appdir=$(find stage/opt -mindepth 1 -maxdepth 1 -type d)

# Read the launcher name from the vendor's own desktop entry:
#   Exec=/opt/<App Dir>/<launcher> --ozone-platform=x11 %U
# Only the first word is the program; the rest are its arguments.
desktop=$(find stage/usr/share/applications -name '*.desktop' | head -n 1)
[ -n "$desktop" ] || { echo "no .desktop in .deb" >&2; exit 1; }
launcher=$(sed -n 's/^Exec=//p' "$desktop" | head -n 1 \
           | sed -e 's/^"\([^"]*\)".*/\1/' -e t -e 's/ .*//' | sed 's:.*/::')
[ -n "$launcher" ] || { echo "could not read launcher name from $desktop" >&2; exit 1; }
[ -x "$appdir/$launcher" ] || {
  echo "launcher '$launcher' not executable in $appdir" >&2
  exit 1
}

# The program the desktop entry names is electron-builder's shell launcher,
# which only decides whether to pass --no-sandbox before exec'ing the real
# Electron binary, <launcher>.bin, beside it. zypak has to start the Electron
# binary itself (and supplies the sandbox), so link that one when it exists.
if [ -x "$appdir/$launcher.bin" ]; then
  launcher="$launcher.bin"
fi

mv "$appdir" app
ln -sf "$launcher" app/launch
rm -rf stage app.deb
[ -x app/launch ] || { echo "launcher missing after stage" >&2; exit 1; }
