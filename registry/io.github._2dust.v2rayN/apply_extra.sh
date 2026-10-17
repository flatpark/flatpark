#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream's .deb
# holds the whole app under /opt/v2rayN: the self-contained .NET apphost and
# its assemblies, the SkiaSharp/HarfBuzzSharp native libraries, and bin/ with
# the Xray and sing-box cores and the geo rule sets. That directory is staged
# whole at /app/extra/v2rayn, unmodified. The deb's /usr/bin launcher and
# desktop entry are not used; the manifest ships its own at build time.
#
# The unpack below is a pipeline; enable pipefail where the shell has it so a
# failed first bsdtar cannot leave a partial tree.
# shellcheck disable=SC3040
(set -o pipefail) 2>/dev/null && set -o pipefail || true

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f app.deb ] || { echo "missing extra-data: app.deb" >&2; exit 1; }

rm -rf stage v2rayn
mkdir stage
# The Platform runtime has no ar/dpkg, but bsdtar reads the .deb's ar container.
# --no-same-owner: a system-wide apply_extra runs as root with every capability
# dropped and cannot restore the archive's ownership.
bsdtar -xOf app.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

[ -x stage/opt/v2rayN/v2rayN ] || { echo "v2rayN apphost missing from the .deb" >&2; exit 1; }
[ -x stage/opt/v2rayN/bin/xray/xray ] || { echo "Xray core missing from the .deb" >&2; exit 1; }
mv stage/opt/v2rayN v2rayn
rm -rf stage app.deb
