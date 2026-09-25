#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# PI-Desktop as an electron-builder .deb: the whole app under /opt/PI-Desktop
# (the Chromium launcher, app.asar, the bundled agent runtime, the Rust
# host-core binary, skills/plugins/models.dev) plus a .desktop entry and a
# 512px icon. Unpack the .deb's data member and keep the app directory at the
# stable path the wrapper execs: /app/extra/PI-Desktop. That directory name is
# ours, not upstream's — which file inside it launches the app is resolved from
# the payload below. The desktop file, icon and AppStream metainfo are shipped
# by the manifest at *build* time — extra-data is fetched later on the user's
# machine, so anything Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

deb="pi-desktop.deb"
[ -f "$deb" ] || { echo "missing extra-data: $deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage PI-Desktop
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf "$deb" 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# The launcher name is read out of the .deb's own desktop entry rather than
# hardcoded, so an upstream rename cannot refresh into a pin nobody can install
# (the #130 lesson). The Exec= line points at the absolute install path
# (/opt/PI-Desktop/<launcher>); strip the field codes and any quoting first.
desktop="$(ls stage/usr/share/applications/*.desktop 2>/dev/null | head -n 1 || true)"
[ -n "$desktop" ] || { echo "no desktop entry found in .deb" >&2; exit 1; }
exec_line="$(sed -n 's/^Exec=//p' "$desktop" | head -n 1 \
    | sed -e 's/[[:space:]]*%[a-zA-Z].*$//' -e 's/^"//' -e 's/"$//')"
[ -n "$exec_line" ] || { echo "no Exec= line in the .deb's .desktop file" >&2; exit 1; }
app_dir="$(dirname "$exec_line")"
launcher="$(basename "$exec_line")"
case "$app_dir" in
  */..|*/../*) echo "unexpected Exec= path in the .deb's .desktop file: $exec_line" >&2; exit 1 ;;
  /*) : ;;
  *) echo "unexpected Exec= path in the .deb's .desktop file: $exec_line" >&2; exit 1 ;;
esac

[ -x "stage$app_dir/$launcher" ] \
    || { echo "launcher from Exec= not executable in .deb: $app_dir/$launcher" >&2; exit 1; }

mv "stage$app_dir" PI-Desktop
rm -rf stage "$deb"
[ -x "PI-Desktop/$launcher" ] || { echo "launcher missing after stage: $launcher" >&2; exit 1; }

# Record the launcher name where the wrapper reads it — the wrapper cannot see
# the .deb itself. It lives beside the app tree, not inside it, so the upstream
# tree stays as shipped.
printf '%s\n' "$launcher" > launcher
