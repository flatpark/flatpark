#!/usr/bin/env bash
# Update resolver for MailCraft.
#
# The same GitHub release also ships an AppImage, a .flatpak bundle, deb, rpm,
# and Windows, macOS and FreeBSD archives. Take the official Linux tar.gz for
# each architecture from releases/latest: every release carries both, so a
# missing one fails instead of settling on an older release.
# Prints JSON on stdout:
#   { "version": "0.11.1", "releaseDate": "YYYY-MM-DD", "releaseUrl": "...",
#     "sources": [ { "filename": "mailcraft.tar.gz", "arch": "...", "url": "..." }, ... ] }
set -euo pipefail

repo="UCS-Care-Group/mailcraft"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases/latest")"

asset_url() {
  jq -r --arg a "$1" '
    [ .assets[] | select(.name | test("^mailcraft-[0-9][0-9.]*-linux-" + $a + "\\.tar\\.gz$")) ]
    | if length == 1 then .[0].browser_download_url else empty end' <<<"$rel"
}

version="$(jq -r '.tag_name | select(test("^v[0-9]+(\\.[0-9]+)*$")) | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at // empty' <<<"$rel" | cut -c1-10)"
release_url="$(jq -r '.html_url // empty' <<<"$rel")"
x64="$(asset_url x86_64)"
arm="$(asset_url aarch64)"

[ -n "$version" ] && [ -n "$x64" ] && [ -n "$arm" ] || { echo "failed to resolve MailCraft release" >&2; exit 1; }
echo "resolved MailCraft $version ($date)" >&2

jq -n --arg v "$version" --arg d "$date" --arg r "$release_url" --arg x "$x64" --arg a "$arm" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[
     {filename:"mailcraft.tar.gz", arch:"x86_64", url:$x},
     {filename:"mailcraft.tar.gz", arch:"aarch64", url:$a}
   ]}'
