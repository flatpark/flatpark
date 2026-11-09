# Agent instructions

Start with [`docs/README.md`](docs/README.md). It indexes everything an agent
needs to package, review and maintain apps in this repository.

- Packaging an app: [`docs/packagers/playbook.md`](docs/packagers/playbook.md),
  which links each step to its page in [`docs/packagers/`](docs/packagers/README.md).
- Testing a package or a change to one: [`docs/reviewers/testing-playbook.md`](docs/reviewers/testing-playbook.md).
- Something doesn't work in the sandbox: [`docs/packagers/solutions/`](docs/packagers/solutions/README.md).
- Reviewing a PR: [`docs/reviewers/review-runbook.md`](docs/reviewers/review-runbook.md).
- After the PR is open, ask before cleaning up, then follow [`docs/packagers/cleanup.md`](docs/packagers/cleanup.md).
- Documentation is written in `docs/` and nowhere else; the site renders it.
  Link between pages with relative `.md` paths.
