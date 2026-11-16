#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream's Linux
# download is an electron-builder AppImage, unpacked here without running it: a
# type-2 AppImage is an ELF stub with a SquashFS appended, and the two tools
# from the appimage-tools extra-data find where it starts and unpack it.
#
# The result is the AppDir, staged whole at /app/extra/couchtunes: the Electron
# launcher, resources/app.asar, the .pak/.dat resources and the bundled
# ffmpeg/SwiftShader.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in couchtunes.AppImage appimage-tools.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
rm -rf couchtunes appimage-tools launcher

# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring an archive's recorded owner would
# fail. unsquashfs never chowns, and -no-xattrs keeps it from trying to set
# xattrs the sandbox doesn't allow.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" couchtunes.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac
"$tools/unsquashfs" -q -no-xattrs -o "$offset" -d couchtunes couchtunes.AppImage >/dev/null

# Which file is the Electron launcher? electron-builder names it after
# executableName, which upstream can change between releases, and pin
# refreshes are merged without a human (a hardcoded name broke installs of
# com.tldraw.Offline, issue #130). The AppDir's own AppRun names it:
#
#   BIN="$APPDIR/couchtunes"
#
# Some electron-builder versions put a shell shim there with the real ELF
# beside it as "<name>.bin"; prefer that, so zypak wraps Chromium itself.
[ -f couchtunes/AppRun ] || { echo "AppRun missing from the AppDir" >&2; exit 1; }
name="$(sed -n 's|^BIN="\$APPDIR/\([^"]*\)".*|\1|p' couchtunes/AppRun | head -n1)"
[ -n "$name" ] || { echo "could not read the launcher name from the AppDir's AppRun" >&2; exit 1; }
if [ -x "couchtunes/$name.bin" ]; then
    launcher="$name.bin"
elif [ -x "couchtunes/$name" ]; then
    launcher="$name"
else
    echo "launcher '$name' from AppRun not executable in the AppDir" >&2
    exit 1
fi
[ -f couchtunes/resources/app.asar ] || { echo "resources/app.asar missing in the AppDir" >&2; exit 1; }

# The wrapper reads the resolved name from here. It sits beside the app tree,
# not inside it, so the upstream tree stays as shipped.
printf '%s\n' "$launcher" > launcher

# Drop the AppImage and the extractor now that the tree is staged; otherwise
# both stay on the user's disk for the life of the install.
rm -rf couchtunes.AppImage appimage-tools.tar.xz appimage-tools
