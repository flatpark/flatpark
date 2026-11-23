---
description: The issue forms, what each label means, and how a new issue is sorted.
order: 4
---

# Issues and labels

Every new issue starts from a form: app problem, app request, proposal,
question about the rules, website or docs, security problem, or something
else. Only the app problem form asks for much: it can't be found without the
reporter's setup. The others take a sentence or a link, and a maintainer or
an agent fills in the rest.

Labels say what an issue is about and what it is waiting for. The forms add
the first one; the rest are added while it is handled.

## For agents

### Labels

What it is about (one per issue, set by the form or when sorting):

| Label | For |
|---|---|
| `bug` | An app or install that doesn't work |
| `app-request` | An app, or a set of apps, someone would like listed |
| `app-discover` | A scan's candidates, one table per scan ([finding apps](../packagers/finding-apps.md#recording-what-you-found)) |
| `proposal` | A change to the rules, the process, or how FlatPark works |
| `rule-question` | How a rule applies, or whether an app can be listed |
| `site` | flatpark.org and these docs |
| `security` | A package, release or pipeline that puts users at risk |
| `enhancement` | A change to an existing package that isn't a bug: a permission, an architecture, a setting |
| `community` | Growing the project: maintainers, channels, outreach |
| `ci-alert` | Opened by a failing workflow; never added by hand |

What it is waiting for (add and remove as the issue moves):

| Label | Means | Remove when |
|---|---|---|
| `needs-info` | The reporter has to add something: an output, a step, which app | They answer |
| `needs-testers` | Needs hardware or a setup we don't have (a GPU vendor, aarch64, a desktop) | Someone has tested |
| `report-to-upstream` | The cause is in the app itself, not the package | Never; link the developer's issue in a comment once it is filed |
| `help wanted` | Open for anyone to pick up | Someone takes it (`/claim` removes it) |

