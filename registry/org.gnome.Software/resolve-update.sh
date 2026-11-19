#!/usr/bin/env bash
# Update resolver for Software (gnome-software-next).
#
# Prints the newest build as JSON on stdout:
#   { "version": "51.1.818.ga2d879480", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "app.tar.xz", "url": "..." } ] }
# Logs go to stderr. No hashing: FlatPark downloads the URL and pins it.
#
# The project releases on GitLab (gitlab.gnome.org) into its generic package
# registry, one package version per build, with the tarball
# gnome-software-next-<version>-x86_64.tar.xz; the API needs no token.
set -euo pipefail

api="https://gitlab.gnome.org/api/v4/projects/user_c1a5830a%2Fgnome-software-next"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

pkg="$(curl -fsSL "$api/packages?package_type=generic&package_name=gnome-software-next&order_by=created_at&sort=desc&per_page=1" | jq -c 'first // empty')"
[ -n "$pkg" ] || { echo "no gnome-software-next package in the registry" >&2; exit 1; }

version="$(jq -r '.version' <<<"$pkg")"
date="$(jq -r '.created_at' <<<"$pkg" | cut -c1-10)"
file="gnome-software-next-$version-x86_64.tar.xz"
url="$api/packages/generic/gnome-software-next/$version/$file"

curl -fsSIL -o /dev/null "$url" || { echo "missing $url" >&2; exit 1; }
echo "resolved gnome-software-next $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"app.tar.xz", url:$u}]}'
