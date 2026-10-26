---
description: 桌面把你在权限对话框里的回答（打开方式、截图、摄像头、打开过的文件）存在哪里，以及怎么检查和修改。附 calibre 选择 PDF 阅读器的例子。
order: 5
---

# 权限存储（permission store）

沙箱里的应用有些事自己做不了：用别的程序打开文件、截图、使用摄像头、读取你选中的文件。它会通过**门户（portal）**去请求桌面，桌面可能弹出一个对话框问你。你的回答会存进 Flatpak 的**权限存储**，这样就不用每次都问。

它和 [flatpak override](override.md) 是两回事：

- `flatpak override` 改的是沙箱允许什么；由你来设置。
- 权限存储记的是你在对话框里的回答；由桌面来设置。

所以 `flatpak override --reset` 清不掉权限存储，卸载应用也会把它的条目留下来。

## 检查和重置

```sh
flatpak permission-show <app-id>      # 某个应用被记住的所有回答
flatpak permission-reset <app-id>     # 全部忘掉，下次会重新询问
flatpak permissions                   # 所有应用的全部条目
```

GNOME 的"设置 › 应用"也能查看和修改其中一部分；其他桌面就用上面这些命令。

## 例子：选择 calibre 的 PDF 阅读器

calibre 不在自己的阅读器里显示 PDF，而是交给桌面，由桌面问你用哪个程序打开。同一个阅读器选过几次之后，对话框就不再出现：这个选择已经针对 calibre 和 PDF 记住了。以后想换阅读器，先看记住的是什么，再删掉它：

```sh
flatpak permissions desktop-used-apps application/pdf
# desktop-used-apps  application/pdf  com.calibre_ebook.calibre  org.gnome.Evince,3,3  0x00

flatpak permission-remove desktop-used-apps application/pdf com.calibre_ebook.calibre
```

下一个 PDF 就会重新弹出对话框。其他文件类型同理：把 `application/pdf` 换成对应的类型，`xdg-mime query filetype <文件>` 可以查出来。每个应用的选择是分开记的，你在浏览器里选的阅读器不会被 calibre 用上。

## 其他可能想改的回答

| 你遇到的情况 | 命令 |
|---|---|
| 截图工具不再询问，或者被拒绝过一次后一直失败 | `flatpak permission-remove screenshot screenshot io.github.jswysnemc.MarkShot` |
| 应用被拒绝使用摄像头，或者你想收回摄像头权限 | `flatpak permission-remove devices camera <app-id>` |
| 屏幕共享总是共享同一块屏幕 | 先 `flatpak permissions screencast`，再 `flatpak permission-remove screencast <id>` |
| 应用还能打开你很久以前选过的文件 | 先 `flatpak documents <app-id>`，再 `flatpak permission-remove documents <id> <app-id>` |

删掉一条回答，意味着下次会重新问你。

存储方式、各张表的含义和预先设置回答的方法，见英文版的 For agents 部分。
