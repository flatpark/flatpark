# FlatPark PR review runbook

The maintainer's review process for incoming PRs — primarily new-app and
app-update submissions. An AI agent runs this top to bottom; a human merges.

**How to run it:** for "review PR #N", copy the [template](#review-template) into
your working notes, then work the phases in order, filling one row at a time with
verifiable evidence (command output, `file:line`, a hash, a URL). The output is
the filled template plus a drafted PR comment. **The reviewer recommends only —
it never merges or publishes.**

> **Rule of engagement — never execute untrusted code.** No running `install.sh`,
> manifest `build-commands`, the app, `npm`/`pip`, or any shipped binary/script/
> installer. Static analysis only. Download artifacts as **bytes** into an
> isolated temp dir, inspect before extracting, and run nothing inside. If a
> decision genuinely needs execution to resolve, escalate to a human.

This runbook is the single source of truth; the public
[listing policies](https://flatpark.org/policies/) and the
[publishing guide](https://flatpark.org/contributing/) are audience-tuned
summaries of it. It layers on top of `.github/workflows/pr-checks.yml` (which
validates descriptors, tests, dead-link-checks, and does a no-secrets fork
build) and the `scripts/audit-descriptor.mjs` guardrails — this runbook owns the
judgment calls CI can't make.

## Provenance-based trust model

License is **not** the trust axis — it is compliance input only. Non-FOSS is
allowed (the registry ships proprietary broker apps), and open-source apps are
often shipped as official prebuilts rather than source builds (e.g. electerm).
What matters is **where the bytes you run come from**. Place each submission in a
tier:

- **Tier 1 — source-built / reproducible / source-verifiable.** Shipped
  interpreted code is byte-for-byte identical to the public source, or the build
  is reproducible from the manifest.
- **Tier 2 — official upstream prebuilt (the dominant case).** The vendor's or
  genuine project's own release, repackaged unmodified. Requires: (1) **official
  download source** — every `extra-data`/`archive` URL on the vendor's official
  domain or genuine upstream repo, not the submitter's account or a mirror;
  (2) **unmodified repackage** — `build-commands` only install the wrapper/
  desktop/metainfo/icon + an `apply_extra` that unpacks the official download; no
  patch/`sed`/recompile of the payload; shipped artifact == what the official
  URL serves. *External* sandbox adaptation is allowed and does not break Tier 2:
  wrapper env vars, extra modules supplying libraries the runtime lacks, `PATH`
  shims, an `LD_PRELOAD` shim (`com.ccswitch.desktop`, `io.enpass.Enpass`) —
  review those as code, since they run. (3) **pinned bytes** — sha256 (+ size for
  extra-data).
- **Tier 3 — opaque third-party / submitter-built binary.** Neither
  source-verifiable nor a pinned official-upstream release (PR #13). **Reject.**

## Phases

### Phase 0 — Rules of engagement (safety)
Static-only; nothing executed. Artifacts downloaded as bytes into an isolated
temp dir; inspect-before-extract (traversal/symlink/setuid); extract
`--no-same-owner --no-same-permissions`; run nothing. Read-only `gh`. Execution
needed to decide → escalate to a human.

### Phase 1 — Scope & classification
Classify: new app (`registry/<id>/`) / existing-app change / infrastructure.
**High-scrutiny surface (STOP if a non-owner touches it):** `.github/`,
`scripts/`, signing config, `registry/*/resolve-update.sh`, and a `flatpark.yml`
`update.command` — these are CI-executed on a repo-write token
(`update-check.yml` runs `contents: write` + `pull-requests: write`;
`check-updates.sh` `eval`s `update.command`). Identify the changed app id(s).

### Phase 2 — Submitter & provenance
Account age, history, social graph, other repos, prior contributions. Source-repo
age and corroboration; commit identity (watch for malformed emails); timeline
plausibility (account → repo → release within hours is a red flag). Emit a trust
tier: established / unknown-but-plausible / throwaway-suspicious. Assign the
artifact provenance tier (1/2/3).

### Phase 3 — Descriptor & manifest static review
- **Source pinning, per type:** `git` → immutable `commit` (reject branch/tag
  only); `archive` → `sha256` + genuine-upstream URL; `extra-data` → `sha256` +
  non-zero `size`; `file` → local, reviewed as part of the PR; other → NEEDS-HUMAN.
- **finish-args risk scan:** near-auto-reject on escape perms
  (`--talk-name=org.freedesktop.Flatpak`, `--filesystem=host`, `--filesystem=/`)
  unless declared in `policy.dangerous_permissions` **with a justification** (then
  it is not an auto-reject but a reviewed exemption → NEEDS-HUMAN, never a silent
  pass); warn on `--device=all`, `--filesystem=home`, needless `--share=network`.
- **Optional capabilities are opt-in, not pre-granted:** a broad permission that
  the app's *core* feature doesn't need must be absent from `finish-args` and
  instead documented as a `flatpak override` command in the metainfo description
  (see `org.electerm.Electerm`). A broad grant kept in `finish-args` needs a
  written justification in the PR body → warn if missing.
- **Local-test attestation:** the PR body states the submitter built, `flatpak
  install`ed, and launched the app, with the core feature exercised and the gaps
  named. Missing → warn (the reviewer never runs it; see Phase 0).
- **`policy:` block vs reality:** `proprietary` accurate; `dangerous_permissions`
  covers the high-risk finish-args actually used (hard enforcement deferred — see
  guardrail G2(b)).
- **build-commands:** read every line; flag network fetch, `curl|bash`, writes
  outside the build dir, and **any modification of the vendor payload/behavior**.
- **source URLs** resolve to genuine upstream (no lookalike / fork).
- **`app-id`** reverse-DNS matches the real vendor (impersonation / typosquat).
- **`update.command`** is a simple relative script path (e.g. `./resolve-update.sh`).
- **[Tier 2]** download host = official vendor domain / upstream, not the
  submitter's personal namespace.

### Phase 4 — Runtime-behavior scan
Grep manifest + shipped scripts + source for runtime fetch-and-exec
(`npm install`, `pip install`, `curl|wget`, `nc`, download-then-run).
**Allowed (vendor self-updater exception):** the vendor's own installer/updater
that downloads into the app's data/cache dir, when packaging does not patch the
official behavior, writes stay in the per-app data/cache dir (no host-home),
endpoints are the vendor's own, and there is no shell pipeline from an arbitrary
URL. **Rejected:** runtime fetch-and-exec of arbitrary/unpinned third-party code
as a core mechanism (PR #13's `npm install peerflix`), or an updater whose
packaging patches official behavior. Review `update.command`/resolve scripts as
code. Note network endpoints and broad filesystem×network combos.

### Phase 5 — Artifact / binary provenance
- sha256 of the artifact == manifest pin.
- **Inspect without execution, per artifact type:** tar/tar.gz/tgz/tar.zst → list
  entries, reject traversal/symlink-escape/setuid; zip → list with zip tooling,
  same checks; deb/rpm → inspect payload without running maintainer scripts
  (review those statically); shell installer (`.sh`) → static review where
  practical, else treat as opaque official prebuilt needing stronger Tier-2
  provenance + human judgment; **AppImage → not accepted (reject)**.
- **[Tier 1]** shipped interpreted code == public source (byte-diff each file).
- **[Tier 2]** shipped artifact == official download (re-fetch + hash-compare);
  build did not alter the payload.
- Any "official" prebuilt (node, electron, a JRE, …) hash-verified against the
  real upstream (compare code sections / build-id where a canonical artifact
  exists, as done for `node`). From-source builds with no reproducible build →
  NEEDS-HUMAN, not PASS.
- IOC scan: persistence (autostart/cron/systemd/`.bashrc`), miners
  (`xmrig`/`stratum+`), reverse shells (`/dev/tcp`, `nc -e`), hardcoded IPs,
  embedded second ELF, RPATH/RUNPATH injection.

### Phase 6 — Compliance & purpose
Non-FOSS / proprietary is **allowed** — not a rejection reason. Reject only for
purpose/legality: piracy, malware or abuse tooling, trademark-infringing
impersonation, content illegal to distribute.

### Phase 7 — Verdict & report
Decide per the rubric. Produce the filled template and a drafted PR comment.
Reviewer recommends only — a human merges.

## Decision rubric

**AUTO-REJECT (any one):**
- Compliance / legality violation (piracy, malware, trademark, illegal-to-distribute).
- Sandbox-escape permission (`--talk-name=org.freedesktop.Flatpak`, `--filesystem=host`/`/`)
  **not** declared in `policy.dangerous_permissions` with a justification (declared → NEEDS-HUMAN).
- Unpinned / mutable source for its type (git without commit; archive/extra-data
  without sha256; extra-data `size: 0`).
- Tier 3 provenance (opaque third-party / submitter-built binary).
- [Tier 1] shipped code ≠ public source.
- [Tier 2] download source not official, OR packaging patches/recompiles the
  payload, OR shipped artifact ≠ official download. (External adaptation —
  wrapper env, extra library modules, `PATH`/`LD_PRELOAD` shims — is not a
  modification; review it as code.)
- AppImage artifact.
- Runtime fetch-and-exec of arbitrary / unpinned code as a core mechanism (the
  vendor self-updater exception does not count).
- `update.command` that is not a simple relative script path.
- IOC found (traversal / setuid / persistence / miner / reverse-shell / embedded
  payload / RPATH injection).
- Infra/workflow/resolver tampering from an external contributor.
- Throwaway account **+** Tier-3 binary (the PR #13 combination).

**NEEDS-HUMAN:** from-source binaries not byte-verifiable · novel permission
needing justification · borderline provenance · unknown source type · shell
installer that can't be statically reviewed.

**PASS:** clean + trusted + provenance verified for its tier.

## Review template

Copy this per PR and fill it in. Legend: ✅ pass · ❌ fail (hard-reject) ·
⚠️ warn (needs justification) · 👤 needs-human · ➖ N/A. Tier: 1 =
source-verifiable · 2 = official prebuilt · ★ = all.

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
| 2.6 | Provenance | Artifact provenance tier: 1 source-verifiable / 2 official prebuilt / 3 opaque (→reject) | ★ | | |
| 3.1 | Manifest | Sources pinned per type (git→commit; archive/extra-data→sha256; extra-data size≠0; file→local) | ★ | | |
| 3.2 | Manifest | finish-args has no escape perms (or: declared in `dangerous_permissions` + justified → needs-human); broad perms justified | ★ | | |
| 3.3 | Manifest | `policy:` block honest: `proprietary` accurate, `dangerous_permissions` vs actual (warn until schema) | ★ | | |
| 3.4 | Manifest | build-commands install-only; no patch/recompile of vendor payload (external wrapper/module/shim adaptation OK, reviewed as code) | ★ | | |
| 3.5 | Manifest | source URLs = genuine upstream (no lookalike / fork) | ★ | | |
| 3.6 | Manifest | `app-id` reverse-DNS matches real vendor (no impersonation) | ★ | | |
| 3.7 | Manifest | `update.command` is a simple relative script path | ★ | | |
| 3.8 | Manifest | download host = official vendor domain / upstream, not submitter account | 2 | | |
| 3.9 | Manifest | Optional caps not pre-granted: documented as `flatpak override` in metainfo; any broad grant kept in `finish-args` justified in the PR | ★ | | |
| 3.10 | Manifest | PR body attests to a local build + `flatpak install` + launch smoke-test, with gaps named | ★ | | |
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

Every ❌ carries verifiable evidence; the verdict follows mechanically from "any
hard-fail row hit".
