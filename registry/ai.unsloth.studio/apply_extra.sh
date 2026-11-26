#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream's Ubuntu
# package has a launcher in usr/bin and its bundled install.sh in
# usr/lib/Unsloth; Tauri finds that resource at ../lib/Unsloth from the
# executable. Keep that relative layout under a fixed /app/extra/app.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f app.deb ] || { echo "missing extra-data: app.deb" >&2; exit 1; }

rm -rf stage app
mkdir stage
# The runtime has no ar/dpkg; bsdtar reads the .deb's ar container directly.
# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, so restoring the archive's uid would abort it.
bsdtar -xOf app.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# Read the launcher from the package's own desktop entry. Upstream can rename
# it between releases; an automated pin refresh must not fail on that.
launcher="$(sed -n 's|^Exec=\([^ %]*\).*|\1|p' stage/usr/share/applications/*.desktop 2>/dev/null | head -n1)"
case "$launcher" in
    ''|*/*) echo "cannot read the launcher from the .deb's desktop entry: '$launcher'" >&2; exit 1 ;;
esac
[ -x "stage/usr/bin/$launcher" ] || { echo "launcher '$launcher' not executable in .deb" >&2; exit 1; }

resources="$(find stage/usr/lib -mindepth 1 -maxdepth 2 -type f -name install.sh 2>/dev/null | head -n1)"
[ -n "$resources" ] || { echo "bundled install.sh missing in .deb" >&2; exit 1; }

mkdir app
mv stage/usr/bin stage/usr/lib stage/usr/share app/
chmod -R a-s app

[ -x "app/bin/$launcher" ] || { echo "launcher missing after unpacking" >&2; exit 1; }
# Read by the wrapper, so an upstream rename of the binary needs no wrapper edit.
printf '%s\n' "$launcher" > launcher
[ -f "app/lib/Unsloth/install.sh" ] || { echo "install.sh not at the Tauri resource path" >&2; exit 1; }

rm -rf stage app.deb
