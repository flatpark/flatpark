#!/bin/sh
# Runs offline at install time, inside the runtime, after Flatpak has
# downloaded Tessera's release build and the vendors' driver packages
# (extra-data) and checked their sizes and sha256.
#
# Tessera's release build (tessera.tar.gz, the /app tree of Tessera's own
# Flatpak build) goes to /app/extra/tessera, unmodified. Without it there is
# no app, so a problem there is fatal.
#
# Each driver is unpacked into /app/extra/drivers/<id> the same "clean" way
# distrobox-adv-br installs them: only the package's files are taken; no
# maintainer script (postinst, postrm) ever runs, and nothing is written
# outside the driver's own directory. A driver that fails to unpack is
# skipped, not fatal: Tessera lists it as "driver files missing" and the
# others keep working.
set -u
# The install environment has no locale; without this every bsdtar call
# warns "Failed to set default locale".
export LC_ALL=C

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root" || exit 1
mkdir -p drivers

log() { echo "tessera apply_extra: $*" >&2; }

# --- Tessera ----------------------------------------------------------------
[ -f tessera.tar.gz ] || { log "missing extra-data: tessera.tar.gz"; exit 1; }
rm -rf tessera tessera-stage
mkdir tessera-stage
bsdtar --no-same-owner -xf tessera.tar.gz -C tessera-stage || { log "could not unpack tessera.tar.gz"; exit 1; }
[ -d tessera-stage/tessera ] || { log "tessera/ missing from tessera.tar.gz"; exit 1; }
mv tessera-stage/tessera tessera
rm -rf tessera-stage tessera.tar.gz
for f in bin/tessera lib/libpcsclite.so.1 lib/tessera/drivers/safesign/driver.toml \
         lib/tessera/drivers/safenet/driver.toml lib/tessera/drivers/serproid/driver.toml; do
    [ -e "tessera/$f" ] || { log "$f missing from tessera.tar.gz"; exit 1; }
done
# (tessera/bin/apply_extra, Tessera's own copy of the driver part below, and
# the tree's desktop file and metainfo are simply not used: the package
# ships its own.)

# Unpack the data part of a .deb (the runtime has no dpkg/ar, but bsdtar
# reads the ar container). --no-same-owner: a system-wide install runs this
# as root with every capability dropped.
unpack_deb() { # deb dest
    mkdir -p "$2"
    bsdtar -xOf "$1" 'data.tar*' | bsdtar --no-same-owner -xf - -C "$2"
}

# A launcher for a vendor tool: its own libraries first on the library path.
write_launcher() { # path exec-path libdir...
    out="$1"; shift
    target="$1"; shift
    libs=""
    for d in "$@"; do libs="${libs:+$libs:}$d"; done
    cat > "$out" <<EOF
#!/bin/sh
export LD_LIBRARY_PATH="$libs\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
exec "$target" "\$@"
EOF
    chmod +x "$out"
}

# --- SafeSign IC (A.E.T. Europe): GD Burti tokens -------------------------
if [ -f safesign.deb ]; then
    d=drivers/safesign
    rm -rf "$d"
    if unpack_deb safesign.deb "$d"; then
        lib=$(find "$d" -name 'libaetpkss.so*' \( -type f -o -type l \) | sort | head -n1)
        if [ -n "$lib" ]; then
            ln -sf "/app/extra/$lib" "$d/libaetpkss.so"
        else
            log "libaetpkss.so not found in the SafeSign package"
        fi
        rm -rf "$d/etc"
        # GDBM for libaetpkss.so (the AUR package depends on gdbm).
        for g in gdbm.deb gdbm-compat.deb; do
            [ -f "$g" ] && unpack_deb "$g" "$d/gdbm" || log "could not unpack $g"
        done
        # Token Administration: the vendor's RHEL 10 build, which needs no
        # wxWidgets (the AUR package does the same).
        if [ -f safesign.rpm ] && mkdir -p "$d/rpm" &&
            bsdtar --no-same-owner -xf safesign.rpm -C "$d/rpm"; then
            ta=$(find "$d/rpm" -type f -name tokenadmin | head -n1)
        else
            log "could not unpack the SafeSign rpm"
            ta=$(find "$d/usr" -type f -name tokenadmin | head -n1)
        fi
        if [ -n "$ta" ]; then
            write_launcher "$d/tokenadmin" "/app/extra/$ta" \
                "/app/extra/$d/usr/lib" \
                "/app/extra/$d/gdbm/usr/lib/x86_64-linux-gnu"
        fi
    else
        log "could not unpack SafeSign"
    fi
    rm -f safesign.deb
