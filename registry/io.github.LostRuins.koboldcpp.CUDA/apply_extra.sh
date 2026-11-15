#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
# Upstream ships a single self-contained PyInstaller executable; keep it intact.
[ -s koboldcpp.bin ] || { echo 'missing extra-data: koboldcpp.bin' >&2; exit 1; }
# Reject an unexpected payload before handing it to the launcher.
[ "$(od -An -tx1 -N4 koboldcpp.bin | tr -d ' \n')" = 7f454c46 ] || {
    echo 'expected an upstream ELF executable' >&2; exit 1;
}
mv -f koboldcpp.bin koboldcpp
chmod 755 koboldcpp
