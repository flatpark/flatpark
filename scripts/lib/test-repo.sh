#!/usr/bin/env bash
# shellcheck disable=SC2034  # TR_* state is read by the scripts that source this
# Shared by the per-PR test repository scripts (#585): test-repo-plan.sh,
# test-repo-reconcile.sh and test-repo-publish.sh. Source lib/common.sh first.
#
# A PR labeled needs-testers gets an OSTree repository of its own at
# https://test.flatpark.org/pr/<N>/ (bucket flatpark-testing), built from the
# PR's pr-checks artifacts and signed with the FlatPark *testing* key. State
# rule: pr/<N>/ is live iff PR N is open and labeled; otherwise it is retired
# (every ref end-of-lifed, a `retired` marker written) and, after
# TEST_REPO_RETIRE_DAYS, purged. Every job handles exactly one PR and touches
# only pr/<N>/. See docs/reference/infrastructure.md.
#
# Env: GITHUB_REPOSITORY (owner/repo), GH_TOKEN for gh. Optional:
#   TEST_REPO_BASE_URL     public URL of the bucket (default https://test.flatpark.org/)
#   TEST_REPO_REMOTE       rclone remote (default r2)
#   TEST_REPO_BUCKET       bucket (default flatpark-testing)
#   TEST_REPO_RETIRE_DAYS  days a retired prefix is kept before purge (default 14)
#   TEST_REPO_PUBKEY       armored public testing key (default config/flatpark-testing.pub.asc)
#   TEST_REPO_DRY_RUN=1    print PR comments instead of posting them
#   FLATPAK_TESTING_GPG_KEY  armored secret testing key (signing only)

TR_MARKER='<!-- flatpark:test-repo -->'
TR_LABEL='needs-testers'
TR_APP_ID_RE='^[A-Za-z][A-Za-z0-9_-]*(\.[A-Za-z0-9_-]+){2,}$'
# Mutable and short: these prefixes are rewritten on every push and deleted
# when the PR closes, so the production one-year `immutable` header must never
# be used here.
TR_CACHE='Cache-Control: public, max-age=300'
TR_ARCHES='x86_64 aarch64'

tr_init() {
    load_config "$ROOT"
    TR_REPO="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is not set}"
    TR_BASE_URL="${TEST_REPO_BASE_URL:-https://test.flatpark.org/}"
    TR_BASE_URL="${TR_BASE_URL%/}/"
    TR_DEST="${TEST_REPO_REMOTE:-r2}:${TEST_REPO_BUCKET:-flatpark-testing}"
    TR_RETIRE_DAYS="${TEST_REPO_RETIRE_DAYS:-14}"
    TR_PUBKEY="${TEST_REPO_PUBKEY:-$ROOT/config/flatpark-testing.pub.asc}"
    TR_MAX_BYTES="${TEST_REPO_MAX_BYTES:-4294967296}"   # 4 GiB uncompressed per artifact
    TR_TMP="$(mktemp -d)"
    trap tr_cleanup EXIT
}

tr_cleanup() {
    if [ -n "${TR_GNUPG:-}" ]; then
        GNUPGHOME="$TR_GNUPG" gpgconf --kill all >/dev/null 2>&1 || true
    fi
    [ -n "${TR_TMP:-}" ] && rm -rf "$TR_TMP"
    return 0
}

tr_is_pr_number() { [[ "$1" =~ ^[1-9][0-9]{0,8}$ ]]; }
tr_remote_name()  { printf 'flatpark-pr%s\n' "$1"; }
tr_pr_url()       { printf '%spr/%s/\n' "$TR_BASE_URL" "$1"; }

# ---------------------------------------------------------------------------
# GitHub (always through gh, so the tests can stub it).

# Loads PR $1 into TR_PR_JSON. A PR that does not exist is {"state":"missing"};
# any other API failure is fatal, so a GitHub outage never reads as "closed"
# and retires a live repo.
tr_pr_load() {
    local out err="$TR_TMP/gh-err"
    if out="$(gh api "repos/$TR_REPO/pulls/$1" 2>"$err")"; then
        TR_PR_JSON="$out"
    elif grep -q 'HTTP 404' "$err" || grep -q '"Not Found"' <<<"$out"; then
        TR_PR_JSON='{"state":"missing"}'
    else
        cat "$err" >&2
        die "could not read PR #$1 from GitHub"
    fi
}
tr_pr_live()   { jq -e --arg l "$TR_LABEL" '.state == "open" and any(.labels[]?; .name == $l)' <<<"$TR_PR_JSON" >/dev/null; }
tr_pr_head()   { jq -r '.head.sha // empty' <<<"$TR_PR_JSON"; }
tr_pr_merged() { jq -e '.merged == true or (.merged_at // null) != null' <<<"$TR_PR_JSON" >/dev/null; }

