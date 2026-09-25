#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. The CNJ's own
# Linux zip has already been fetched here by extra-data: the PJeOffice Pro jar,
# a bundled Java 8 runtime (Zulu, with JavaFX) and a static ffmpeg. The
# vendor's bytes run unmodified; nothing is patched.
#
# The desktop entry, icon and AppStream metainfo are shipped by the manifest at
# *build* time - extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f pjeoffice-pro.zip ] || { echo "missing extra-data: pjeoffice-pro.zip" >&2; exit 1; }

rm -rf stage pjeoffice-pro
mkdir stage

# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring an archive's recorded uid/gid
# fails and aborts the unpack even though every member extracted fine.
bsdtar --no-same-owner -xf pjeoffice-pro.zip -C stage

[ -d stage/pjeoffice-pro ] || { echo "pjeoffice-pro/ missing from the zip" >&2; exit 1; }
mv stage/pjeoffice-pro pjeoffice-pro
for f in pjeoffice-pro.jar jre/bin/java ffmpeg.exe; do
    [ -f "pjeoffice-pro/$f" ] || { echo "$f missing from the zip" >&2; exit 1; }
done

# The zip stores jre/bin/java without its execute bit; upstream's own launcher
# (pjeoffice-pro.sh) sets it with chmod 755 on every start, which a read-only
# /app/extra would not allow, so it is done once here instead. Same for
# ffmpeg.exe, a static Linux ffmpeg despite the name.
chmod 755 pjeoffice-pro/jre/bin/java pjeoffice-pro/ffmpeg.exe

rm -rf stage pjeoffice-pro.zip
