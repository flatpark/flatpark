#!/usr/bin/env bash
# Update resolver for darktable: the official x86_64 and aarch64 AppImages of
# the latest stable GitHub release, as JSON on stdout. Logs go to stderr.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# releases/latest excludes the rolling "nightly" prerelease.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        https://api.github.com/repos/darktable-org/darktable/releases/latest)"

# Tags look like release-5.6.2.
version="$(jq -r '.tag_name | capture("^release-(?<v>[0-9]+(\\.[0-9]+)+)$").v // empty' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
asset() {
    jq -r --arg n "Darktable-$version-$1.AppImage" \
        '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel" | head -n1
}
x86="$(asset x86_64)"
arm="$(asset aarch64)"

[ -n "$version" ] && [ -n "$x86" ] && [ -n "$arm" ] \
    || { echo "failed to resolve darktable release (tag $(jq -r .tag_name <<<"$rel"))" >&2; exit 1; }
echo "resolved darktable $version ($date)" >&2

jq -n --arg v "$version" --arg d "$date" --arg x "$x86" --arg a "$arm" --arg r "$(jq -r .html_url <<<"$rel")" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[
     {filename:"darktable.AppImage", arch:"x86_64", url:$x},
     {filename:"darktable.AppImage", arch:"aarch64", url:$a}]}'
