#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package is a plain FHS tree whose payload is a single self-contained Tauri
# binary (usr/bin/<name>; the React frontend is embedded in the binary). We keep
# only that binary, at the stable path the wrapper expects: /app/extra/leepanel.
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak has to export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f leepanel.deb ] || { echo "missing extra-data: leepanel.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage leepanel
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf leepanel.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# Read the launcher name out of the package's own desktop entry instead of
# hardcoding it: pin refreshes are automated, and a renamed binary would
# otherwise ship an app that installs but cannot start.
desktop="$(find stage/usr/share/applications -maxdepth 1 -name '*.desktop' | head -n1)"
[ -n "$desktop" ] || { echo "no .desktop in the upstream package" >&2; exit 1; }
exe="$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' "$desktop" | head -n1)"
exe="$(basename "${exe:-leepanel}")"
[ -x "stage/usr/bin/$exe" ] || { echo "launcher not found in .deb: usr/bin/$exe" >&2; exit 1; }

mv "stage/usr/bin/$exe" leepanel
rm -rf stage leepanel.deb
chmod +x leepanel
