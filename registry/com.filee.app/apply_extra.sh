#!/bin/sh
set -eu
# The official portable tree includes .NET, native libraries and small engines.
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"
[ -f filee.tar.gz ] || { echo "missing extra-data: filee.tar.gz" >&2; exit 1; }
rm -rf stage filee
mkdir stage
bsdtar --no-same-owner -xf filee.tar.gz -C stage
top="$(find stage -mindepth 1 -maxdepth 1 -type d)"
[ "$(printf '%s\n' "$top" | wc -l)" -eq 1 ] && [ -n "$top" ] || {
    echo "expected one portable Filee directory" >&2; exit 1;
}
mv "$top" filee
# .NET's apphost and runtimeconfig share a name; exclude the separate CLI.
config="$(find filee -maxdepth 1 -name '*.runtimeconfig.json' ! -name '*cli*')"
[ "$(printf '%s\n' "$config" | wc -l)" -eq 1 ] && [ -n "$config" ] || {
    echo "expected one desktop runtimeconfig" >&2; exit 1;
}
launcher="${config%.runtimeconfig.json}"
[ -x "$launcher" ] && [ -x filee/filee-cli ] || {
    echo "desktop or CLI apphost missing from portable Filee" >&2; exit 1;
}
ln -s "${launcher#filee/}" filee/desktop-launcher
rm -rf stage filee.tar.gz
