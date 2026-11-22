#!/usr/bin/env bash
# Publish the local OSTree repo (REPO_DIR) + discovery files to R2 with rclone.
#
# Ordering matters: content-addressed objects go up FIRST (and are cached
# forever), the mutable `summary` pointer goes up LAST, so a client never reads
# a summary that references objects not yet uploaded. With RECLAIM_REFS /
# RECLAIM_LIST set, the stale ref files and the orphaned objects listed there
# are deleted AFTER the new summary is live — refs before the objects they name
# (see prune-and-reclaim.sh and drop-dangling-refs.sh).
#
# The uploads are additive on purpose (copy, not sync), so deletions only ever
# happen through those two explicit lists — never as a mirror side effect. The
# one exception is summaries/, which PRUNE_SUMMARIES=1 (cleanup only)
# mirrors to the set the freshly written summary.idx references.
#
# rclone must have an R2 (S3) remote configured; in CI that is done with
# RCLONE_CONFIG_<REMOTE>_* env vars. Required: R2_BUCKET. Optional: R2_REMOTE
# (default r2), RECLAIM_LIST, RECLAIM_REFS, PRUNE_SUMMARIES.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
need rclone
repo="${1:-$REPO_DIR}"
[ -d "$repo" ] || die "repo dir not found: $repo"
remote="${R2_REMOTE:-r2}"
bucket="${R2_BUCKET:?set R2_BUCKET (the R2 bucket name)}"
dest="$remote:$bucket"

IMMUTABLE="Cache-Control: public, max-age=31536000, immutable"
# s-maxage lets the Cloudflare edge (a cache rule on dl.flatpark.org that
# follows origin headers, see docs/reference/infrastructure.md) answer the hot
# mutable files — summary.idx, config, summaries/, *.commitmeta — for 60 s
# instead of revalidating every request against R2, which is billed per read.
# Clients still get max-age=0. A minute of staleness is safe because of the
# upload order below: every file an edge-held summary.idx names is still in R2,
# and every file a fresh one names went up before it. The free plan cannot set
# an edge TTL under 2 h in the rule itself, hence the header.
MUTABLE="Cache-Control: public, max-age=0, s-maxage=60, must-revalidate"
FLAGS=(--fast-list --transfers=16 --checkers=32)
# How the mutable uploads decide what to send: by content, normally. rclone
# never rewrites the headers of a file whose bytes are unchanged, so after
# MUTABLE changes, REWRITE_HEADERS=1 (a publish dispatch input) re-uploads
# every mutable file once — config and old commits' commitmeta otherwise keep
# the old header for good. A few thousand small PUTs.
if [ "${REWRITE_HEADERS:-}" = 1 ]; then
    MUTABLE_CMP=(--ignore-times)
    log "REWRITE_HEADERS=1: re-uploading every mutable file to refresh its headers"
else
    MUTABLE_CMP=(--checksum)
fi

log "sync objects -> $dest (immutable)"
# Content-addressed: same name => same bytes, so --size-only is safe and fast.
# Except *.commitmeta: a commit's detached metadata holds its signatures, and
# backfilling a new key during a rotation (publish-repo.sh) rewrites it in
# place. It is compared by content and gets the short MUTABLE edge TTL, not
# the immutable one, or the edge keeps serving the old signatures for a year
# and a client that trusts only the new key cannot verify commits nothing
# rebuilt. It goes up with the objects, before the summary that names its
# commit.
rclone copy "$repo/objects" "$dest/objects" --size-only --exclude "*.commitmeta" --header-upload "$IMMUTABLE" "${FLAGS[@]}"
rclone copy "$repo/objects" "$dest/objects" "${MUTABLE_CMP[@]}" --include "*.commitmeta" --header-upload "$MUTABLE" "${FLAGS[@]}"
[ -d "$repo/deltas" ] && rclone copy "$repo/deltas" "$dest/deltas" --size-only --header-upload "$IMMUTABLE" "${FLAGS[@]}"

