#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# Voiden as an electron-forge .deb: the whole app under /usr/lib/voiden (the
# Chromium binary, app.asar plus app.asar.unpacked with node-pty, and the
# bundled plugins under resources/) and /usr/bin/voiden as a relative symlink to
# it. Unpack the .deb's data member and keep just the app directory at a stable
# path the wrapper execs: /app/extra/voiden.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f voiden.deb ] || { echo "missing extra-data: voiden.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage voiden
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf voiden.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# Don't hardcode the launcher: follow the package's own /usr/bin/voiden symlink
# (the name its .desktop Exec= runs) to the real binary. A rename between
# releases then changes only where the symlink points — the com.tldraw.Offline
# lesson (flatpark#130). The target looks like ../lib/voiden/Voiden.
target="$(readlink stage/usr/bin/voiden 2>/dev/null || true)"
[ -n "$target" ] || { echo "no usr/bin/voiden symlink in the .deb" >&2; exit 1; }
app_dir="stage/usr/bin/${target%/*}"
launcher="${target##*/}"
[ -x "$app_dir/$launcher" ] || { echo "launcher $target not found in the .deb" >&2; exit 1; }

mv "$app_dir" voiden
rm -rf stage voiden.deb

# chrome-sandbox is the setuid helper for a host install; inside Flatpak zypak
# takes its place and a setuid bit cannot survive an extra-data unpack anyway.
rm -f voiden/chrome-sandbox

# The wrapper execs a stable name; link it to whatever the package pointed at.
[ "$launcher" = voiden ] || ln -sf "$launcher" voiden/voiden
[ -x voiden/voiden ] || { echo "voiden launcher missing after stage" >&2; exit 1; }
