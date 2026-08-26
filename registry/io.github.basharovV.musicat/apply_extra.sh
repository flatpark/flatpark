#!/bin/sh
set -eu

# The unpack below is a pipeline. Enable pipefail when the runtime shell supports
# it so a failure in either bsdtar process cannot leave a partial installation.
# shellcheck disable=SC3040
(set -o pipefail) 2> /dev/null && set -o pipefail || true

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package is an FHS tree with three parts that belong together:
#
#   usr/bin/Musicat                     the Tauri binary
#   usr/bin/pvr                         a Tauri sidecar (vocal remover), which
#                                       Tauri resolves next to the main binary
#   usr/lib/Musicat/resources/          Tauri resources, which Tauri resolves as
#                                       <dir of the binary>/../lib/<product name>
#
# So the tree is kept whole under /app/extra/usr and the wrapper execs
# /app/extra/usr/bin/Musicat — flattening it to a single binary would break both
# the sidecar and the resource lookup. The desktop file, icon and AppStream
# metainfo come from the manifest at *build* time, because extra-data is fetched
# later on the user's machine, so usr/share is dropped here.
LC_ALL=C
export LC_ALL

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f musicat.deb ] || {
  echo "missing extra-data: musicat.deb" >&2
  exit 1
}

# org.gnome.Platform has no ar/dpkg, but bsdtar reads the .deb ar container;
# pipe its data member into a second bsdtar for the inner archive.
rm -rf usr
# --no-same-owner is required because a system-wide apply_extra runs as root
# with all capabilities dropped and cannot restore archive ownership.
bsdtar -xOf musicat.deb 'data.tar*' | bsdtar --no-same-owner -xf -

[ -x usr/bin/Musicat ] || {
  echo "Musicat binary not found in .deb" >&2
  exit 1
}
[ -x usr/bin/pvr ] || {
  echo "pvr sidecar not found in .deb" >&2
  exit 1
}
[ -d usr/lib/Musicat/resources ] || {
  echo "Musicat resources not found in .deb" >&2
  exit 1
}

rm -rf usr/share
rm -f musicat.deb
