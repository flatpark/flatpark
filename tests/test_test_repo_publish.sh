#!/usr/bin/env bash
# test-repo-publish.sh on a crafted pr-checks artifact: only the PR's refs
# reach the bucket, signed by the testing key alone, with discovery files and
# built-from; an unsafe tar or a PR that moved on publishes nothing. Stub gh
# and flatpak (build-update-repo only writes empty summary files here; the
# container e2e, tests/test-repo/run.sh, runs the real one).
# shellcheck disable=SC2016  # backticks in expected Markdown, not expansions
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for c in jq python3 rclone ostree gpg tar; do
    command -v "$c" >/dev/null 2>&1 || { echo "test_test_repo_publish: SKIP (no $c)"; exit 0; }
done
fail() { echo "FAIL: $*"; exit 1; }
tmp="$(mktemp -d)"
cleanup() {
    local h
    for h in key throwaway; do GNUPGHOME="$tmp/$h" gpgconf --kill all >/dev/null 2>&1 || true; done
    rm -rf "$tmp"
}
trap cleanup EXIT
mkdir -p "$tmp/bin" "$tmp/bucket" "$tmp/gh/repos/o/r/pulls/5" "$tmp/art"
G="$tmp/gh/repos/o/r"
ln -s "$ROOT/tests/lib/gh-stub.sh" "$tmp/bin/gh"
cat > "$tmp/bin/flatpak" <<'EOF'
#!/usr/bin/env bash
case "$1" in build-update-repo) repo="${!#}"; : > "$repo/summary"; : > "$repo/summary.sig" ;; esac
EOF
chmod +x "$tmp/bin/flatpak"
key() { mkdir -m700 "$tmp/$1"; GNUPGHOME="$tmp/$1" gpg -q --batch --passphrase '' --quick-generate-key "$1 <t@example.org>" ed25519 sign never 2>/dev/null
        GNUPGHOME="$tmp/$1" gpg --list-keys --with-colons 2>/dev/null | awk -F: '/^fpr:/{print $10; exit}'; }
tfpr="$(key key)"; wfpr="$(key throwaway)"
GNUPGHOME="$tmp/key" gpg --armor --export > "$tmp/testing.pub.asc" 2>/dev/null
export FLATPAK_TESTING_GPG_KEY; FLATPAK_TESTING_GPG_KEY="$(GNUPGHOME="$tmp/key" gpg --armor --export-secret-keys 2>/dev/null)"
H=1111111111111111111111111111111111111111
export PATH="$tmp/bin:$PATH" GH_FX="$tmp/gh" GITHUB_REPOSITORY=o/r TEST_REPO_DRY_RUN=1 \
    RCLONE_CONFIG_R2_TYPE=local TEST_REPO_BUCKET="$tmp/bucket" TEST_REPO_PUBKEY="$tmp/testing.pub.asc" \
    RCLONE_CONFIG="$tmp/rclone.conf" TEST_REPO_BASE_URL=http://localhost:8000 TEST_REPO_HEAD_SHA="$H" TEST_REPO_RUN_ID=77
: > "$tmp/rclone.conf"

echo "{\"state\":\"open\",\"labels\":[{\"name\":\"needs-testers\"}],\"head\":{\"sha\":\"$H\"}}" > "$G/pulls/5.json"
echo '[{"filename":"registry/io.example.One/flatpark.yml"},{"filename":"registry/io.example.Ext.Plugin/x.sh"},{"filename":"README.md"}]' \
    > "$G/pulls/5/files.json"

# The artifact: the PR's app, its Locale and its extension, plus what must
# never be published: another PR's app, a dependency, an unknown arch, an
# appstream branch.
src="$tmp/build/repo"; mkdir -p "$tmp/build"; ostree --repo="$src" init --mode=archive-z2
mkdir -p "$tmp/tree"; echo x > "$tmp/tree/f"
for ref in app/io.example.One/x86_64/stable runtime/io.example.One.Locale/x86_64/stable \
           runtime/io.example.Ext.Plugin/x86_64/1 app/org.evil.App/x86_64/stable \
           runtime/org.freedesktop.Platform/x86_64/24.08 app/io.example.One/riscv64/stable appstream/x86_64; do
    ostree --repo="$src" commit --branch="$ref" --subject="$ref" --gpg-sign="$wfpr" --gpg-homedir="$tmp/throwaway" "$tmp/tree" >/dev/null
done
mkdir -p "$tmp/art/x86_64"; tar -C "$tmp/build" -cf "$tmp/art/x86_64/flatpak-repo-x86_64.tar" repo

out="$("$ROOT/scripts/test-repo-publish.sh" 5 "$tmp/art/x86_64" 2>"$tmp/err")" || { cat "$tmp/err"; fail "publish failed"; }
p="$tmp/bucket/pr/5"
refs="$(cd "$p/refs/heads" && find . -type f | sed 's#^\./##' | sort | tr '\n' ' ')"
[ "$refs" = "app/io.example.One/x86_64/stable runtime/io.example.Ext.Plugin/x86_64/1 runtime/io.example.One.Locale/x86_64/stable " ] \
    || fail "published refs: $refs"
