#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform, in /app/extra,
# where Flatpak has already fetched two files: the official PJe-Calc Cidadão
# installer for Windows and an OpenJDK 8 runtime for Linux. The installer is a
# 7-Zip self-extracting archive and is not executed: bsdtar reads the archive.
# The program inside it is Java (Tomcat and the PJe-Calc web application); the
# Windows Java runtime and the bundled Firefox Portable are left out, the rest
# is kept byte for byte.

# Plain C locale: the runtime has no other here, and every name in the archive
# is ASCII.
export LC_ALL=C

installer=pjecalc-installer.exe
jre=jre.tar.gz

[ -f "$installer" ] || { echo "apply_extra: $installer is missing" >&2; exit 1; }
[ -f "$jre" ] || { echo "apply_extra: $jre is missing" >&2; exit 1; }

rm -rf pjecalc java pjecalc-windows*
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring the recorded owners would fail.
bsdtar --no-same-owner -xf "$installer" \
    --exclude '*/navegador/*' --exclude '*/bin/jre/*'
for dir in pjecalc-windows*; do :; done
[ -f "$dir/bin/pjecalc.jar" ] || { echo "apply_extra: no bin/pjecalc.jar in $installer" >&2; exit 1; }
mv "$dir" pjecalc
rmdir pjecalc/navegador pjecalc/bin/jre 2>/dev/null || true
basename "$dir" | sed -n 's/^pjecalc-windows64-//p' > version
[ -s version ] || { echo "apply_extra: no version in the folder name $dir" >&2; exit 1; }

# PJe-Calc's own launcher turns this template into persistence.xml on first
# start, in the program folder, which is read-only here. The file is used as it
# is, so the rename is done once, now.
meta=pjecalc/tomcat/webapps/pjecalc/WEB-INF/classes/META-INF
if [ -f "$meta/persistence.xml.tmp" ]; then
    mv "$meta/persistence.xml.tmp" "$meta/persistence.xml"
fi

# The Java options come from the installer's own iniciarPjeCalc.bat, so a new
# version that changes them (the service token, the PJe security context) needs
# no change here. One option per line.
line=$(tr -d '\r' < pjecalc/iniciarPjeCalc.bat | grep -a ' -jar ')
options=${line#*javaw }
options=${options% -jar*}
printf '%s\n' "$options" | xargs -n 1 > java-options
grep -q '^-Dseguranca\.pjecalc\.tokenServicos=' java-options || {
    echo "apply_extra: the Java options in iniciarPjeCalc.bat changed shape" >&2
    exit 1
}

mkdir java
tar --no-same-owner -xzf "$jre" -C java --strip-components=1
[ -x java/bin/java ] || { echo "apply_extra: no bin/java in $jre" >&2; exit 1; }

rm -f "$installer" "$jre"
