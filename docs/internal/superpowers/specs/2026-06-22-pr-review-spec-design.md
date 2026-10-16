# FlatPark PR Review Spec — Design

Date: 2026-06-22
Status: approved design (revised per Codex review notes), pending implementation plan
Origin case: PR #13 ("add Native Popcorn") — a Popcorn Time-class BitTorrent
streaming client submitted by a ~2-hour-old throwaway account, shipping an
opaque, non-reproducible prebuilt binary from the submitter's own GitHub
release. Closed. This spec generalizes that review into a repeatable process.

Revision note: the original draft split reviews by license (open-source vs
proprietary). That was wrong for FlatPark — `org.electerm.Electerm` is
`proprietary: false` yet ships an **official prebuilt** release tarball, not a
source build. The trust axis is therefore **artifact provenance**, not license.
See review notes: `2026-06-22-pr-review-spec-design-review-notes.md`.

## 1. Goal

Give FlatPark a written, repeatable review process for incoming PRs — primarily
new-app and app-update submissions — that an AI agent (the maintainer's agent)
executes top-to-bottom, plus a small set of deterministic CI guardrails. The
process owns the judgment calls that CI cannot make: provenance, supply-chain
trust, binary integrity, and compliance.

This layers **on top of** the existing automated gate in
`.github/workflows/pr-checks.yml`, which already validates every descriptor,
runs the shell test suite, dead-link-checks hotlinked screenshots, and builds
changed apps with a throwaway signing key and **no secrets** (fork PRs cannot
reach the real signing key or R2/Pages credentials; untrusted build-commands are
gated behind GitHub's "require approval for fork PR workflows" setting). The
review spec does not duplicate those mechanical checks; it adds the trust layer.

## 2. Deliverables

| # | Artifact | Path | Audience |
|---|---|---|---|
| 1 | PR-review runbook (ordered, agent-executable) + the review template table | `docs/pr-review.md` | The maintainer's agent — run on every PR |
| 2a | Public review-bar (plain-language rules users can see and trust) | expand `site/src/content/pages/policies.md` (Review section); also drop AppImage from "What we host" | End users — public trust |
| 2b | "What we review" contributor note | append to `site/src/content/pages/contributing.md` | Contributors' agents — pre-comply / self-check |
| 3 | Guardrail code (land this round) | `scripts/` + `.github/workflows/pr-checks.yml` | CI — deterministic auto-gate |

`docs/pr-review.md` is the single source of truth; 2a and 2b are
audience-tuned summaries that link back to it. The site already ships
user-facing trust pages (`policies.md`, `trust.md`), so the rules live there
rather than in a new page — making the review bar publicly visible is itself a
trust signal.

## 3. Provenance-based trust model (the core idea)

License is **not** the trust axis — it is compliance metadata only. Non-FOSS is
allowed; the registry already ships proprietary broker software
(`com.schwab.thinkorswim`, `com.interactivebrokers.ibkrdesktop`). And open-source
apps are not necessarily source-built: `org.electerm.Electerm` is
`proprietary: false` yet FlatPark ships its **official prebuilt** GitHub-release
tarball as extra-data.

What matters is **where the bytes you run come from**. Every submission is placed
in one of three provenance tiers:

- **Tier 1 — source-built / reproducible / source-verifiable.** The shipped
  interpreted code is byte-for-byte identical to the public source, or the build
  is reproducible from the manifest. (Verify by diffing shipped `.py`/`.js`/`.sh`
  against the public repo, or comparing code sections / build-id against a
  canonical artifact, as was done for the bundled `node` in the PR #13 review.)

- **Tier 2 — official upstream prebuilt (the dominant FlatPark case).** The app
  is the vendor's or genuine project's **own** release, repackaged unmodified.
  Trust requires all of:
  1. **Official download source** — every `extra-data`/`archive` URL resolves to
     the vendor's official domain or the genuine upstream repo (e.g.
     `tosmediaserver.schwab.com`, `download2.interactivebrokers.com`,
     `cdn.azul.com`, `github.com/electerm/electerm/releases/...`). **Not** the
     submitter's personal account, **not** a third-party mirror.
  2. **Unmodified repackage** — `build-commands` only `install` the FlatPark
     wrapper/desktop/metainfo/icon and an `apply_extra` that unpacks the official
     download. The manifest must **not** patch, `sed`, recompile, or otherwise
     alter the vendor payload, and must not change the official package's runtime
     behavior. The shipped artifact must equal what the official URL serves
     (re-download and hash-compare).
  3. **Pinned bytes** — the source is pinned (sha256 + size for extra-data) so a
     build cannot silently swap the binary.

- **Tier 3 — opaque third-party or submitter-built binary.** A prebuilt that is
  neither source-verifiable nor a pinned official-upstream release — e.g. a
  binary the submitter built on their own machine and hosts on their own account
  (PR #13). **Auto-reject.**

The "official URL + unmodified + pinned" rule (Tier 2) applies to **all** official
prebuilts, FOSS or proprietary alike. License feeds Phase 6 (compliance) only.

Why PR #13 fails: its download URL was the submitter's own personal release (not
official), and the binary was re-built on the submitter's machine
(`bundle-binaries.sh`) — Tier 3 — on top of the compliance (piracy) failure.

## 4. The runbook — ordered phases

Each review executes these in sequence and records results in the template
(section 7).

### Phase 0 — Rules of engagement (safety)
- **Never execute untrusted code.** No running `install.sh`, manifest
  `build-commands`, the app itself, `npm`/`pip`, or any shipped binary/script /
  installer. Static analysis only.
- Download artifacts as **bytes** into an isolated temp dir. **Inspect before
  extract** (path-traversal / symlink / setuid check), then extract with
  `--no-same-owner --no-same-permissions`. Run nothing inside.
- Use read-only `gh` / API calls. Never paste secrets.
- If a decision genuinely requires execution to resolve, **escalate to a human**
  — do not execute.

### Phase 1 — Scope & classification
- Classify what the PR touches: new app (`registry/<id>/`), change to an existing
  app, or **infrastructure**.
- **High-scrutiny surface (STOP if a non-owner touches it):** `.github/`,
  `scripts/`, signing config, **and** `registry/*/resolve-update.sh` plus
  `flatpark.yml`'s `update.command` — these are CI-executed on a repo-write
  token (`update-check.yml` runs with `contents: write` + `pull-requests: write`
  and `check-updates.sh` `eval`s `update.command`).
- Identify the changed app id(s).

### Phase 2 — Submitter & provenance
- Account age, history, social graph, other repos, prior contributions.
- Source-repo age, corroboration, commit history and author identity (e.g. the
  malformed `...@gmail.com@gmail.com` in PR #13).
- **Timeline plausibility** — account → repo → release all created within hours
  is a red flag.
- Emit a trust tier: *established* / *unknown-but-plausible* / *throwaway-suspicious*.

### Phase 3 — Descriptor & manifest static review
- **Source pinning, per type:**
  - `git` → require immutable `commit` (reject branch-only or tag-only).
  - `archive` → require `sha256`; URL must resolve to genuine upstream.
  - `extra-data` → require `sha256` and non-zero `size`.
  - `file` → local packaging file; no remote pin, but reviewed as part of the PR.
  - other / unknown types → NEEDS-HUMAN.
- `finish-args` **risk scan**: near-auto-reject on escape perms
  (`--talk-name=org.freedesktop.Flatpak`, `--filesystem=host`, `--filesystem=/`);
  warn on `--device=all`, `--filesystem=home`, needless `--share=network`.
- Read the descriptor `policy:` block and **cross-check against reality**: is
  `proprietary` accurate; does `dangerous_permissions` cover the high-risk
  finish-args actually used? (Hard enforcement deferred — see G2(b)/§9.)
- Read **every build-command**: flag network fetch, `curl|bash`, writes outside
  the build dir, and **any modification of the vendor payload or its runtime
  behavior** (Tier-2 requirement 2).
- Source URLs resolve to the **genuine upstream** (no lookalike domains, no
  attacker fork masquerading as upstream).
- `app-id` reverse-DNS vs the real vendor (impersonation / typosquat).
- **`update.command`** must be a simple relative script path (e.g.
  `./resolve-update.sh`); anything else → fail/NEEDS-HUMAN.
- **[Tier 2]** download host = official vendor domain / genuine upstream, **not**
  the submitter's personal namespace.

### Phase 4 — Runtime-behavior scan
- Grep manifest + shipped scripts + source for runtime fetch-and-exec
  (`npm install`, `pip install`, `curl|wget`, `nc`, download-then-run).
- **Vendor self-updater / runtime-download exception (allowed):** a vendor's own
  installer/updater that downloads into the app's data/cache directory is
  acceptable **when** all hold: it is the official vendor mechanism; FlatPark's
  packaging does **not** patch or alter the official package's behavior; writes
  stay inside the per-app data/cache dir (no host-home); endpoints are the
  vendor's own and documented; no shell pipeline from an arbitrary URL. This is
  how the existing brokers work (install4j self-updates jars in the app dir) and
  is **not** a rejection.
- **Still rejected:** runtime fetch-and-exec of **arbitrary third-party / unpinned
  code** as a core mechanism (PR #13's `npm install peerflix`), or any updater
  whose packaging patches the official behavior.
- Review `update.command` / resolve scripts **as code** — they run on FlatPark's
  CI infrastructure with a repo-write token.
- Note the network endpoints the app talks to and any broad
  filesystem × network combination.

### Phase 5 — Artifact / binary provenance (the PR #13 deep-dive, generalized)
- sha256 of the downloaded artifact == the manifest pin.
- **Inspect without execution, per artifact type:**
  - `tar` / `tar.gz` / `tgz` / `tar.zst` → list entries; reject path traversal,
    symlink escape, setuid/setgid.
  - `zip` → list with zip tooling; same traversal/symlink/setuid checks.
  - `deb` / `rpm` → inspect the package payload **without running maintainer
    scripts**; review those scripts statically.
  - shell installer (`.sh`) → static review where practical; otherwise classify
    as an opaque official prebuilt and require stronger Tier-2 provenance + human
    judgment (do not execute it).
  - **AppImage → not accepted** (rejected artifact type).
- **[Tier 1]** shipped interpreted code == public source (byte-diff each file).
- **[Tier 2]** shipped artifact == the official download (re-fetch the official
  URL and hash-compare); confirm build-commands did not alter the payload.
- Any "official" prebuilt (node, electron, a JRE, …) hash-verified against the
  real upstream artifact (compare code sections / build-id where a canonical
  artifact exists, as done for `node`). From-source builds with no reproducible
  build resolve to NEEDS-HUMAN, not PASS.
- IOC scan: persistence (autostart/cron/systemd/`.bashrc`), miners
  (`xmrig`/`stratum+`), reverse shells (`/dev/tcp`, `nc -e`), hardcoded IPs,
  embedded second ELF, RPATH/RUNPATH injection.

### Phase 6 — Compliance & purpose
- Non-FOSS / proprietary is **allowed** — not a rejection reason.
- Reject only for **purpose/legality**: piracy, malware or abuse tooling,
  trademark-infringing impersonation, content that is illegal to distribute.

### Phase 7 — Verdict & report
- Decision per the rubric (section 5). Produce a structured report and draft a PR
  comment.
- **The reviewer never merges or publishes — it recommends only. A human merges.**

## 5. Decision rubric

- **AUTO-REJECT (any one):**
  - Compliance / legality violation (piracy, malware, trademark, illegal-to-distribute).
  - Sandbox-escape permission (`--talk-name=org.freedesktop.Flatpak`, `--filesystem=host`/`/`).
  - Unpinned / mutable source for its type (git without commit; archive/extra-data
    without sha256; extra-data `size: 0`).
  - **Tier 3** provenance: opaque third-party / submitter-built binary.
  - **[Tier 1]** shipped code ≠ public source.
  - **[Tier 2]** download source not official, OR packaging modifies the payload /
    official behavior, OR shipped artifact ≠ official download.
  - AppImage artifact.
  - Runtime fetch-and-exec of arbitrary third-party / unpinned code as a core
    mechanism (vendor self-updater exception in §4 does not count).
  - `update.command` that is not a simple relative script path.
  - IOC found (traversal / setuid / persistence / miner / reverse-shell /
    embedded payload / RPATH injection).
  - Infra/workflow/resolver tampering from an external contributor.
  - Throwaway account **+** Tier-3 binary (the PR #13 combination).
- **NEEDS-HUMAN:** from-source binaries not byte-verifiable · novel permission
  needing justification · borderline provenance · unknown source type · shell
  installer that can't be statically reviewed.
- **PASS:** clean + trusted + provenance verified for its tier.

## 6. Threat catalog → phase coverage

| Attack class | Caught in |
|---|---|
| Opaque/submitter-built binary, Tier 3 (PR #13) | P5 |
| Shipped code ≠ public source (Tier 1) | P5 |
| Upstream prebuilt swapped / trojaned | P5 |
| App-id / brand impersonation (typosquat) | P3 |
| Malicious build-commands (CI RCE) | P3 |
| Unpinned / mutable sources (post-review swap) | P3 + G1 |
| Sandbox over-permission / escape | P3 + G2(a) |
| Runtime fetch-and-exec of arbitrary code | P4 + G3 |
| Update-channel hijack (`resolve-update.sh` / `update.command` on CI) | P1 + P4 + G4 |
| Metainfo / metadata injection & phishing links | P3 (+ existing link check) |
| CI / workflow / resolver tampering, secret exfiltration | P1 + G4 |
| Throwaway account / social engineering | P2 |
| Hijacked upstream / compromised maintainer | P2 (re-verify on update) |
| Compliance / legal (piracy, trademark) | P6 |
| Spyware / exfiltration / telemetry | P4 / P5 |
| Cryptominer / resource abuse | P5 |
| Dependency-confusion / lookalike source URL | P3 |
| Steganographic / second-stage payload | P5 (+ stated limits) |
| Non-official download source for a prebuilt | P3 + P5 |
| Packaging modifies vendor payload / behavior | P3 + P5 |
| Disallowed artifact type (AppImage) | P5 + G(backlog) |

## 7. Review template table

Copied into each review and filled in line by line.

Legend: ✅ pass · ❌ fail (hard-reject) · ⚠️ warn (needs justification) ·
👤 needs-human · ➖ N/A. Tier: 1 = source-verifiable · 2 = official prebuilt ·
★ = all.

| # | Phase | Check | Tier | Verdict | Evidence (cmd output / `file:line` / hash / url) |
|---|---|---|---|---|---|
| 0 | Safety | Static-only; nothing executed; artifacts handled in an isolated dir | ★ | | |
| 1.1 | Scope | Classified: new app / app change / infra | ★ | | |
| 1.2 | Scope | Touches high-scrutiny surface (`.github/`·`scripts/`·signing·`resolve-update.sh`·`update.command`)? non-owner → STOP | ★ | | |
| 2.1 | Provenance | Submitter account age / history / graph / other repos | ★ | | |
| 2.2 | Provenance | Source repo age, corroboration | ★ | | |
| 2.3 | Provenance | Commit identity sane (no malformed email) | ★ | | |
| 2.4 | Provenance | Timeline plausible (not account→repo→release within hours) | ★ | | |
| 2.5 | Provenance | Trust tier: established / unknown-plausible / throwaway-suspicious | ★ | | |
| 2.6 | Provenance | Artifact provenance tier assigned: 1 source-verifiable / 2 official prebuilt / 3 opaque (→reject) | ★ | | |
| 3.1 | Manifest | Sources pinned per type (git→commit; archive/extra-data→sha256; extra-data size≠0; file→local) | ★ | | |
| 3.2 | Manifest | finish-args has no escape perms; broad perms justified | ★ | | |
| 3.3 | Manifest | `policy:` block honest: `proprietary` accurate, `dangerous_permissions` vs actual (warn until schema) | ★ | | |
| 3.4 | Manifest | build-commands install-only; no patch/alter of vendor payload or behavior | ★ | | |
| 3.5 | Manifest | source URLs = genuine upstream (no lookalike / fork) | ★ | | |
| 3.6 | Manifest | `app-id` reverse-DNS matches real vendor (no impersonation) | ★ | | |
| 3.7 | Manifest | `update.command` is a simple relative script path | ★ | | |
| 3.8 | Manifest | download host = official vendor domain / upstream, not submitter account | 2 | | |
| 4.1 | Runtime | No runtime fetch-and-exec of arbitrary/unpinned code (vendor self-updater to data dir, behavior unpatched = OK) | ★ | | |
| 4.2 | Runtime | `update.command` / resolve script reviewed as code (runs on CI, repo-write) | ★ | | |
| 4.3 | Runtime | Network endpoints noted; no broad filesystem×network combo | ★ | | |
| 5.1 | Artifact | extra-data sha256 == manifest pin | ★ | | |
| 5.2 | Artifact | Inspected per type (tar/zip/tgz/deb/rpm listed clean; AppImage rejected; .sh static-or-opaque); no traversal/symlink/setuid | ★ | | |
| 5.3 | Artifact | shipped interpreted code == public source (byte diff) | 1 | | |
| 5.4 | Artifact | shipped artifact == official download (re-fetch & hash); build did not alter payload | 2 | | |
| 5.5 | Artifact | "official" prebuilts hash-verified vs upstream (from-source w/o reproducible → NEEDS-HUMAN) | ★ | | |
| 5.6 | Artifact | IOC scan clean (persistence/miner/reverse-shell/hardcoded-IP/embedded-ELF/RPATH) | ★ | | |
| 6.1 | Compliance | Purpose legal & policy-compliant (not piracy/malware/trademark/illegal-to-distribute) | ★ | | |
| 6.2 | Compliance | Non-FOSS is NOT a rejection reason | ★ | | |
| 7.1 | Verdict | Overall: AUTO-REJECT / NEEDS-HUMAN / PASS | ★ | | |
| 7.2 | Verdict | Hard-fail triggers hit (list) | ★ | | |
| 7.3 | Verdict | PR comment drafted; reviewer recommends only, human merges | ★ | | |

Every ❌ must carry verifiable evidence (command output / `file:line` / hash /
url). The verdict follows mechanically from "any hard-fail row hit".

## 8. Public review-bar + contributing note (artifacts 2a, 2b)

Both are audience-tuned summaries of the runbook; `docs/pr-review.md` stays the
single source of truth that both link to.

**2a — Public review-bar (`policies.md`, user-facing).** Expand the existing
"Review" section into a concrete, plain-language statement of the bar, and align
"What we host" with the provenance model:
- FlatPark either verifies source-built packages where possible, or repackages
  **official upstream prebuilts unmodified** — "the bytes you run are the
  vendor's own".
- Official prebuilts must come from the real upstream/vendor release channel;
  unofficial or modified binaries are rejected.
- Non-FOSS is allowed; openness is not the bar.
- Every download is pinned by checksum; sandbox-escape permissions are rejected.
- **Remove AppImage** from the accepted-download list ("an installer, AppImage,
  `.deb`, `.rpm`, or tarball" → drop AppImage).
- Do **not** imply every open-source prebuilt is byte-for-byte source-verified
  unless FlatPark actually performs that verification.
- Link to `docs/pr-review.md`; cross-link `trust.md` if it reads naturally.

**2b — Contributor note (`contributing.md`, agent-facing).** Append a short
"What we review (and what gets a PR rejected)" pre-flight checklist: pin every
source per type; use official download URLs; do not modify the vendor payload or
behavior; `update.command` is a plain `./resolve-update.sh`; declare
`policy.proprietary` and `policy.dangerous_permissions`; no runtime fetch-and-exec
of arbitrary code (vendor self-updaters to the data dir are fine); no
sandbox-escape permissions; no AppImage; legitimate purpose.

## 9. Guardrails to land this round (artifact 3)

Deterministic, CI-enforced, hooked into the existing per-descriptor validation
seam (`scripts/read-descriptor.mjs`, run for every descriptor in pr-checks.yml)
and the fork-safe PR gate.

- **G1 — source-pinning check (hard), per source type.** Fail a descriptor whose
  referenced manifest has an unpinned source: `git` without `commit`; `archive`
  or `extra-data` without `sha256`; `extra-data` with `size: 0`. `type: file`
  needs no remote pin (do not flag the 30 existing file sources). Implement in a
  new `scripts/audit-descriptor.mjs` (or extend `read-descriptor.mjs`).
- **G2 — finish-args linter.**
  - **(a) escape-perm hard-fail (ship now, trips no existing app):**
    `--talk-name=org.freedesktop.Flatpak`, `--filesystem=host`, `--filesystem=/`.
  - **(b) declaration-consistency (warn-only this round):** a dangerous finish-arg
    not declared in `policy.dangerous_permissions`. Stays warning until a
    machine-readable `dangerous_permissions` schema is defined and existing
    descriptors are migrated (all currently declare `[]`).
- **G3 — runtime-fetch grep (warn-only this round).** Grep manifest
  build-commands and shipped scripts for `npm install` / `pip install` /
  `curl … | sh` / `wget … | sh`; warn for human review (vendor self-updaters are
  expected to surface here — hence warn, not fail).
- **G4 — infra/resolver-change tripwire (author-gated).** In `pr-checks.yml`, a
  PR that modifies `.github/`, `scripts/`, signing config,
  `registry/*/resolve-update.sh`, or a `flatpark.yml` `update.command` is flagged.
  The threat is an *external* contributor sneaking such a change in, so it
  **hard-fails only for untrusted authors**; for a trusted author
  (`author_association` OWNER / MEMBER / COLLABORATOR) it emits a notice and
  passes, so the maintainer's own infra PRs aren't blocked and the job is safe to
  mark as a required check. `update.command` is also enforced to be a simple
  relative path (in `audit-descriptor.mjs`, for every author).

**Backlog (not this round):** `dangerous_permissions` schema + registry
migration (unblocks G2(b) → hard); reproducible-build verification; automated
official-source / host-ownership check for prebuilts (3.8); AppImage-reject
descriptor check; XXE-safe metainfo validation; `eval` removal in
`check-updates.sh`.

## 10. Integration & process

- The runbook is invoked manually by the maintainer's agent ("review PR #N") and
  followed top-to-bottom; the filled template + drafted comment is the output.
- Guardrails run automatically in `pr-checks.yml` on every PR (fork-safe: no
  secrets), failing the gate on hard violations before a human looks.
- The reviewer role recommends only; merge/publish stays a human action on push
  to main (existing signing/publish flow is unchanged).

## 11. Out of scope

- No change to the signing/publish pipeline or its security boundary.
- No automated official-domain ownership oracle this round (human/agent judges in
  the runbook; automation is backlog).
- `dangerous_permissions` hard-enforcement, reproducible-build verification, and
  `eval` removal in `check-updates.sh` are backlog, not this round.
- From-source-built binaries lacking a reproducible build resolve to NEEDS-HUMAN,
  not PASS.
