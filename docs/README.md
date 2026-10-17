# FlatPark documentation

FlatPark is a signed Flatpak remote for Linux desktop apps. Every app is the
vendor's own release, fetched at install time and run in a sandbox.

These docs are written for two readers. People get a short explanation at the top
of each page. Agents packaging or reviewing apps read the whole page, including
the details below it. The same files are rendered at
[flatpark.org/docs](https://flatpark.org/docs/).

- [Users](users/README.md): installing apps, permissions, getting help.
- [Developers](developers/README.md): your app on FlatPark, and instant updates from your releases.
- [Packagers](packagers/README.md): adding and maintaining apps.
- [Reviewers](reviewers/README.md): how PRs are checked and tested.
- [Reference](reference/README.md): records and lookup tables.
- [Project](project/README.md): what FlatPark is, its policies and rules.

## For agents

- Packaging an app: follow the [packaging playbook](packagers/playbook.md); each
  step links to the page that holds its rules.
- Finding apps to package: [finding apps](packagers/finding-apps.md).
- Something doesn't work in the sandbox: [common problems](packagers/solutions/README.md),
  and the checklist for the app's stack in [by stack](packagers/solutions/by-stack.md).
- Testing a package or a change to one: the [testing playbook](reviewers/testing-playbook.md);
  for a runtime upgrade or a prebuilt re-cut, [batch changes](reviewers/batch-changes.md).
- Reviewing a PR: follow the [review runbook](reviewers/review-runbook.md).
- A fix for a listed app: add a row to the [incident list](reference/incidents.md).
- After a run: [cleaning up](packagers/cleanup.md).
- How decisions are made: [principles](project/principles.md) and
  [governance](project/governance.md).
- Link between pages with relative `.md` paths. The site rewrites them, and the
  build fails on a link to a page that doesn't exist.
- `specs/` holds the plans being worked through, one step at a time; it isn't
  published on the site.
