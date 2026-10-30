#!/usr/bin/env bash
# Run each app's update resolver, recompute its extra-data pins + metainfo
# release, and rewrite them in place. Prints the ids of apps that changed (one
# per line) — the update workflow turns those into a PR.
# Does NOT commit or open a PR itself.
#
# A resolver or pin rewrite that fails leaves the app on its current pin and
# only logs a warning, so a run where half the registry failed still looks
# clean. With FAILED_OUT set, each failure is also appended to that file as
# `<id>\t<reason>` (the reason is the last stderr line), which is what the
# update workflow turns into its resolver-failure alert.
#
# An app with `update.auto: false` is skipped too: its upstream opens the
# update PR itself and a pin-only refresh would race it. FORCE=1 runs its
# resolver anyway, for when that upstream PR doesn't come.
#
# Usage: [FORCE=1] check-updates.sh [app-id ...]   (default: every app with an update cmd)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
need node

apps=()
while IFS= read -r id; do apps+=("$id"); done < <("$ROOT/scripts/scan-registry.sh" --ids "$@")
[ "${#apps[@]}" -gt 0 ] || die "registry scan returned no apps"

# record_failure <id> <reason>
record_failure() {
    [ -n "${FAILED_OUT:-}" ] || return 0
    printf '%s\t%s\n' "$1" "$(printf '%s' "$2" | tr '\t\n' '  ')" >> "$FAILED_OUT"
}
errf="$(mktemp)"; trap 'rm -f "$errf"' EXIT

changed=()
for id in "${apps[@]}"; do
    load_app "$id"
    [ -n "${APP_UPDATE_COMMAND:-}" ] || { log "$id: no update command, skipping"; continue; }
    [ "$APP_UPDATE_AUTO" != false ] || [ "${FORCE:-}" = 1 ] ||
        { log "$id: update.auto is false (upstream sends the PR), skipping"; continue; }
    [ -f "$MANIFEST" ] || { warn "$id: manifest not found ($MANIFEST)"; continue; }

    log "$id: resolving via $APP_UPDATE_COMMAND"
    if ! resolver_json="$( cd "$APP_SRC" && eval "$APP_UPDATE_COMMAND" 2>"$errf" )"; then
        cat "$errf" >&2
        warn "$id: resolver failed"
        record_failure "$id" "resolver failed: $(grep -v '^[[:space:]]*$' "$errf" | tail -n1)"
        continue
    fi
    cat "$errf" >&2

    metainfo="$APP_SRC/$APP_ID.metainfo.xml"
    set +e
    version="$(printf '%s' "$resolver_json" | node "$ROOT/scripts/update-pins.mjs" "$MANIFEST" "$metainfo" 2>"$errf")"
    rc=$?
    set -e
    cat "$errf" >&2
    case "$rc" in
        0)  log "$id: pins updated -> ${version:-?}"; changed+=("$id") ;;
        10) log "$id: up to date" ;;
        *)  warn "$id: update-pins failed (exit $rc)"
            record_failure "$id" "update-pins failed (exit $rc): $(grep -v '^[[:space:]]*$' "$errf" | tail -n1)" ;;
    esac
done

printf '%s\n' "${changed[@]}"
