#!/bin/sh
set -eu
# Flatpak runs this offline, with only the runtime and /app/extra available.
cd "${EXTRA_ROOT:-/app/extra}"
[ -f energyplus.tar.gz ] || { echo "missing energyplus.tar.gz" >&2; exit 1; }
rm -rf stage energyplus tcltk
mkdir stage tcltk
# A system install has uid 0 without permission to restore archive ownership.
bsdtar --no-same-owner -xf energyplus.tar.gz -C stage
top="$(find stage -mindepth 1 -maxdepth 1 -type d)"
[ -n "$top" ] && [ "$(printf '%s\n' "$top" | wc -l)" -eq 1 ] || {
    echo "expected one EnergyPlus directory" >&2; exit 1;
}
mv "$top" energyplus
for required in energyplus Energy+.idd python_lib/eplaunch/__main__.py; do
    [ -f "energyplus/$required" ] || { echo "missing EnergyPlus file: $required" >&2; exit 1; }
done
[ -x energyplus/energyplus ] || { echo "EnergyPlus executable missing" >&2; exit 1; }
# Hold an automatic update if its bundled scripts need different libraries.
grep -Eq '^package require -exact Tcl +8[.]6[.]14$' energyplus/python_lib/tcl8.6/init.tcl &&
grep -Eq '^package require -exact Tk +8[.]6[.]14$' energyplus/python_lib/tk8.6/tk.tcl || {
    echo "EnergyPlus Tcl/Tk scripts no longer match the pinned 8.6.14 libraries" >&2; exit 1;
}
# Keep Tcl/Tk libraries and their script data together, beside the vendor tree.
for package in libtcl8.6 libtk8.6; do
    [ -f "$package.deb" ] || { echo "missing $package.deb" >&2; exit 1; }
    bsdtar -xOf "$package.deb" 'data.tar*' | bsdtar --no-same-owner -xf - -C tcltk
done
[ -f tcltk/usr/lib/x86_64-linux-gnu/libtk8.6.so ]
[ -f tcltk/usr/lib/x86_64-linux-gnu/libtcl8.6.so ]
[ -f tcltk/usr/share/tcltk/tcl8.6/init.tcl ]
[ -f tcltk/usr/share/tcltk/tk8.6/tk.tcl ]
rm -rf stage energyplus.tar.gz libtcl8.6.deb libtk8.6.deb
