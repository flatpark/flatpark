#!/bin/sh
set -eu

# Runs offline at install time. The release asset is a single self-contained
# binary (GUI and CLI in one); stage it under the name /app/bin/cellar links to.
# The Debian packages give it 7-Zip and cabextract, staged under tools/, which
# /app/bin/7z and /app/bin/cabextract link to.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in cellar-x86_64 7zip.deb cabextract.deb libmspack0t64.deb; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
mv cellar-x86_64 cellar
chmod +x cellar

rm -rf stage tools
mkdir -p stage tools/bin tools/lib tools/7zip
for deb in 7zip.deb cabextract.deb libmspack0t64.deb; do
    # The runtime has no ar/dpkg, but bsdtar reads the .deb ar container;
    # --no-same-owner because a system-wide install runs this as root with
    # every capability dropped.
    bsdtar -xOf "$deb" 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
done

# 7z loads its formats from 7z.so next to argv[0], so it must be exec'd by
# its real path, not through a link: started as tools/bin/7z it finds no
# 7z.so and opens no cabinet. Debian's /usr/bin/7z is such a script too.
for f in 7z 7z.so; do
    [ -f "stage/usr/lib/7zip/$f" ] || { echo "$f not found in 7zip.deb" >&2; exit 1; }
    cp -a "stage/usr/lib/7zip/$f" tools/7zip/
done
cat > tools/bin/7z <<'WRAP'
#!/bin/sh
exec /app/extra/tools/7zip/7z "$@"
WRAP
chmod +x tools/bin/7z

# cabextract needs libmspack.so.0, which the runtime lacks: a wrapper of its
# own carries the library path, keeping it out of cellar's and Wine's.
[ -x stage/usr/bin/cabextract ] || { echo "cabextract not found in cabextract.deb" >&2; exit 1; }
cp -a stage/usr/bin/cabextract tools/bin/cabextract.bin
# -a and -e: the loader looks up the soname link, not the file behind it.
find stage/usr/lib -maxdepth 3 \( -type f -o -type l \) -name 'libmspack.so.*' \
    -exec cp -a {} tools/lib/ \;
[ -e tools/lib/libmspack.so.0 ] || { echo "libmspack.so.0 not found in libmspack0t64.deb" >&2; exit 1; }
cat > tools/bin/cabextract <<'WRAP'
#!/bin/sh
LD_LIBRARY_PATH="/app/extra/tools/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    exec /app/extra/tools/bin/cabextract.bin "$@"
WRAP
chmod +x tools/bin/cabextract

rm -rf stage 7zip.deb cabextract.deb libmspack0t64.deb
