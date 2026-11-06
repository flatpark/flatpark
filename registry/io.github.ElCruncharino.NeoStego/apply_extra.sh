#!/bin/sh
set -eu

# Keep the official jpackage tree, including its Java runtime, intact.
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"
[ -f neostego.deb ] || { echo "missing extra-data: neostego.deb" >&2; exit 1; }
rm -rf stage neostego
mkdir stage
# System installs have uid 0 without capabilities: never restore ownership.
bsdtar -xOf neostego.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# Read the main launcher from upstream's desktop entry so renamed bundles fail
# during the unpack check rather than installing an unusable application.
set -- stage/opt/*/lib/*.desktop
[ "$#" -eq 1 ] && [ -f "$1" ] || { echo "expected one upstream desktop entry" >&2; exit 1; }
exec_path="$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' "$1" | head -n1)"
case "$exec_path" in
    /opt/*/bin/*) ;;
    *) echo "unexpected launcher path: $exec_path" >&2; exit 1 ;;
esac
app_dir="stage${exec_path%/bin/*}"
launcher="${exec_path##*/}"
[ -x "stage$exec_path" ] || { echo "launcher missing: $exec_path" >&2; exit 1; }
[ -f "$app_dir/lib/app/$launcher.cfg" ] || { echo "jpackage config missing" >&2; exit 1; }
[ -f "$app_dir/lib/runtime/lib/server/libjvm.so" ] || { echo "bundled Java runtime missing" >&2; exit 1; }
mv "$app_dir" neostego
# An external symlink gives the wrapper a stable name without changing the bundle.
ln -sfn "neostego/bin/$launcher" launcher
[ -x launcher ] || { echo "staged launcher missing" >&2; exit 1; }
rm -rf stage neostego.deb
