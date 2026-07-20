#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# THS as a Kylin .deb laying the app out under /opt/apps/cn.com.10jqka in the
# deepin/Kylin store convention: entries/ holds the desktop entry and icon,
# files/ holds the application itself. Only files/ is staged here; FlatPark
# ships its own desktop entry, icon and AppStream metadata.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f ths.deb ] || { echo "missing extra-data: ths.deb" >&2; exit 1; }

rm -rf stage ths
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf ths.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/opt/apps/cn.com.10jqka/files/HevoNext.B2CApp ] || {
    echo "THS binary not found in .deb" >&2
    exit 1
}
mv stage/opt/apps/cn.com.10jqka/files ths
rm -rf stage ths.deb
[ -x ths/HevoNext.B2CApp ] || { echo "THS binary missing after stage" >&2; exit 1; }

# The .deb carries a Debian changelog/copyright tree that is meaningless here.
rm -rf ths/doc

# The setuid Chromium sandbox helper cannot be setuid inside a Flatpak and is
# never used: the wrapper starts CEF with --no-sandbox and relies on the Flatpak
# sandbox as the boundary instead.
rm -f ths/cef/Release/chrome-sandbox

# Note: libcoreclrtraceptprovider.so must be kept even though its liblttng-ust
# dependency is absent from the runtime. It is listed in HevoNext.B2CApp.deps.json,
# and the host resolves every listed asset before startup, so deleting it aborts
# the app outright. Left in place it is simply never loaded.

# The app expects to write logs and its resolver/quote working state next to
# itself, which is read-only here. Redirect those into the per-app data dir.
# hevoConfig ships defaults, so it is kept as a template the wrapper seeds from.
if [ -d ths/hevoConfig ]; then
    mv ths/hevoConfig ths/hevoConfig.dist
fi
if [ -d ths/workspace ]; then
    mv ths/workspace ths/workspace.dist
fi

for dir in hevoLog hevoConfig workspace; do
    rm -rf "ths/$dir"
    ln -s "/var/data/THS/$dir" "ths/$dir"
done