# The registry ids PR $1 touches (registry/<id>/...), one per line. Only these
# can ever be published for the PR.
tr_pr_app_ids() {
    local files
    files="$(gh api "repos/$TR_REPO/pulls/$1/files?per_page=100" --paginate --jq '.[].filename')" \
        || die "could not list the files of PR #$1"
    printf '%s\n' "$files" | sed -n 's#^registry/\([^/]*\)/.*#\1#p' | sort -u \
        | { grep -E "$TR_APP_ID_RE" || true; }
}

# Creates or edits in place the one comment carrying TR_MARKER. An unchanged
# body is not re-sent, so a state that is re-decided every hour (no build yet)
# is commented once.
tr_put_comment() {
    local pr="$1" body="$2" existing old
    if [ "${TEST_REPO_DRY_RUN:-0}" = 1 ]; then
        printf '%s\n' "$body"
        return 0
    fi
    existing="$(gh api "repos/$TR_REPO/issues/$pr/comments?per_page=100" --paginate \
        --jq ".[] | select(.user.login == \"github-actions[bot]\") | select(.body | startswith(\"$TR_MARKER\")) | [.id, (.body | @base64)] | @tsv" \
        | head -n1)" || die "could not list the comments of PR #$pr"
    if [ -n "$existing" ]; then
        old="$(printf '%s' "${existing#*$'\t'}" | base64 -d)"
        if [ "$old" = "$body" ]; then
            log "PR #$pr comment already up to date"
            return 0
        fi
        gh api -X PATCH "repos/$TR_REPO/issues/comments/${existing%%$'\t'*}" -f body="$body" >/dev/null
        log "updated the test-repo comment on PR #$pr"
    else
        gh api -X POST "repos/$TR_REPO/issues/$pr/comments" -f body="$body" >/dev/null
        log "posted the test-repo comment on PR #$pr"
    fi
}

# ---------------------------------------------------------------------------
# Untrusted input: the artifacts of a pr-checks run, which the PR's own code
# produced.

# Unpacks the single .tar inside an artifact zip into dir $2. The zip must hold
# exactly one plain file name ending in .tar, at most TR_MAX_BYTES unpacked.
tr_unpack_artifact_zip() {
    mkdir -p "$2"
    python3 -I - "$1" "$2" "$TR_MAX_BYTES" <<'PY' || die "rejected artifact zip $1"
import os, re, shutil, sys, zipfile
src, dest, limit = sys.argv[1], sys.argv[2], int(sys.argv[3])
with zipfile.ZipFile(src) as z:
    infos = z.infolist()
    if len(infos) != 1:
        sys.exit(f"expected one file in the artifact, found {len(infos)}")
    i = infos[0]
    if not re.fullmatch(r"[A-Za-z0-9._-]+\.tar", i.filename) or i.is_dir():
        sys.exit(f"unexpected artifact member {i.filename!r}")
    if i.file_size > limit:
        sys.exit(f"{i.filename} is {i.file_size} bytes, over the {limit} limit")
    # ZipExtFile stops at the declared file_size, so this is bounded too.
    with z.open(i) as r, open(os.path.join(dest, i.filename), "xb") as w:
        shutil.copyfileobj(r, w, 1 << 20)
PY
}

# Rejects (dies on) a tar that could write outside the directory it is
# extracted into: absolute names, `..` components, a symlink target that is
# absolute or has a `..` component (so every link points at or below its own
# directory and none can escape, even chained), a hard link to such a name,
# device files and FIFOs, or more than TR_MAX_BYTES of content.
tr_check_tar() {
    python3 -I - "$1" "$TR_MAX_BYTES" <<'PY' || die "rejected tar $1"
import sys, tarfile
path, limit = sys.argv[1], int(sys.argv[2])
def bad(msg):
    sys.exit(f"unsafe member: {msg}")
def check_path(p, what):
    if p.startswith("/"):
        bad(f"absolute {what} {p!r}")
    if ".." in p.split("/"):
        bad(f"'..' in {what} {p!r}")
    if "\0" in p:
        bad(f"NUL in {what}")
total = 0
with tarfile.open(path, "r:*") as t:
    for m in t:
        check_path(m.name, "path")
        if m.issym():
            check_path(m.linkname, f"symlink target of {m.name}")
        elif m.islnk():
            check_path(m.linkname, f"hard link target of {m.name}")
        elif m.isdev() or m.isfifo():
            bad(f"device or FIFO {m.name!r}")
        elif not (m.isfile() or m.isdir()):
            bad(f"unsupported member type of {m.name!r}")
        total += max(m.size, 0)
        if total > limit:
            bad(f"more than {limit} bytes of content")
PY
}

# Extracts a checked tar into $2 and prints the OSTree repo inside it (the tar
# root, or its repo/ dir as pr-checks packs it). It has to be an archive-z2
# repo, and its config may not name a parent repo (which would make ostree
# read objects from elsewhere on this machine).
tr_extract_repo() {
    local tar="$1" dir="$2" repo
    tr_check_tar "$tar"
    mkdir -p "$dir"
    tar --no-same-owner --no-same-permissions -xf "$tar" -C "$dir" || die "could not extract $tar"
    repo="$dir/repo"; [ -f "$repo/config" ] || repo="$dir"
    [ -f "$repo/config" ] && [ ! -L "$repo/config" ] || die "$tar holds no OSTree repo"
    grep -qE '^[[:space:]]*parent[[:space:]]*=' "$repo/config" && die "$tar: repo config names a parent repo"
    [ "$(ostree --repo="$repo" config get core.mode 2>/dev/null)" = archive-z2 ] \
        || die "$tar: not an archive-z2 OSTree repo"
    printf '%s\n' "$repo"
}

# True when ref $1 may be published for a PR whose registry ids are the lines
# of $2: app/<id>/<arch>/<branch>, runtime/<id>/... (an extension) and the
# <id>.Locale / <id>.Debug runtimes, for a FlatPark arch and a plain branch.
tr_ref_allowed() {
    local ref="$1" ids="$2" kind name base
    [[ "$ref" =~ ^(app|runtime)/([^/]+)/(x86_64|aarch64)/([A-Za-z0-9._-]+)$ ]] || return 1
    kind="${BASH_REMATCH[1]}"; name="${BASH_REMATCH[2]}"
    base="$name"
    if [ "$kind" = runtime ]; then
        case "$name" in
            *.Locale) base="${name%.Locale}" ;;
            *.Debug)  base="${name%.Debug}" ;;
        esac
    fi
    [[ "$base" =~ $TR_APP_ID_RE ]] || return 1
    grep -qxF -- "$base" <<<"$ids"
}

