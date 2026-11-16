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
| `app-discover` | A candidate from a scan ([finding apps](../packagers/finding-apps.md#recording-what-you-found)) |
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
| `help wanted` | Open for anyone to pick up | Someone takes it |

`help wanted` says only that anyone may take it; the label beside it says what
kind of help: `app-request` + `help wanted` is an app anyone may package,
`community` + `help wanted` is a call for people.

Closing: `duplicate` with a link to the earlier issue; GitHub's "not planned"
for an app that can't be listed or a proposal that was declined, with the
reason in the last comment. `wontfix` and `invalid` aren't used.

### Titles

| Form | Title |
|---|---|
| App problem | `[Bug] <app-id>: <what goes wrong>` |
| App request | `[App Request] <Name>` |
| Scan candidate | `[App Discover] <Name>` |
| Proposal | `[Proposal] <what changes>` |
| Question about the rules | `[Question] <the question>` |
| Security problem | `[Security] <app-id or area>: <what>` |

Fix the prefix and the app's spelling (its official name, its id) when sorting;
leave the rest of the reporter's words, and never edit their text.

### Sorting a new issue

- **App problem.** Check the form is complete: the `rpak doctor` output and the
  output of `flatpak run`. If one is missing or cut short, ask for exactly what
  is missing and add `needs-info`. Read the Problems section of `rpak doctor`
  first; a global override, a missing remote, a stopped portal or an
  extra-data URL marked ✗ explains many reports on its own. Reproduce before
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
