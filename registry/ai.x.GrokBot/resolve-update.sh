#!/usr/bin/env bash
# Update resolver for Grok Bot.
#
# Resolves the official Linux x86_64 and aarch64 .deb downloads from the same
# api2.cursor.sh redirect endpoints used by https://x.ai/bot, and emits JSON on
# stdout (logs on stderr):
#   { "version": "1.2.3", "releaseDate": "YYYY-MM-DD",
#     "sources": [
#       { "filename": "grok-bot.deb", "arch": "x86_64",  "url": "..." },
#       { "filename": "grok-bot.deb", "arch": "aarch64", "url": "..." }
#     ] }
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

endpoint_x64="https://api2.cursor.sh/updates/download/stable/linux-x64/grok-bot-fb0a830618be0c54"
endpoint_arm="https://api2.cursor.sh/updates/download/stable/linux-arm64/grok-bot-922bf0a2bf7ebaa3"

resolve_location() {
  curl -fsSI "$1" | sed -n 's/^[Ll]ocation:[[:space:]]*//p' | tr -d '\r' | tail -n 1
}

url_x64="$(resolve_location "$endpoint_x64")"
url_arm="$(resolve_location "$endpoint_arm")"

[ -n "$url_x64" ] || { echo "failed to resolve x86_64 .deb redirect from $endpoint_x64" >&2; exit 1; }
[ -n "$url_arm" ] || { echo "failed to resolve aarch64 .deb redirect from $endpoint_arm" >&2; exit 1; }

# Constrain redirects to upstream's official download host so an unexpected
# redirect fails loudly instead of re-pinning unattended from another host.
case "$url_x64" in
  https://downloads.cursor.com/grokbot/stable/*/linux/x64/grok-bot_*_amd64.deb) ;;
  *) echo "refusing unexpected x86_64 download URL: $url_x64" >&2; exit 1 ;;
esac
case "$url_arm" in
  https://downloads.cursor.com/grokbot/stable/*/linux/arm64/grok-bot_*_arm64.deb) ;;
  *) echo "refusing unexpected aarch64 download URL: $url_arm" >&2; exit 1 ;;
esac

base_x64="${url_x64##*/}"
base_arm="${url_arm##*/}"
version="${base_x64#grok-bot_}"
version="${version%_amd64.deb}"
version_arm="${base_arm#grok-bot_}"
version_arm="${version_arm%_arm64.deb}"

[ -n "$version" ] && [ "$version" = "$version_arm" ] || {
  echo "version mismatch between x86_64 ($version) and aarch64 ($version_arm)" >&2
  exit 1
}

last_modified="$(curl -fsSI "$url_x64" | sed -n 's/^[Ll]ast-[Mm]odified:[[:space:]]*//p' | tr -d '\r' | tail -n 1 || true)"
date="$(date -u -d "$last_modified" +%Y-%m-%d 2>/dev/null || date -u +%Y-%m-%d)"

echo "resolved Grok Bot $version ($date): $url_x64" >&2

jq -n --arg v "$version" --arg d "$date" --arg ux "$url_x64" --arg ua "$url_arm" \
  '{version:$v, releaseDate:$d, sources:[
     {filename:"grok-bot.deb", arch:"x86_64",  url:$ux},
     {filename:"grok-bot.deb", arch:"aarch64", url:$ua}
   ]}'
