---
title: 关于 FlatPark
description: 介绍 FlatPark 是什么、为何存在，以及它与 Flatpak 和 Flathub 的关系。
group: Project
order: 1
---

FlatPark 是一个社区 Flatpak 应用中心，收录提供明确下载产物的应用——即在稳定、公开的发布 URL 上提供官方安装程序或预构建归档的应用。FlatPark 会在构建时获取该发布产物，将其重新打包为 Flatpak（使用 [extra-data](/zh-Hans/trust/)），固定其版本并对结果签名。FlatPark 从不自行从源码构建应用。

## 为什么需要 FlatPark

- **统一 runtime 版本，并始终使用最新版。** 每个应用都以其 runtime 的*当前*主版本为目标——不会出现一个应用使用 GNOME 49、另一个使用 50 的情况。旧主版本只会闲置在你的磁盘上，因此整个应用目录会同步向前升级，而你只需保留一份 runtime。
- **在 sandbox 中运行，不侵入主目录。** Flatpak 将每个应用隔离在 sandbox 中；FlatPark 会尽量收紧权限，并在每个应用页面上明确展示这些权限。
- **集中安装和更新。** 原本只提供原始 `.deb`、`.rpm` 或 tarball 的应用，也能通过同一个 remote 安装并自动更新。（不接受 AppImage——请参阅[收录政策](/zh-Hans/policies/)。）
- **只看应用做了什么，不看它是怎么写出来的。** “AI slop”这个标签正在泛滥——Flathub 的 PR 队列、Reddit，到处都是——好软件被它随手一句打发，背后却没有任何真正的审核。FlatPark 拒绝这种反射式否定：这里的每个应用都经过实际构建、运行，并按[公开标准](/zh-Hans/policies/)审核——我们贴出的每个标签都经得起追问。

## 与 Flatpak 和 Flathub 的关系

FlatPark 基于 [Flatpak](https://flatpak.org/) 构建，且**与 [Flathub](https://flathub.org/) 没有关联**。Flathub 会从源码构建大多数应用；FlatPark 则有意只重新打包官方下载产物（extra-data）。二者相互补充——如果某个应用已在 Flathub 上提供，请从 Flathub 安装。

## 谁在运营 FlatPark

FlatPark 是一个独立、由社区运营的项目。FlatPark 自身的代码采用 MIT 许可证；所打包应用的所有权仍归各自厂商所有，并会在安装时从官方来源获取。
