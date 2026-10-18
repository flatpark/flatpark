#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream's release
# tarball holds the whole inua desktop shell: one top-level directory with a
# dozen Go binaries (the shell, its CLI, the file manager, the games, the VM
# and remote-desktop managers ...) beside their desktop entries and session
# files. This package offers only the light apps on inua.lyric.im/apps.html,
# which run as `inua-apps <name>` and `inua-viewer`; the shell itself needs a
# login session of its own and cannot run from a sandbox. Every other binary
# is left out.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in inua.tar.gz poppler-glib.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done

rm -rf stage inua
mkdir stage
# --no-same-owner: on a system-wide install apply_extra runs as root with every
# capability dropped, so restoring the recorded runner uid/gid would fail.
bsdtar --no-same-owner -xf inua.tar.gz -C stage

# The top directory carries the arch (inua_linux_amd64); read it, don't name it.
top="$(find stage -mindepth 1 -maxdepth 1 -type d)"
[ -n "$top" ] && [ "$(printf '%s\n' "$top" | wc -l)" -eq 1 ] || { echo "expected one top-level directory in inua.tar.gz" >&2; exit 1; }

mkdir inua
for bin in inua-apps inua-viewer; do
    [ -f "$top/$bin" ] || { echo "$bin not found in inua.tar.gz" >&2; exit 1; }
    mv "$top/$bin" inua/
    chmod 755 "inua/$bin"
done
mv "$top/LICENSE" inua/ 2>/dev/null || true

rm -rf stage inua.tar.gz

# The prebuilt archive has one top-level poppler-glib/ directory holding lib/.
# inua-viewer renders PDFs with it.
rm -rf poppler-glib
bsdtar --no-same-owner -xf poppler-glib.tar.xz
[ -e poppler-glib/lib/libpoppler-glib.so.8 ] || { echo "libpoppler-glib.so.8 not found in poppler-glib.tar.xz" >&2; exit 1; }
rm -f poppler-glib.tar.xz
