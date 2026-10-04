#!/usr/bin/env bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
need node
need npm

: "${SITE_DIR:=$ROOT/site}"

# 1. Registry -> catalog.json + base apps/<id>.json (+ icons).
"$ROOT/scripts/gen-apps-json.sh" "$@"

# 2. Install site deps once (enrichment + build both need them).
if [ ! -d "$SITE_DIR/node_modules" ]; then
    log "installing site dependencies"
    ( cd "$SITE_DIR" && npm install --no-audit --no-fund )
fi

# 3. Enrich each app file from the developer repo (manifest/metainfo/flatpark.yml),
# plus the published install counts.
( cd "$SITE_DIR" && FLATPARK_STATS_URL="$STATS_URL" node tools/enrich.mjs )

# 4. Build the static site into PAGES_DIR. SITE_URL feeds the sitemap and
# canonical/absolute URLs; keep it single-sourced from REPO_HOMEPAGE.
log "building site -> $PAGES_DIR"
( cd "$SITE_DIR" \
    && SITE_OUT_DIR="$PAGES_DIR" SITE_URL="${REPO_HOMEPAGE:-https://flatpark.org}" \
        npm run build )

# Keep R2 lean: publish only what must be self-hosted. Detail pages are
# pre-rendered, so the per-app JSON is build-time only — strip it from the
# output. catalog.json stays (drives client-side search). Screenshots are
# downloaded + recompressed to webp under public/screenshots/ by enrich, so
# Astro copies them into the published tree (fast local serving, no upstream
# timeouts); only a failed fetch falls back to a hotlink.
rm -f "$PAGES_DIR/apps/"*.json
# Astro's 404.astro special case only fires at the pages root, so a locale's
# not-found page lands at <locale>/404/index.html. Cloudflare Pages walks up
# from a missing path looking for <dir>/404.html, so move it where Pages looks.
for notfound in "$PAGES_DIR"/*/404/index.html; do
    [ -e "$notfound" ] || continue
    dir="$(dirname "$notfound")"
    mv "$notfound" "$(dirname "$dir")/404.html"
    rmdir "$dir"
done
# Astro's content layer leaves empty module stubs in the output root; they are
# never linked from any page, so drop them from the published tree.
rm -f "$PAGES_DIR/content-assets.mjs" "$PAGES_DIR/content-modules.mjs"
log "wrote $PAGES_DIR"