fi
rm -f safesign.rpm gdbm.deb gdbm-compat.deb

# --- SafeNet Authentication Client (Thales): SafeNet 5100 eToken ----------
# The zip carries packages for several distributions; like distrobox-adv-br,
# take only the Ubuntu "withoutUI" core package.
if [ -f safenet.zip ]; then
    d=drivers/safenet
    rm -rf "$d" safenet-tmp
    mkdir -p safenet-tmp
    if bsdtar --no-same-owner -xf safenet.zip -C safenet-tmp; then
        deb=$(find safenet-tmp -path '*withoutUI*' -name 'safenetauthenticationclient-core_*_amd64.deb' | sort | tail -n1)
        if [ -n "$deb" ] && unpack_deb "$deb" "$d"; then
            rm -rf "$d/etc"
            lib=$(find "$d" -name 'libeToken.so*' \( -type f -o -type l \) | sort | head -n1)
            if [ -n "$lib" ]; then
                ln -sf "/app/extra/$lib" "$d/libeToken.so"
            else
                log "libeToken.so not found in the SafeNet package"
            fi
        else
            log "SafeNet core package not found in the zip"
        fi
    else
        log "could not unpack SafeNet"
    fi
    rm -rf safenet-tmp safenet.zip
fi

# --- SerproID (Serpro): cloud certificate ---------------------------------
# As in distrobox-adv-br: no /etc, no maintainer scripts, and the module is
# also offered as libneoidp11.so, the name some signers look for.
if [ -f serproid.deb ]; then
    d=drivers/serproid
    rm -rf "$d"
    if unpack_deb serproid.deb "$d"; then
        rm -rf "$d/etc"
        # The app's launcher script and configuration use absolute paths
        # (cd /usr/share/serproid-desktop; ./jre/bin/java ...). Point the text
        # files at our copy; binaries are left alone.
        grep -rlI '/usr/share/serproid-desktop' "$d/usr" 2>/dev/null | while read -r f; do
            sed -i "s|/usr/share/serproid-desktop|/app/extra/$d/usr/share/serproid-desktop|g" "$f"
        done
        lib=$(find "$d" -name 'libserproidp11.so' \( -type f -o -type l \) | head -n1)
        if [ -n "$lib" ]; then
            ln -sf "/app/extra/$lib" "$d/libserproidp11.so"
            ln -sf "/app/extra/$lib" "$(dirname "$lib")/libneoidp11.so"
        else
            log "libserproidp11.so not found in the SerproID package"
        fi
        # The desktop app: take its Exec line and point it at our copy.
        desktop=$(find "$d" -name 'serproid*.desktop' | head -n1)
        if [ -n "$desktop" ]; then
            exec_line=$(sed -n 's/^Exec=//p' "$desktop" | head -n1 | sed 's/ %[fFuU]//g')
            prog=${exec_line%% *}
            case "$prog" in
                /*) prog="/app/extra/$d$prog" ;;
                *) prog="/app/extra/$d/usr/bin/$prog" ;;
            esac
            write_launcher "$d/serproid" "$prog" "/app/extra/$d/usr/lib"
        else
            log "SerproID desktop file not found"
        fi
    else
        log "could not unpack SerproID"
    fi
    rm -f serproid.deb
fi

exit 0
