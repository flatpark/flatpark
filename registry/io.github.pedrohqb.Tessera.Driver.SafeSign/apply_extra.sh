#!/bin/sh
# SafeSign IC (A.E.T. Europe), for GD Burti and other SafeSign tokens.
#
# Runs offline at install time, in the extension's extra/ folder, after
# Flatpak has downloaded the vendor's packages and checked their sha256. The
# packages are unpacked the "clean" way distrobox-adv-br installs them: only
# their files are taken; no maintainer script runs, /etc is left out, and
# nothing is written outside this folder.
set -eu
# The install environment has no locale; without this every bsdtar call
# warns "Failed to set default locale".
export LC_ALL=C

# Where this folder is once installed (Tessera's extension point, see
# flatpak/io.github.pedrohqb.Tessera.yml): for the launcher, which runs
# from anywhere.
final=/app/lib/tessera/extensions/SafeSign/extra

log() { echo "SafeSign apply_extra: $*" >&2; }

# The data part of a .deb (the runtime has no dpkg/ar, but bsdtar reads the
# ar container). --no-same-owner: a system-wide install runs this as root
# with every capability dropped.
unpack_deb() { # deb dest
    mkdir -p "$2"
    bsdtar -xOf "$1" 'data.tar*' | bsdtar --no-same-owner -xf - -C "$2"
}

unpack_deb safesign.deb .
rm -rf etc
lib=$(find usr -name 'libaetpkss.so*' \( -type f -o -type l \) | sort | head -n1)
[ -n "$lib" ] || { log "libaetpkss.so not found in the package"; exit 1; }
ln -sf "$lib" libaetpkss.so

# GDBM for libaetpkss.so, which the runtime lacks (the AUR package depends
# on gdbm), from Ubuntu 24.04.
for g in gdbm.deb gdbm-compat.deb; do
    unpack_deb "$g" gdbm
done

# Token Administration: the vendor's RHEL 10 build, which needs no wxWidgets
# (the AUR package does the same). Without it, the tool is left out and the
# driver still works.
ta=""
if mkdir -p rpm && bsdtar --no-same-owner -xf safesign.rpm -C rpm; then
    ta=$(find rpm -type f -name tokenadmin | head -n1)
else
    log "could not unpack the rpm; Token Administration is left out"
fi
if [ -n "$ta" ]; then
    cat > tokenadmin <<LAUNCHER
#!/bin/sh
export LD_LIBRARY_PATH="$final/usr/lib:$final/gdbm/usr/lib/x86_64-linux-gnu\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
exec "$final/$ta" "\$@"
LAUNCHER
    chmod +x tokenadmin
fi

rm -f safesign.deb safesign.rpm gdbm.deb gdbm-compat.deb
test -e libaetpkss.so
