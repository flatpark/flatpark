#!/usr/bin/env bash
# Drop refs whose commit object is not in the repo, and record the ref files so
# the caller can delete the same paths from R2 (see sync-r2.sh RECLAIM_REFS).
#
# Why this exists: sync-r2.sh uploads refs with `rclone copy`, which never
# deletes, so a ref that the cleanup workflow removed locally survives in R2. Once
# prune reclaims that commit's objects, the leftover ref file is a dangling
# pointer — and publish's R2 reconcile syncs it straight back into the local
# repo, where the next summary regeneration (flatpak build-export does one on
# export) hard-fails with "No such metadata object <commit>.commit". That wedges
# every publish, not just the one after the de-list.
#
# Deleting here stays within the "targeted delete, never a blind mirror" rule:
# only refs whose commit object is provably absent are touched, and the local
# object store is an exact copy of R2's at this point in the run.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
need ostree
repo="${1:-$REPO_DIR}"
[ -d "$repo/objects" ] || die "not an ostree repo: $repo"
# Object stores do not preserve empty directories; R2 omits refs/remotes/ when
# it is empty and `ostree refs` fails without it.
mkdir -p "$repo/refs/remotes" "$OUT_DIR"

# Truncated, not appended: this sweep runs first and owns the list;
# prune-and-reclaim.sh appends the refs it delists to the same file.
reclaim_refs="${RECLAIM_REFS:-$OUT_DIR/reclaim-refs.txt}"
: > "$reclaim_refs"

dropped=0
while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    case "$ref" in *:*) continue ;; esac      # remote ref, not ours to touch
    commit="$(ostree --repo="$repo" rev-parse "$ref" 2>/dev/null || true)"
    [ -n "$commit" ] \
        && [ -f "$repo/objects/${commit:0:2}/${commit:2}.commit" ] \
        && continue
    warn "dangling ref $ref -> ${commit:-<unreadable>}: commit object missing, dropping"
    # Queue the R2 delete only for a ref whose app left the registry — that is
    # the one case where the leftover file is provably garbage. A live app with
    # a dangling ref (a half-finished object sync, say) is only dropped locally:
    # its next build re-exports the ref and overwrites R2's copy, so a bad sync
    # can never cost us a published pointer.
    if ref_is_delisted "$ref"; then
        # Record the file that actually holds the ref (heads or mirrors), so the
        # R2 delete targets the same key the reconcile would pull back down.
        for base in refs/heads refs/mirrors; do
            [ -f "$repo/$base/$ref" ] && printf '%s\n' "$base/$ref" >> "$reclaim_refs"
        done
    else
        warn "keeping R2's copy of $ref: still in the registry, a rebuild will replace it"
    fi
    ostree --repo="$repo" refs --delete "$ref"
    dropped=$((dropped + 1))
done < <(ostree --repo="$repo" refs)

log "dangling refs dropped: $dropped -> $reclaim_refs"
printf '%s\n' "$reclaim_refs"