# The registry id a ref belongs to (its .Locale / .Debug suffix dropped).
tr_ref_id() {
    local id="${1#*/}"; id="${id%%/*}"
    case "$id" in *.Locale) id="${id%.Locale}" ;; *.Debug) id="${id%.Debug}" ;; esac
    printf '%s\n' "$id"
}

# "<id>\t<arch> <arch>" per app or extension, from refs on stdin.
tr_id_arch_table() {
    awk -F/ '($1 == "app" || $1 == "runtime") && $2 !~ /\.(Locale|Debug)$/ { a[$2] = a[$2] ? a[$2] " " $3 : $3 }
             END { for (k in a) print k "\t" a[k] }' | sort
}

# ---------------------------------------------------------------------------
# Signing: a keyring of its own holding only the testing key, never the
# production one in $GNUPGHOME_DIR.

tr_import_testing_key() {
    local want got
    [ -n "${FLATPAK_TESTING_GPG_KEY:-}" ] || die "FLATPAK_TESTING_GPG_KEY is not set"
    [ -f "$TR_PUBKEY" ] || die "missing testing public key: $TR_PUBKEY"
    TR_GNUPG="$TR_TMP/gnupg"
    mkdir -m700 "$TR_GNUPG"
    export GNUPGHOME="$TR_GNUPG" GNUPGHOME_DIR="$TR_GNUPG"
    unset KEY_PASSPHRASE
    printf '%s\n' "$FLATPAK_TESTING_GPG_KEY" | gpg --batch --quiet --import 2>/dev/null \
        || die "could not import FLATPAK_TESTING_GPG_KEY"
    want="$(gpg --show-keys --with-colons "$TR_PUBKEY" 2>/dev/null | awk -F: '$1 == "fpr" { print $10; exit }')"
    got="$(signing_keys | awk '{ print $1 }')"
    [ -n "$want" ] && [ "$got" = "$want" ] \
        || die "FLATPAK_TESTING_GPG_KEY must hold exactly the key in $TR_PUBKEY ($want), got: ${got:-none}"
    TR_FPR="$want"
    TR_PUBKEY_BIN="$TR_TMP/testing.gpg"
    export_signing_pubkeys "$TR_PUBKEY_BIN"
}

