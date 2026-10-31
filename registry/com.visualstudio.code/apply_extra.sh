#!/bin/sh
set -eu

# Runs offline at install time inside the runtime. Microsoft's .deb installs
# VS Code under /usr/share/code; keep that tree at the stable path the wrapper
# executes, /app/extra/vscode. host-spawn is upstream's static binary and goes
# to /app/extra/bin, which the wrapper puts on PATH.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in code.deb host-spawn; do
  [ -f "$f" ] || {
    echo "missing extra-data: $f" >&2
    exit 1
  }
done

rm -rf stage vscode bin
mkdir stage bin
# The runtime has no ar/dpkg, but bsdtar reads the .deb's ar container directly.
# --no-same-owner: on a system-wide install apply_extra runs as root with every
# capability dropped, so restoring the recorded uid/gid would abort the unpack.
bsdtar -xOf code.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

mv stage/usr/share/code vscode
for f in vscode/code vscode/resources/app/out/cli.js; do
  [ -e "$f" ] || {
    echo "$f missing after unpack: upstream layout changed" >&2
    exit 1
  }
done

mv host-spawn bin/host-spawn
chmod 755 bin/host-spawn

rm -rf stage code.deb
