#!/usr/bin/env bash
# Reconcile the local OSTree repo (REPO_DIR) with R2, the authoritative copy.
# The mirror image of sync-r2.sh, shared by publish and delist-prune.
#
# REPO_DIR may start empty (a full pull) or as an actions/cache restore of an
# earlier run; either way it ends identical to R2. That is why both calls are
# sync, not copy: objects and refs a delist-prune removed from R2 must also
# leave a cached copy, or they get re-signed into the summary and re-uploaded.
# objects/ are content-addressed (same name => same bytes), so a size compare
# is enough. Everything else (refs, summary, config) is mutable and often
# same-size, so compare by checksum. No `|| true`: with a cache-restored base,
# a half-failed pull would mean working on a stale repo — better to fail the
# run and retry.
#
# Pulls are many small objects, so latency rather than bandwidth bounds them:
# hence the high parallelism. --stats prints a progress line every minute
# (object count, rate) without listing each file.
#
# rclone must have an R2 (S3) remote configured; in CI that is done with
# RCLONE_CONFIG_<REMOTE>_* env vars. Required: R2_BUCKET. Optional: R2_REMOTE
# (default r2).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
need rclone
repo="${1:-$REPO_DIR}"
remote="${R2_REMOTE:-r2}"
bucket="${R2_BUCKET:?set R2_BUCKET (the R2 bucket name)}"
src="$remote:$bucket"

FLAGS=(--fast-list --transfers=32 --checkers=64 --stats=1m --stats-log-level=NOTICE)

mkdir -p "$repo"
log "pull objects <- $src"
rclone sync "$src/objects" "$repo/objects" --size-only "${FLAGS[@]}"
log "pull refs/summary/config <- $src"
rclone sync "$src" "$repo" --exclude "objects/**" --checksum "${FLAGS[@]}"
log "R2 pull complete -> $repo"