# Fingerprint in groups of four, as gpg prints it.
tr_fpr_pretty() { sed -E 's/(.{4})/\1 /g; s/ $//' <<<"$1"; }

tr_update_repo() {   # <repo> <pr>
    local sign
    signing_args sign
    flatpak build-update-repo "${sign[@]}" --gpg-import="$TR_PUBKEY_BIN" \
        --title="FlatPark PR #$2 test build" "$1" >/dev/null
    [ -f "$1/summary.sig" ] || die "summary.sig not produced"
}

# ---------------------------------------------------------------------------
# Bucket.

# Upload local repo $1 to pr/<N>/ ($2) in the order a client can never see
# half of: objects and deltas, then refs, config and discovery files, then the
# summary files last. `publish` then mirrors the whole dir to the prefix,
# deleting what earlier pushes left there (including a `retired` marker).
tr_upload() {
    local repo="$1" pr="$2" mode="$3" dest="$TR_DEST/pr/$2"
    local flags=(--fast-list --transfers=16 --checkers=32 --header-upload "$TR_CACHE")
    log "upload $repo -> $dest ($mode)"
    # Content-addressed, except *.commitmeta (the signatures), which is
    # rewritten when a commit is re-signed.
    rclone copy "$repo/objects" "$dest/objects" --size-only --exclude '*.commitmeta' "${flags[@]}"
    rclone copy "$repo/objects" "$dest/objects" --checksum --include '*.commitmeta' "${flags[@]}"
    if [ -d "$repo/deltas" ]; then
        rclone copy "$repo/deltas" "$dest/deltas" --size-only "${flags[@]}"
    fi
    rclone copy "$repo/refs" "$dest/refs" --checksum "${flags[@]}"
    rclone copy "$repo" "$dest" --max-depth 1 --checksum "${flags[@]}" \
        --include config --include '*.flatpakrepo' --include '*.flatpakref' \
        --include built-from --include retired
    if [ -d "$repo/summaries" ]; then
        rclone copy "$repo/summaries" "$dest/summaries" --checksum "${flags[@]}"
    fi
    rclone copy "$repo" "$dest" --max-depth 1 --checksum "${flags[@]}" \
        --include summary --include summary.sig
    rclone copy "$repo" "$dest" --max-depth 1 --checksum "${flags[@]}" --include 'summary.idx*'
    if [ "$mode" = publish ]; then
        # ostree's own scratch space and lock are not part of what is served.
        rclone sync "$repo" "$dest" --checksum "${flags[@]}" --exclude '/tmp/**' --exclude '/.lock'
    fi
}

# Loads the state of pr/<N>/: TR_PFX_EXISTS (0/1), TR_PFX_RETIRED (the
# marker's timestamp, empty when live) and TR_PFX_BUILT (the head sha it was
# built from).
tr_prefix_load() {
    local listing
    TR_PFX_EXISTS=0 TR_PFX_RETIRED="" TR_PFX_BUILT=""
    listing="$(rclone lsf "$TR_DEST/pr/$1/" --max-depth 1 2>/dev/null)" || listing=""
    [ -n "$listing" ] || return 0
    TR_PFX_EXISTS=1
    if grep -qx retired <<<"$listing"; then
        TR_PFX_RETIRED="$(rclone cat "$TR_DEST/pr/$1/retired" | tr -d '[:space:]')"
        [ -n "$TR_PFX_RETIRED" ] || TR_PFX_RETIRED=unknown
    fi
    if grep -qx built-from <<<"$listing"; then
        TR_PFX_BUILT="$(rclone cat "$TR_DEST/pr/$1/built-from" | tr -d '[:space:]')"
    fi
    return 0
}

# Days since a retired marker's timestamp; an unreadable one counts as old.
tr_retired_age_days() {
    local t
    t="$(date -u -d "$1" +%s 2>/dev/null)" || { echo 999999; return; }
    echo $(( ($(date -u +%s) - t) / 86400 ))
}

