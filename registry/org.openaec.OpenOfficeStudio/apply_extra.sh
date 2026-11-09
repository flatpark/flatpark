#!/bin/sh
set -eu

# The unpack below is a pipeline. Enable pipefail when the runtime shell supports
# it so a failure in either bsdtar process cannot leave a partial installation.
# shellcheck disable=SC3040
(set -o pipefail) 2> /dev/null && set -o pipefail || true

# Runs offline at install time. The upstream package is a Debian archive
# holding one self-contained binary, usr/bin/open-office-studio, plus its
# desktop file, icons and a shared-mime-info file; there is no usr/lib
# resource tree. The usr/ layout is kept anyway, as Tauri resolves resources
# relative to the executable.
#
# A symlink named after the app id is the entry point: its name becomes the
# program name and with it the window class, which the desktop file's
# StartupWMClass matches.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f open-office-studio.deb ] || { echo "missing extra-data: open-office-studio.deb" >&2; exit 1; }

rm -rf stage office
mkdir stage
# The Platform runtime has no ar/dpkg. bsdtar reads the .deb and the inner
# data.tar*. --no-same-owner: a system install runs apply_extra as root with
# every capability dropped.
bsdtar -xOf open-office-studio.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/usr/bin/open-office-studio ] || { echo "open-office-studio not found in .deb" >&2; exit 1; }

mkdir office
mv stage/usr office/usr
ln -s open-office-studio office/usr/bin/org.openaec.OpenOfficeStudio
rm -rf stage open-office-studio.deb
