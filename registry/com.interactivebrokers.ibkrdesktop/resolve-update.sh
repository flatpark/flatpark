#!/usr/bin/env bash
# Update resolver for IBKR Desktop.
#
# Prints the current version + bootstrap sources as JSON on stdout:
#   { "version": "...", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "ntws-installer.sh", "url": "..." },
#                  { "filename": "zulu-jre.tar.gz",   "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark applies the
# URLs and computes the extra-data pins at build time. The internal jars are NOT
# listed: install4j downloads and self-updates them at runtime in the data dir.
set -euo pipefail

CHANNEL="${CHANNEL:-latest-standalone}"
BASE_URL="https://download2.interactivebrokers.com/installers/ntws/$CHANNEL"
VERSION_URL="$BASE_URL/version.json"
CHANNEL_NAME="${CHANNEL%-standalone}"
INSTALLER_URL="$BASE_URL/ntws-$CHANNEL_NAME-standalone-linux-x64.sh"
# Zulu JRE from Azul's official CDN (not IB's mirror). Pinned; bump for security
# via Azul's metadata API: api.azul.com/metadata/v1/zulu/packages/?java_version=17
# &os=linux&arch=x64&java_package_type=jre&javafx_bundled=false&latest=true&availability_types=CA
JRE_URL="https://cdn.azul.com/zulu/bin/zulu17.66.19-ca-jre17.0.19-linux_x64.tar.gz"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need sed; need awk; need python3

meta="$(curl -fsSL "$VERSION_URL")"
version="$(printf '%s' "$meta" | sed -nE 's/.*"buildVersion":"([^"]+)".*/\1/p')"
build_datetime="$(printf '%s' "$meta" | sed -nE 's/.*"buildDateTime":"([^"]+)".*/\1/p')"
[ -n "$version" ] && [ -n "$build_datetime" ] || { echo "failed to parse $VERSION_URL: $meta" >&2; exit 1; }

build_tag="$(printf '%s' "$version-$build_datetime" | tr -d ' :-')"
release_date="$(printf '%s' "$build_datetime" | awk '{print substr($1,1,4) "-" substr($1,5,2) "-" substr($1,7,2)}')"
installer_url="$INSTALLER_URL?build=$build_tag"
echo "resolved IBKR Desktop $version ($build_datetime)" >&2

python3 - "$version" "$release_date" "$installer_url" "$JRE_URL" <<'PY'
import json, sys
version, release_date, installer_url, jre_url = sys.argv[1:5]
print(json.dumps({
    "version": version,
    "releaseDate": release_date,
    "sources": [
        {"filename": "ntws-installer.sh", "url": installer_url},
        {"filename": "zulu-jre.tar.gz", "url": jre_url},
    ],
}, indent=2))
PY