# The build a live PR would be published from: the newest pr-checks run
# (event pull_request) on head sha $2, for PR $1. Sets TR_BUILD to
#   norun    no pr-checks run on that commit
#   pending  a run on it has not completed (its completion triggers again)
#   failed   none succeeded (TR_RUN_ID / TR_RUN_CONCL: the newest run)
#   expired  the newest success has no unexpired flatpak-repo-*-pr<N> artifact
#   ready    it has: TR_ARTS holds "<artifact-id>\t<name>" lines
# Reads GitHub only.
tr_find_build() {
    local pr="$1" head="$2" runs ok last
    TR_BUILD="" TR_RUN_ID="" TR_RUN_CONCL="" TR_ARTS=""
    [[ "$head" =~ ^[0-9a-f]{40}$ ]] || die "PR #$pr has no usable head sha"
    runs="$(gh api "repos/$TR_REPO/actions/workflows/pr-checks.yml/runs?event=pull_request&head_sha=$head&per_page=100" \
        --paginate --jq ".workflow_runs[] | select(.head_sha == \"$head\" and .event == \"pull_request\") | [.id, .status, (.conclusion // \"\"), .created_at] | @tsv")" \
        || die "could not list the pr-checks runs of $head"
    if [ -z "$runs" ]; then
        TR_BUILD=norun; return 0
    fi
    last="$(awk -F'\t' '$2 != "completed"' <<<"$runs" | head -n1)"
    if [ -n "$last" ]; then
        TR_BUILD=pending TR_RUN_ID="${last%%$'\t'*}"; return 0
    fi
    ok="$(awk -F'\t' '$3 == "success"' <<<"$runs" | sort -t$'\t' -k4,4 | tail -n1)"
    if [ -z "$ok" ]; then
        last="$(sort -t$'\t' -k4,4 <<<"$runs" | tail -n1)"
        IFS=$'\t' read -r TR_RUN_ID _ TR_RUN_CONCL _ <<<"$last"
        TR_BUILD=failed; return 0
    fi
    TR_RUN_ID="${ok%%$'\t'*}" TR_RUN_CONCL=success
    TR_ARTS="$(gh api "repos/$TR_REPO/actions/runs/$TR_RUN_ID/artifacts?per_page=100" --paginate \
        --jq ".artifacts[] | select(.name | test(\"^flatpak-repo-(x86_64|aarch64)-pr$pr\$\")) | select(.expired | not) | [.id, .name] | @tsv")" \
        || die "could not list the artifacts of run $TR_RUN_ID"
    if [ -n "$TR_ARTS" ]; then TR_BUILD=ready; else TR_BUILD=expired; fi
}

# The one decision, for PR $1, from TR_PR_JSON and the tr_prefix_load state.
# Sets TR_ACTION and TR_REASON (why, for logs and, on retire,
# merged|withdrawn). Actions:
#   none     nothing to do
#   publish  a build is ready to publish (needs flatpak + ostree)
#   check    the repo is stale but there is nothing to publish: re-run an
#            expired build or say why there is none (needs gh only)
#   retire   end-of-life the repo (needs flatpak + ostree)
#   purge    delete the prefix
tr_decide() {
    local pr="$1" head stale=""
    TR_ACTION=none TR_REASON="" TR_BUILD=""
    if tr_pr_live; then
        head="$(tr_pr_head)"
        if [ "$TR_PFX_EXISTS" = 0 ]; then
            stale="no repo yet"
        elif [ -n "$TR_PFX_RETIRED" ]; then
            stale="retired, but labeled again"
        elif [ "$TR_PFX_BUILT" != "$head" ]; then
            stale="built from ${TR_PFX_BUILT:-?}, head is $head"
        else
            TR_REASON="live and current ($head)"
            return 0
        fi
        tr_find_build "$pr" "$head"
        case "$TR_BUILD" in
            ready)   TR_ACTION=publish TR_REASON="$stale; run $TR_RUN_ID has the build" ;;
            pending) TR_REASON="$stale; pr-checks run $TR_RUN_ID on it is still running" ;;
            *)       TR_ACTION=check TR_REASON="$stale; build: $TR_BUILD${TR_RUN_ID:+ (run $TR_RUN_ID)}" ;;
        esac
        return 0
    fi
    if [ "$TR_PFX_EXISTS" = 0 ]; then
        TR_REASON="no repo, not open and labeled"
    elif [ -z "$TR_PFX_RETIRED" ]; then
        TR_ACTION=retire
        if tr_pr_merged; then TR_REASON=merged; else TR_REASON=withdrawn; fi
    elif [ "$(tr_retired_age_days "$TR_PFX_RETIRED")" -ge "$TR_RETIRE_DAYS" ]; then
        TR_ACTION=purge TR_REASON="retired at $TR_PFX_RETIRED"
    else
        TR_REASON="retired at $TR_PFX_RETIRED, kept $TR_RETIRE_DAYS days"
    fi
}

