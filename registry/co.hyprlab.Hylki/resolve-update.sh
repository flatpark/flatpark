#!/usr/bin/env bash
# Update resolver for Hylki.
#
# Prints the latest stable release and its amd64 and arm64 .debs as JSON:
#   { "version": "1.47.1", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "hylki.deb", "arch": "x86_64", "url": "..." },
#                  { "filename": "hylki.deb", "arch": "aarch64", "url": "..." } ] }
# Logs go to stderr. Only the stable channel is followed: upstream publishes
# betas as GitHub pre-releases (v1.48.0-beta.2), which /releases/latest skips;
# a tag that still looks like a pre-release is refused as well.
set -euo pipefail

repo="hyprlab/hylki"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

tag="$(jq -r '.tag_name' <<<"$rel")"
version="${tag#v}"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
[[ "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]] && [ "$(jq -r '.prerelease' <<<"$rel")" = "false" ] ||
    { echo "latest release $tag is not a stable version" >&2; exit 1; }

# The release carries .debs, .rpms, AppImages and Flatpak bundles for x86_64
# and aarch64. Match the amd64 .deb of this version exactly, with its Debian
# revision, and require exactly one; the arm64 .deb must carry the same
# revision.
debs="$(jq -r --arg v "$version" \
        '.assets[] | select(.name | test("^hylki_" + ($v | gsub("\\."; "\\.")) + "-[0-9]+_amd64\\.deb$")) | .name + " " + .browser_download_url' \
        <<<"$rel")"
[ -n "$debs" ] && [ "$(wc -l <<<"$debs")" -eq 1 ] ||
    { echo "expected exactly one amd64 .deb in $tag, found: ${debs:-none}" >&2; exit 1; }
name="${debs%% *}"
url="${debs#* }"

# A re-cut .deb under a new Debian revision (hylki_X-2_amd64.deb) has to
# compare newer than the first one, so a revision above 1 joins the version.
revision="${name#hylki_"$version"-}"
revision="${revision%%_*}"
[ "$revision" = "1" ] || version="$version-$revision"

arm_name="${name%_amd64.deb}_arm64.deb"
url_arm="$(jq -r --arg n "$arm_name" '.assets[] | select(.name == $n) | .browser_download_url' \
        <<<"$rel" | head -n1)"
[ -n "$url_arm" ] || { echo "no $arm_name in $tag" >&2; exit 1; }

echo "resolved hylki $version ($date): $url $url_arm" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg ua "$url_arm" \
  '{version:$v, releaseDate:$d, sources:[{filename:"hylki.deb", arch:"x86_64", url:$u}, {filename:"hylki.deb", arch:"aarch64", url:$ua}]}'
