#!/usr/bin/env bash
# scripts/lib/test-repo.sh: the checks on a pr-checks artifact (tar, refs) and
# the PR comment (rendering, edit in place by marker, against a stub gh).
# shellcheck disable=SC2016  # backticks in expected Markdown, not expansions
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for c in jq python3 tar base64; do
    command -v "$c" >/dev/null 2>&1 || { echo "test_test_repo_lib: SKIP (no $c)"; exit 0; }
done
. "$ROOT/scripts/lib/common.sh"
. "$ROOT/scripts/lib/test-repo.sh"
fail() { echo "FAIL: $*"; exit 1; }

export GITHUB_REPOSITORY=o/r GH_FX TEST_REPO_DRY_RUN=0
tr_init
t="$TR_TMP/t"; mkdir -p "$t/bin" "$t/gh"; GH_FX="$t/gh"
ln -s "$ROOT/tests/lib/gh-stub.sh" "$t/bin/gh"; export PATH="$t/bin:$PATH"

# ---- tar validation --------------------------------------------------------
mk_tar() { # <name> <python adding members to tarfile t>
    python3 -I -c "import io, sys, tarfile
t = tarfile.open(sys.argv[1], 'w')
def f(name, data=b'x'):
    i = tarfile.TarInfo(name); i.size = len(data); t.addfile(i, io.BytesIO(data))
def link(name, target, kind=tarfile.SYMTYPE):
    i = tarfile.TarInfo(name); i.type = kind; i.linkname = target; t.addfile(i)
def dev(name):
    i = tarfile.TarInfo(name); i.type = tarfile.CHRTYPE; i.devmajor = 1; i.devminor = 3; t.addfile(i)
$2
t.close()" "$t/$1.tar"
}
rejects() { ( tr_check_tar "$t/$1.tar" ) 2>/dev/null && fail "accepted the $1 tar" || true; }
mk_tar good    "f('repo/config'); f('repo/objects/ab/cd.filez'); link('repo/l', 'objects/ab'); link('repo/h', 'repo/config', tarfile.LNKTYPE)"
mk_tar dotdot  "f('repo/../x')"
mk_tar abs     "f('/abs')"
mk_tar symout  "link('repo/l', '../../etc')"
mk_tar symabs  "link('repo/l', '/etc/passwd')"
mk_tar hardout "link('repo/h', '../outside', tarfile.LNKTYPE)"
mk_tar device  "dev('repo/null')"
mk_tar big     "f('repo/a', b'0' * 4096)"
( tr_check_tar "$t/good.tar" ) || fail "rejected a plain repo tar"
for n in dotdot abs symout symabs hardout device; do rejects "$n"; done
( TR_MAX_BYTES=1000 tr_check_tar "$t/big.tar" ) 2>/dev/null && fail "accepted a tar over the size limit"

# An artifact zip holds exactly one .tar.
python3 -I -c 'import sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w") as z: z.writestr("flatpak-repo-x86_64.tar", "data")
with zipfile.ZipFile(sys.argv[2], "w") as z: z.writestr("../evil.tar", "data")' "$t/ok.zip" "$t/evil.zip"
( tr_unpack_artifact_zip "$t/ok.zip" "$t/unz" ) || fail "rejected a one-tar artifact zip"
[ -f "$t/unz/flatpak-repo-x86_64.tar" ] || fail "artifact tar not unpacked"
( tr_unpack_artifact_zip "$t/evil.zip" "$t/unz2" ) 2>/dev/null && fail "accepted a zip member with a path"

# ---- ref filtering ---------------------------------------------------------
ids=$'io.example.One\nio.example.Ext.Plugin'
for ref in app/io.example.One/x86_64/stable app/io.example.One/aarch64/beta \
           runtime/io.example.One.Locale/x86_64/stable runtime/io.example.One.Debug/aarch64/stable \
           runtime/io.example.Ext.Plugin/x86_64/24.08; do
    tr_ref_allowed "$ref" "$ids" || fail "dropped the PR's ref $ref"
done
for ref in app/org.evil.App/x86_64/stable runtime/org.freedesktop.Platform/x86_64/24.08 \
           app/io.example.One/riscv64/stable app/io.example.One/x86_64/st@ble \
           app/io.example.One.Locale/x86_64/stable runtime/io.example.One.Sources/x86_64/stable \
           appstream/x86_64 ostree-metadata app/io.example.One/x86_64 app/io.example.On/x86_64/stable; do
    tr_ref_allowed "$ref" "$ids" && fail "kept the foreign ref $ref"
