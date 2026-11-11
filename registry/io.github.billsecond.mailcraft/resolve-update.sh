#!/usr/bin/env bash
# Update resolver for MailCraft.
#
# The same GitHub release also ships an AppImage, a .flatpak bundle, deb, rpm,
# and Windows, macOS and FreeBSD archives. Take the official Linux tar.gz for
# each architecture. Among the releases that have both, pick the highest
# version number, not the newest publish date.
# Prints JSON on stdout:
#   { "version": "0.11.1", "releaseDate": "YYYY-MM-DD", "releaseUrl": "...",
#     "sources": [ { "filename": "mailcraft.tar.gz", "arch": "...", "url": "..." }, ... ] }
set -euo pipefail

repo="UCS-Care-Group/mailcraft"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

best="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases?per_page=30" | jq '
  [ .[] | select((.draft or .prerelease) | not)
        | select(.tag_name | test("^v[0-9]+(\\.[0-9]+)*$"))
        | . as $r
        | .assets
        | { published: $r.published_at,
            html: $r.html_url,
            ver: ($r.tag_name | ltrimstr("v")),
            x64: ([ .[] | select(.name | test("^mailcraft-[0-9][0-9.]*-linux-x86_64\\.tar\\.gz$")) | .browser_download_url ] | first // ""),
            arm: ([ .[] | select(.name | test("^mailcraft-[0-9][0-9.]*-linux-aarch64\\.tar\\.gz$")) | .browser_download_url ] | first // "") }
        | select(.x64 != "" and .arm != "") ]
  | max_by(.ver | split(".") | map(tonumber))')"

version="$(jq -r '.ver // empty' <<<"$best")"
date="$(jq -r '.published // empty' <<<"$best" | cut -c1-10)"
release_url="$(jq -r '.html // empty' <<<"$best")"
x64="$(jq -r '.x64 // empty' <<<"$best")"
arm="$(jq -r '.arm // empty' <<<"$best")"

[ -n "$version" ] && [ -n "$x64" ] && [ -n "$arm" ] || { echo "failed to resolve MailCraft release" >&2; exit 1; }
echo "resolved MailCraft $version ($date)" >&2

jq -n --arg v "$version" --arg d "$date" --arg r "$release_url" --arg x "$x64" --arg a "$arm" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[
     {filename:"mailcraft.tar.gz", arch:"x86_64", url:$x},
     {filename:"mailcraft.tar.gz", arch:"aarch64", url:$a}
   ]}'
