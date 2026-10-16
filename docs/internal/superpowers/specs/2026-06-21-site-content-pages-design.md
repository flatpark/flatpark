# FlatPark site content pages — design

**Date:** 2026-06-21
**Status:** approved (brainstorming), pending implementation plan

## Goal

FlatPark's site (flatpark.org) currently has only three page types: the catalog
index, per-app detail pages, and `/setup`. It has **no standalone content
pages** — no policies, no trust/safety explainer, no user or publishing guide,
no code of conduct, no legal pages. The `docs/` directory is empty.

This is a real gap because FlatPark's README already *promises* things that have
no home: "clear rules enforced by AI review," "an explicit de-listing process,"
and the trust story behind extra-data repackaging. Those promises currently
exist nowhere as actual documents.

This design adds a small, flat set of content pages rendered on the Astro site,
mapped from (and deliberately trimmed against) the content Flathub publishes at
flathub.org + docs.flathub.org.

## Scope decisions (settled during brainstorming)

- **Surfacing:** content is rendered as real pages on flatpark.org (not
  repo-only markdown, not a separate docs subsite).
- **Structure:** flat top-level pages with a grouped site footer. No `/docs`
  sidebar / hierarchy.
- **Language:** English, matching the existing site, README, and CONTRIBUTING.
- **CONTRIBUTING.md:** the site `/contributing` page becomes canonical; the repo
  `CONTRIBUTING.md` is slimmed to a short pointer to it, so the publishing guide
  is maintained in exactly one place.
- **Legal:** a single `/legal` page (privacy + terms together), not two pages —
  lighter to maintain for a solo project.

## Out of scope (Flathub has these; FlatPark deliberately skips them)

Statistics, "Get it on FlatPark" badges, consultants directory, developer
portal / login, RSS feeds, and i18n. None are worth the cost for a solo,
cost-minimal project. The site stays a static build.

## Architecture: the content system (built once)

Astro 5.7 is already the site framework. Add the **Content Layer**:

- `site/src/content.config.ts` — defines a `pages` collection using the `glob`
  loader over `src/content/pages/*.md`, with a typed frontmatter schema:
  `title` (string), `description` (string, for `<meta>`), `group` (enum: the
  footer groups), `order` (number, for footer/link ordering), and optional
  `hideFromFooter` (boolean).
- `site/src/content/pages/<slug>.md` — one markdown file per page. The filename
  is the slug (`about.md` → `/about/`).
- `site/src/pages/[...slug].astro` — a single dynamic route that
  `getStaticPaths()` over the `pages` collection and renders each entry's
  markdown body inside a shared prose layout. Keeps with the existing
  static-output model (`output: 'static'`).
- `site/src/components/Footer.astro` — reads the `pages` collection (build time),
  groups entries by `group`, sorts by `order`, and renders the grouped link
  columns + the existing GitHub link. Added to `Base.astro` (or each
  layout) so the footer is global. Today only the per-app page has an ad-hoc
  footer; this replaces it with a shared one.
- A **prose style** block (Tailwind 4) for rendered markdown (headings, lists,
  code, links), since the site has no prose styles today.

Once this is in place, "filling in" each remaining page is just adding one
markdown file and one footer entry — no new code.

### Why this shape

- Single dynamic route + content collection = each page is data, not code. An AI
  agent (FlatPark's intended authoring model) can add a page by writing one
  markdown file.
- Type-safe frontmatter means a missing title/group fails the build, not silently
  ships a broken footer.
- No new runtime, no sidebar/nav state, no client JS — fits the static,
  cost-minimal model.

## Page set

Each page maps to Flathub content, trimmed to FlatPark's model (extra-data only,
AI-driven onboarding, community packaging, solo-run).

| Slug | Footer group | Maps to (Flathub) | Content outline |
|---|---|---|---|
| `/policies` | Project | requirements + quality-guidelines + review + quality-moderation | What FlatPark accepts (incl. vibe-coded apps); the requirements (public/stable release URL, extra-data, metainfo present, tightest permissions); how AI review weighs dev history + app quality; the **de-listing process** and what triggers it |
| `/trust` | Project | verification + app-safety-layered-approach | The trust model: extra-data-only repackaging, fetch from official source at build, pin + sign, permission tightening; "community package, not endorsed by upstream" semantics; how a user can verify what they install |
| `/contributing` | Docs | for-app-authors/* | Canonical publishing guide: the `flatpark.yml` schema, manifest, `resolve-update.sh` resolver templates, sandbox/permission guidance. Migrated from `CONTRIBUTING.md` |
| `/guide` | Docs | for-users/* | User guide: install (links to `/setup`), `--user` vs system install, the one-runtime/auto-update model, uninstalling, reading an app's permissions, basic troubleshooting |
| `/about` | Project | about | What FlatPark is, why it exists, how it relates to Flatpak and Flathub, who runs it |
| `/conduct` | Community | Code of Conduct | Behaviour expectations + how to report (GitHub issue / maintainer email) |
| `/legal` | Legal | privacy-policy + terms-and-conditions | Minimal privacy (what is *not* collected; static site, downloads served from R2) + terms (no warranty; packaged apps remain their vendors' property, fetched from official sources) |

`/setup` stays as-is (install instructions); `/guide` links to it rather than
duplicating it.

## Footer groups

- **Project:** About · Policies · Trust & safety
- **Docs:** User guide · Publishing guide
- **Community:** Code of conduct · GitHub (existing external link)
- **Legal:** Privacy & terms

Groups are derived from page frontmatter `group`, so adding a page to a group is
a frontmatter line, not a footer edit.

## Relationship to existing files

- `README.md` — unchanged content; may gain links to `/about`, `/policies`,
  `/trust` where it currently makes bare promises. (Optional, low priority.)
- `CONTRIBUTING.md` — slimmed to a pointer: "The publishing guide lives at
  flatpark.org/contributing (source: site/src/content/pages/contributing.md)."
- `/setup` page — unchanged; linked from `/guide`.
- Per-app page's inline `<footer>` — replaced by the shared `Footer.astro`.

## Rollout sequence ("逐个补齐" — one small PR per step)

- **Step 0 — content system + footer.** Build `content.config.ts`,
  `[...slug].astro`, `Footer.astro`, prose styles, and wire the footer into the
  layout. Ship one real page (`/about`) through it to validate the pipeline end
  to end (build, link-check, deploy).
- **Step 1 — `/policies` + `/trust`.** The promised-but-missing differentiators.
  Highest priority.
- **Step 2 — `/contributing` (migrate from CONTRIBUTING.md) + `/guide` (user).**
- **Step 3 — `/conduct` + finalize `/about` body.**
- **Step 4 — `/legal`** (privacy + terms).

Each step is independently shippable; the content system (Step 0) is the only
hard prerequisite for the rest.

## Success criteria

- Every footer link resolves to a built page; `scripts/check-links.sh` and the
  existing link checker pass.
- Adding a new content page requires only: one markdown file + (implicitly, via
  frontmatter) a footer entry. No code change.
- `/contributing` content matches today's `CONTRIBUTING.md`; the repo file no
  longer duplicates it.
- No new client-side JavaScript; static build unchanged in shape.

## Open / deferred

- Exact prose copy for each page is written during implementation, per step.
- Whether to later split `/legal` or add `/verification`-style per-app trust
  badges is deferred — not part of this work.