grep -q 'ignoring ref app/org.evil.App/x86_64/stable' "$tmp/err" || fail "foreign ref not reported"
[ "$(cat "$p/built-from")" = "$H" ] || fail "built-from"
for f in config summary summary.sig flatpark-pr5.flatpakrepo io.example.One.flatpakref io.example.Ext.Plugin.flatpakref; do
    [ -f "$p/$f" ] || fail "missing $f"
done
[ ! -e "$p/io.example.One.Locale.flatpakref" ] || fail "a flatpakref for a Locale ref"
ref="$(cat "$p/io.example.One.flatpakref")"
for want in 'Name=io.example.One' 'Branch=stable' 'Url=http://localhost:8000/pr/5/' 'SuggestRemoteName=flatpark-pr5' \
    'RuntimeRepo=https://dl.flathub.org/repo/flathub.flatpakrepo' 'IsRuntime=false' "GPGKey=$(GNUPGHOME="$tmp/key" gpg --export 2>/dev/null | base64 -w0)"; do
    grep -qxF -- "$want" <<<"$ref" || fail "flatpakref lacks $want"
done
grep -qx 'IsRuntime=true' "$p/io.example.Ext.Plugin.flatpakref" || fail "extension flatpakref is not a runtime"
grep -qx 'Branch=1' "$p/io.example.Ext.Plugin.flatpakref" || fail "extension branch"
grep -qx 'Url=http://localhost:8000/pr/5/' "$p/flatpark-pr5.flatpakrepo" || fail "flatpakrepo Url"
# Signed by the testing key only: the throwaway signature is gone.
cp -r "$p" "$tmp/check"
sig="$(GNUPGHOME="$tmp/key" ostree --repo="$tmp/check" show app/io.example.One/x86_64/stable 2>&1)"
grep -qF "${tfpr: -16}" <<<"$sig" || fail "not signed by the testing key: $sig"
grep -qF "${wfpr: -16}" <<<"$sig" && fail "the throwaway signature survived: $sig"
grep -qF 'flatpak install --user http://localhost:8000/pr/5/io.example.One.flatpakref' <<<"$out" || fail "comment: $out"
grep -qF '| `io.example.Ext.Plugin` | yes | no |' <<<"$out" || fail "comment table: $out"

# A second push replaces the first: leftovers (and a retired marker) go.
echo old > "$p/retired"; mkdir -p "$p/refs/heads/app/org.gone.App/x86_64"; echo 00 > "$p/refs/heads/app/org.gone.App/x86_64/stable"
"$ROOT/scripts/test-repo-publish.sh" 5 "$tmp/art/x86_64" >/dev/null 2>&1 || fail "republish failed"
[ ! -e "$p/retired" ] && [ ! -e "$p/refs/heads/app/org.gone.App" ] || fail "republish left old files"

# A PR whose head moved, or without the label, publishes nothing.
rm -rf "$p"
TEST_REPO_HEAD_SHA=2222222222222222222222222222222222222222 "$ROOT/scripts/test-repo-publish.sh" 5 "$tmp/art/x86_64" >/dev/null 2>&1
[ ! -e "$p" ] || fail "published a build of a commit that is not the PR head"
echo "{\"state\":\"open\",\"labels\":[],\"head\":{\"sha\":\"$H\"}}" > "$G/pulls/5.json"
"$ROOT/scripts/test-repo-publish.sh" 5 "$tmp/art/x86_64" >/dev/null 2>&1
[ ! -e "$p" ] || fail "published for an unlabeled PR"
echo "{\"state\":\"open\",\"labels\":[{\"name\":\"needs-testers\"}],\"head\":{\"sha\":\"$H\"}}" > "$G/pulls/5.json"

# An unsafe tar is refused before anything is extracted.
python3 -I -c 'import io, sys, tarfile
t = tarfile.open(sys.argv[1], "w"); i = tarfile.TarInfo("repo/../../escaped"); i.size = 1; t.addfile(i, io.BytesIO(b"x")); t.close()' \
    "$tmp/evil.tar"
mkdir -p "$tmp/art/evil"; mv "$tmp/evil.tar" "$tmp/art/evil/"
"$ROOT/scripts/test-repo-publish.sh" 5 "$tmp/art/evil" >/dev/null 2>&1 && fail "published from an unsafe tar"
[ ! -e "$p" ] || fail "uploaded from an unsafe tar"
# An artifact with none of the PR's refs is an error, not an empty repo.
echo '[{"filename":"registry/io.example.Other/flatpark.yml"}]' > "$G/pulls/5/files.json"
"$ROOT/scripts/test-repo-publish.sh" 5 "$tmp/art/x86_64" >/dev/null 2>&1 && fail "published with no allowed ref"
[ ! -e "$p" ] || fail "uploaded with no allowed ref"

echo "test_test_repo_publish: PASS"
