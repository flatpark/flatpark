#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
for f in cellar-cli-x86_64 OpenDSSInstaller.exe; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
mv cellar-cli-x86_64 cellar
chmod +x cellar

# Keep Python independent of the Windows installer and unpack it offline.
python_dir=pycontrol/python
mkdir -p "$python_dir"
for archive in pycontrol-python.zip pycontrol-numpy.whl pycontrol-pywin32.whl; do
    bsdtar --no-same-owner -xf "$archive" -C "$python_dir"
    rm "$archive"
done
cp "$python_dir"/pywin32_system32/*.dll "$python_dir/"
test -f "$python_dir/python.exe"
test -f "$python_dir/python312.zip"

# The embeddable distribution uses an explicit module search path. Include
# the vendor's server directory so Server.py can import pyPIPES_API.
cat > "$python_dir/python312._pth" <<'PATHS'
python312.zip
.
win32
win32/lib
C:\OpenDSS\DSSpyServer
PATHS
