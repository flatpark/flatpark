#!/bin/sh
set -eu

# Cellar installs the vendor payload before we register its bundled server.
cellar apply
prefix=${CELLAR_HOME:-"$XDG_DATA_HOME/cellar"}/pfx
server="$prefix/drive_c/OpenDSS/DSSpyServer"
settings_dir="$prefix/drive_c/users/$(id -un)/AppData/Roaming/DSSpyServer"
settings="$settings_dir/settings.ini"

# Match the vendor's registration format, preserving any existing setup.
if [ -f "$server/Server.py" ] && [ ! -e "$settings" ]; then
    mkdir -p "$settings_dir"
    (
        set -C
        printf '%s\r\n' '[Application]' 'path="C:\\OpenDSS\\DSSpyServer\\Server.py"' > "$settings"
    ) || [ -f "$settings" ]
fi

exec cellar "$@"
