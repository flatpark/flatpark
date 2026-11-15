#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream's official
# .deb carries a complete jpackage image under its install prefix: the native
# launcher in bin/, the app jars, its bundled Java runtime and native libraries
# in lib/. Keep that directory byte-for-byte at /app/extra/nuvio; the wrapper,
# desktop entry, icon and metainfo are installed by the manifest at build time.
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

archive=nuvio.deb
[ -f "$archive" ] || { echo "missing extra-data: $archive" >&2; exit 1; }

rm -rf stage nuvio launcher
mkdir stage
# The runtime has no ar/dpkg; bsdtar reads the .deb's ar container directly.
# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, so restoring recorded ownership would abort the unpack.
bsdtar -xOf "$archive" 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# The .deb's own desktop entry names the launcher (Exec=/opt/nuvio/bin/Nuvio).
# Read the prefix and launcher from it instead of hardcoding them: pin
# refreshes are automated, and a rename upstream would otherwise ship a release
# nobody can start.
entries=$(find stage/usr/share/applications -maxdepth 1 -name '*.desktop')
[ "$(printf '%s\n' "$entries" | grep -c .)" -eq 1 ] || { echo "expected exactly one desktop entry in the .deb" >&2; exit 1; }
exec_path=$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' "$entries" | head -n1)
case "$exec_path" in
  /opt/*/bin/*) ;;
  *) echo "unexpected launcher path in desktop entry: $exec_path" >&2; exit 1 ;;
esac
prefix="${exec_path%/bin/*}"
launcher="${exec_path##*/}"
case "${prefix#/opt/}" in */*|'') echo "unexpected install prefix: $prefix" >&2; exit 1 ;; esac

[ -x "stage$prefix/bin/$launcher" ] || { echo "launcher $exec_path not found in .deb" >&2; exit 1; }
[ -f "stage$prefix/lib/runtime/lib/server/libjvm.so" ] || { echo "bundled Java runtime not found in .deb" >&2; exit 1; }
ls "stage$prefix/lib/app/"*.cfg >/dev/null 2>&1 || { echo "jpackage app configuration not found in .deb" >&2; exit 1; }

mv "stage$prefix" nuvio
# Recorded for the wrapper, which cannot inspect the payload itself.
printf '%s\n' "$launcher" > launcher
rm -rf stage "$archive"
