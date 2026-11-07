#!/bin/sh
set -eu

# PJe-Calc Cidadão is unpacked by apply_extra to /app/extra, read-only. Its
# launcher (bin/pjecalc.jar) treats the working directory as the install folder:
# it starts Tomcat there and keeps the H2 database in .dados/. This builds that
# folder in the app's data directory, with the program linked from /app/extra
# and only what PJe-Calc writes kept as real files, then starts it with the
# Java options of the vendor's iniciarPjeCalc.bat. The web interface opens in
# the user's browser, as on Windows.

extra=${PJECALC_EXTRA:-/app/extra}
data=${XDG_DATA_HOME:?}/pjecalc
# The launcher always serves on port 9257; the override is for the tests.
url=${PJECALC_URL:-http://localhost:9257/pjecalc}
open_browser=${PJECALC_BROWSER:-/app/bin/pjecalc-browser}

# Already running: PJe-Calc's launcher would ask whether to reuse it. The
# answer is always yes, so just open the page.
if curl -fs -o /dev/null -m 5 "$url/"; then
    exec "$open_browser" "$url"
fi

version=$(cat "$extra/version")
mkdir -p "$data/tomcat" "$data/navegador/linux"
cd "$data"

ln -sfn "$extra/pjecalc/bin" bin
ln -sfn "$extra/pjecalc/pjecalc_splash.gif" pjecalc_splash.gif
ln -sfn "$extra/pjecalc/tomcat/lib" tomcat/lib
ln -sfn "$extra/pjecalc/tomcat/webapps" tomcat/webapps
# On Linux the launcher opens the page with this file, the Firefox AppImage
# older installers shipped.
ln -sfn "$open_browser" navegador/linux/Firefox-45.0.1-x86_64.AppImage

if [ "$(cat version 2>/dev/null || true)" != "$version" ]; then
    # Tomcat writes under conf/ and caches compiled pages in work/; both belong
    # to one version.
    rm -rf tomcat/conf tomcat/work
    cp -r "$extra/pjecalc/tomcat/conf" tomcat/conf
    chmod -R u+w tomcat/conf
    # PJe-Calc migrates the database to the new version on start. A copy of the
    # previous one stays until the next update, as there is no way back.
    if [ -f .dados/pjecalc.h2.db ]; then
        rm -rf .dados.anterior
        cp -a .dados .dados.anterior
    fi
    echo "$version" > version
fi

if [ ! -f .dados/pjecalc.h2.db ]; then
    mkdir -p .dados
    cp "$extra/pjecalc/.dados/pjecalc.h2.db" .dados/
    chmod u+w .dados/pjecalc.h2.db
fi

options=$(cat "$extra/java-options")
# shellcheck disable=SC2086 # one option per line, none with spaces
"$extra/java/bin/java" $options -jar bin/pjecalc.jar "$@" &
java=$!

# With a system tray the launcher opens the page itself; without one (GNOME,
# most Wayland desktops) it only shows a small window with an "Abrir o PjeCalc"
# button. Opening it here covers both: pjecalc-browser skips a second request
# within a few seconds.
tries=0
while kill -0 "$java" 2>/dev/null; do
    if curl -fs -o /dev/null -m 5 "$url/"; then
        "$open_browser" "$url" || true
        break
    fi
    tries=$((tries + 1))
    [ "$tries" -lt 180 ] || break
    sleep 1
done

wait "$java"
