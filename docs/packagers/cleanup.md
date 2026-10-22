---
description: Removing everything a packaging, review or test run left on the machine, and nothing else.
order: 8
---

# Cleaning up after a run

A packaging, review or test run leaves things behind: a worktree, build output,
a test install and its data, files the app wrote into your home folder, a test
display, downloads. When the work is merged or abandoned, remove all of it, and
**only** what this run created. Then report what was removed, what was kept on
purpose, and what was found but isn't yours.

The machine is usually shared: other sessions work in other worktrees, use the
same build cache, and may be testing an app right now. The person also uses
Flatpak themselves. Most cleanup mistakes are removing something that belonged
to someone else.

## For agents

### Rules

- **Inventory first, with read-only commands.** List what exists, decide what
  is yours, then remove. Never put a destructive command in an inventory step:
  one run put `flatpak uninstall --user --unused --noninteractive` in a "what's
  there" command and removed runtimes before anyone looked.
- **Yours is what this run created.** Track it as you go (worktree paths, remote
  names, test files, ports). Anything else, including other worktrees, other
  sessions' scratch directories and the user's own installs and overrides, is
  left alone and mentioned in the report.
- **The user's own data wins.** If a test build replaced an app the user
  already had, uninstall the test build **without** `--delete-data` so their
  settings survive, and say how to reinstall from `flatpark`.
- **Kill by PID or exact name, never `pkill -f <pattern>`**: the pattern is in
  your own command line, and it kills your shell. `pgrep -a -x <name>` to check.
- **Use absolute paths in `rm -rf`.** Safety checks may refuse a path built
  from variables; write it out.
- **Merged or not?** Check the PR is merged before deleting its branch;
  squash merges need `git branch -D`, because `--merged` doesn't recognise them.

### Checklist

**Processes and displays**

```sh
flatpak ps                       # apps and stuck builders still running
flatpak kill <app-id>            # `timeout flatpak run` leaves the app running
pgrep -a -x Xwayland             # a test display (:99) left up
ss -ltnp | grep <port>           # preview servers, test daemons, sshd
```

A leftover app keeps writing to the host after cleanup and can recreate
directories you just deleted. Kill it before removing anything.

**Flatpak**

```sh
flatpak --user uninstall -y <app-id>
flatpak --user remote-delete <test-remote>      # flatpark-local, test-tmp, <app>-test
rm -rf ~/.var/app/<app-id>                       # only if the app was installed only for the test
flatpak override --user --reset <app-id>         # only overrides you set
flatpak permission-show <app-id>                 # portal answers given while testing
flatpak permission-reset <app-id>                # only for an app installed just for the test
```

- `flatpak remotes --user` should show only the user's own remotes afterwards
  (usually `flathub` and `flatpark`).
- Portal answers given during a test stay in the permission store, even after
  uninstalling: an "open with" default (`desktop-used-apps`), screenshot and
  camera answers, files opened through the file chooser (`documents`). For an
  app the user also uses, remove only the entries the test made
  (`flatpak permission-remove <table> <id> <app-id>`); never
  `permission-reset` their app.
- Run `flatpak uninstall --unused` only when the test pulled in a runtime, and
  only after showing the user what it would remove.
- A private D-Bus used to drive a fake portal can start a second document
  portal; closing it unmounts `/run/user/$UID/doc`, and every later
  `flatpak run` fails with "Can't find source path /run/user/…/doc/by-app".
  Check `mount | grep /run/user/$UID/doc` and run
  `systemctl --user restart xdg-document-portal` if it's gone.
- A `--installation=test` install is cleaned with
  `flatpak --installation=test uninstall --all`.

**Files the app wrote outside its sandbox**

- Directories it was granted with `:create` (`~/.app`), and test files it saved
  into granted folders (`~/Pictures/…`, `~/Documents/…`, `~/Desktop/…`).
- If the app was also run natively for comparison:
  `~/.local/share/<name>`, `~/.cache/<name>`, `~/.config/<name>` and
  `~/.config/autostart/<name>.desktop`.
- Secrets the test stored: Secret Service entries (`secret-tool search
  service <name>`), kernel keyring keys.
- Compare with the `$HOME` listing taken before the test; anything new and
  related to the app goes.

**Git**

```sh
git worktree list
git worktree remove --force <path>     # takes its out/ build tree with it
git worktree prune
git branch -D <branch>
git push origin --delete <branch>      # often already deleted on merge
git fetch --prune                      # drops stale remote-tracking refs
git update-ref -d refs/remotes/pr/<N>  # refs fetched to review a PR
```

Then fast-forward `main` and check `git status` is clean. Untracked files you
didn't create are the user's; leave them.

**Build output**

- A worktree's own `out/` goes with the worktree.
- The main checkout's `out/` (`out/repo`, `flatpak-builder-state`, `build-*`)
  is shared by every session. Remove only your app's build directory, and its
  ref from the local repo:
  `ostree --repo=out/repo refs --delete app/<id>/x86_64/stable` then
  `ostree --repo=out/repo prune --refs-only`.
- A copy or symlink of the signing keyring (`.gnupg-flatpark`) made into a
  worktree goes, and so does a `gpg-agent` started for it
  (`gpgconf --homedir <dir> --kill gpg-agent`). An agent for the main
  checkout's keyring may be another session's; leave it.
- `site/node_modules` installed into a worktree by a link check or site build.

**Downloads and temporary files**

- The session's scratch directory: downloaded payloads, unpacked trees,
  screenshots, logs, draft comments. They are often hundreds of megabytes to a
  few gigabytes.
- Upstream clones and source checkouts under `/tmp`.
- Other sessions' scratch directories are theirs, however large.
- A temporary clone of `flatpark/prebuilt` goes once the release is cut; nothing
  needs a resident copy.

**Containers**

Database servers and other services started to test a client (`podman ps -a`,
`podman images`) are removed with the test, images included; they run to
gigabytes.

**GitHub (only when asked)**

- Failed workflow runs that were superseded by a fix:
  `gh run delete <id>`. Leave cancelled runs that were only folded into a
  later one by the concurrency queue.
- Old Actions caches: keep the newest of each family (`flatpak-repo-*`,
  `flatpark-screenshots-*`, the npm cache); the workflows restore by prefix and
  only use the newest.
- Superseded `flatpark/prebuilt` releases that no package or stack pins:
  delete the release and its tag. "No pin" means `git grep 'releases/download/<tag>/'`
  finds nothing on `origin/main` of both `flatpark/flatpark` and
  `flatpark/prebuilt` (stacks pin each other); stale local checkouts don't
  count, and GitHub code search lags. Installed users are unaffected: extra-data
  is only fetched on an install or an update that changes the pin.

### The report

Three short lists:

1. **Removed:** what, and how large where it matters.
2. **Kept on purpose:** the user's own installs and data, shared build caches,
   anything waiting on a reply (a branch an open PR still uses).
3. **Not ours:** other worktrees, other sessions' files and processes, with
   enough detail for the user to decide.
