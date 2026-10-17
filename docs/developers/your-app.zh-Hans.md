---
description: 你的应用怎么来到 FlatPark、哪些事由你决定、开发者授权盾牌，以及怎么在你自己的网站上链接过来。
order: 1
---

# 你的应用在 FlatPark 上

FlatPark 打包那些发布了官方 Linux 版本的桌面应用。它不重新构建你的应用：用户安装时，软件包从你的服务器下载你自己发布的文件，解包后放在 Flatpak 沙箱里运行。用户拿到的就是你发布的那个二进制，校验和和你的一致，你一发版他们就能更新。

这里的大多数应用是 FlatPark 打包的，很多是在开发者知道 FlatPark 之前就上架了。如果你也是这样发现自己的应用在这里的：它怎么处理，由你决定。

## 由你决定的事

对你自己的应用，你说了算：

- **要不要在这里。**你提出，就下架，不需要理由。
- **怎么打包。**权限、默认设置、用你的哪个下载文件。你希望软件包换一种行为，说一声就改。
- **我们怎么介绍它。**应用的描述和应用页面上的其他内容。

以上任何一件，都可以在 [github.com/flatpark/flatpark](https://github.com/flatpark/flatpark/issues) 开 issue，或者直接回复我们在你项目里开的那个 issue。

## 申请上架

开一个 issue，附上你的应用和它的 Linux 下载链接。容易打包的应用通常有这些：

- 一个放在稳定公开地址上的官方 Linux 版本：tarball、`.deb`、AppImage 或 zip，放在 GitHub Releases 或你自己的网站上都行；
- 每个版本的发布文件名遵循同一个规律；
- 如果你已经在用某个 Flatpak 或 Tauri 的 app id，这里也用同一个。

完整的条件，包括沙箱里做不到的事，见[能不能打包](../packagers/can-it-be-packaged.md)。

## 开发者授权盾牌

如果你同意应用放在 FlatPark 上，请在我们能链接到的公开地方说一声：issue、PR、discussion 都可以。之后你的应用页面会显示蓝色的**开发者授权**盾牌，链接记录在[授权记录](../reference/upstream-approvals.md)里。只发私信邮件不够，因为看页面的人得能自己去核实。

没有盾牌时，这个软件包是社区打包，不代表你的认可，应用描述里也会这样写。

## 链接到 FlatPark

如果你愿意在网站或 README 里把 FlatPark 列为一种安装方式，应用页面上有安装命令，也有一个徽章：

```markdown
[![Get it on FlatPark](https://flatpark.org/badges/get-it-on-flatpark.svg)](https://flatpark.org/apps/<app-id>/)
```

```sh
flatpak remote-add --if-not-exists --user flatpark https://dl.flatpark.org/flatpark.flatpakrepo
flatpak install --user flatpark <app-id>
```

## 更新

FlatPark 每天检查两次你的发布，每个新版本都会自动上线：重新固定下载文件的校验和、确认能解包、然后发布。如果你在 GitHub 上发版，在发布工作流里加上 [publish-action](publish-action.md)，几分钟内就能上线。

如果某次发布的变化超出了软件包的预期（二进制改名、压缩包结构变了），更新会停在解包检查这一步，之前的版本照常可用，我们手动修好软件包。

## Flathub

如果你自己在 Flathub 上发布了应用，告诉我们。我们会下架 FlatPark 的软件包，除非你希望两边都保留。只有当 Flathub 上的包由别人维护、而且有明确理由（缺功能、更新严重滞后）时，FlatPark 才会同时提供，并在描述里写明两者的区别。

## 改名或更换 app id

Flatpak 应用以 app id 区分，所以新 id 就是一个新软件包：已安装的副本不会自己迁过去。请在改 id 的那个版本发布之前告诉我们；新 id 会和旧的并列上架，等新版本发出后再下架旧的。

## 问题报告

打包方式的问题（在沙箱里启动不了、缺权限、记不住设置）归我们：用户在 [FlatPark 的 issues](https://github.com/flatpark/flatpark/issues) 报告。应用本身的问题，我们会连同查到的情况转给你。
