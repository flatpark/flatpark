#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream's Debian
# package is a plain FHS tree: the Tauri launcher at usr/bin/<Name> plus its
# Tauri resource directory at usr/lib/<Product Name>/, which holds the Spring
# Boot jar (libs/) and the Java runtime image the launcher runs it with
# (runtime/jre/). Tauri resolves that resource directory from the launcher's own
# location - <exe>/../lib/<product name>, taken only when the executable sits in
# a directory ending in /usr/bin - so the whole usr tree is staged as-is at
# /app/extra/usr and the wrapper launches it through /app/extra/bin/stirling-pdf.
# Nothing is flattened or moved inside that tree: dropping the version-stamped
# jar or the jre out of it would leave the launcher with no backend to start.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time - extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f stirling-pdf.deb ] || { echo "missing extra-data: stirling-pdf.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb
# ar container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage usr bin
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf stirling-pdf.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# The launcher name comes out of the package's own .desktop Exec= rather than
# being hardcoded, so a rename upstream cannot ship an app that will not start.
desktop="$(find stage/usr/share/applications -maxdepth 1 -name '*.desktop' | head -n1)"
[ -n "$desktop" ] || { echo "no .desktop in the .deb" >&2; exit 1; }
exec_name="$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' "$desktop" | head -n1 | xargs basename)"
[ -n "$exec_name" ] || { echo "no Exec= in $desktop" >&2; exit 1; }
[ -f "stage/usr/bin/$exec_name" ] || { echo "launcher $exec_name not found in the .deb" >&2; exit 1; }

# The backend has to be there too, and its directory name is upstream's Tauri
# product name, so find it rather than spell it out. Both are fatal if missing:
# without them the window opens on a backend that can never start.
java="$(find stage/usr/lib -mindepth 5 -maxdepth 5 -path '*/runtime/jre/bin/java' | head -n1)"
[ -n "$java" ] || { echo "no bundled Java runtime in the .deb" >&2; exit 1; }
jar="$(find stage/usr/lib -mindepth 3 -maxdepth 3 -path '*/libs/*.jar' | head -n1)"
[ -n "$jar" ] || { echo "no backend jar in the .deb" >&2; exit 1; }

mv stage/usr usr
rm -rf stage stirling-pdf.deb
chmod +x "usr/bin/$exec_name"

# Stable path for the wrapper, whatever upstream calls the binary. The name of
# this symlink is also the window class the toolkit derives from argv[0], so it
# has to keep matching StartupWMClass in the exported .desktop file - hence a
# link named stirling-pdf rather than one named after the artifact. The app's
# own resource lookup goes through /proc/self/exe, which resolves back to
# usr/bin/<launcher>, so ../lib/<product name> still resolves.
mkdir -p bin
ln -sf "../usr/bin/$exec_name" bin/stirling-pdf

# --- the command-line tools the engine looks for on PATH -----------------------
#
# Stirling PDF hands some of its work to external programs and probes for each one
# at startup, disabling the tools that have no other implementation when a program
# is absent. Neither upstream's package nor the runtime carries any of them. These
# two are staged beside the app, under /app/extra/cli, and put on PATH by the
# wrapper; their libraries are never added to the app's own library path, because
# the Ghostscript snap brings a whole second userland (fontconfig, freetype,
# X11, ...) that would shadow the runtime's for the app itself.

rm -rf cli
mkdir -p cli/bin cli/lib

# unsquashfs, to crack the Ghostscript snap. Artifex publishes no plain Linux
# tarball; their snap is an ordinary xz squashfs image, and this is the same
# offline extractor the AppImage packages use. Never executed as an AppImage tool.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/unsquashfs" ] || { echo "appimage-tools stack incomplete" >&2; exit 1; }

# The .tgz holds a README and the .snap; find the image rather than spell out the
# version-stamped directory upstream wraps it in.
mkdir -p snapstage
bsdtar --no-same-owner -xf ghostscript-snap.tgz -C snapstage
snap="$(find snapstage -maxdepth 2 -name '*.snap' -type f | head -n1)"
[ -n "$snap" ] || { echo "no .snap inside ghostscript-snap.tgz" >&2; exit 1; }
# -no-xattrs: this sandbox has every capability dropped and cannot set security
# xattrs. A snap is a squashfs image with no prepended stub, so there is no offset.
"$tools/unsquashfs" -no-xattrs -d cli/ghostscript "$snap"
rm -rf snapstage ghostscript-snap.tgz appimage-tools.tar.xz appimage-tools

# The two libraries the snap expects from its own base image and does not carry.
# Only the shared objects are kept; the rest of each package is documentation.
for pkg in libidn12 libpaper2; do
    [ -f "$pkg.deb" ] || { echo "missing extra-data: $pkg.deb" >&2; exit 1; }
    rm -rf debstage && mkdir debstage
    bsdtar -xOf "$pkg.deb" 'data.tar*' | bsdtar --no-same-owner -xf - -C debstage
    # Both the real file and the SONAME symlink beside it: the loader asks for
    # libidn.so.12, and the package ships that as a link to libidn.so.12.6.7.
    find debstage -name '*.so.*' \( -type f -o -type l \) -exec cp -a {} cli/lib/ \;
    rm -rf debstage "$pkg.deb"
done

# qpdf's own build is self-contained: RUNPATH=$ORIGIN/../lib, and $ORIGIN follows
# the resolved path, so reaching bin/qpdf through a symlink still finds lib/.
mkdir -p cli/qpdf
bsdtar --no-same-owner -xf qpdf.zip -C cli/qpdf
qpdf_bin="$(find cli/qpdf -path '*/bin/qpdf' -type f | head -n1)"
[ -n "$qpdf_bin" ] || { echo "no qpdf binary inside qpdf.zip" >&2; exit 1; }
chmod +x "$qpdf_bin"
ln -sf "../${qpdf_bin#cli/}" cli/bin/qpdf
rm -f qpdf.zip

# gs comes out of the snap wherever upstream put it, with its libraries in the
# snap's own lib directories. Wrap it rather than exporting that library path
# globally, so nothing but gs itself sees the snap's userland.
gs_bin="$(find cli/ghostscript -path '*/bin/gs' -type f | head -n1)"
[ -n "$gs_bin" ] || { echo "no gs binary inside the snap" >&2; exit 1; }
chmod +x "$gs_bin"
gs_libs=""
for d in $(find cli/ghostscript -type d \( -name 'x86_64-linux-gnu' -o -name lib \) | sort); do
    gs_libs="${gs_libs:+$gs_libs:}$extra_root/$d"
done
cat > cli/bin/gs <<WRAPPER
#!/bin/sh
exec env LD_LIBRARY_PATH="$gs_libs:$extra_root/cli/lib" "$extra_root/$gs_bin" "\$@"
WRAPPER
chmod +x cli/bin/gs
