---
description: 介绍 FlatPark 是什么、为何存在，以及它与 Flatpak 和 Flathub 的关系。
order: 1
---

# 关于 FlatPark

FlatPark 是一个社区 Flatpak remote，收录提供官方 Linux 下载的应用：在稳定、公开的发布 URL 上提供安装程序、`.deb`、tarball 或 AppImage。FlatPark 用校验和与文件大小固定这份下载，把它包装成 Flatpak（[extra-data](trust.md)）并签名。你安装应用时，Flatpak 直接从开发者的服务器下载文件。FlatPark 不从源码构建应用，也不托管应用文件。

## 目标

FlatPark 的目标是做一个高效运转、容易参与的 Flatpak remote。速度最重要：应用常常在上游发布几分钟后就上架，修复也同样快地送到用户手里。每条规则都用两个问题来衡量：能不能避免我们自己带着 bug 发布，会不会拖慢这个速度。

## 为什么需要 FlatPark

- **集中安装和更新。**原本只提供原始 `.deb`、`.rpm`、tarball 或 AppImage 的应用，也能通过同一个 remote 安装并自动更新。
- **每个应用都用当前的 runtime。**freedesktop、GNOME 或 KDE runtime 出新版本时，用它的应用会一起升级并测试，不会因为某个 FlatPark 应用让你的磁盘上留着旧 runtime。其他来源安装的应用仍可能需要它们自己的 runtime。
- **最小权限，每个页面都写明。**每个软件包只授予应用主要功能所需的权限，页面上列出每一项权限并说明它允许什么。更多的权限由你自己用 `flatpak override` 打开。
- **只看应用做了什么，不看它是怎么写出来的。** “AI slop”这个标签正在泛滥——Flathub 的 PR 队列、Reddit，到处都是——好软件被它随手一句打发，背后却没有任何真正的审核。FlatPark 拒绝这种反射式否定：这里的每个应用都经过实际构建、运行，并按[公开标准](policies.md)审核——我们贴出的每个标签都经得起追问。

## 与 Flatpak 和 Flathub 的关系

FlatPark 基于 [Flatpak](https://flatpak.org/) 构建，且**与 [Flathub](https://flathub.org/) 没有关联**。Flathub 会从源码构建大多数应用；FlatPark 只重新打包官方下载。二者相互补充。

开发者自己在 Flathub 上发布的应用（在 Flathub 上有认证），FlatPark 不会重复打包，除非开发者要求。Flathub 上的包由别人维护、并且缺少功能、更新滞后或已经不能用时，FlatPark 可能也提供这个应用，并在应用描述里写明两者的区别。

## 谁在运营 FlatPark

FlatPark 是一个独立、由社区运营的项目。FlatPark 自身的代码采用 MIT 许可证；所打包应用的所有权仍归各自厂商所有，并在安装时从官方来源下载。