done
table="$(printf '%s\n' app/io.example.One/x86_64/stable app/io.example.One/aarch64/stable \
    runtime/io.example.One.Locale/x86_64/stable runtime/io.example.Ext.Plugin/x86_64/1 | tr_id_arch_table)"
[ "$table" = $'io.example.Ext.Plugin\tx86_64\nio.example.One\tx86_64 aarch64' ] || fail "id/arch table: $table"

# ---- comment rendering -----------------------------------------------------
fpr=7858FD7DD9F527EC02342A9A7630ADC35A942414
live="$(tr_body_live 5 abc1234def0 77 "$fpr" "$table")"
for want in "$TR_MARKER" "built from \`abc1234\`" "https://github.com/o/r/actions/runs/77" \
    '| `io.example.One` | yes | yes |' '| `io.example.Ext.Plugin` | yes | no |' \
    'flatpak install --user https://test.flatpark.org/pr/5/io.example.One.flatpakref' \
    'flatpak remote-add --user --if-not-exists flatpark-pr5 https://test.flatpark.org/pr/5/flatpark-pr5.flatpakrepo' \
    'flatpak install --user --reinstall flatpark-pr5 io.example.One' \
    'flatpak install --user --reinstall flatpark io.example.One' \
    'Drop `--user`' '7858 FD7D D9F5 27EC 0234 2A9A 7630 ADC3 5A94 2414' 'needs-testers'; do
    grep -qF -- "$want" <<<"$live" || fail "live comment lacks [$want]"
done
[ "$(head -n1 <<<"$live")" = "$TR_MARKER" ] || fail "marker is not the first line"

reb="$(tr_body_rebuilding 5 abc1234def0 77)"
if ! grep -qF 'expired' <<<"$reb" || ! grep -qF 'actions/runs/77' <<<"$reb"; then fail "rebuilding comment: $reb"; fi

ret="$(tr_body_retired merged 5 2026-11-16T00:00:00Z io.example.One)"
for want in 'flatpak install --reinstall flatpark io.example.One' 'flatpak remote-delete flatpark-pr5' \
    '14 days after 2026-11-16T00:00:00Z'; do
    grep -qF -- "$want" <<<"$ret" || fail "retired (merged) comment lacks [$want]"
done
ret="$(tr_body_retired withdrawn 5 2026-11-16T00:00:00Z io.example.One)"
grep -qF 'flatpak uninstall io.example.One' <<<"$ret" || fail "retired (withdrawn) comment: $ret"

# The EOL messages, word for word, and short enough for a terminal notice.
m="$(tr_eol_message merged 5 io.example.One)"
[ "$m" = 'PR #5 merged; switch to the released build: flatpak install --reinstall flatpark io.example.One && flatpak remote-delete flatpark-pr5' ] || fail "merged EOL: $m"
w="$(tr_eol_message withdrawn 5 io.example.One)"
[ "$w" = 'PR #5 test build withdrawn: flatpak uninstall io.example.One && flatpak remote-delete flatpark-pr5' ] || fail "withdrawn EOL: $w"

# ---- edit in place ---------------------------------------------------------
c="$GH_FX/repos/o/r/issues/5/comments.json"
tr_put_comment 5 "$live" 2>/dev/null
grep -q '^POST repos/o/r/issues/5/comments' "$GH_FX/calls" || fail "first comment not posted"
# Someone else's comment that quotes the marker is never ours to edit.
jq --arg m "$TR_MARKER" '[{id: 1, user: {login: "someone"}, body: ($m + " quoted")}] + .' "$c" > "$c.n" && mv "$c.n" "$c"
: > "$GH_FX/calls"
tr_put_comment 5 "$live" 2>/dev/null
if grep -qv '^GET' "$GH_FX/calls"; then fail "re-sent an unchanged comment: $(cat "$GH_FX/calls")"; fi
tr_put_comment 5 "$ret" 2>/dev/null
grep -q '^PATCH repos/o/r/issues/comments/1001' "$GH_FX/calls" || fail "did not edit in place: $(cat "$GH_FX/calls")"
grep -q '^POST' "$GH_FX/calls" && fail "posted a second comment"
if [ "$(jq 'length' "$c")" != 2 ] || [ "$(jq -r '.[0].body' "$c")" != "$TR_MARKER quoted" ] \
    || [ "$(jq -r '.[1].body' "$c")" != "$ret" ]; then fail "comments after edit: $(cat "$c")"; fi
# Dry run prints instead of posting.
: > "$GH_FX/calls"
out="$(TEST_REPO_DRY_RUN=1 tr_put_comment 5 "$reb")"
if [ "$out" != "$reb" ] || [ -s "$GH_FX/calls" ]; then fail "dry run posted or printed something else"; fi

echo "test_test_repo_lib: PASS"
