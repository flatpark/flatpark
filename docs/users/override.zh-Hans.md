---
description: 用 flatpak override 修改应用能访问什么：它是什么、怎么检查，以及常见情况：其他磁盘、SSH 密钥、设备、网络、缩放、在系统上执行命令。
order: 4
---

# flatpak override

每个 Flatpak 应用都在沙箱里运行，软件包规定了它能接触什么：哪些文件夹、设备、网络、桌面服务。FlatPark 的每个应用只申请主要功能所需的最少权限，应用页面列出了每一项权限，并用通俗的话说明它允许什么。

`flatpak override` 是**你**为某个应用修改这份清单的方式，两个方向都可以：给它一个原本没有的文件夹，或者收回软件包给的某项权限。你的修改和软件包分开保存，所以更新后依然有效，也随时可以撤销。

你在桌面自己的权限对话框里做的回答（允许截图、使用摄像头、"打开方式"）存在另一个地方，见[权限存储](permission-store.md)。

## 检查

```sh
flatpak info --show-permissions <app-id>      # 应用现在实际拥有的权限，包含所有修改
flatpak override --user --show <app-id>       # 只看你改过的
flatpak override --user --reset <app-id>      # 撤销你的所有修改
```

你**收回**的权限在第一条命令的输出里根本看不到，第二条才能看到。Flatseal 之类的工具改的也是同一份 override，所以你在那里做的修改这两条命令都能看到。

带 `--user` 的修改只影响你自己。不带它（并用 `sudo`）的修改对这台电脑上的所有人生效，你自己的修改叠加在上面。

## 常见情况

**打开可选权限。**有些应用拿到更宽的权限能做更多事，这些默认是关的。应用页面会给出确切命令：

```sh
flatpak override --user --filesystem=~/.ssh:ro org.electerm.Electerm
```

运行之前想一想它会放开什么。`--filesystem=home` 会让应用能读写你主目录里的所有东西。

**资料库在另一块磁盘上。**通过文件选择框打开的文件总能用。但要让应用自己看到某个文件夹（在第二块硬盘或 U 盘上），就需要授权；只需要读的话加 `:ro`：

```sh
flatpak override --user --filesystem=/mnt/music com.foobar2000.Foobar2000
flatpak override --user --filesystem=/mnt/data:ro com.calibre_ebook.calibre
flatpak override --user --filesystem=/run/media com.foobar2000.Foobar2000     # U 盘、移动硬盘
```

**SSH 密钥。**`--socket=ssh-auth` 让应用通过你的 SSH agent 使用密钥，但看不到密钥本身；应用支持 agent 时优先用它。`--filesystem=~/.ssh:ro` 让应用读取密钥文件。

**串口、安全密钥、摄像头。**Flatpak 没法只授权某一个设备，要么 `--device=all`，要么没有，所以只给确实需要的应用：

```sh
flatpak override --user --device=all io.github.binaricat.Netcatty
```

**让应用保持离线。**`--unshare=network` 切断网络；检查更新、登录、在线功能都会停止。`--share=network` 恢复。

```sh
flatpak override --user --unshare=network com.snipaste.Snipaste
```

**大小和显示问题。**应用页面会写出修复用的设置，通常是一个环境变量。`--unset-env=变量名` 去掉。

```sh
flatpak override --user --env=GDK_SCALE=2 com.falconpdf.app
flatpak override --user --env=UI_SCALE=2 com.schwab.thinkorswim
flatpak override --user --env=WEBKIT_DISABLE_COMPOSITING_MODE=1 dev.aninsomniacy.rayburst
```

**能在你的系统上执行命令的应用。**少数软件包为了某一个功能需要这项权限，页面上会标"隔离降低"并写明原因。收回后只有那个功能会停（Enpass 是浏览器扩展）：

```sh
flatpak override --user --no-talk-name=org.freedesktop.Flatpak io.enpass.Enpass
```

**应用记不住设置。**如果你关掉过它的某个文件夹（比如在 Flatseal 里），Flatpak 会在原处放一个空的临时文件夹，应用写进去的东西就丢了。用 `--show` 检查，去掉那一项或者 `--reset`。如果你什么都没改过，那是打包问题，请[报告](troubleshooting.md#报告问题)。修好之前，`flatpak override --user --persist=.something <app-id>` 可以把主目录下的隐藏文件夹 `~/.something` 存进应用自己的数据里。

**保存文件时报"Device or resource busy"。**软件包授权的是这一个文件，而不是它所在的文件夹。挂载到文件本身上的授权没法被"写新文件再改名覆盖"的方式替换。改成授权文件夹；文件直接在主目录下时：

```sh
flatpak override --user --filesystem=home --nofilesystem=~/.app.json <app-id>
```

授权重叠时（比如主目录只读、"文档"可写，或者关掉某个子文件夹）具体怎么生效，英文版的 For agents 部分有一张实测过的对照表。
