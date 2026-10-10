#!/usr/bin/env bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"

# Usage: scan-registry.sh [--ids] [--arch <arch>] [app-id...]
# --arch keeps only the apps whose build.arches include <arch>, which is how a
# per-arch build job picks its share of a changed-apps list.
ids_only=0
arch=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --ids)  ids_only=1; shift ;;
        --arch) arch="${2:?--arch needs a value}"; shift 2 ;;
        *)      break ;;
    esac
done

if [ "$#" -gt 0 ]; then
    apps=("$@")
else
    apps=()
    for record in "$REGISTRY_DIR"/*/flatpark.yml; do
        [ -e "$record" ] || die "no app registry entries in $REGISTRY_DIR"
        apps+=("$(basename "$(dirname "$record")")")
    done
fi

for app_id in "${apps[@]}"; do
    load_app "$app_id"
    if [ -n "$arch" ] && ! app_has_arch "$arch"; then
        continue
    fi
    if [ "$ids_only" = "1" ]; then
        printf '%s\n' "$APP_ID"
    else
        printf '%s\t%s\t%s\t%s\n' "$APP_ID" "$APP_BRANCH" "$UPDATE_MODE" "$MANIFEST"
    fi
done
