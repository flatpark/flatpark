#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream's
# ToDesktop build ships the same Electron tree as a .deb and an AppImage; the
# .deb is smaller and needs no extractor. Its whole app lives under
# "opt/Comfy Desktop" (Electron launcher, resources/app.asar, the bundled
# bootstrap Python). Keep that directory at a stable path: /app/extra/app.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f app.deb ] || { echo "missing extra-data: app.deb" >&2; exit 1; }

rm -rf stage app launcher
mkdir stage
# The runtime has no ar/dpkg; bsdtar reads the .deb's ar container directly.
# --no-same-owner: a system-wide install runs this as root with no capabilities.
bsdtar -xOf app.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# The .deb has no /usr/bin link (postinst makes it), so take the app directory
# and launcher from its desktop entry, which electron-builder writes as
#   Exec=/bin/sh -c '"/opt/Comfy Desktop/comfyui-desktop-2" ...'
# Upstream can rename either (productName, executableName); reading them here
# keeps an automated pin refresh from failing on a rename.
exe="$(sed -n 's|^Exec=.*"/opt/\([^"]*\)".*|\1|p' stage/usr/share/applications/*.desktop 2>/dev/null | head -n1)"
appdir="${exe%/*}"
name="${exe##*/}"
case "$appdir" in ''|*/*) echo "cannot read the app directory from the .deb's desktop entry: '$exe'" >&2; exit 1 ;; esac
[ -n "$name" ] && [ -x "stage/opt/$appdir/$name" ] \
    || { echo "launcher '$exe' from the desktop entry not executable in .deb" >&2; exit 1; }
[ -f "stage/opt/$appdir/resources/app.asar" ] || { echo "resources/app.asar missing in .deb" >&2; exit 1; }

# The app provisions ComfyUI environments with these; a layout without them
# would install but not work.
for tool in python3 uv; do
    [ -x "stage/opt/$appdir/resources/bootstrap-python/bin/$tool" ] \
        || { echo "bootstrap $tool missing in .deb" >&2; exit 1; }
done

mv "stage/opt/$appdir" app
# Debian packages may record chrome-sandbox setuid; never leave one behind.
chmod -R a-s app
# Read by the wrapper; beside the app tree so the vendor's tree stays as shipped.
printf '%s\n' "$name" > launcher
rm -rf stage app.deb
