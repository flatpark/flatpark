#!/bin/sh
set -eu

# The unpacks below are pipelines. Enable pipefail when the runtime shell
# supports it so a failure in either bsdtar process cannot leave a partial
# installation.
# shellcheck disable=SC3040
(set -o pipefail) 2> /dev/null && set -o pipefail || true

# Runs offline at install time inside org.freedesktop.Platform. Two payloads:
#
#   app.deb        upstream's electron-builder .deb: one directory under /opt
#                  holding the Electron app (launcher, app.asar, libffmpeg.so,
#                  ANGLE/SwiftShader) and resources/nix/bin/exiftool, the
#                  ExifTool Perl script ExifCleaner runs for every format its
#                  native JPEG/PNG/WebP code does not handle.
#   perl-base.deb  Debian's perl-base: the perl interpreter and its core
#                  modules. ExifTool is a Perl program, the .deb does not carry
#                  an interpreter, and the runtime has none.
#
# The Electron app is kept at a stable path the wrapper execs: /app/extra/app.
# Neither its directory name nor the launcher name is written down here: pin
# refreshes are automated, and both are names upstream can change between
# releases, so they are read out of the artifact instead. The .deb's own
# .desktop Exec line is the authoritative launcher name; a `launch` symlink next
# to it gives the wrapper a fixed entry point.
#
# perl goes to /app/extra/perl: the interpreter at perl/bin/perl and the module
# tree at perl/lib. /app/bin/perl, shipped at build time, runs it with that
# module path.
LC_ALL=C
export LC_ALL

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in app.deb perl-base.deb; do
  [ -f "$f" ] || {
    echo "missing extra-data: $f" >&2
    exit 1
  }
done

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container; pipe its data member into a second bsdtar for the inner archive.
# --no-same-owner is required because a system-wide apply_extra runs as root with
# every capability dropped and cannot restore archive ownership.
rm -rf stage perl-stage app perl
mkdir stage perl-stage
bsdtar -xOf app.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
bsdtar -xOf perl-base.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C perl-stage

# Exactly one application directory is expected under /opt.
count=$(find stage/opt -mindepth 1 -maxdepth 1 -type d | wc -l)
[ "$count" -eq 1 ] || {
  echo "expected exactly one directory under opt/, found $count" >&2
  exit 1
}
appdir=$(find stage/opt -mindepth 1 -maxdepth 1 -type d)

# Read the launcher name from the vendor's own desktop entry:
#   Exec=/opt/<App Dir>/<launcher> %U
desktop=$(find stage/usr/share/applications -name '*.desktop' | head -n 1)
[ -n "$desktop" ] || { echo "no .desktop in .deb" >&2; exit 1; }
launcher=$(sed -n 's/^Exec=//p' "$desktop" | head -n 1 \
           | sed 's/ %[A-Za-z]*$//; s/^"//; s/"$//' | sed 's:.*/::')
[ -n "$launcher" ] || { echo "could not read launcher name from $desktop" >&2; exit 1; }
[ -x "$appdir/$launcher" ] || {
  echo "launcher '$launcher' not executable in $appdir" >&2
  exit 1
}
[ -f "$appdir/resources/nix/bin/exiftool" ] || {
  echo "resources/nix/bin/exiftool missing in $appdir" >&2
  exit 1
}

# Debian installs the interpreter at usr/bin/perl and its core modules under
# usr/lib/<multiarch>/perl-base. The multiarch directory is found, not assumed.
[ -x perl-stage/usr/bin/perl ] || { echo "usr/bin/perl missing in perl-base.deb" >&2; exit 1; }
perllib=$(find perl-stage/usr/lib -mindepth 2 -maxdepth 2 -type d -name perl-base | head -n 1)
[ -n "$perllib" ] && [ -f "$perllib/strict.pm" ] || {
  echo "perl-base module tree not found in perl-base.deb" >&2
  exit 1
}

mv "$appdir" app
ln -sf "$launcher" app/launch
mkdir -p perl/bin
mv perl-stage/usr/bin/perl perl/bin/perl
mv "$perllib" perl/lib
rm -rf stage perl-stage app.deb perl-base.deb
[ -x app/launch ] || { echo "launcher missing after stage" >&2; exit 1; }
[ -x perl/bin/perl ] || { echo "perl missing after stage" >&2; exit 1; }
