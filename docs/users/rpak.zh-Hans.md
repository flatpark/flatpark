---
description: rpak 包装 flatpak：并发下载安装包、释放 Flatpak 留下的副本，同时接受所有 flatpak 命令。
order: 2
---

# 使用 rpak

[rpak](https://github.com/flatpark/rpak) 是 `flatpak` 的包装器。建议把 `flatpak` 设成它的别名，照常敲熟悉的命令即可：

- **并发下载**：`install` 和 `update` 同时下载多个应用安装包，而不是一个接一个。
- **清理空间**：每次安装或更新后释放 Flatpak [留下](cleanup.zh-Hans.md#回收下载的安装包占用的空间)的安装包副本；`rpak clean` 清理更早的副本和其他残余。
- **完全兼容**：其他 flatpak 命令和选项原样透传。

## 安装

```sh
curl -Lo ~/.local/bin/rpak https://github.com/flatpark/rpak/releases/latest/download/rpak-linux-amd64   # aarch64: rpak-linux-arm64
chmod +x ~/.local/bin/rpak
```

或者用 [mise](https://mise.jdx.dev/)：`mise use -g github:flatpark/rpak`。

## 别名和补全

zsh 把下面这段加到 `~/.zshrc` 的 `compinit` 之后：

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

bash：在 `~/.bashrc` 里加 `alias flatpak=rpak` 和 `source <(rpak completion bash)`。fish：在 `config.fish` 里加同样的别名和 `rpak completion fish | source`。

软件中心和自动更新仍直接调用 flatpak；偶尔跑一次 `rpak clean` 清掉它们留下的副本。