`needs-testers` on a **PR** also publishes it (check it first, as in
[opening a test build](triage.md#opening-a-test-build)): once pr-checks passes, the PR
gets a test repository at `https://test.flatpark.org/pr/<N>/` and a comment
with the install commands ([testing a PR build](../users/testing.md)), updated
on every push. Removing the label, or closing the PR, withdraws it: installed
copies show an end-of-life notice with the commands to switch back, and the
files are deleted 14 days later. Adding the label again publishes it again.

`help wanted` says only that anyone may take it; the label beside it says what
kind of help: `app-request` + `help wanted` is an app anyone may package,
`community` + `help wanted` is a call for people.

### Claims

Commenting `/claim` on an open `app-request` issue assigns it to the
commenter, so two people don't package the same app; `/unclaim` gives it back.
The comment must start with the command on its own line. A bot reacts 👍 when
it worked; if someone else already holds the claim it replies with their name
and assigns nobody. One claim per request.

A scan issue (`app-discover`) lists many apps, so a claim there names the row,
by its app or its number as the table gives them: `/claim Letter` or
`/claim 3`, one row per comment. Each claimer is added to the assignees, so
several people can work through one scan; a claim on a row someone already
holds, by either name, gets the same reply, and so does one naming a row the
table doesn't have. `/unclaim` gives back every
row the commenter holds.

When an issue first gets either label, a bot comments once: it thanks the
requester (app requests only), explains `/claim` and links the README's
[package an app with your agent](../../README.md#package-an-app-with-your-agent),
so whoever reads the issue later knows to claim before starting and how to
start.

A claim that has gone quiet (no PR, no answer when asked) is released by a
maintainer: unassign the person, say why in a comment, and add `help wanted`
back. Maintainers can still assign by hand; the command is for everyone else.

Closing: `duplicate` with a link to the earlier issue; GitHub's "not planned"
for an app that can't be listed or a proposal that was declined, with the
reason in the last comment. `wontfix` and `invalid` aren't used.

### Titles

Every issue title starts with the prefix of its "what it is about" label,
however the issue was opened: from a form, by a maintainer or an agent
directly, or by a bot.

| Label | Title |
|---|---|
| `bug` | `[Bug] <app-id>: <what goes wrong>` |
| `app-request` | `[App Request] <Name>` |
| `app-discover` | `[App Discover] Scan <YYYY-MM-DD>: <n> candidates` |
| `proposal` | `[Proposal] <what changes>` |
| `rule-question` | `[Question] <the question>` |
| `site` | `[Site] <page or area>: <what>` |
| `security` | `[Security] <app-id or area>: <what>` |
| `enhancement` | `[Enhancement] <app-id>: <what changes>` |
| `community` | `[Community] <what>` |
| `ci-alert` | `[CI] <workflow>: <what failed>` (set by `scripts/ci-alert.sh`) |

The forms prefill the prefix, except "Something else", which gets one when it
is sorted. When you open an issue yourself, pick the label first and take its
prefix; status labels (`help wanted`, `needs-testers`, …) never give one.

Fix the prefix and the app's spelling (its official name, its id) when sorting;
leave the rest of the reporter's words, and never edit their text.

### Sorting a new issue

- **App problem.** Check the form is complete: the `rpak doctor` output and the
  output of `flatpak run`. If one is missing or cut short, ask for exactly what
  is missing and add `needs-info`. Go through the `rpak doctor` output with
  [the list below](#reading-rpak-doctor-output) first. Reproduce before
  changing the package ([testing playbook](testing-playbook.md)); a cause in
  the app itself gets `report-to-upstream`, and a fix to the package gets a row
  in the [incident list](../reference/incidents.md).
- **App request.** Answer it as in
  [finding apps](../packagers/finding-apps.md#answering-an-app-request).
- **Proposal, question.** Answer from the docs, linking the rule. A question
  the docs don't answer means the docs are missing something: say so, and fix
  the page in the PR that settles it.
- **Security problem.** Before anything else, as
  [security](../project/security.md#when-a-release-is-dangerous) describes.
- **Something else.** Give it the label it should have had, and fix the title.

### Reading `rpak doctor` output

`rpak doctor` only collects; deciding what matters is done here, so this list
can grow without a new rpak release. Check, in this order:

| Look at | What it can explain |
|---|---|
| App section: `extra-data` lines | `HTTP 404`, or a size that differs from `pinned`: the vendor replaced or removed the file; the install or update fails with "Wrong size". Both commits are listed when an update is pending; a broken remote commit with a good installed one fails only on update. |
| Network | A remote that doesn't answer, or a proxy in the way: installs and updates fail before any app runs. |
| `global override` blocks | Apply to every app. A filesystem, socket or variable there explains permissions the package doesn't grant, and settings that vanish ([override](../users/override.md#where-overrides-live-and-in-what-order-they-apply)). |
| The app's override and `permissions` | What the app really runs with. Compare with the package's `finish-args`; a removed folder means lost settings, extra `host` or `home` grants mean the test setup differs from ours. |
| GPUs, `NVIDIA driver`, `GL extension` lines | Two GPUs (Intel or AMD next to NVIDIA) and the nvidia driver are the setup WebKitGTK and Chromium apps most often fail on. The `GL.nvidia-<version>` extension must match the driver version exactly (dots become dashes), or GL falls back to software or fails. |
| `XDG_SESSION_TYPE`, `XDG_CURRENT_DESKTOP`, portal lines | Wayland or X11, and which portal backends run: tray icons, file choosers, screenshots and "open with" depend on them. `xdg-desktop-portal: not running` breaks all of those. |
| `user.max_user_namespaces=0`, `unprivileged_userns_clone=0` | Flatpak can't start any app. |
| `end-of-life` on the app's runtime | The app needs a runtime bump; EOL refs the app doesn't use are unrelated. |
| Installations | Where the app is installed (user or system), whether the remote it came from is configured there, a lock held by another process, little free space. |
| `RPAK_DRY_RUN`, `RPAK_FLATPAK` | rpak set to do nothing, or pointed at itself. |

`flatpak run` printing nothing doesn't mean nothing happened: many apps
(Tauri ones among them) write their log only to a file, usually under
`~/.var/app/<id>/data/` or `~/.var/app/<id>/.local/share/`. Find it in the
app's source or in the package's wrapper, and ask for it by its exact path.

Write down what led to the cause in the reply, so the reporter learns to read
it too. A pattern that turns up in several reports belongs in this table.
