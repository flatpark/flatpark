#!/usr/bin/env bash
# Update resolver for Audacity 4: the official x86_64 AppImage of the latest
# stable GitHub release, as JSON on stdout. Logs go to stderr.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# releases/latest excludes prereleases and drafts.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        https://api.github.com/repos/audacity/audacity/releases/latest)"

# Tags look like Audacity-4.0.1; accept any dotted version so 4.1 or 4.0.2.1
# don't stop updates.
version="$(jq -r '.tag_name | capture("^Audacity-(?<v>[0-9]+(\\.[0-9]+)+)$").v // empty' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r --arg v "$version" \
        '.assets[] | select(.name == ("audacity-linux-" + $v + "-x86_64.AppImage")) | .browser_download_url' \
        <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] \
    || { echo "failed to resolve audacity release (tag $(jq -r .tag_name <<<"$rel"))" >&2; exit 1; }
echo "resolved audacity $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg r "$(jq -r .html_url <<<"$rel")" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[{filename:"audacity.AppImage", arch:"x86_64", url:$u}]}'
