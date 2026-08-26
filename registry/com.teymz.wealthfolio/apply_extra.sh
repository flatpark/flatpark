#!/bin/sh
set -eu

# The unpack below is a pipeline. Enable pipefail when the runtime shell supports
# it so a failure in either bsdtar process cannot leave a partial installation.
# shellcheck disable=SC3040
(set -o pipefail) 2> /dev/null && set -o pipefail || true

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package is a plain FHS tree whose payload is one self-contained Tauri binary
# (usr/bin/Wealthfolio, with the frontend and SQLite embedded). Keep only that
# binary, at the stable path the wrapper execs: /app/extra/wealthfolio.
# The desktop file, icon and AppStream metainfo are installed by the manifest at
# build time because extra-data is fetched later on the user's machine.
LC_ALL=C
export LC_ALL

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f wealthfolio.deb ] || {
  echo "missing extra-data: wealthfolio.deb" >&2
  exit 1
}

# org.gnome.Platform has no ar/dpkg, but bsdtar reads the .deb ar container;
# pipe its data member into a second bsdtar for the inner archive.
rm -rf stage wealthfolio
mkdir stage
# --no-same-owner is required because a system-wide apply_extra runs as root
# with all capabilities dropped and cannot restore archive ownership.
bsdtar -xOf wealthfolio.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

[ -x stage/usr/bin/Wealthfolio ] || {
  echo "Wealthfolio binary not found in .deb" >&2
  exit 1
}

mv stage/usr/bin/Wealthfolio wealthfolio
rm -rf stage wealthfolio.deb
chmod +x wealthfolio
