#!/usr/bin/env bash
set -euo pipefail

DEB_FILE=$(ls -1 *.deb | head -n 1)
if [[ -z "${DEB_FILE:-}" || ! -f "$DEB_FILE" ]]; then
    echo "Error: Expected .deb archive in /app/extra" >&2
    exit 1
fi

ar x "$DEB_FILE"
if [[ -f data.tar.xz ]]; then
    tar -xJf data.tar.xz
elif [[ -f data.tar.zst ]]; then
    unzstd -c data.tar.zst | tar -x
elif [[ -f data.tar.gz ]]; then
    tar -xzf data.tar.gz
else
    echo "Error: Unsupported Debian data archive in $DEB_FILE" >&2
    exit 1
fi

rm -f "$DEB_FILE" debian-binary control.tar.* data.tar.*
