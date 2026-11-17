---
description: Install the build of a pull request that needs testers, switch back to the released app, and remove the test repository when you're done.
order: 8
---

# Testing a PR build

Some changes need a machine we don't have: a GPU, an arm computer, a
particular desktop. Their pull requests carry the `needs-testers` label, and
each one gets a test repository of its own at
`https://test.flatpark.org/pr/<N>/`, where `<N>` is the PR number. A comment
on the PR lists its apps and the exact commands. It is updated on every push,
so the commands there are always the current ones.

A test build is signed with the FlatPark **testing** key, not the release key,
and it is meant for trying out a change, not for everyday use.

## Installing it

Not installed from FlatPark yet? Install from the PR's link:

```sh
flatpak install --user https://test.flatpark.org/pr/<N>/<app-id>.flatpakref
```

Already have the app from FlatPark? Add the PR's repository and switch the app
over to it:

```sh
flatpak remote-add --user --if-not-exists flatpark-pr<N> https://test.flatpark.org/pr/<N>/flatpark-pr<N>.flatpakrepo
flatpak install --user --reinstall flatpark-pr<N> <app-id>
```

The first install may ask whether to add Flathub as the runtime repository
(the shared base the app runs on); say yes. That happens once.

Your settings stay where they are (`~/.var/app/<app-id>/`). Drop `--user` from
these commands to install for everyone on the computer. `flatpak update` then
picks up new pushes to the PR.

Tell the PR what you tested and what happened: that is what the app is waiting
for. What to try and a short report to copy are in
[testing a PR build](../reviewers/triage.md#testing-a-pr-build).

## Switching back

To the released app:

```sh
flatpak install --user --reinstall flatpark <app-id>
flatpak remote-delete --user flatpark-pr<N>
```

For an app that isn't listed yet, uninstall it instead:

```sh
flatpak uninstall --user <app-id>
flatpak remote-delete --user flatpark-pr<N>
```

## When the PR is merged or closed

The test repository is withdrawn. On the next `flatpak update`, Flatpak shows
the app as **end-of-life** with a message saying what to do, for example:

```
Info: <app-id> is end-of-life, with reason: PR #<N> merged; switch to the released build: flatpak install --reinstall flatpark <app-id> && flatpak remote-delete flatpark-pr<N>
```

The app keeps working. Run the two commands from the message: after a merge
they switch you to the released app, and otherwise they remove the test build.
Fourteen days later the repository is deleted, and its remote stops working;
remove it if you haven't.

## For agents

- The repository holds only the apps the PR's diff touches (`registry/<id>/`),
  built by its pr-checks run; never a parent app, a dependency or anything from
  `dl.flatpark.org`. Runtimes come from Flathub, as for the real remote.
- An extension that pr-checks rebuilt only because the PR moved its parent's
  runtime is not in the PR's diff, so it isn't published: the tester installs
  that extension from FlatPark as usual.
- The remote is named `flatpark-pr<N>`, so it never replaces or rewrites the
  `flatpark` remote. A reinstall moves the app's origin between the two.
- How the repository is made and when it is withdrawn and deleted:
  [infrastructure](../reference/infrastructure.md#test-repositories). How a PR
  gets the label: [issues and labels](../reviewers/issues.md#labels).