log "sync refs/config/discovery -> $dest (revalidate)"
rclone copy "$repo/refs" "$dest/refs" "${MUTABLE_CMP[@]}" --header-upload "$MUTABLE" "${FLAGS[@]}"
rclone copy "$repo" "$dest" --max-depth 1 "${MUTABLE_CMP[@]}" --header-upload "$MUTABLE" "${FLAGS[@]}" \
    --include "config" --include "*.flatpakrepo" --include "*.flatpakref" --include "*.pub.asc"

log "sync summary -> $dest (LAST, revalidate)"
# Referenced blobs before the pointers that name them: a client that reads a
# fresh summary.idx must find every summaries/<digest>.gz it lists, so the
# digested summaries (and the signature) go up first and the idx strictly last.
[ -d "$repo/summaries" ] && rclone copy "$repo/summaries" "$dest/summaries" "${MUTABLE_CMP[@]}" --header-upload "$MUTABLE" "${FLAGS[@]}"
rclone copy "$repo" "$dest" --max-depth 1 "${MUTABLE_CMP[@]}" --header-upload "$MUTABLE" "${FLAGS[@]}" \
    --include "summary" --include "summary.sig"
rclone copy "$repo" "$dest" --max-depth 1 "${MUTABLE_CMP[@]}" --header-upload "$MUTABLE" "${FLAGS[@]}" \
    --include "summary.idx"

# The summaries upload above is additive, so every publish leaves its
# <digest>.gz and <history>-<digest>.delta files in R2 (~75 KB each).
# `flatpak build-update-repo` already trimmed the local summaries/ to exactly
# what the new summary.idx needs (the current and history digests, plus the
# deltas into the current one), so with PRUNE_SUMMARIES=1 (cleanup only)
# mirror that set now that the idx is live. A client still holding the
# previous idx is fine: that idx's digest is in the new history and is kept,
# and a missing delta makes flatpak fall back to it. Skipped unless the local
# set holds a digested summary, so a missing or empty dir can never wipe R2.
if [ "${PRUNE_SUMMARIES:-}" = 1 ] && [ -f "$repo/summary.idx" ] \
    && compgen -G "$repo/summaries/*.gz" >/dev/null; then
    log "prune summaries/ in $dest to the set summary.idx references"
    rclone sync "$repo/summaries" "$dest/summaries" --checksum --header-upload "$MUTABLE" "${FLAGS[@]}"
fi

# The reclaim lists hold repo-relative paths (refs/..., objects/...), which is
# what --files-from wants against the bucket root. One rclone process deleting
# in parallel, not one process per key: 7515 sequential deletefile calls took
# 96 minutes on 2026-10-17. --no-traverse stats each listed key instead of
# listing the bucket, and a key that is already gone is skipped, not an error.
# Plain --files-from (not -raw) skips blank lines; no ref or object name holds
# whitespace or a leading #.
DELETE_FLAGS=(--no-traverse --checkers=64 --stats=1m --stats-log-level=NOTICE)

if [ -n "${RECLAIM_REFS:-}" ] && [ -s "$RECLAIM_REFS" ]; then
    n="$(wc -l < "$RECLAIM_REFS" | tr -d ' ')"
    log "reclaim: deleting $n stale ref file(s) from $dest"
    # Before the objects below: a ref file R2 still serves must never outlive
    # the commit it points at, or the next publish pulls a dangling ref back.
    rclone delete "$dest" --files-from "$RECLAIM_REFS" "${DELETE_FLAGS[@]}" \
        || warn "some stale refs could not be deleted"
fi

if [ -n "${RECLAIM_LIST:-}" ] && [ -s "$RECLAIM_LIST" ]; then
    n="$(wc -l < "$RECLAIM_LIST" | tr -d ' ')"
    log "reclaim: deleting $n orphaned object(s) from $dest"
    rclone delete "$dest" --files-from "$RECLAIM_LIST" "${DELETE_FLAGS[@]}" \
        || warn "some orphaned objects could not be deleted"
fi

log "R2 sync complete -> $dest"
