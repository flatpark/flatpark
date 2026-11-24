#!/bin/sh
set -eu

cellar_home=${CELLAR_HOME:-"$XDG_DATA_HOME/cellar"}
mkdir -p "$cellar_home"
exec 9>"$cellar_home/setup.lock"
flock -n 9 || exit 0

# Use Qorvo's Start Menu shortcut so both installation modes and custom
# destinations work. Check its target in case a previous install was removed.
programs="$(cellar app discover --json)"
program="$(printf '%s\n' "$programs" | jq -r '
    first(.[]? | select(.from == "start-menu" and .name == "QSPICE") | .exe |
        gsub("\\\\"; "/") | select(test("^[A-Za-z]:/(.*/)?QUX\\.exe$"; "i"))) // empty
')"
if [ -n "$program" ]; then
    drive="$(printf '%s' "${program%%:*}" | tr '[:upper:]' '[:lower:]')"
    if exe="$(realpath -e "$cellar_home/pfx/dosdevices/$drive:/${program#*:}")" && [ -f "$exe" ]; then
        exec 9>&-
        exec cellar run --exe "$exe" -- "$@"
    fi
fi

# The downloader presents the terms and starts QSPICE when setup succeeds.
# If setup is cancelled, the next launch can start it again.
exec cellar
