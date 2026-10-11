#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# ZCode as an electron-builder .deb: a plain FHS tree with the whole app under
# /opt/ZCode (Chromium, app.asar, the bundled agent CLI and its ripgrep/ugrep/
# bfs helpers) plus icons and a .desktop file. Unpack the .deb data member and
# keep the app directory at /app/extra/ZCode, the stable path the wrapper execs.
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

deb="zcode.deb"
[ -f "$deb" ] || { echo "missing extra-data: $deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage ZCode
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf "$deb" 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# The launcher name is read out of the .deb's own desktop entry rather than
# hardcoded, so a rename upstream cannot ship a pin nobody can install. The
# Exec= line points at the absolute install path (/opt/ZCode/<launcher>).
desktop="$(ls stage/usr/share/applications/*.desktop 2>/dev/null | head -n 1 || true)"
[ -n "$desktop" ] || { echo "no desktop entry found in .deb" >&2; exit 1; }
exec_line="$(sed -n 's/^Exec=//p' "$desktop" | head -n 1)"
app_path="$(printf '%s\n' "$exec_line" | awk '{print $1}')"
app_dir="$(dirname "$app_path")"
launcher="$(basename "$app_path")"

[ -x "stage$app_dir/$launcher" ] || { echo "ZCode binary not found in .deb: $app_path" >&2; exit 1; }
mv "stage$app_dir" ZCode
rm -rf stage "$deb"
[ -x "ZCode/$launcher" ] || { echo "ZCode binary missing after stage" >&2; exit 1; }

# Record the launcher name for the wrapper, which cannot read the .deb itself.
printf '%s\n' "$launcher" > zcode-launcher
