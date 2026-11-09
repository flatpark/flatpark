#!/bin/sh
# SerproID (Serpro), the cloud certificate.
#
# Runs offline at install time, in the extension's extra/ folder, after
# Flatpak has downloaded the package and checked its sha256. As in
# distrobox-adv-br: the package's files only, no /etc, no maintainer
# scripts; the module is also offered as libneoidp11.so, the name some
# signers look for.
set -eu
export LC_ALL=C

final=/app/lib/tessera/extensions/SerproID/extra

log() { echo "SerproID apply_extra: $*" >&2; }

unpack_deb() { # deb dest
    mkdir -p "$2"
    bsdtar -xOf "$1" 'data.tar*' | bsdtar --no-same-owner -xf - -C "$2"
}

unpack_deb serproid.deb .
rm -rf etc serproid.deb

# The app's launcher script and configuration use absolute paths
# (cd /usr/share/serproid-desktop; ./jre/bin/java ...). Point the text files
# at this copy; binaries are left alone.
grep -rlI '/usr/share/serproid-desktop' usr 2>/dev/null | while read -r f; do
    sed -i "s|/usr/share/serproid-desktop|$final/usr/share/serproid-desktop|g" "$f"
done

lib=$(find usr -name 'libserproidp11.so' \( -type f -o -type l \) | sort | head -n1)
[ -n "$lib" ] || { log "libserproidp11.so not found in the package"; exit 1; }
ln -sf "$lib" libserproidp11.so
ln -sf "$(basename "$lib")" "$(dirname "$lib")/libneoidp11.so"

# The desktop app: take its Exec line and point it at this copy.
desktop=$(find usr -name 'serproid*.desktop' | sort | head -n1)
if [ -n "$desktop" ]; then
    exec_line=$(sed -n 's/^Exec=//p' "$desktop" | head -n1 | sed 's/ %[fFuU]//g')
    prog=${exec_line%% *}
    case "$prog" in
        /*) prog="$final$prog" ;;
        *) prog="$final/usr/bin/$prog" ;;
    esac
    cat > serproid <<LAUNCHER
#!/bin/sh
export LD_LIBRARY_PATH="$final/usr/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
exec "$prog" "\$@"
LAUNCHER
    chmod +x serproid
else
    log "the desktop file is not in the package; the SerproID app is left out"
fi
test -e libserproidp11.so
