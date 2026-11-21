---
description: rpak 包装 flatpak：并发下载安装包、释放 Flatpak 留下的副本、让其他仓库的应用跑在新运行时上，同时接受所有 flatpak 命令。
order: 2
---

# 使用 rpak

[rpak](https://github.com/flatpark/rpak) 是 `flatpak` 的包装器。建议把 `flatpak` 设成它的别名，照常敲熟悉的命令即可：

- **并发下载**：`install` 和 `update` 同时下载多个应用安装包，而不是一个接一个。
- **清理空间**：每次安装或更新后释放 Flatpak [留下](cleanup.zh-Hans.md#回收下载的安装包占用的空间)的安装包副本；`rpak clean` 清理更早的副本和其他残余。
- **报告问题**：`rpak doctor` 收齐报 bug 需要的信息。
- **新运行时**（实验性）：`rpak patch` 让[没跟上](#让应用跑在新运行时上实验性)的应用用上当前的运行时。
- **完全兼容**：其他 flatpak 命令和选项原样透传。

## 安装

```sh
curl -Lo ~/.local/bin/rpak "https://github.com/flatpark/rpak/releases/latest/download/rpak-linux-$(uname -m)"
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

## 出问题时

```sh
rpak doctor <app-id>
```

列出发行版、桌面、显卡、flatpak 配置、override，以及应用的下载地址能不能访问。它只负责收集，输出怎么解读交给看报告的人。[报告问题](troubleshooting.zh-Hans.md#报告问题)时把完整输出贴上。它不改动任何东西，也不会带上 home 路径、用户名和你打开过的文件名。不带应用 id 只收集环境信息；带多个就逐个收集。

## 让应用跑在新运行时上（实验性）

FlatPark 的应用[一起升级运行时](updates.zh-Hans.md#运行时一起升级)，其他仓库的应用不一定。截至 2026-11-21，在 Flathub 上，Zen（`app.zen_browser.zen`）还在用 `org.freedesktop.Platform` 25.08 构建，Sublime Merge（`com.sublimemerge.App`）还在用已经停止维护的 24.08。每个这样的应用都会让一份旧运行时留在磁盘上，几百 MB，更老的那些还没有安全更新。

`--force-runtime` 让应用直接跑在它所用运行时的最新分支上：

```sh
rpak install --force-runtime flathub app.zen_browser.zen   # 安装时就强制
rpak patch --force-runtime com.sublimemerge.App            # 强制已经装好的应用
rpak patch                                                 # 列出强制了哪些
rpak patch --reset app.zen_browser.zen                     # 回到构建时的运行时
flatpak uninstall --unused                                 # 没有应用再用旧运行时后删掉它
```

之后的 `rpak update` 会保持强制；等打包者自己把应用升到那个运行时，就不再强制。Zen 没有 [extra-data](cleanup.zh-Hans.md#回收下载的安装包占用的空间)，rpak 只改已安装应用声明的运行时。Sublime Merge 要从厂商下载安装包、在运行时里跑脚本解包，所以 rpak 会先按 Flathub 的签名校验每个文件，再生成一份只改了运行时的 Flathub 包，从本地仓库 `rpak-local` 安装。两种情况下应用的文件和权限都和打包者做的一样。不经过 rpak 的 `flatpak update`（软件中心、自动更新）会让应用回到旧运行时，下一次 `rpak update` 再强制回来。

### 可能弄坏应用

应用是在旧运行时上构建和测试的，没人在新运行时上测过，rpak 也不检查兼容性，只在每次强制时提醒。运行时版本之间库会变，应用可能打不开、崩溃，或者丢掉某个功能：视频播放、硬件加速、输入法、插件。跟着运行时版本走的扩展（编解码器、GL 驱动）不会自动装上新版本。

出了问题先 `rpak patch --reset <app-id>`。只在强制时才出现的问题不是应用的 bug，别报给它的打包者。

### 长久的办法

强制只是权宜之计，真正的解决是一个为当前运行时构建的包。先看开发者是不是自己在 Flathub 上发布这个应用：

```sh
curl -s https://flathub.org/api/v2/verification/<app-id>/status   # "verified": true = 开发者自己发布
```

- **已认证**（Zen）：到应用的 Flathub 仓库 `github.com/flathub/<app-id>` 或开发者自己的 issue 区提 issue，请他们尽快升级到当前运行时。开发者自己在 Flathub 发布的应用，FlatPark 不会重复打包。
- **未认证**（Sublime Merge）：Flathub 上是第三方在打包，包落后太多正是 FlatPark 收录自己版本的理由（[哪些应用我们收](../packagers/can-it-be-packaged.md#apps-already-on-flathub)）。[提个收录请求](https://github.com/flatpark/flatpark/issues/new?template=2-app-request.yml)，上架后换过来。

rpak 还能用另一个下载地址替换应用的 extra-data 文件（`--extra-data=URL`：厂商已发新版而包还没跟上、原链接失效），同样是实验性的、没人检查过；见 [rpak 的 README](https://github.com/flatpark/rpak#patch-experimental)。
