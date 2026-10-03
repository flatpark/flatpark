#!/usr/bin/env bash
# Update resolver for SurrealDB Studio.
#
# Prints the latest version, release date and the official Linux x86_64 .deb as
# JSON on stdout; logs go to stderr. Hashing and manifest rewriting are handled
# by FlatPark's update automation.
#
# Studio is not released on GitHub. Its electron-builder update feed for Linux,
# latest-linux.yml under download.surrealdb.com/studio, names the version, the
# release date and the files of the current stable release. The .deb is the
# entry ending in _amd64.deb (it is listed more than once with the same path);
# the URL is that path under the feed's base.
set -euo pipefail

base="https://download.surrealdb.com/studio"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

feed="$(curl -fsSL "$base/latest-linux.yml")"

version="$(sed -n 's/^version: *//p' <<<"$feed" | head -n 1 | tr -d "'\"")"
date="$(sed -n 's/^releaseDate: *//p' <<<"$feed" | head -n 1 | tr -d "'\"" | cut -c1-10)"
paths="$(sed -n 's/^ *- url: *//p' <<<"$feed" | tr -d "'\"" | grep -E '_amd64\.deb$' | sort -u)"

[ -n "$version" ] && [ -n "$date" ] && [ "$(wc -l <<<"$paths")" -eq 1 ] && [ -n "$paths" ] || {
  echo "failed to resolve SurrealDB Studio release" >&2
  exit 1
}
url="$base/$paths"
echo "resolved SurrealDB Studio $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"app.deb", url:$u}]}'
