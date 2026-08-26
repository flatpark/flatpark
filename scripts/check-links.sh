#!/usr/bin/env bash
# Regenerate app data, then batch-check every external URL the site hotlinks.
# Exits non-zero if any link is broken. Usage:
#   scripts/check-links.sh [--json] [app-id ...]
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
need node
: "${SITE_DIR:=$ROOT/site}"

json=""
appids=()
for a in "$@"; do
    case "$a" in
        --json) json="--json" ;;
        *) appids+=("$a") ;;
    esac
done

"$ROOT/scripts/gen-apps-json.sh" ${appids[@]+"${appids[@]}"}

if [ ! -d "$SITE_DIR/node_modules" ]; then
    need npm
    ( cd "$SITE_DIR" && npm install --no-audit --no-fund )
fi

# Link checking only needs the URLs enrichment pulls out of the metainfo; the
# git listing dates it also computes are irrelevant here, so a shallow checkout
# (link-check.yml uses the default depth) is fine and must not be rejected.
( cd "$SITE_DIR" && FLATPARK_ALLOW_SHALLOW=1 node tools/enrich.mjs )
( cd "$SITE_DIR" && node tools/check-links.mjs $json )
