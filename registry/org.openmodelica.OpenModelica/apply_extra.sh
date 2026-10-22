#!/bin/sh
set -eu

# Runs offline at install time inside org.kde.Sdk. The official OpenModelica
# Debian packages and their missing runtime libraries have already been fetched
# as extra-data. No maintainer scripts run and the vendor binaries are not
# patched.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

openmodelica_debs="omc.deb omc-common.deb libomc.deb libomcsimulation.deb omedit.deb libomplot.deb libomsimulator.deb libomsensplugin.deb omlibrary.deb"
debian_debs="libicu76.deb libblas3.deb liblapack3.deb libomniorb4-3t64.deb libomnithread4.deb libopenscenegraph161.deb libopenthreads21.deb"

for deb in $openmodelica_debs $debian_debs; do
    [ -f "$deb" ] || { echo "missing extra-data: $deb" >&2; exit 1; }
done

rm -rf stage openmodelica
mkdir stage

# The runtime has no dpkg, but bsdtar reads the .deb ar container directly.
# --no-same-owner also matches the privilege-dropped system-install path.
for deb in $openmodelica_debs $debian_debs; do
    bsdtar -xOf "$deb" 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
done

[ -x stage/usr/bin/OMEdit ] || { echo "OMEdit missing after unpack" >&2; exit 1; }
[ -x stage/usr/bin/omc ] || { echo "omc missing after unpack" >&2; exit 1; }
[ -d stage/usr/share/omlibrary/cache ] || { echo "Modelica library cache missing after unpack" >&2; exit 1; }

# OMC links generated simulation executables with -lblas and -llapack. Debian's
# runtime packages contain only versioned linker names in multiarch subfolders,
# so provide the two unversioned links under OPENMODELICAHOME/lib.
ln -s x86_64-linux-gnu/blas/libblas.so.3 stage/usr/lib/libblas.so
ln -s x86_64-linux-gnu/lapack/liblapack.so.3 stage/usr/lib/liblapack.so

mv stage/usr openmodelica
rm -rf stage $openmodelica_debs $debian_debs
