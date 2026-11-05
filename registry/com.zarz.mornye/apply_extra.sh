#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream's
# official .deb keeps a complete, relocatable Flutter bundle under
# usr/lib/<name>: the launcher next to lib/ (the Flutter engine, plugins, the
# Rust core and a bundled FFmpeg) and data/ (icudtl.dat and flutter_assets).
# Keep that directory byte-for-byte at /app/extra/app; the wrapper, desktop
# entry, icon and metainfo are installed by the manifest at build time.
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

archive=mornye.deb
[ -f "$archive" ] || { echo "missing extra-data: $archive" >&2; exit 1; }

rm -rf stage app
mkdir stage
# The runtime has no ar/dpkg; bsdtar reads the .deb's ar container directly.
# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, so restoring recorded ownership would abort the unpack.
bsdtar -xOf "$archive" 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# The .deb's usr/bin/<name> symlink points at the launcher inside its bundle
# directory. Read both out of the package instead of hardcoding them: pin
# refreshes are automated, and a rename upstream would otherwise ship a release
# nobody can start.
links=$(find stage/usr/bin -maxdepth 1 -type l)
[ "$(printf '%s\n' "$links" | grep -c .)" -eq 1 ] || { echo "expected exactly one launcher symlink in usr/bin" >&2; exit 1; }
target=$(readlink "$links")
case "$target" in
  /usr/lib/*/*) rel="${target#/usr/lib/}" ;;
  ../lib/*/*) rel="${target#../lib/}" ;;
  *) echo "unexpected launcher symlink target: $target" >&2; exit 1 ;;
esac
bundle="${rel%%/*}"
launcher="${rel#*/}"
case "$launcher" in */*|'') echo "unexpected launcher path: $target" >&2; exit 1 ;; esac

[ -x "stage/usr/lib/$bundle/$launcher" ] || { echo "launcher $bundle/$launcher not found in .deb" >&2; exit 1; }
[ -d "stage/usr/lib/$bundle/data/flutter_assets" ] || { echo "Flutter assets not found in .deb" >&2; exit 1; }
[ -d "stage/usr/lib/$bundle/lib" ] || { echo "Flutter library directory not found in .deb" >&2; exit 1; }

mv "stage/usr/lib/$bundle" app
# Recorded for the wrapper, which cannot inspect the payload itself.
printf '%s\n' "$launcher" > launcher
rm -rf stage "$archive"
