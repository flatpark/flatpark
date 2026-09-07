#!/bin/sh
set -eu

# The unpack below is a pipeline risk only if extended; keep pipefail guarded
# so a failure cannot leave a partial installation.
# shellcheck disable=SC3040
(set -o pipefail) 2> /dev/null && set -o pipefail || true

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# Klipp as a .tar.gz holding one top-level directory with a prebuilt binary
# plus the desktop entry, AppStream metainfo, hicolor icons and fonts:
#
#   klipp-<version>/bin/klipp
#   klipp-<version>/share/{applications,metainfo,icons,klipp}
#
# Only the binary is staged (the desktop file, metainfo and icons are
# installed by the manifest at build time because extra-data is fetched
# later on the user's machine).
LC_ALL=C
export LC_ALL

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

archive="$(ls klipp-*-linux-x86_64.tar.gz 2>/dev/null | head -n 1 || true)"
[ -n "$archive" ] || {
  echo "missing extra-data: klipp-*-linux-x86_64.tar.gz" >&2
  exit 1
}

rm -rf stage bin
mkdir stage
# --no-same-owner is required because system-wide apply_extra runs as root with
# all capabilities dropped and cannot restore archive ownership.
bsdtar --no-same-owner -xf "$archive" -C stage

# Exactly one top-level directory, holding the prebuilt binary.
[ "$(ls stage | wc -l)" -eq 1 ] || {
  echo "expected one top-level directory in $archive" >&2
  exit 1
}
root="stage/$(ls stage)"
[ -x "$root/bin/klipp" ] || {
  echo "prebuilt launcher missing in $archive: bin/klipp" >&2
  exit 1
}

mv "$root/bin" bin
rm -rf stage "$archive"

[ -x bin/klipp ] || {
  echo "klipp launcher missing after stage" >&2
  exit 1
}
