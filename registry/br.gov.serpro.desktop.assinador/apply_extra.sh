#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Serpro's Linux
# installer has already been fetched here by extra-data: a Go binary with a
# tar.zst embedded in it. It is not executed; only the program it carries is
# taken from the archive: the jar, a bundled Java runtime, the terms of use and
# the version file. The vendor's bytes run unmodified.
#
# The desktop entry, icon and AppStream metainfo are shipped by the manifest at
# *build* time - extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

installer=assinador.bin

# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring the archive's recorded uid/gid
# would fail.
extract() { # <offset>
    tail -c "+$(($1 + 1))" "$installer" | zstd -dc 2>/dev/null \
        | tar --no-same-owner -xf - ./lib ./jre_amd64 \
            ./TermoDeUsoAssinadorSERPRO.md ./version.json 2>/dev/null
}

# The zstd magic number also appears in the binary's code, so each match is only
# a candidate; the extraction result decides.
for offset in $(LC_ALL=C grep -aboP '\x28\xb5\x2f\xfd\x04' "$installer" | cut -d: -f1); do
    extract "$offset" || true
    if [ -x jre_amd64/bin/java ]; then
        break
    fi
done

for jar in lib/serpro-signer-*.jar; do :; done
if [ ! -s "$jar" ] || [ ! -x jre_amd64/bin/java ]; then
    echo "apply_extra: the jar or the Java runtime is missing from the installer" >&2
    exit 1
fi

rm -f "$installer"
