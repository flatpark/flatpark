---
description: 安装需要测试者的 PR 的构建，切回正式版应用，用完后删除测试仓库。
order: 8
---

# 测试 PR 的构建

有些改动需要我们没有的机器：某种显卡、arm 电脑、特定的桌面环境。这类 PR 带有 `needs-testers` 标签，每个都有自己的测试仓库，地址是 `https://test.flatpark.org/pr/<N>/`，`<N>` 是 PR 编号。PR 下有一条评论，列出其中的应用和要用的命令。每次推送它都会更新，所以那里的命令总是最新的。

测试构建用 FlatPark 的**测试**密钥签名，不是正式密钥。它用来试一个改动，不适合日常使用。

## 安装

还没从 FlatPark 装过这个应用？用 PR 给的链接安装：

```sh
flatpak install --user https://test.flatpark.org/pr/<N>/<app-id>.flatpakref
```

已经从 FlatPark 装了？添加 PR 的仓库，再把应用切过去：

```sh
flatpak remote-add --user --if-not-exists flatpark-pr<N> https://test.flatpark.org/pr/<N>/flatpark-pr<N>.flatpakrepo
flatpak install --user --reinstall flatpark-pr<N> <app-id>
```

第一次安装时可能会问是否把 Flathub 添加为运行时仓库（应用运行所依赖的共用基础），选是即可，只会问这一次。

设置留在原处（`~/.var/app/<app-id>/`）。去掉 `--user` 就是给整台电脑装。之后 `flatpak update` 会拿到 PR 的新推送。

在 PR 里说你测了什么、结果如何：应用等的就是这个。该试哪些、可以照抄的简短报告，见[测试 PR 构建](../reviewers/triage.md#testing-a-pr-build)。

## 切回去

切回正式版：

```sh
flatpak install --user --reinstall flatpark <app-id>
flatpak remote-delete --user flatpark-pr<N>
```

还没上架的应用，直接卸载：

```sh
flatpak uninstall --user <app-id>
flatpak remote-delete --user flatpark-pr<N>
```

## PR 合并或关闭之后

测试仓库会被撤下。下次 `flatpak update` 时，Flatpak 把应用显示为 **end-of-life**，并附上该怎么做，例如：

```
Info: <app-id> is end-of-life, with reason: PR #<N> merged; switch to the released build: flatpak install --reinstall flatpark <app-id> && flatpak remote-delete flatpark-pr<N>
```

应用照常能用。运行消息里的两条命令：合并的 PR 会把你切到正式版，其他情况会删掉测试构建。十四天后仓库被删除，它的 remote 也就不能用了；还没删的话删掉它。
