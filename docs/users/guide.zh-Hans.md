---
description: 安装、更新、卸载和了解 FlatPark 应用。
order: 1
---

# 用户指南

## 安装应用

先添加 FlatPark remote（只需一次），然后即可安装任意应用：

```sh
flatpak --user remote-add --if-not-exists flatpark https://dl.flatpark.org/flatpark.flatpakrepo
flatpak --user install flatpark <app-id>
```

[配置页面](/setup/)提供了完整的首次使用步骤，其中也包括 runtime remote。

## 用户安装与系统安装

`--user` 会将应用安装到你的主目录中，不需要管理员权限。若要安装到整个系统，请从两条命令中去掉 `--user`（需要 root 权限）。两种方式都可以；如果不确定，使用 `--user` 最简单。

## 更新与 runtime

每日检查会监控每个应用的 upstream 发布渠道，并通过 Pull Request 固定新版本，因此正常运行 `flatpak update` 即可让所有内容保持最新。

Runtime 会同步升级。每个应用都以其 runtime 的当前主版本为目标——应用目录绝不会分散使用诸如 GNOME 49 和 50 这样的不同版本——因此你不必仅为某个迟迟未升级的应用在磁盘上保留旧主版本。新主版本发布后，整个应用目录会一起基于它重新构建和测试：

```sh
flatpak --user update
```

## 查看应用权限

每个应用页面都会列出它请求的确切 sandbox 权限，并附有通俗易懂的风险标签。安装前请先检查这些权限——请参阅[信任与安全](../project/trust.md)了解此模型提供的保障。

## 授予可选权限

软件包默认采用仍能让应用正常工作的最严格 sandbox，因此会有意关闭一些可选功能。如果应用存在这类功能，其页面会列出启用功能所需的确切命令，由你决定是否运行：

```sh
flatpak override --user --filesystem=~/.ssh:ro org.electerm.Electerm
```

授予权限前，请确认它会开放哪些访问范围——例如，`--filesystem=home` 会让应用能够访问你的整个主目录。若要查看自己做过的更改或撤销更改：

```sh
flatpak override --user --show org.electerm.Electerm
flatpak override --user --reset org.electerm.Electerm
```

## 卸载

```sh
flatpak --user uninstall <app-id>
```

之后若还要移除不再使用的 runtime：

```sh
flatpak --user uninstall --unused
```

## 故障排除

- **找不到应用：** 请确保已经添加 remote（运行 `flatpak remotes` 检查），并确认 app id 与应用页面显示的内容完全一致。
- **签名/GPG 错误：** 使用上面的命令重新添加 remote；该命令会固定签名密钥。
- **无法启动：** 从终端运行应用（`flatpak run <app-id>`）以查看错误输出。
