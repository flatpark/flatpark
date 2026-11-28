#!/usr/bin/env bash
# Update resolver for Ginrose.
#
# Ginrose's developer publishes the official builds as releases of
# nunreasonable/ginrose-flatpak (the source is nunreasonable/ginrose). Each
# release carries two files this package pins, the same two the developer's own
# Flatpak bundle is made from:
#   ginrose-<version>-x86_64.tar.gz   the launcher and its licence
#   rosemary-ginrose-x86_64           Ginrose's build of Rosemary, a plain binary
# The release also has an Arch, Debian and RPM package, FreeBSD builds and the
# Flatpak bundle itself; none of those is used.
#
# Prints { version, releaseDate, releaseUrl, sources } as JSON on stdout.
set -euo pipefail

repo="nunreasonable/ginrose-flatpak"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r '.html_url' <<<"$rel")"

# Anchored: `ginrose-<version>-x86_64-freebsd.tar.gz` sits beside it and must
# not match. Both assets must exist; a release without one fails here instead
# of pinning half a package.
asset() {
    jq -r --arg re "$1" \
        '[.assets[] | select(.name | test($re)) | .browser_download_url] | first // empty' <<<"$rel"
}
tarball="$(asset '^ginrose-[0-9][0-9.]*-x86_64\.tar\.gz$')"
rosemary="$(asset '^rosemary-ginrose-x86_64$')"

[ -n "$version" ] && [ -n "$tarball" ] && [ -n "$rosemary" ] \
    || { echo "failed to resolve the release: version='$version' tarball='$tarball' rosemary='$rosemary'" >&2; exit 1; }

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg t "$tarball" --arg r "$rosemary" \
    '{version: $v, releaseDate: $d, releaseUrl: $u,
      sources: [
        {filename: "ginrose.tar.gz", url: $t},
        {filename: "rosemary",       url: $r}
      ]}'
