#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# Titanium Inspector as a .deb holding a self-contained .NET 10 app under
# /opt/titanium-inspector (the apphost, the runtime, every managed assembly and
# the native SkiaSharp/HarfBuzz/OpenSSL/msquic libs) and /usr/bin/TitaniumInspector
# as an absolute symlink into it. Keep that directory whole at a stable path the
# wrapper execs: /app/extra/titanium-inspector. Nothing in it is removed — the
# apphost resolves every asset listed in TitaniumInspector.deps.json before it
# starts, so dropping even an unused native aborts the launch.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f titanium-inspector.deb ] || { echo "missing extra-data: titanium-inspector.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage titanium-inspector
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf titanium-inspector.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# Read the launcher out of the package's own .desktop Exec= (an absolute
# /opt/... path) rather than hardcoding it, so a rename between releases fails
# here instead of shipping an install nobody can start (flatpark#130).
desktop="$(ls stage/usr/share/applications/*.desktop 2>/dev/null | head -n1)"
[ -n "$desktop" ] || { echo "no .desktop in the .deb" >&2; exit 1; }
exec_path="$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' "$desktop" | head -n1)"
app_dir="stage${exec_path%/*}"
launcher="${exec_path##*/}"
[ -x "$app_dir/$launcher" ] || { echo "launcher $exec_path not found in the .deb" >&2; exit 1; }

mv "$app_dir" titanium-inspector
rm -rf stage titanium-inspector.deb

# certutil from Debian's libnss3-tools: keep just that binary. Everything it
# links (libnss3, libsmime3, libssl3, libnssutil3, NSPR) is in the runtime.
[ -f libnss3-tools.deb ] || { echo "missing extra-data: libnss3-tools.deb" >&2; exit 1; }
rm -rf nss-stage nss-tools
mkdir nss-stage nss-tools
bsdtar -xOf libnss3-tools.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C nss-stage ./usr/bin/certutil
mv nss-stage/usr/bin/certutil nss-tools/certutil
rm -rf nss-stage libnss3-tools.deb
[ -x nss-tools/certutil ] || { echo "certutil missing after stage" >&2; exit 1; }

[ "$launcher" = TitaniumInspector ] || ln -sf "$launcher" titanium-inspector/TitaniumInspector
[ -x titanium-inspector/TitaniumInspector ] || { echo "TitaniumInspector missing after stage" >&2; exit 1; }
