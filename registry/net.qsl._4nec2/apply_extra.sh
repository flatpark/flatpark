#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
for f in 4nec2.zip cellar-cli-x86_64 innoextract-1.9-linux.tar.xz; do
  [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
# Unpack the Windows installer. Cellar runs it in the user's Wine prefix.
bsdtar -x --no-same-owner -f 4nec2.zip Setup_4nec2.exe
[ -f Setup_4nec2.exe ] || { echo "installer missing from archive" >&2; exit 1; }
# Stage the installer's own DirectX 8 Visual Basic library for Wine.
extractor=innoextract-1.9-linux/bin/amd64/innoextract
bsdtar -x --no-same-owner -f innoextract-1.9-linux.tar.xz "$extractor"
"$extractor" --silent --extract --include sys/dx8vb.dll Setup_4nec2.exe
[ -s sys/dx8vb.dll ] || { echo "DirectX library missing from installer" >&2; exit 1; }
mv sys/dx8vb.dll dx8vb.dll
rmdir sys
rm -r innoextract-1.9-linux
rm 4nec2.zip innoextract-1.9-linux.tar.xz
mv cellar-cli-x86_64 cellar
chmod +x cellar
