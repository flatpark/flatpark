#!/usr/bin/env bash
# Update resolver for Flectar Mail.
#
# Prints the latest release and its amd64 .deb as JSON on stdout; logs go to
# stderr. Upstream publishes its preview builds (0.1.0-alpha.N) as regular
# releases, so releases/latest is the newest one.
set -euo pipefail

repo="flectar/mail"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The .deb version swaps the pre-release dash for a dot
# (flectar-mail_0.1.0.alpha.7_amd64.deb), so match the name's shape, not the
# tag. The same release carries the AppImage, .rpm and Flatpak bundle.
url="$(jq -r '.assets[] | select(.name | test("^flectar-mail_[0-9][0-9A-Za-z.+~-]*_amd64\\.deb$")) | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve Flectar Mail release" >&2; exit 1; }
[ "$(wc -l <<<"$url")" -eq 1 ] || { echo "expected exactly one amd64 .deb, got:" >&2; echo "$url" >&2; exit 1; }
echo "resolved flectar-mail $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"flectar-mail.deb", url:$u}]}'
