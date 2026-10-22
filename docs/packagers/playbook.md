---
description: The full process an agent follows on every packaging run, from candidate to listed app.
order: 9
---

# Packaging playbook

The ordered steps an agent (or a person) follows to take an app from candidate to
listed. Each step links to the page that holds its rules; this page adds only
the order, the checks an agent must not skip, and the parts with no page of
their own yet. Where this page and a linked page disagree, the linked page wins.

---

## 0. Rules (read every time)

1. **What can be listed and how a package is built** are in
   [can it be packaged?](can-it-be-packaged.md), [what a package is](basics.md)
   and [permissions](permissions.md). Read them; don't work from memory.
2. **Two outward-facing actions need an explicit human OK first:** opening a PR
   on this repository, and posting anything on an upstream repository. Prepare
   everything, show the draft, then wait. Branches, commits, pushes and local
   builds need no OK.
3. **Never open a PR for an app you haven't run** (step 4).
4. **Describe only what our package does.** Never claim upstream is broken,
   needs a workaround, or that we fix their bug: not in manifest comments, PRs
   or upstream messages ([step 6](#6-tell-upstream)).
5. **When workarounds start stacking, stop.** If a package needs a second or
   third workaround to run, report what you found and let the maintainer
   decide; don't keep adding them.
6. **De-list on request, no argument.** If upstream says "please don't," remove
   it right away and don't re-post.

---

## 1. Find a candidate

[Finding apps](finding-apps.md): the channels (GitHub popular apps, Flathub's
closed submissions, Flathub packages that fell behind, requests), the Flathub
checks, and how to rank by fit. Record demand and prior attempts for each
candidate; the PR and any upstream message use them. Re-run the searches
periodically to catch new releases and new Flathub rejections.

## 2. Check it can be packaged

[Can it be packaged?](can-it-be-packaged.md): the official download, what
works in the sandbox, Flathub overlap, the app id. Record what you found; the
PR and any upstream message use it.

## 3. Package

Write the files in [what a package is](basics.md) for the download chosen in
[choosing a format](formats/README.md); libraries the runtime lacks come from
[prebuilt](prebuilt.md); grants follow [permissions](permissions.md); known
problems are in [common problems](solutions/README.md). In particular:

- **Pick the runtime** from [choosing a format](formats/README.md#choosing-the-runtime):
  always the version the rest of the catalog is on, never an older one to dodge a
  build break. Moving the catalog to a new version is a
  [batch change](../reviewers/batch-changes.md).
- **Stack recipes and known problems** → [common problems](solutions/README.md),
  and the checklist for the app's stack in [by stack](solutions/by-stack.md).
- **metainfo** → [what a package is](basics.md#the-metainfo-and-the-version).

## 4. Test / verify — every run, no exceptions

Run the [testing playbook](../reviewers/testing-playbook.md) on the build
installed from a local repository ([submitting an app](submitting.md#build) has
the build and install steps), and say in the PR what you tested and what you
couldn't. `flatpak kill
<id>` after every run; when the work is merged or dropped, clean up as in
[cleaning up after a run](cleanup.md).

## 5. Open the PR

Branch, commit and PR body as in [submitting an app](submitting.md#open-the-pr).
One app per PR. When packaging several apps in one run, open each app's PR as
soon as that app is tested, then start the next; a run can end before the batch
does, and unpushed work is lost.
Add the trailer and footer your tool uses for AI-assisted work. Draft the body,
show it, and open the PR only on approval (rule 2).

## 6. Tell upstream

Once the package is live and you have used it, tell the developer. We have
made a Flatpak install for their app; if they're happy with it, a link from
their README or download page sends users to it and saves them and their users
work. If they'd rather not have it, it is removed.

- **Check [#379](https://github.com/flatpark/flatpark/issues/379) first.** It
  tracks upstream contact for every app without a shield; an upstream already
  asked keeps its thread. A `commenter:<you>` search on the upstream repository
  finds earlier asks the issue doesn't list.
- **Always a new issue** on the app's own tracker, even when a Flatpak request
  already exists there; link to that one. With no tracker or issues turned off,
  use the maintainer's public channel and say why you're writing there.
- **Short and plain.** A few sentences, no slang, no emoji. Long template
  letters read as spam and have drawn objections.
- **Only what our package does.** Never say upstream is broken, needs a
  workaround, or that we fix their bug. Before any comparison with their own
  build, check current upstream: we once told a maintainer our zypak setup
  "sidesteps their `--no-sandbox` launch bug", which that same maintainer had
  fixed months earlier. When in doubt, leave the comparison out.
- **Nothing about it being temporary,** no "stopgap", no "in the meantime", and
  nothing about the app's history on Flathub. Don't call FlatPark a home for
  "apps not on Flathub", and don't call a Modified package unmodified: say what
  its page says.

The message says, a sentence or two each:

1. what we did: <App> is on FlatPark, installed from their official
   <artifact> at install time and updated automatically from their releases;
2. how to install it, and the app's page;
3. that our own testing is partial, and issues or PRs on the packaging are
   welcome; they can also send PRs to the package freely;
4. the ask: if they're happy with it, link FlatPark as an install option in
   their README, docs or download page;
5. the exit: if they'd rather it weren't listed, say so and it is removed; if
   they're happy for it to stay, saying so publicly adds a developer-approved
   shield to its page.

`@`-mention the maintainer once, at the ask.

~~~markdown
Hi @<maintainer>, I've packaged <App> on [FlatPark](https://flatpark.org), a
Flatpak remote for apps that ship their own Linux builds. It downloads your
official <artifact> from your releases at install time and follows new
releases automatically.

```sh
flatpak remote-add --if-not-exists flatpark https://dl.flatpark.org/flatpark.flatpakrepo
flatpak install flatpark <app-id>
```

App page: https://flatpark.org/apps/<app-id>/

I've only tested the main features myself, so issues or PRs on the packaging
are very welcome. If you're happy with it, a link to FlatPark as an install
option in your README would help your Linux users find it. If you'd rather it
weren't listed, say so and I'll remove it; if you're happy for it to stay, a
reply here lets me mark it developer-approved.
~~~

Draft it, show it, and post only on approval (rule 2). Don't post again after
a no.

## 7. On the developer's reply

- **Approves in public:** set `catalog.upstream_approved: true` and add the row
  to [upstream approvals](../reference/upstream-approvals.md)
  ([how](../developers/your-app.md#for-agents)).
- **Asks for a change:** apply it as asked, in its own PR
  ([permissions](permissions.md#when-the-developer-has-asked)).
- **No:** remove the app right away; don't argue and don't ask again.
- **A correction** (an inaccurate claim, say): acknowledge it plainly, fix the
  repository (manifest comments, wrapper, PR body) and the message, then reply
  with a link to the fix.

## 8. Keeping it up

- **Updates are automatic.** `update-check` runs every resolver twice a day,
  and apps whose upstream uses publish-action update within minutes. No version
  is bumped by hand.
- **A new upstream file that doesn't unpack opens an issue.** The pin is held,
  so users stay on the last version that installs, and `scripts/ci-alert.sh`
  opens a `ci-alert` issue naming the app. Fix `registry/<id>/apply_extra.sh`,
  check it with `./scripts/check-apply-extra.sh <id>`, and the next run closes
  the issue. A failed `publish` opens the same kind of issue.
- **A resolver that fails is reported, not skipped.** Its app stays on the
  current pin, the run turns red, and one summary issue (`update-check/resolvers`)
  is rewritten with that day's list on every run and closed when all pass. Fix
  the listed resolvers together in one PR. To reproduce one, run only its
  `update.command` in `registry/<id>/` with `GITHUB_TOKEN=$(gh auth token)`;
  without a token, resolvers that call the GitHub API share an anonymous
  60-per-hour budget and fail. The full `check-updates.sh` downloads payloads.
- **Runtime majors are not bumped by CI.** `runtime-version` and `base-version`
  are pinned by hand; moving the catalog to a new major is a
  [batch change](../reviewers/batch-changes.md).
- **Re-run the searches** in [finding apps](finding-apps.md) now and then for
  new candidates.
