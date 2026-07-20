#!/usr/bin/env bash
# Update resolver for THS (同花顺) Linux.
#
# Upstream's Linux landing page (activity.10jqka.com.cn/acmake/cache/1380.html)
# has no version text at all: each download button just navigates to a numeric
# download-center id, and that id 302-redirects to the current file. Four ids are
# published, one per (distribution, architecture) pair:
#
#   600 -> cn.com.10jqka_<ver>_amd64.deb        (UnionTech/UOS, x86_64)
#   598 -> cn.com.10jqka_<ver>_arm64.deb        (UnionTech/UOS, aarch64)
#   596 -> cn.com.10jqka_kylin_<ver>_amd64.deb  (Kylin, x86_64)
#   594 -> cn.com.10jqka_kylin_<ver>_arm64.deb  (Kylin, aarch64)
#
# This package builds the Kylin x86_64 build, so the resolver follows id 596 and
# reads the version straight out of the filename it lands on. The Kylin and UOS
# builds are versioned independently and are not kept in step.
set -euo pipefail

readonly DOWNLOAD_ID=596
readonly REDIRECT_URL="https://download.10jqka.com.cn/index/download/id/${DOWNLOAD_ID}/"

url="$(curl -fsSL -o /dev/null -w '%{url_effective}' "$REDIRECT_URL")"

filename="${url##*/}"
if [[ ! "$filename" =~ ^cn\.com\.10jqka_kylin_([0-9]+(\.[0-9]+)+)_amd64\.deb$ ]]; then
    echo "unexpected THS download target: $url" >&2
    echo "the download-center id ${DOWNLOAD_ID} no longer resolves to a Kylin x86_64 .deb" >&2
    exit 1
fi
version="${BASH_REMATCH[1]}"

# The landing page carries no release date; fall back to the file's own
# Last-Modified, which upstream sets when it publishes a build.
release_date=""
last_modified="$(curl -fsSLI "$url" | tr -d '\r' | sed -n 's/^[Ll]ast-[Mm]odified: //p' | tail -1)"
if [ -n "$last_modified" ]; then
    release_date="$(date -u -d "$last_modified" +%Y-%m-%d 2>/dev/null || true)"
fi

printf '{\n  "version": "%s",\n  "releaseDate": "%s",\n  "sources": [{ "filename": "ths.deb", "url": "%s" }]\n}\n' \
    "$version" "$release_date" "$url"