# ---------------------------------------------------------------------------
# Texts.

tr_eol_message() {   # <merged|withdrawn> <pr> <id>
    local remote; remote="$(tr_remote_name "$2")"
    if [ "$1" = merged ]; then
        printf 'PR #%s merged; switch to the released build: flatpak install --reinstall flatpark %s && flatpak remote-delete %s\n' "$2" "$3" "$remote"
    else
        printf 'PR #%s test build withdrawn: flatpak uninstall %s && flatpak remote-delete %s\n' "$2" "$3" "$remote"
    fi
}

# tr_body_live <pr> <sha> <run-id> <fingerprint> <table>   (table: tr_id_arch_table)
tr_body_live() {
    local pr="$1" sha="$2" run="$3" fpr="$4" table="$5"
    local url remote id arches a rows="" refs="" switch="" back=""
    url="$(tr_pr_url "$pr")"; remote="$(tr_remote_name "$pr")"
    while IFS=$'\t' read -r id arches; do
        [ -n "$id" ] || continue
        rows+="| \`$id\` |"
        for a in $TR_ARCHES; do
            case " $arches " in *" $a "*) rows+=" yes |" ;; *) rows+=" no |" ;; esac
        done
        rows+=$'\n'
        refs+="flatpak install --user ${url}${id}.flatpakref"$'\n'
        switch+="flatpak install --user --reinstall $remote $id"$'\n'
        back+="flatpak install --user --reinstall flatpark $id"$'\n'
    done <<<"$table"
    cat <<EOF
$TR_MARKER
### Test this PR

A test repository with the apps this PR changes, built from \`${sha:0:7}\` in [this run](https://github.com/$TR_REPO/actions/runs/$run).

| App | x86_64 | aarch64 |
|---|---|---|
${rows}
Install:

\`\`\`
${refs}\`\`\`

Already have it from FlatPark? Switch to the test build:

\`\`\`
flatpak remote-add --user --if-not-exists $remote ${url}${remote}.flatpakrepo
${switch}\`\`\`

To go back to the released build (for a new app, \`flatpak uninstall --user <id>\` instead):

\`\`\`
${back}flatpak remote-delete --user $remote
\`\`\`

Drop \`--user\` to install system-wide. The repository is signed with the FlatPark **testing** key (\`$(tr_fpr_pretty "$fpr")\`), not the release key. It is withdrawn when this PR closes or loses the \`$TR_LABEL\` label. This comment is updated on every push.
EOF
}

tr_body_rebuilding() {   # <pr> <sha> <run-id>
    cat <<EOF
$TR_MARKER
### Test this PR

The build of \`${2:0:7}\` has expired, so [pr-checks is running again](https://github.com/$TR_REPO/actions/runs/$3). This comment shows the install commands once it finishes.
EOF
}

tr_body_nobuild() {   # <pr> <sha> <why>
    cat <<EOF
$TR_MARKER
### Test this PR

No test repository yet: $3 The repository is published once pr-checks passes on \`${2:0:7}\`.
EOF
}

# tr_body_retired <merged|withdrawn> <pr> <retired-at> <id>...
tr_body_retired() {
    local reason="$1" pr="$2" at="$3"; shift 3
    local remote cmds="" id why
    remote="$(tr_remote_name "$pr")"
    for id in "$@"; do
        if [ "$reason" = merged ]; then
            cmds+="flatpak install --reinstall flatpark $id"$'\n'
        else
            cmds+="flatpak uninstall $id"$'\n'
        fi
    done
    if [ "$reason" = merged ]; then why="This PR is merged, so its test repository is withdrawn. Switch to the released build:"
    else why="This PR's test repository is withdrawn. Remove the test build:"; fi
    cat <<EOF
$TR_MARKER
### Test build withdrawn

$why

\`\`\`
${cmds}flatpak remote-delete $remote
\`\`\`

Add \`--user\` to each command if you installed with it. Installed apps show the same commands as an end-of-life notice. The repository's files are deleted $TR_RETIRE_DAYS days after $at.
EOF
}
