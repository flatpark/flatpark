---
description: 新版本怎么到你手里，以及为什么所有应用同时换到新的运行时。
order: 3
---

# 更新

和其他 Flatpak 应用一样运行 `flatpak update`，或者交给软件中心：

```sh
flatpak --user update
```

## 新版本怎么来

FlatPark 盯着每个应用的官方发布。很多开发者一发版就会通知 FlatPark，其余的每天检查两次。新版本会被重新固定校验和、确认能装上，然后发布，通常在上游发版后几分钟到几小时内完成，不需要有人逐个批准。

更新时你下载的是开发者自己发布的新版本：和安装时一样，Flatpak 从开发者的服务器下载，在你的电脑上解包。

## 关注新应用和新版本

网站发布两个 Atom 订阅源，可以加到你的阅读器里：

- [flatpark.org/feed.xml](https://flatpark.org/feed.xml)：新上架的应用，最新的在前。
- [flatpark.org/updates.xml](https://flatpark.org/updates.xml)：已上架应用的新版本，标题为应用名称加版本号。

两个订阅源都随每次发布和网站一起重建。`updates.xml` 里的版本按应用自己的发布列表中的日期出现，可能比 FlatPark 重新固定它稍早一点；现在能装什么，以 `flatpak update` 为准。

## 运行时一起升级

每个应用都用它所在运行时（Flatpak 应用共用的基础环境）的当前版本。运行时出新版本时，整个目录一起切过去、一起测试，所以你不会为了某个没跟上的应用在磁盘上多留一份旧运行时。切换之后，`flatpak update` 会下载一次新运行时，`flatpak uninstall --unused` 可以删掉旧的（见[清理](cleanup.md)）。其他仓库的应用可能停在旧运行时上，rpak 可以[让它们跑在新的上面](rpak.zh-Hans.md#让应用跑在新运行时上实验性)。
