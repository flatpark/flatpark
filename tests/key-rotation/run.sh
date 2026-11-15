#!/bin/bash
# Key-rotation e2e (docs/reference/signing-key-rotation.md): a server running
# the real publish scripts (ubuntu:24.04, the flatpak of the GitHub runner) and
# clients on several flatpak versions, user and system installs, walked through
# a rotation. Needs podman and network access for the images.
#
#   KEYS=<dir holding ci-subkey.secret.asc> tests/key-rotation/run.sh
#
# The incoming subkey is used as the "new" key, so the run also proves that
# exact key works; the "old" key is a throwaway of the live key's shape.
set -uo pipefail
K=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$K/../.." && pwd)
KEYS=${KEYS:?dir holding ci-subkey.secret.asc}
SERVER_BASE=docker.io/library/ubuntu:24.04
CLIENT_BASES=${CLIENT_BASES:-"docker.io/library/debian:trixie docker.io/library/debian:bookworm docker.io/library/ubuntu:22.04"}
fails=0; mkdir -p "$K/out"; log=$K/out/e2e.log; : > "$log"
img() { local t=localhost/keyrot:$(echo "$1" | tr -c 'a-z0-9\n' '-'); podman build -q --build-arg BASE="$1" -t "$t" "$K" >/dev/null && echo "$t"; }
cleanup() { podman rm -f -t0 keyrot-srv $(podman ps -aq --filter name=keyrot-c-) >/dev/null 2>&1; podman volume rm -f keyrot-srv >/dev/null 2>&1; }
trap cleanup EXIT; cleanup
podman volume create keyrot-srv >/dev/null
S=$(img $SERVER_BASE) || exit 1
run_srv() { podman run --rm --network host -v keyrot-srv:/srv -v "$K:/t:ro" -v "$ROOT:/src:ro" -v "$KEYS/ci-subkey.secret.asc:/keys/ci-subkey.secret.asc:ro" "$S" /t/server.sh "$@"; }
echo "== server: $(podman run --rm $S flatpak --version)"
run_srv init || exit 1
podman run -d --name keyrot-srv --network host -v keyrot-srv:/srv -v "$K:/t:ro" "$S" /t/server.sh serve >/dev/null; sleep 1
clients=()
for b in $CLIENT_BASES; do
  t=$(img "$b") || { echo "build failed: $b"; exit 1; }
  n=keyrot-c-$(echo "$b" | sed 's#.*/##; s/[^a-z0-9]/-/g')
  podman run -d --name "$n" --network host -v keyrot-srv:/srv:ro -v "$K:/t:ro" "$t" sleep infinity >/dev/null
  clients+=("$n"); echo "== client $n: $(podman exec "$n" flatpak --version)"
done
# expect <ok|fail> <desc> <client.sh args...>   (runs on every client container)
expect() { local want=$1 desc=$2; shift 2
  for c in "${clients[@]}"; do
    out=$(podman exec "$c" /t/client.sh "$@" 2>&1); rc=$?
    got=ok; [ $rc -eq 0 ] || got=fail
    if [ "$got" = "$want" ]; then r=PASS; else r=FAIL; fails=$((fails+1)); fi
    printf '%-4s %-22s %-48s (want %s)\n' "$r" "${c#keyrot-c-}" "$desc" "$want"
    { echo "### $c :: $* (rc=$rc)"; echo "$out"; } >> "$log"
    [ "$got" = "$want" ] || echo "$out" | tail -3 | sed 's/^/       | /'
  done; }
# check <desc> <expected-output> <client.sh args...>
check() { local desc=$1 want=$2; shift 2
  for c in "${clients[@]}"; do
    got=$(podman exec "$c" /t/client.sh "$@" 2>/dev/null)
    if [ "$got" = "$want" ]; then r=PASS; else r=FAIL; fails=$((fails+1)); fi
    printf '%-4s %-22s %-48s = %s\n' "$r" "${c#keyrot-c-}" "$desc" "${got:-<empty>}"
  done; }
phase() { echo; echo "######## $1"; run_srv "$2" || { echo "server $2 failed"; exit 1; }; run_srv inspect; }

echo; echo "######## phase 0: live state (old key only)"; run_srv inspect
for id in A B C; do expect ok "$id: add remote (old key)" $id user add old.gpg; expect ok "$id: install v1" $id user install; done
expect ok "S: add remote (old key, system)" S system add old.gpg; expect ok "S: install v1 (system)" S system install
check "A: trusted keys" "OLD stand-in," A user keys

phase "rotation starts: new key added, backfill dispatch (no app changes)" backfill
expect ok "A: update, nothing pending (idle user)" A user update
check  "A: trusted keys after idle update" "(2026-11),OLD stand-in," A user keys
expect ok "S: update, nothing pending (system)" S system update
check  "S: trusted keys (system)" "(2026-11),OLD stand-in," S system keys
expect ok "D: new user, add remote (NEW key only)" D user add new.gpg
expect ok "D: install v1 (backfilled app + runtime)" D user install
check  "D: version" v1 D user version

phase "overlap: ordinary publish of v2" publish-v2
expect ok "B: update v1->v2 (first update in overlap)" B user update
check  "B: trusted keys" "(2026-11),OLD stand-in," B user keys
for id in A D; do expect ok "$id: update to v2" $id user update; check "$id: version" v2 $id user version; done

phase "switch: old key removed from CI, v3 published" switch
for id in A B D; do expect ok "$id: update to v3" $id user update; check "$id: version" v3 $id user version; done
expect ok "S: update to v3 (system)" S system update
expect ok "C: missed overlap: update exits 0 + non-fatal warn" C user update-silent
check  "C: version (silently stuck)" v1 C user version
expect fail "C: remote-ls surfaces the error" C user ls
expect ok "C: manual fix (remote-modify --gpg-import)" C user fix new.gpg
expect ok "C: update after fix" C user update
check  "C: version" v3 C user version

echo; [ $fails -eq 0 ] && echo "ALL PASS" || echo "$fails FAILED (details: $log)"
exit $fails
