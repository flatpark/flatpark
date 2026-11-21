---
description: rpak wraps flatpak to download installers in parallel, free the copies Flatpak keeps and run apps from other remotes on a newer runtime, while accepting every flatpak command.
order: 2
---

# Using rpak

[rpak](https://github.com/flatpark/rpak) wraps `flatpak`. We recommend
aliasing `flatpak` to it, so you keep typing the commands you know:

- **Parallel downloads**: `install` and `update` fetch app installers several
  at a time instead of one after another.
- **Cleaning up**: frees the installer copies Flatpak
  [keeps](cleanup.md#reclaiming-space-from-downloaded-installers) after every
  install or update; `rpak clean` frees older ones and other leftovers.
- **Reporting problems**: `rpak doctor` collects what a bug report needs.
- **Newer runtimes** (experimental): `rpak patch` runs an app that
  [stayed behind](#running-an-app-on-a-newer-runtime-experimental) on the
  current runtime.
- **Fully compatible**: every other flatpak command and option is passed
  through unchanged.

## Installing

```sh
curl -Lo ~/.local/bin/rpak "https://github.com/flatpark/rpak/releases/latest/download/rpak-linux-$(uname -m)"
chmod +x ~/.local/bin/rpak
```

Or with [mise](https://mise.jdx.dev/): `mise use -g github:flatpark/rpak`.

## Alias and completion

For zsh, add this to `~/.zshrc` after `compinit`:

```zsh
if (( $+commands[rpak] )); then
  alias flatpak=rpak
  () {
    local dir=${XDG_CACHE_HOME:-$HOME/.cache}/zsh
    [[ -d $dir ]] || mkdir -p $dir
    [[ $dir/_rpak -nt $commands[rpak] ]] || rpak completion zsh >| $dir/_rpak
    fpath=($dir $fpath)
    autoload -Uz _rpak && compdef _rpak rpak
  }
fi
```

For bash: `alias flatpak=rpak` and `source <(rpak completion bash)` in
`~/.bashrc`. For fish: the same alias and `rpak completion fish | source` in
`config.fish`.

Software centres and automatic updates still call flatpak directly; run
`rpak clean` now and then to free what they leave.

## When something goes wrong

```sh
rpak doctor <app-id>
```

prints your distribution, desktop, graphics cards, flatpak setup, overrides
and whether the app's downloads can be reached. It only collects; what the
output means is for whoever reads your report. Paste the whole output when you
[report a problem](troubleshooting.md#reporting-a-problem). It changes nothing,
and leaves out home paths, your user name and the names of files you opened.
Without an app id it covers only your setup; with several, each app.

## Running an app on a newer runtime (experimental)

FlatPark's apps [move to a new runtime together](updates.md#runtimes-move-together).
Apps from other remotes don't always. As of 2026-11-21, on Flathub Zen
(`app.zen_browser.zen`) is built for `org.freedesktop.Platform` 25.08,
and Sublime Merge (`com.sublimemerge.App`) for 24.08, which no longer gets
fixes. Each such app keeps an old runtime on your disk, a few hundred MB, and
the older ones run without security fixes.

`--force-runtime` runs the app on the newest branch of its runtime anyway:

```sh
rpak install --force-runtime flathub app.zen_browser.zen   # install it forced
rpak patch --force-runtime com.sublimemerge.App            # force an app already installed
rpak patch                                                 # list what is forced
rpak patch --reset app.zen_browser.zen                     # back to the runtime it was built for
flatpak uninstall --unused                                 # remove the old runtime once nothing needs it
```

Later `rpak update` keeps the apps forced, and stops forcing one once its
packagers move it to that runtime themselves. Zen has no
[extra-data](cleanup.md#reclaiming-space-from-downloaded-installers), so
rpak only changes the runtime the installed app names. Sublime Merge
downloads its installer from the vendor and runs a script in the runtime to
unpack it, so rpak builds a copy of Flathub's package with only the runtime
changed, after checking every file against Flathub's signature, and
installs it from a local remote, `rpak-local`. Either way the app's files
and permissions stay as its packagers made them. `flatpak update` without
rpak (software centres, automatic updates) puts an app back on its old
runtime; the next `rpak update` forces it again.

### It can break the app

The app was built and tested on the old runtime. Nobody has tested it on the
new one, and rpak checks nothing about compatibility; it only warns each time
it forces an app. Libraries change between runtime versions, so the app may
not start, may crash, or may lose a feature: video playback, hardware
acceleration, input methods, plugins. Extensions that follow the runtime
version (codecs, GL drivers) are not installed for you in the new version.

If something stops working, `rpak patch --reset <app-id>` first. A problem
that only happens while forced is not the app's bug: don't report it to its
packagers.

### The lasting fix

Forcing is a stopgap; the fix is a package built for the current runtime.
Check whether the developer publishes the app on Flathub themselves:

```sh
curl -s https://flathub.org/api/v2/verification/<app-id>/status   # "verified": true = the developer's
```

- **Verified** (Zen): open an issue in the app's Flathub repository,
  `github.com/flathub/<app-id>`, or the developer's tracker, asking them to
  move to the current runtime. FlatPark doesn't package an app its developer
  publishes on Flathub.
- **Not verified** (Sublime Merge): a third party packages it there, and a
  package that has fallen behind is reason enough for FlatPark to list its
  own ([which apps we take](../packagers/can-it-be-packaged.md#apps-already-on-flathub)).
  [Request it](https://github.com/flatpark/flatpark/issues/new?template=2-app-request.yml)
  and switch once it is listed.

rpak can also install an app with another download in place of its
extra-data file (`--extra-data=URL`: a vendor release the package hasn't
caught up with, a dead link), just as experimental and unchecked; see
[rpak's README](https://github.com/flatpark/rpak#patch-experimental).
