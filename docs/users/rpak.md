---
description: rpak wraps flatpak to download installers in parallel and free the copies Flatpak keeps, while accepting every flatpak command.
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
- **Fully compatible**: every other flatpak command and option is passed
  through unchanged.

## Installing

```sh
curl -Lo ~/.local/bin/rpak https://github.com/flatpark/rpak/releases/latest/download/rpak-linux-amd64   # aarch64: rpak-linux-arm64
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
