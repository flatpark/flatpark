---
description: 介绍 FlatPark 是什么、相信什么，以及它与 Flatpak 和 Flathub 的关系。
order: 1
---

# 关于 FlatPark

FlatPark 是一个社区 Flatpak remote，收录提供官方 Linux 下载的应用：在稳定、公开的发布 URL 上提供安装程序、`.deb`、tarball 或 AppImage。FlatPark 用校验和与文件大小固定这份下载，把它包装成 Flatpak（[extra-data](trust.md)）并签名。你安装应用时，Flatpak 直接从开发者的服务器下载文件。FlatPark 不从源码构建应用，也不托管应用文件。

有些应用由开发者自己发布。更多的应用是社区因为用户需要而打包的：厂商只在自己官网放一个安装包，从没考虑过 Flatpak。无论哪种，文件都是厂商自己发布的那一份，上游发版后通常几分钟内就能更新。

## 宗旨

**在 Linux 上装应用，本该很简单。**

- 让每个开发者都能把应用直接交到 Linux 用户手里。
- 让每个用户想用的应用都能在 FlatPark 找到。

## 我们相信什么

1. **软件丰富是好事。** AI 让写软件变得前所未有地容易，Linux 桌面第一次迎来了应用的繁荣。其中难免有随手写、没人维护的作品，但整体利远大于弊。生态缺的从来不是软件太多。
2. **发布是开发者的权利。** 在网上发一个网页不需要谁许可，发布一个应用也一样。规模大不代表有资格替所有人决定什么软件配存在。
3. **用户需要的应用，就该装得上。** 很多应用只通过厂商自己的渠道分发，厂商不会为 Linux 商店操心，但用户确实需要它们。这时由社区替用户打包，用的仍是厂商的官方发布。
4. **选择是用户的权利。** 用户能自己判断装什么。商店的责任是把事实摆清楚，而不是替用户做决定。
5. **商店的权力用来服务，不是用来把关。** 商店天然掌握推荐和引流，这份权力应该在保障开发者和用户权利的前提下，用来带来便利、让好应用被看见，绝不能变成打压别人的工具。

FlatPark 的每条规则都由这几条出发，经过[原则](principles.md)推导而来。

## 与 Flatpak 和 Flathub 的关系

**Flatpak。** FlatPark 就是一个普通的 [Flatpak](https://flatpak.org/) remote：应用的安装、更新和沙盒运行，用原版 `flatpak` 以及基于它的各种工具都可以。[rpak](../users/rpak.zh-Hans.md) 是 `flatpak` 的包装器，接受所有 flatpak 命令，补上了原版 Flatpak 没有的能力：并行下载安装包、释放 Flatpak 留下的安装包副本、让其他 remote 的应用跑在更新的 runtime 上。

**Flathub。** FlatPark 和 [Flathub](https://flathub.org/) 一样是一个 remote，**但与 Flathub 没有关联**。FlatPark 的应用使用 Flathub 上的 freedesktop、GNOME 和 KDE runtime，所以需要同时添加 Flathub。应用以 extra-data 的方式发布，Flathub 上也有很多应用是这样发布的：包里固定官方下载，安装时由 Flatpak 从厂商那里下载。FlatPark 的不同之处在于每个应用都保持在最新的 runtime 上：新的 runtime 出来后，用它的应用会一起升级并测试。

开发者自己在 Flathub 上发布的应用（在 Flathub 上有认证），FlatPark 不会重复打包，除非开发者要求。Flathub 上的包由别人维护、并且缺少功能、更新滞后或已经不能用时，FlatPark 可以提供这个应用，并在应用描述里写明两者的区别。

## 谁在运营 FlatPark

FlatPark 是一个独立、由社区运营的项目。FlatPark 自身的代码采用 MIT 许可证；所打包应用的所有权仍归各自厂商所有，并在安装时从官方来源下载。
