---
title: 信任与安全
description: FlatPark 如何重新打包、固定、签名并以 sandbox 运行其收录的应用。
group: Project
order: 3
---

FlatPark 的整个模式都是重新打包官方下载产物，而不是重新构建它们。下面准确说明这对你安装的内容意味着什么。

## 仅使用 extra-data

FlatPark 会在安装时下载**厂商自己的发布产物**，并将其封装为 Flatpak。你运行的是官方 binary，而不是 FlatPark 重新构建的版本。当厂商发布的是 **AppImage** 时，FlatPark 会离线解包其末尾附带的文件系统——AppImage 只被读取、绝不执行，也不涉及 FUSE。

有些软件包包含少量厂商下载产物之外的内容，例如 wrapper 脚本，或 Flatpak runtime 没有提供的库（比如托盘图标库）。共享的支持库来自 FlatPark 经过审核的 [`flatpark/prebuilt`](https://github.com/flatpark/prebuilt) repo，由固定源码构建。这些只是应用外围的打包支撑，不会替换或修改厂商的 binary。

开源应用的进程中不会被注入任何代码。闭源应用偶尔需要一个小型的注入适配才能在 sandbox 中工作（例如 `LD_PRELOAD` shim）；遇到这种情况，应用说明中会准确写明它是什么、为什么需要。

## 固定并签名

每个发布版本都在 manifest 中按 `sha256` 和大小固定，因此构建过程无法悄悄替换 binary。由于固定项指定了精确 checksum，即使厂商悄悄更改某个 URL 背后的文件，变更也**不会**传递给你——构建反而会失败。每日检查会发现新的 upstream 发布版本，并新建 Pull Request 重新固定版本，再由维护者审核和合并。

发布的 repo **使用 GPG 签名**，客户端会在安装和更新时验证该签名。

## 严格的 sandbox

FlatPark 倾向使用仍能让应用正常工作的最少 `finish-args`，并避免 `--filesystem=home` 这类范围宽泛的授权。每个应用页面都会列出其确切权限，并附有通俗易懂的风险标签，让你能在安装前了解应用可以访问哪些内容。

应用并非绝对需要的功能**默认保持关闭**。如果应用获得更宽泛的权限后可以使用更多功能，其页面会记录用于授权的 `flatpak override` 命令，让选择权留在你手中——请参阅[用户指南](/zh-Hans/guide/)。

## 社区软件包不代表认可

FlatPark 是独立项目，**与其打包的应用没有关联**。应用在此出现并不代表其厂商认可该软件包，除非应用自己的页面明确说明。每个软件包都会链接到 upstream 源码和网站，供你自行核实来源。

## 验证你安装的内容

- 查看应用页面上的**权限**面板。
- 通过 **Source** 和 **Website** 链接前往 upstream。
- 通过已签名的 remote 安装（请参阅[用户指南](/zh-Hans/guide/)）；客户端会自动验证签名。
