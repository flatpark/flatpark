#!/usr/bin/env bash
# Update resolver for PJe-Calc Cidadão.
#
# TRT8, which develops PJe-Calc for the Labour Courts, links the current
# installers from its install page, with the version in the file name:
#
#   /sites/portal/files/roles/pje-calc/pjecalc-2.16.0-instalador-x64.exe
#
# The highest x64 version on that page is the latest. Older ones move to a
# separate page, so the URL keeps its bytes. The URL is checked before it is
# printed, and the date is its Last-Modified.
#
# The Java runtime is Azul's Zulu 8 JRE, pinned here: PJe-Calc needs Java 8
# (Tomcat 7, Seam 2), and a newer JRE is a PR, not an automatic update, since
# the version compared is PJe-Calc's. The current one is listed by
#   https://api.azul.com/metadata/v1/zulu/packages/?java_version=8&os=linux&arch=x64&java_package_type=jre&javafx_bundled=false&latest=true&availability_types=CA&archive_type=tar.gz
#
# Prints:
#   { "version": "2.16.0", "releaseDate": "2026-06-25", "sources": [
#       { "filename": "pjecalc-installer.exe", "url": "..." },
#       { "filename": "jre.tar.gz", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

site="https://www.trt8.jus.br"
page="$site/pjecalc-cidadao/instalando-o-pje-calc-cidadao"
JRE_URL="https://cdn.azul.com/zulu/bin/zulu8.98.0.111-ca-jre8.0.512-linux_x64.tar.gz"

html="$(curl -fsSL --retry 3 -A 'Mozilla/5.0' "$page")" || { echo "cannot read $page" >&2; exit 1; }
version="$(grep -oE 'pjecalc-[0-9]+(\.[0-9]+)+-instalador-x64\.exe' <<<"$html" \
  | sed -E 's/^pjecalc-(.*)-instalador-x64\.exe$/\1/' | sort -Vu | tail -n1)"
[ -n "$version" ] || { echo "no x64 installer linked from $page" >&2; exit 1; }

url="$site/sites/portal/files/roles/pje-calc/pjecalc-$version-instalador-x64.exe"
headers="$(curl -fsSI -A 'Mozilla/5.0' "$url")" || { echo "installer for $version not found at $url" >&2; exit 1; }

# The date is a nicety; a missing header must not block an update.
release_date="$(printf '%s\n' "$headers" | tr -d '\r' \
  | sed -nE 's/^[Ll]ast-[Mm]odified: *(.*)$/\1/p' | head -n1)"
[ -z "$release_date" ] || release_date="$(date -u -d "$release_date" +%F 2>/dev/null || true)"

echo "resolved PJe-Calc Cidadão $version (${release_date:-no date}): $url" >&2

jq -n \
  --arg v "$version" \
  --arg d "$release_date" \
  --arg u "$url" \
  --arg j "$JRE_URL" \
  '{version:$v} + (if $d == "" then {} else {releaseDate:$d} end)
   + {sources:[{filename:"pjecalc-installer.exe", url:$u}, {filename:"jre.tar.gz", url:$j}]}'
