---
description: What the triage team does, and the checks before approving CI or opening a test build.
order: 5
---

# Triage

The triage team helps new apps get tested before they reach users. Members
let outside contributors' CI run, open test builds for apps that need testers,
and sort issues and PRs with labels. They don't merge: the full
[review](review-runbook.md) and the merge stay with maintainers
([governance](../project/governance.md#roles)).

Nobody is expected to handle every PR. Pick the ones you're interested in, and
leave any that look too complex to judge quickly: a maintainer will get to it.

## What the role can do

| Action | How |
|---|---|
| Let a PR's CI run | Comment `/approve-ci` ([approving CI](#approving-ci)) |
| Open a test build | Add the `needs-testers` label to the PR ([opening a test build](#opening-a-test-build)); remove it to withdraw the build |
| Sort issues and PRs | Labels, as in [issues and labels](issues.md) |

The team has GitHub's triage role on the repository: labels, assignees,
closing and reopening issues and PRs. It can't push, merge or change settings.

## Approving CI

GitHub holds the checks of every push from an outside contributor until
someone approves them. Comment `/approve-ci` on the PR, alone on the comment's
first line, and the runs held for the PR's newest push start. Each new push is
held again and needs its own `/approve-ci`.

The bot answers with a reaction:

- 🚀 the runs were approved and are starting.
- 😕 with a reply: nothing was waiting, the command came from someone outside
  the team, or GitHub refused. The reply says which.

Only runs that existed when you commented are approved. If the contributor
pushed after you looked, that push stays held, and the reply asks you to look
again.

### What to check first

There is one question before approving: **will this CI run do anything
malicious?** For example, try to read the runner's token or other credentials,
attack hosts outside, or use the runner for something unrelated such as
mining. Whether the app is any good, or follows every convention, is for the
full review later.

The run already has protections: it gets no secrets and a read-only token,
signs with a throwaway key and can't publish anything. This check is an extra
layer on top of them, not the only safeguard. It still matters, because
pr-checks executes code from the PR: the repository's scripts and tests as the
PR has them, and each changed app's build commands and `apply_extra` script.

Work through these in order, on the newest push. For a PR you approved before,
GitHub's **Files changed → Changes since your last review** shows only what
is new.

1. **Which files changed.** A new app, or a change to one, only touches its own
   `registry/<app-id>/` directory, sometimes `config/collections.yml`, and
   sometimes `docs/`. If anything else changed, leave the PR for a maintainer:
   `.github/`, `scripts/`, `tests/`, `config/`, `site/` (its `package.json` and
   lock file run on install), or any other file that isn't documentation.
2. **Commands that run.** Read every command in the app's directory: the
   manifest's `build-commands`, `apply_extra.sh`, the wrapper script and any
   other script. Leave the PR if any of them:
   - fetch something (`curl`, `wget`, `git clone`, `pip`, `npm`): downloads
     belong in the manifest's `sources`, where the build checks their hash;
   - carry encoded or obfuscated content: a long base64 or hex string, `eval`
     of a built-up string, a command assembled from pieces;
   - read things a package has no use for: environment variables such as
     `GITHUB_*` or `ACTIONS_*`, `~/.git`, `/proc`, `/run`, anything under `$HOME`
     outside the build directory;
   - start something that keeps running: a background process, a loop, a
     long `sleep`.
3. **Where downloads come from.** Each `sources` and `extra-data` URL should
   look like the app's own download: its website, or a release on its source
   repository. A quick look is enough here; checking it properly is part of
   [opening a test build](#opening-a-test-build).

If everything passes, comment `/approve-ci`. If something looks wrong, don't
approve. Say what you saw in the PR, or tell a maintainer if it looks
deliberate. If it's just unclear, leave it and say why.

### With an agent

An AI agent can run this check. Ask it to follow this section for the PR, and
to read the diff without running anything from it:

```sh
gh pr diff <N> --name-only    # step 1
gh pr diff <N>                # steps 2 and 3
```

It should answer with "approve" or "leave", and the lines that decided it. You
comment `/approve-ci` yourself, after reading its answer.

## Opening a test build

Adding `needs-testers` to a PR publishes its build to a test repository, and
the PR gets a comment with the install commands
([testing a PR build](../users/testing.md)). This build goes onto testers'
machines, so look closer than for CI:

- pr-checks has passed on the newest push;
- the PR meets the review runbook's first two
  [base requirements](review-runbook.md#provenance-based-trust-model): every
  download is the upstream's official one, from its own domain or its genuine
  source repository; the build only repackages it, and fetches or runs nothing
  else.

Running the whole [review runbook](review-runbook.md) with an agent is welcome,
and its filled table can go in the PR for the maintainer. If you can't confirm
both points, don't add the label; say what's missing in the PR.

The test repository follows the PR: every push that passes CI updates it.
Pushes still need `/approve-ci`, so the build testers get is always one someone
on the team has looked at. Remove the label once testing is done or if the PR
changes in a way you can't vouch for: installed copies get an end-of-life
notice, and the files are deleted 14 days later.
