#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Five files have
# already been fetched here by extra-data: upstream's AppImage, the two-tool
# stack that opens it, and the two clipboard helpers Mark Shot looks for on
# PATH (plus xclip's one extra library). The vendor's bytes run unmodified -
# nothing is patched or recompiled, and the AppImage is never executed.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time - extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in mark-shot.AppImage appimage-tools.tar.xz wl-clipboard.deb xclip.deb libxmu6.deb; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done

rm -rf stage tools usr squashfs-root appimage-tools

# --no-same-owner throughout: on a system-wide install Flatpak runs apply_extra
# as root with every capability dropped, so restoring an archive's recorded
# uid/gid fails and aborts the unpack even though every member extracted fine.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools_bin="$extra_root/appimage-tools/bin"
[ -x "$tools_bin/appimage-offset" ] && [ -x "$tools_bin/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

# A type-2 AppImage is an ELF stub with a SquashFS appended to it: ask where
# that starts, then unpack from the offset. No libfuse, no mounting.
offset="$("$tools_bin/appimage-offset" mark-shot.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac
"$tools_bin/unsquashfs" -q -no-xattrs -d squashfs-root -o "$offset" mark-shot.AppImage >/dev/null

# Keep the AppDir's usr tree whole. The launcher finds its bundled Qt, FFmpeg
# and translation plugins through its own RUNPATH ($ORIGIN/../lib) and its
# qt.conf (Prefix=../, Plugins=plugins), and the app looks for its provider
# plugins at <exe>/../lib/mark-shot/plugins - all of which only resolve while
# usr/bin, usr/lib and usr/plugins stay siblings. Nothing here is put on the
# app's LD_LIBRARY_PATH, so the bundle's libraries can never shadow the
# runtime's for anything else.
[ -x squashfs-root/usr/bin/mark-shot ] || { echo "no usr/bin/mark-shot in the AppImage" >&2; exit 1; }
mv squashfs-root/usr usr

# The bundle keeps its provider plugins under the Debian multiarch directory
# (usr/lib/x86_64-linux-gnu/mark-shot/plugins) while the app searches
# <exe>/../lib/mark-shot/plugins, so point one at the other. A symlink, added
# next to the tree rather than inside it: not one byte of the vendor payload is
# touched, and plugins the user installs later still land in their own
# directory under ~/.var/app, which the app searches first.
if [ -d usr/lib/x86_64-linux-gnu/mark-shot ] && [ ! -e usr/lib/mark-shot ]; then
    ln -s x86_64-linux-gnu/mark-shot usr/lib/mark-shot
fi

# The clipboard helpers get a prefix of their own; the wrapper puts tools/bin
# on PATH and keeps their one private library out of any global search path.
mkdir -p stage tools/bin tools/lib
for deb in wl-clipboard.deb xclip.deb libxmu6.deb; do
    # The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the
    # .deb ar container directly; pipe its data member into a second bsdtar.
    bsdtar -xOf "$deb" 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
done
for tool in wl-copy wl-paste; do
    [ -x "stage/usr/bin/$tool" ] || { echo "$tool not found in wl-clipboard.deb" >&2; exit 1; }
    cp -a "stage/usr/bin/$tool" tools/bin/
done
[ -x stage/usr/bin/xclip ] || { echo "xclip not found in xclip.deb" >&2; exit 1; }
cp -a stage/usr/bin/xclip tools/bin/xclip.bin
# -a, and the -e test, because the loader looks up the SONAME link
# (libXmu.so.6 -> libXmu.so.6.2.0), not the regular file behind it.
find stage/usr/lib -maxdepth 3 \( -type f -o -type l \) -name 'libXmu.so.*' \
    -exec cp -a {} tools/lib/ \;
[ -e tools/lib/libXmu.so.6 ] || { echo "libXmu.so.6 not found in libxmu6.deb" >&2; exit 1; }

# xclip is the only staged binary needing a library from outside the runtime,
# so it carries its search path in a wrapper of its own.
cat > tools/bin/xclip <<'WRAP'
#!/bin/sh
LD_LIBRARY_PATH="/app/extra/tools/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    exec /app/extra/tools/bin/xclip.bin "$@"
WRAP
chmod +x tools/bin/xclip

rm -rf stage squashfs-root appimage-tools \
    mark-shot.AppImage appimage-tools.tar.xz wl-clipboard.deb xclip.deb libxmu6.deb
