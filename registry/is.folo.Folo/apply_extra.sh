#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# Folo's Linux build as an electron-builder .deb: a plain FHS tree with the
# whole app under /usr/lib/folo (the Chromium launcher "Folo",
# resources/app.asar, its .pak resources, the bundled
# libffmpeg/libEGL/libGLESv2/SwiftShader) plus /usr/bin/folo -> ../lib/folo/Folo
# and an icon and .desktop. Unpack the .deb's data member and keep just the app
# directory at a stable path the wrapper execs: /app/extra/folo. The directory
# keeps its contents exactly as shipped. The desktop file, icon and AppStream
# metainfo are shipped by the manifest at *build* time — extra-data is fetched
# later on the user's machine, so anything Flatpak must export cannot come from
# here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f folo.deb ] || { echo "missing extra-data: folo.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar.zst compression is auto-detected).
rm -rf stage folo
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf folo.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# Which file is the launcher, and what directory is it in? electron-builder
# always drops /usr/bin/<pkg> as a relative symlink into the app tree:
#
#   usr/bin/folo -> ../lib/folo/Folo
#
# so the app directory and the launcher's real name (productName, "Folo", which
# upstream could change) both fall out of that link. Reading them from the
# payload rather than hardcoding survives the next rename — pin refreshes are
# automated, and a rename would otherwise reach users as a failed install
# (com.tldraw.Offline hit exactly that, issue #130). The launcher itself is
# located by glob rather than by name: it is named after the Debian package,
# which is upstream's to change just as much.
link=""
for f in stage/usr/bin/*; do
    [ -L "$f" ] || continue
    link="$(readlink "$f")"
    break
done
[ -n "$link" ] || { echo "no launcher symlink in the .deb's /usr/bin to resolve the app dir from" >&2; exit 1; }
appdir="stage/usr/lib/$(basename "$(dirname "$link")")"
launcher="$(basename "$link")"
[ -d "$appdir" ] || { echo "app directory from the launcher symlink not found in .deb: $appdir" >&2; exit 1; }
[ -x "$appdir/$launcher" ] || { echo "launcher '$launcher' from the symlink not executable in .deb" >&2; exit 1; }
[ -f "$appdir/resources/app.asar" ] || { echo "resources/app.asar missing in .deb app dir" >&2; exit 1; }

mv "$appdir" folo
# The wrapper reads the resolved name from here rather than hardcoding it. It
# lives beside the app tree, not inside it, so the upstream tree stays as
# shipped.
printf '%s\n' "$launcher" > launcher
rm -rf stage folo.deb
[ -x "folo/$launcher" ] || { echo "Folo launcher missing after stage" >&2; exit 1; }
