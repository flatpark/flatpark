#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# tldraw office (formerly tldraw offline) as an electron-builder .deb: a plain
# FHS tree with the whole app under /opt (the Chromium launcher, its .pak
# resources, libffmpeg/ANGLE/SwiftShader and the bundled SDK type stubs) plus
# icons, a .desktop and a shared-mime-info file. Unpack the .deb's data member and keep
# just the app directory at a stable, space-free path the wrapper execs:
# /app/extra/tldraw-offline. The directory is renamed but its contents are
# untouched — the launcher keeps its upstream name. The desktop file, icons,
# MIME definition and AppStream metainfo are shipped by the manifest at *build*
# time — extra-data is fetched later on the user's machine, so anything Flatpak
# must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f tldraw-offline.deb ] || { echo "missing extra-data: tldraw-offline.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage tldraw-offline
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf tldraw-offline.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# Which file is the launcher, and which directory holds the app? Read both out of
# the .desktop file upstream ships in the same .deb, whose Exec is an absolute
# path into the app directory:
#
#   Exec="/opt/tldraw office/tldraw-offline" %U
#
# Neither is hardcoded because upstream has renamed both: v1.11.0 shipped the
# launcher as `@tldesktop`, v1.12.0 renamed it to `tldraw-offline`, and because
# pin refreshes are automated that rename reached users as `apply_extra script
# failed, exit status 256` (issue #130). v1.24.0 then renamed the product to
# "tldraw office", moving the tree from "/opt/tldraw offline" to
# "/opt/tldraw office" (the launcher and .desktop names were kept). There is
# exactly one .desktop in the .deb; take it whatever it is called.
set -- stage/usr/share/applications/*.desktop
[ "$#" -eq 1 ] && [ -f "$1" ] \
    || { echo "expected exactly one .desktop file in .deb to resolve the launcher from" >&2; exit 1; }
exec_path="$(sed -n 's/^Exec=//p' "$1" | head -n1 \
    | sed -e 's/[[:space:]]*%[a-zA-Z].*$//' -e 's/^"//' -e 's/"$//')"
case "$exec_path" in
    /opt/?*/?*) ;;
    *) echo "unexpected Exec= path in the .deb's .desktop file: $exec_path" >&2; exit 1 ;;
esac
launcher="${exec_path##*/}"
app_dir="stage${exec_path%/*}"
[ -d "$app_dir" ] || { echo "app directory not found in .deb: ${exec_path%/*}" >&2; exit 1; }
[ -x "$app_dir/$launcher" ] \
    || { echo "launcher from Exec= not executable in .deb: $exec_path" >&2; exit 1; }

mv "$app_dir" tldraw-offline
# The wrapper reads the resolved name from here rather than hardcoding it. It
# lives beside the app tree, not inside it, so the upstream tree stays as
# shipped.
printf '%s\n' "$launcher" > launcher
rm -rf stage tldraw-offline.deb
[ -x "tldraw-offline/$launcher" ] || { echo "tldraw offline launcher missing after stage" >&2; exit 1; }
