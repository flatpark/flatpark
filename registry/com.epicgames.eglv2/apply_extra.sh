#!/bin/sh
set -eu

# The unpack below is a pipeline. Enable pipefail when the runtime shell supports
# it so a failure in either bsdtar process cannot leave a partial installation.
# shellcheck disable=SC3040
(set -o pipefail) 2> /dev/null && set -o pipefail || true

# Runs offline at install time inside org.gnome.Platform. Since 0.111.0 Epic
# ships its Linux launcher (a Tauri app) only as a .deb: a plain FHS tree with
# the binary in usr/bin and libEOSSDK plus resources/ in
# usr/lib/epic-games-launcher, linking against the system's WebKitGTK 4.1 and
# GTK 3 (both in the GNOME runtime). The usr/ tree is kept as shipped at
# /app/extra/epic, because the binary finds libEOSSDK and its resources through
# its RUNPATH $ORIGIN/../lib/epic-games-launcher.
LC_ALL=C
export LC_ALL

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f epic.deb ] || { echo "missing extra-data: epic.deb" >&2; exit 1; }

rm -rf epic
mkdir epic
# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, so restoring an archive's owner would fail.
bsdtar -xOf epic.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C epic

# The wrapper execs the binary the vendor's desktop file names. Fail here, not
# at launch, if a release changes that layout.
exe="$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' epic/usr/share/applications/*.desktop | head -n1)"
[ "$exe" = EpicGamesLauncher ] && [ -x epic/usr/bin/EpicGamesLauncher ] \
    || { echo "launcher '$exe' named by the .deb's desktop file is not usr/bin/EpicGamesLauncher" >&2; exit 1; }
[ -f epic/usr/lib/epic-games-launcher/libEOSSDK-Linux-Shipping.so ] \
    || { echo "libEOSSDK-Linux-Shipping.so missing from usr/lib/epic-games-launcher" >&2; exit 1; }

rm -f epic.deb
