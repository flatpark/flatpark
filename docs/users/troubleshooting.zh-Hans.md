---
description: 应用装不上、打不开或记不住设置时查什么，以及怎么报告问题。
order: 7
---

# 排查问题

- **找不到应用：**用 `flatpak remotes` 确认 remote 在，并确认 app id 和应用页面上的完全一致。按用户添加的 remote 和系统级安装互相看不见（反过来也一样），见[配置](setup.md)。
- **签名或 GPG 错误：**用[配置](setup.md)里的命令重新添加 remote，它带着签名密钥。
- **安装时报"Wrong size"或下载失败：**应用文件是安装时从开发者服务器下载的。如果开发者替换了文件，在我们更新校验和之前（通常一天内）会对不上。稍后再试，一直不行就报告。
- **应用打不开：**在终端里运行看原因：`flatpak run <app-id>`。
- **应用从目录里消失了或改了名：**下架的应用在你卸载之前都能继续用，但不会再更新。改名的应用是一个新 id：从它的页面用新 id 安装，再卸载旧的。设置不会自动迁过去。
- **重启后设置没了：**先确认你没有关掉它的某个文件夹（见 [flatpak override](override.md#常见情况)）。如果没有，那是打包问题，请报告。

## 报告问题

在 [github.com/flatpark/flatpark/issues](https://github.com/flatpark/flatpark/issues) 开一个 issue，写上 app id、你做了什么、发生了什么，以及在终端运行 `flatpak run <app-id>` 的输出。说明你用的发行版和桌面环境。打包方式的问题由我们修；应用本身的问题我们会转给开发者。
