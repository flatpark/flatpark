# FlatPark documentation

FlatPark is a signed Flatpak remote for Linux desktop apps. Every app is the
vendor's own release, fetched at install time and run in a sandbox.

These docs are written for two readers. People get a short explanation at the top
of each page. Agents packaging or reviewing apps read the whole page, including
the details below it. The same files are rendered at
[flatpark.org/docs](https://flatpark.org/docs/).

- [Users](users/README.md): installing apps, permissions, getting help.
- [Packagers](packagers/README.md): adding and maintaining apps.
- [Reviewers](reviewers/README.md): how PRs are checked and tested.
- [Reference](reference/README.md): records and lookup tables.
- [Project](project/README.md): what FlatPark is, its policies and rules.

## For agents

- Packaging an app: start with the [packaging playbook](packagers/playbook.md),
  then the [publishing guide](packagers/publishing.md) for the descriptor,
  manifest and resolver.
- Reviewing a PR: follow the [review runbook](reviewers/review-runbook.md).
- Link between pages with relative `.md` paths. The site rewrites them, and the
  build fails on a link to a page that doesn't exist.
- `specs/` holds the plans being worked through, one step at a time, and
  `internal/` holds operations notes. Neither is published on the site.
