#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream's .deb
# is a jpackage bundle under /opt/FalconPDF: bin/FalconPDF (the native
# launcher), lib/app (jars + FalconPDF.cfg), lib/runtime (a jlink'd Java
# runtime) and a small `falconpdf` shell launcher that the .desktop Exec= runs.
# The launcher finds lib/app/*.cfg relative to itself, so the tree is staged
# whole at /app/extra/falconpdf.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f falconpdf.deb ] || { echo "missing extra-data: falconpdf.deb" >&2; exit 1; }

rm -rf stage falconpdf
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf falconpdf.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# Read the launcher out of the package's own .desktop Exec= (an absolute
# /opt/<Name>/<launcher> path) rather than hardcoding it (flatpark#130).
desktop="$(ls stage/usr/share/applications/*.desktop 2>/dev/null | head -n1)"
[ -n "$desktop" ] || { echo "no .desktop in the .deb" >&2; exit 1; }
exec_path="$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' "$desktop" | head -n1)"
app_dir="stage${exec_path%/*}"
launcher="${exec_path##*/}"
[ -x "$app_dir/$launcher" ] || { echo "launcher $exec_path not found in the .deb" >&2; exit 1; }
[ -f "$app_dir/lib/runtime/lib/server/libjvm.so" ] || { echo "no bundled Java runtime in the .deb" >&2; exit 1; }

mv "$app_dir" falconpdf
rm -rf stage falconpdf.deb
[ "$launcher" = falconpdf ] || ln -sf "$launcher" falconpdf/falconpdf
[ -x falconpdf/falconpdf ] || { echo "falconpdf launcher missing after stage" >&2; exit 1; }
