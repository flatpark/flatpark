#!/usr/bin/env bash
# Publish PR <N>'s test repository to pr/<N>/ from the artifacts of its
# pr-checks run (#585).
#
#   TEST_REPO_HEAD_SHA=<sha> [TEST_REPO_RUN_ID=<id>] test-repo-publish.sh <pr> <artifact-dir>...
#
# Each artifact dir holds the one tar a pr-checks leg uploaded: the archive-z2
# OSTree repo build-app.sh exported, signed with a throwaway key. It comes from
# the PR's own code, so nothing in it is trusted:
#
#   1. the tar is listed and rejected if it could write outside its dir, then
#      extracted without owners or modes;
#   2. only the refs of the apps this PR's diff touches (pulls/N/files) are
#      taken, every other ref is ignored;
#   3. those refs are `pull-local --untrusted`ed (checksums verified) into a
#      fresh repo, which drops everything else in the artifact, and the
#      artifact's detached metadata (its throwaway signatures) is dropped;
#   4. the commits and summary are signed with the testing key only.
#
# Called by test-repo-reconcile.sh, which picks the run; usable alone (and by
# the e2e) with artifacts downloaded by hand. TEST_REPO_HEAD_SHA is the commit
# the run built: nothing is uploaded unless it is still the PR's head.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
. "$ROOT/scripts/lib/test-repo.sh"
need gh; need jq; need python3; need tar; need ostree; need flatpak; need gpg; need rclone; need base64

usage="usage: TEST_REPO_HEAD_SHA=<sha> test-repo-publish.sh <pr> <artifact-dir>..."
pr="${1:?$usage}"; shift
[ "$#" -gt 0 ] || die "$usage"
tr_is_pr_number "$pr" || die "not a PR number: $pr"
head="${TEST_REPO_HEAD_SHA:?$usage}"
run_id="${TEST_REPO_RUN_ID:-}"
tr_init

# Still open, labeled and at the commit these artifacts were built from.
still_current() {
    tr_pr_load "$pr"
    tr_pr_live && [ "$(tr_pr_head)" = "$head" ]
}
still_current || { log "PR #$pr is not open+labeled at $head; not publishing"; exit 0; }

ids="$(tr_pr_app_ids "$pr")"
[ -n "$ids" ] || die "PR #$pr touches no registry/<id>/; nothing may be published for it"
log "PR #$pr apps: ${ids//$'\n'/ }"

# 1. Extract and check every artifact.
srcs=()
i=0
for d in "$@"; do
    mapfile -t tars < <(find "$d" -maxdepth 1 -type f -name '*.tar')
    [ "${#tars[@]}" -eq 1 ] || die "$d: expected one .tar, found ${#tars[@]}"
    src="$(tr_extract_repo "${tars[0]}" "$TR_TMP/src$i")" || exit 1
    srcs+=("$src")
    i=$((i + 1))
done

# 2 + 3. Only the PR's own refs, re-pulled into a clean repo.
repo="$TR_TMP/repo"
ostree --repo="$repo" init --mode=archive-z2
declare -A seen=()
allowed=()
for src in "${srcs[@]}"; do
    while IFS= read -r ref; do
        [ -n "$ref" ] || continue
        if ! tr_ref_allowed "$ref" "$ids"; then
            log "ignoring ref $ref: not one of PR #$pr's apps"
            continue
        fi
        if [ -n "${seen[$ref]:-}" ]; then
            warn "ref $ref is in more than one artifact; keeping the first"
            continue
        fi
        ostree --repo="$repo" pull-local --untrusted "$src" "$ref"
        seen[$ref]=1
        allowed+=("$ref")
    done < <(ostree --repo="$src" refs)
done
[ "${#allowed[@]}" -gt 0 ] || die "no ref of PR #$pr's apps (${ids//$'\n'/ }) in the artifacts"
mapfile -t allowed < <(printf '%s\n' "${allowed[@]}" | sort)

# 4. Sign with the testing key alone. The artifact's detached metadata holds
# only what the untrusted run put there (its throwaway signature); drop it so
# the testing signature is the only one.
tr_import_testing_key
for ref in "${allowed[@]}"; do
    c="$(ostree --repo="$repo" rev-parse "$ref")"
    rm -f "$repo/objects/${c:0:2}/${c:2}.commitmeta"
    ostree --repo="$repo" gpg-sign --gpg-homedir="$TR_GNUPG" "$c" "$TR_FPR"
    log "signed $ref ($c)"
done
tr_update_repo "$repo" "$pr"

# 5. Discovery files, the same fields gen-discovery.sh writes.
url="$(tr_pr_url "$pr")"
remote="$(tr_remote_name "$pr")"
gpgkey_b64="$(base64 -w0 < "$TR_PUBKEY_BIN")"
cat > "$repo/$remote.flatpakrepo" <<EOF
[Flatpak Repo]
Title=FlatPark PR #$pr test build
Url=$url
Homepage=https://github.com/$TR_REPO/pull/$pr
Icon=$REPO_ICON
Comment=Test build of FlatPark PR #$pr. Not for everyday use.
GPGKey=$gpgkey_b64
EOF
for ref in "${allowed[@]}"; do
    case "$ref" in
        app/*) is_runtime=false ;;
        runtime/*.Locale/*|runtime/*.Debug/*) continue ;;
        runtime/*) is_runtime=true ;;
    esac
    IFS=/ read -r _ id _ branch <<<"$ref"
    cat > "$repo/$id.flatpakref" <<EOF
[Flatpak Ref]
Name=$id
Branch=$branch
Title=$id (PR #$pr test build)
Url=$url
SuggestRemoteName=$remote
RuntimeRepo=$RUNTIME_REPO_URL
GPGKey=$gpgkey_b64
IsRuntime=$is_runtime
EOF
done
printf '%s\n' "$head" > "$repo/built-from"

# 6 + 7. Upload, between two checks that the PR still wants it.
still_current || { log "PR #$pr changed while building (closed, unlabeled or pushed); not uploading"; exit 0; }
tr_upload "$repo" "$pr" publish
if ! still_current; then
    log "PR #$pr changed during the upload; reconciling it"
    "$ROOT/scripts/test-repo-reconcile.sh" "$pr"
    exit $?
fi
log "published PR #$pr: $url"

# 8. The comment.
table="$(printf '%s\n' "${allowed[@]}" | tr_id_arch_table)"
tr_put_comment "$pr" "$(tr_body_live "$pr" "$head" "$run_id" "$TR_FPR" "$table")"
