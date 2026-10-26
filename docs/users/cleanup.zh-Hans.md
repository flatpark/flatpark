---
description: 卸载应用及其数据、删除不再使用的运行时，以及回收 Flatpak 为下载的安装包保留的空间。
order: 6
---

# 清理

## 卸载应用

```sh
flatpak --user uninstall <app-id>                 # 保留设置和数据
flatpak --user uninstall --delete-data <app-id>   # 连同设置和数据一起删
```

不加 `--delete-data` 时，应用的设置留在 `~/.var/app/<app-id>/`，以后重新安装可以接着用。

卸载不会动应用写在沙箱**之外**的文件：也就是它被允许使用的文件夹（文档、图片、它自己的 `~/.应用名` 文件夹）。应用页面的权限列表写着是哪些文件夹。你用 `flatpak override` 做的修改也会保留，用 `flatpak override --user --reset <app-id>` 删掉。你在它的权限对话框里做过的回答也一样，用 `flatpak permission-reset <app-id>` 清掉（见[权限存储](permission-store.md)）。

## 删除不再使用的运行时

运行时是共用的，最后一个用它的应用卸载后它还在；目录切到新版本后，旧版本也还在。删掉没人用的：

```sh
flatpak --user uninstall --unused
```

## 移除 FlatPark

先卸载它的应用，然后：

```sh
flatpak --user remote-delete flatpark
```

系统级配置用同样的命令，去掉 `--user`。

## 回收下载的安装包占用的空间

FlatPark 的应用是在安装时下载开发者自己的文件的。Flatpak 装这类应用时，解包之后**还会把原始下载保留**在它的仓库里，每次更新再多存一份新的。大应用累积起来很可观：这份副本和应用安装包一样大，而且只有重装同一个版本时才会再用到。

查看这些副本占了多少空间：

```sh
find ~/.local/share/flatpak/repo/objects -name '*.commitmeta' -size +100k \
  -exec grep -laF xa.extra-data {} + | xargs -r du -ch | tail -1
```

在没有 Flatpak 安装或更新正在进行时删除它们：

```sh
find ~/.local/share/flatpak/repo/objects -name '*.commitmeta' -size +100k \
  -exec grep -laF xa.extra-data {} + | xargs -r rm -f
```

代价是：Flatpak 把下载和这个应用版本的签名存在同一个文件里，所以签名也会一起删掉。签名只在下载某个版本时才校验，所以运行、更新和 `flatpak repair` 都不受影响，下一次更新会带来新的、有签名的版本。因为每次更新都会再存一份，这件事值得隔一段时间做一次。系统级配置的仓库在 `/var/lib/flatpak/repo`，命令需要 `sudo`。
