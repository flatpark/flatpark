#!/usr/bin/env bash
# Regenerate app data, then batch-check every external URL the site hotlinks,
# plus every extra-data download the manifests pin (the URL must answer and its
# Content-Length must still match the pinned size). Exits non-zero if any link
# is broken. Usage:
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
# The extra-data pins live in the manifests, not in the site data, so they are
# listed here: one TSV line (app, url, size) per pin on each arch the app is
# published for. Nothing else verifies a pin while its version stands still —
# PR checks download a payload only when its sha256 changes — so an upstream
# that deletes or re-uploads a file goes unnoticed until installs fail.
pins="$(mktemp)"; trap 'rm -f "$pins"' EXIT
if [ "${#appids[@]}" -gt 0 ]; then pin_ids=("${appids[@]}")
else mapfile -t pin_ids < <("$ROOT/scripts/scan-registry.sh" --ids); fi
for id in "${pin_ids[@]}"; do
    load_app "$id"
    [ "$UPDATE_MODE" = "extra-data" ] || continue
    for arch in $APP_ARCHES; do
        node "$ROOT/scripts/read-extra-data.mjs" "$MANIFEST" "$arch" \
            | awk -F'\t' -v id="$id" '$1 == "extra" {print id "\t" $3 "\t" $5}' >> "$pins" \
            || die "$id: cannot read the extra-data pins of $MANIFEST"
    done
done
( cd "$SITE_DIR" && LINK_CHECK_EXTRA_DATA="$pins" node tools/check-links.mjs $json )
