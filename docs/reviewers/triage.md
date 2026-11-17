---
description: What the triage team does, how to test a PR build on your own machine, and what to look at before approving CI or opening a test build.
order: 5
---

# Triage

The triage team tries out PR builds in real setups before they reach users.
Agents can read a package and run most of the
[testing playbook](testing-playbook.md), but some things only a person with
the right setup can check: a GPU from a particular vendor, an arm computer, a
desktop, a device, an account. That is where the team helps most: installing
a PR's build from its test repository, trying what the PR is waiting on, and
letting the PR know how it went.

The rest of the role is there to make that work easier:

- `/approve-ci` lets the CI of a contributor outside the organization run
  without waiting for a maintainer to be around, so when CI finds a problem,
  the contributor can fix it right away.
- The `needs-testers` label opens a test build for a PR.
- Labels in general help keep issues and PRs sorted.

Merging stays with maintainers, along with the full [review](review-runbook.md)
([governance](../project/governance.md#roles)).

There's no need to handle every PR. Pick the ones you're interested in,
especially those you have the hardware for. If one looks too complex to judge
quickly, it's fine to leave it: a maintainer will get to it.

## What the role can do

| Action | How |
|---|---|
| Test a PR's build | Install it from its test repository and share how it went in the PR ([testing a PR build](#testing-a-pr-build)) |
| Let a PR's CI run | Comment `/approve-ci` ([approving CI](#approving-ci)) |
| Open a test build | Add the `needs-testers` label to the PR ([opening a test build](#opening-a-test-build)); removing it withdraws the build |
| Sort issues and PRs | Labels, as in [issues and labels](issues.md) |

On GitHub, the team has the triage role on the repository: labels, assignees,
closing and reopening issues and PRs. Pushing, merging and settings aren't part
of it.

## Testing a PR build

**Finding something to test.** Open PRs that are looking for testers carry the
`needs-testers` label:
[here's the list](https://github.com/flatpark/flatpark/pulls?q=is%3Apr+is%3Aopen+label%3Aneeds-testers).
Each PR says what its packager tested and what they couldn't, and the part
they couldn't test is what the PR is waiting for. Issues get the same label
when a bug needs a setup we don't have:
[those issues](https://github.com/flatpark/flatpark/issues?q=is%3Aissue+is%3Aopen+label%3Aneeds-testers).

**Installing it.** A bot comment on the PR has the exact commands. They install
from the PR's own repository, `flatpark-pr<N>`, and leave your `flatpark`
remote alone. How to switch back, and what happens once the PR is merged or
closed, are in [testing a PR build](../users/testing.md).

The test build is the real app, and it uses the same data folder
(`~/.var/app/<app-id>/`) as the released one. If it's an app you use every
day, it's worth backing that folder up first, or trying it with an account and
files you don't mind losing.

**What to try.** The most useful thing is whatever the PR says is untested: the
GPU feature, the arm build, the desktop, the device. If you have a few more
minutes, these basic checks from the [testing playbook](testing-playbook.md)
catch most broken packages:

- it starts and its window draws properly;
- its main feature works: opening a file, playing something, connecting,
  whatever the app is for;
- settings survive a restart: change one, quit, and start it again;
- the tray icon, notifications and file dialogs work, if the app has them.

Starting it from a terminal with `flatpak run <app-id>` means any errors show
up there, which makes problems much easier to track down.

**Sharing how it went.** A comment on the PR is all it takes. Short is fine,
and "it works" counts: often that is exactly the answer the PR is waiting for.
Something like this helps a maintainer see your setup at a glance:

```md
Tested <app-id> from the PR build (commit <short sha from the bot comment>).

- System: <distro and version>, <x86_64 or aarch64>
- Desktop: <GNOME / KDE / …>, <Wayland or X11>
- Hardware this needed: <e.g. AMD RX 7600, Mesa 25.2>
- Installed: <--user or system-wide>

Tested: <what you did>
Result: <works / what went wrong>
```

If something went wrong, the steps that lead to it and the terminal output are
the most helpful things to add; long output fits nicely in a `<details>` block.
If you only got partway, just say what you covered. A partial report is still
useful.

On a PR, the `needs-testers` label can stay on: removing it withdraws the build,
and others may still be testing. A maintainer reads the reports and then merges
or asks for changes. On an issue, you can remove the label once you've tested
and reported.

## Approving CI

GitHub holds the checks of every push from someone outside the flatpark
organization until someone approves them. Commenting `/approve-ci` on the PR,
alone on the comment's first line, starts the runs held for its newest push.
Each new push is held again, so it needs its own `/approve-ci`.

Maintainers and triage members are in the organization, so the checks on your
own PRs start by themselves. `/approve-ci` is only needed on PRs from people
outside the organization.

The bot answers with a reaction:

- 🚀 the runs were approved and are starting.
- 😕 with a reply saying why: nothing was waiting (as on a team member's PR,
  or one already approved), the command came from someone outside the team,
  or GitHub refused.

Only runs that existed when you commented get approved. If the contributor
pushed again after you looked, that push stays held, and the bot asks you to
take another look.

### What to look at first

There's really one question before approving: **could this CI run do anything
malicious?** For example, trying to read the runner's token or other
credentials, attacking hosts outside, or using the runner for something
unrelated such as mining. Whether the app is any good, or follows every
convention, is for the full review later.

The run is already protected: it gets no secrets and a read-only token, signs
with a throwaway key, and can't publish anything. This look is an extra layer
on top of that, not the only safeguard. It still matters, because pr-checks
runs code from the PR: the repository's scripts and tests as the PR has them,
and each changed app's build commands and `apply_extra` script.

These three steps cover it, on the newest push. For a PR you approved before,
GitHub's **Files changed → Changes since your last review** shows just what's
new.

1. **Which files changed.** A new app, or a change to one, usually touches only
   its own `registry/<app-id>/` directory, sometimes `config/collections.yml`,
   and sometimes `docs/`. If anything else changed, that one is best left to a
   maintainer: `.github/`, `scripts/`, `tests/`, `config/`, `site/` (its
   `package.json` and lock file run on install), or any other file that isn't
   documentation.
2. **Commands that run.** These are the manifest's `build-commands`,
   `apply_extra.sh`, the wrapper script and any other script in the app's
   directory. It's best left to a maintainer if any of them:
   - fetch something (`curl`, `wget`, `git clone`, `pip`, `npm`): downloads
     belong in the manifest's `sources`, where the build checks their hash;
   - carry encoded or obfuscated content: a long base64 or hex string, `eval`
     of a built-up string, a command assembled from pieces;
   - read things a package has no use for: environment variables such as
     `GITHUB_*` or `ACTIONS_*`, `~/.git`, `/proc`, `/run`, or anything under
     `$HOME` outside the build directory;
   - start something that keeps running: a background process, a loop, a
     long `sleep`.
3. **Where downloads come from.** Each `sources` and `extra-data` URL should
   look like the app's own download: its website, or a release on its source
   repository. A quick look is enough here; the closer check comes with
   [opening a test build](#opening-a-test-build).

If all looks fine, go ahead and comment `/approve-ci`. If something looks off,
a note in the PR about what you saw is the most helpful thing; if it looks
deliberate, please let a maintainer know. If you're simply not sure, it's fine
to leave it and say so.

### With an agent

An AI agent can do this look for you. You can ask it to follow this section
for the PR and to read the diff without running anything from it:

```sh
gh pr diff <N> --name-only    # step 1
gh pr diff <N>                # steps 2 and 3
```

A good answer is "approve" or "leave", with the lines that decided it. The
`/approve-ci` comment itself is yours to post, once you've read its answer.

## Opening a test build

Adding `needs-testers` to a PR publishes its build to a test repository, and
the PR gets a comment with the install commands
([testing a PR build](../users/testing.md)). Since this build goes onto
testers' machines, it deserves a slightly closer look than CI:

- pr-checks has passed on the newest push;
- the PR meets the review runbook's first two
  [base requirements](review-runbook.md#provenance-based-trust-model): every
  download is the upstream's official one, from its own domain or its genuine
  source repository, and the build only repackages it, fetching or running
  nothing else.

Running the whole [review runbook](review-runbook.md) with an agent is very
welcome, and its filled table can go in the PR for the maintainer. If you
can't confirm both points, it's better not to add the label yet; a note in
the PR about what's missing helps the contributor.

The test repository follows the PR: every push that passes CI updates it.
Since pushes from outside the organization still need `/approve-ci`, the
build testers get is always one someone on the team has looked at or pushed. If the PR later changes in a way you can't
vouch for, removing the label withdraws the build: installed copies get an
end-of-life notice, and the files are deleted 14 days later.
