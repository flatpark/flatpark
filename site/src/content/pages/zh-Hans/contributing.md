---
title: 发布指南
description: 如何向 FlatPark 添加应用——descriptor、manifest 和自动更新 resolver。
group: Docs
order: 1
---

欢迎添加任何提供公开下载的应用——FlatPark 不托管构建产物。只要应用在稳定、公开的发布 URL 上提供官方安装程序或预构建归档（extra-data 模式），就可以添加到这里。FlatPark 会在构建时获取产物，固定产物并对结果签名。

也就是说，upstream 只需提供 `.deb`、`.rpm`、`.tar.gz`、zip、官方安装脚本或 AppImage。AppImage 已受支持——FlatPark 在安装时离线解包 AppImage 末尾附带的文件系统（绝不执行，也不需要 FUSE），使用 [`flatpark/prebuilt`](https://github.com/flatpark/prebuilt) 提供的 `appimage-tools` 辅助工具；参考 recipe：[`is.folo.Folo`](https://github.com/flatpark/flatpark/tree/main/registry/is.folo.Folo)（Electron）和 [`org.openshot.OpenShot`](https://github.com/flatpark/flatpark/tree/main/registry/org.openshot.OpenShot)（Qt5）。**欢迎 Electron 和 Tauri 应用**，也**欢迎闭源应用**——许可证并非审核标准，产物来自哪里才是。编写自己的软件包前，值得先阅读 registry 中的三个软件包：

- **Electron**——
  [`pro.affine.AFFiNE`](https://github.com/flatpark/flatpark/tree/main/registry/pro.affine.AFFiNE)
  和 [`org.electerm.Electerm`](https://github.com/flatpark/flatpark/tree/main/registry/org.electerm.Electerm)：
  Electron 基础应用加上 `zypak-wrapper`，让 Chromium 保持其内部 sandbox。
- **Tauri / WebKitGTK**——
  [`com.ccswitch.desktop`](https://github.com/flatpark/flatpark/tree/main/registry/com.ccswitch.desktop)：
  这是最完整的 Tauri 示例。它的 wrapper 会导出
  `WEBKIT_DISABLE_DMABUF_RENDERER=1`（没有它时，WebKitGTK 在许多驱动下会显示空白窗口）。如果应用使用 Tauri 的 `tray-icon`，还需要 Ayatana appindicator stack：GNOME runtime 并未提供它，而 `tray-icon` 会通过 `dlopen` 加载它，并可能在它缺失时 panic。**不要在每个应用中复制并维护包含五个 module 的源码构建 recipe。** 请使用 FlatPark 在
  [`flatpark/prebuilt`](https://github.com/flatpark/prebuilt) 中经过审核的预构建 stack，并如下所示按 SHA-256 固定 release archive。它的 `finish-args` 也是权限范围设计的良好范例：它仅授权所管理的各个 CLI 配置路径，而不是 `--filesystem=home`。
- **依赖 host 的行为，payload 保持不变**——
  [`io.enpass.Enpass`](https://github.com/flatpark/flatpark/tree/main/registry/io.enpass.Enpass)：
  Enpass 会运行 `lsof` 并读取 `/proc`，以验证通过 localhost 连接到其扩展的浏览器；这在 sandbox 内无法完成。该软件包没有修改厂商 binary，而是在 `PATH` 中放入小型 `lsof`/`readlink`/`cat` shim，通过 `flatpak-spawn --host` 将调用转发给 host，并通过 `LD_PRELOAD` 加载一个小型 `getpid` override。所提供的 Enpass binary 仍然逐字节保持厂商原样。请注意其代价：它需要通常会被自动拒绝的 `--talk-name=org.freedesktop.Flatpak`，因此软件包在 `policy.dangerous_permissions` 中声明了该权限并说明理由——如果采用这种方式，你也应预期接受同等严格的审核。

## 复用 FlatPark 预构建支持库

FlatPark 在 [`flatpark/prebuilt`](https://github.com/flatpark/prebuilt) 中维护可复用、可再分发的支持库。这些归档由 GitHub Actions 根据固定了所有源码和 patch 的 manifest 构建，每个使用它们的应用也会按 SHA-256 固定生成的归档。这样可以避免在多个应用目录中分别编译和维护相同的依赖 stack。prebuilt repo 仅用于开源支持库；专有应用 payload 必须继续使用来自厂商官方 URL 的 `extra-data`。

**共享的 `flatpark/prebuilt` stack 是软件包唯一可以作为 `type: archive`（或 `git`）module 引入的东西。** 这些字节会被打进 Flatpak ref，并从 FlatPark 自己的对象存储分发。应用 payload，以及只对单个应用有意义的依赖，必须走 `extra-data`——在安装时从厂商或 release URL 获取，永不进入 ref。不要把单个应用缺失的库从源码构建进 `/app`：如果多个应用共用，就在 `flatpark/prebuilt` 里加一个可复现的 release；否则作为第二个 `extra-data` 源发布（固定版本的发行版 `.deb`、上游 tarball 等）。

对于在 `org.gnome.Platform//51` 上使用 `tray-icon` 的 Tauri 应用，请在应用 module 之前将当前 Ayatana stack 添加为普通 archive module：

```yaml
modules:
  - name: ayatana-stack
    buildsystem: simple
    build-commands:
      - cp -a ./. /app/
    sources:
      - type: archive
        url: https://github.com/flatpark/prebuilt/releases/download/ayatana-v2/ayatana-stack-ayatana-v2-gnome-51-x86_64.tar.xz
        sha256: 1051a537f22d335eb79557b8c5a610a12c326712dac74032de8e76e78b876fdc
```

当应用确实提供托盘图标时，还要授权 tray socket：

```yaml
finish-args:
  - --filesystem=xdg-run/tray-icon:create
```

请从现有 manifest（例如 [`com.ccswitch.desktop`](https://github.com/flatpark/flatpark/tree/main/registry/com.ccswitch.desktop)）复制当前 module，而不要使用旧的源码构建 recipe。该归档与其注明的 runtime/SDK 主版本绑定。应用目录迁移到新的 GNOME 主版本时，请使用面向该主版本制作的 prebuilt release，不要悄悄复用旧版本。如果 `flatpark/prebuilt` 尚未提供某个缺失的库，请先确认多个应用是否都会使用它；优先在那里添加一个可复现的 stack，而不是在每个应用 manifest 中重复添加。

## 添加应用

在 `registry/` 下创建一个目录，名称必须与 app id 完全一致：

```text
registry/com.example.App/
  flatpark.yml             # the descriptor (below)
  com.example.App.yml      # the Flatpak manifest
  com.example.App.metainfo.xml
  com.example.App.svg
  resolve-update.sh        # optional: upstream update resolver
```

然后在本地验证并构建：

```sh
node scripts/read-descriptor.mjs registry/com.example.App/flatpark.yml
./scripts/publish.sh --verify com.example.App
```

### 测试时不要污染日常使用的 Flatpak

`publish.sh --verify` 会在你的 **`--user`** installation 中添加一个名为 `flatpark-local` 的**临时**本地 `file://` remote，从中安装应用，以证明构建出的 repo 可以正常安装；然后它会卸载应用并再次删除 remote——绝不会改动你真正的 `flatpark` remote（如果两个名称冲突，脚本会拒绝运行）。如果被验证的应用已经从另一个 remote 安装，verify 会使用 `--reinstall` 暂时替换它，并在清理时从原 remote 恢复。

若要在 verify 后保留已安装的应用以便手动测试 runtime，请设置 `FLATPARK_VERIFY_KEEP=1`：

```sh
FLATPARK_VERIFY_KEEP=1 ./scripts/publish.sh --verify com.example.App
flatpak --user run com.example.App
# ... exercise the core feature, then clean up:
flatpak --user uninstall -y com.example.App
flatpak --user remote-delete --force flatpark-local
rm -rf ~/.var/app/com.example.App
```

临时 repo（`out/repo`）每次运行都会重新构建，因此其中的 commit 会与已安装的内容逐渐不一致——使用 `FLATPARK_VERIFY_KEEP=1` 时，不要在两次会话之间保留 `flatpark-local` remote。若要进行持续时间更长的手动测试，请将构建安装到一个单独、可随时丢弃的 installation 中，以免触碰正常使用的 Flatpak 环境：

```sh
# one-time: create an isolated installation named "test"
sudo install -d /etc/flatpak/installations.d
printf '[Installation "test"]\nPath=%s/.local/share/flatpak-test\nDisplayName=FlatPark test\n' \
  "$HOME" | sudo tee /etc/flatpak/installations.d/test.conf >/dev/null

# install the freshly built app into it, then wipe it when done
flatpak --installation=test remote-add --no-gpg-verify flatpark "file://$PWD/out/repo"
flatpak --installation=test install flatpark com.example.App
flatpak --installation=test uninstall --all
```

没有 root 权限，或不想改动 `/etc`？可以在正常的 `--user` installation 中使用一个**单独命名的 remote** 进行安装。上一段所述的冲突来自与真正的 remote 共用 `flatpark` 名称，而不是 installation 本身：

```sh
flatpak --user remote-add --if-not-exists --no-gpg-verify test-tmp "file://$PWD/out/repo"
flatpak --user install -y test-tmp com.example.App
# ... launch it, exercise the core feature ...
flatpak kill com.example.App
flatpak --user uninstall -y com.example.App
flatpak --user remote-delete test-tmp
rm -rf ~/.var/app/com.example.App
```

> **不要尝试用 `FLATPAK_USER_DIR` 获得隔离环境。** 它确实会生成一个可随时丢弃的 installation，但该 installation 未在 `/etc/flatpak/installations.d` 中注册，因此 **host 的 Flatpak portal 不知道它存在**。任何依赖 `flatpak-spawn` 的功能都会因而失败，并显示 `app/<id>/x86_64/stable ... not installed`——这也包括 **glycin**，即 GNOME 48+ runtime 中 gdk-pixbuf 背后的图像 decoder；它会在自己生成的子 sandbox 中执行解码。应用会在启动时 abort：
>
> ```
> Gtk:ERROR:../gtk/gtkiconhelper.c:495:ensure_surface_for_gicon: assertion failed
> (error == NULL): Failed to load .../image-missing.png:
> Loader process exited early with status '1'
> ```
>
> 这看上去完全像是打包后的应用发生 crash，但事实并非如此——同一构建可以从已注册的 installation 正常启动。请使用 `--installation=test` 或上面的临时 remote 操作方式。

新建 PR。`pr-checks` 会验证 descriptor、运行测试套件、检查失效链接并构建发生变更的应用；来自 fork 的 PR 也包括在内，但需由维护者批准 workflow 运行（fork build 不会获得 secret，并使用临时密钥签名）。合并后，`publish` 会构建并发布应用。

## `flatpark.yml` schema

```yaml
id: com.example.App           # required — must match the directory name
name: Example App             # required
summary: One-line description # required
website: https://example.com/ # optional
source_url: https://github.com/you/packaging  # optional
build:
  manifest: com.example.App.yml  # required — relative to this directory
  branch: stable              # optional (default: stable)
  mode: extra-data            # packaging mode (internal label)
catalog:                      # optional — drives the catalog page
  category: Productivity
  tags:
    - Example
    - Demo
update:                       # optional — enables auto pin-bump PRs
  command: ./resolve-update.sh
policy:                       # optional — informational
  proprietary: true
  extra_data_first: true
  dangerous_permissions: []
```

只有 `id`、`name`、`summary` 和 `build.manifest` 是必填项。

## 自动更新（可选）

版本检查**始终通过脚本完成**——不需要学习声明式 checker 类型。让 `update.command` 指向一个 `resolve-update.sh`；该脚本可以按任意方式确定当前发布版本（JSON/HTML endpoint、GitHub API、固定 URL 等），并将以下 JSON 输出到 stdout（日志写入 stderr）：

```json
{
  "version": "1.2.3",
  "releaseDate": "2026-06-19",
  "sources": [
    { "filename": "installer.sh", "url": "https://example.com/installer-1.2.3.sh" }
  ]
}
```

该脚本**不进行 hashing**——它只负责解析版本和真实下载 URL。FlatPark 会下载每个 source，计算 `sha256`/`size`，再重写 manifest 中的 managed block（请使用以下注释标记，使 FlatPark 知道要重写的范围）：

```yaml
# BEGIN MANAGED EXTRA-DATA
- type: extra-data
  filename: installer.sh
  only-arches:
    - x86_64
  url: https://example.com/installer-1.2.3.sh
  sha256: <computed by FlatPark>
  size: <computed by FlatPark>
# END MANAGED EXTRA-DATA
```

**版本存放位置：** 版本位于 AppStream metainfo 的 `<releases>` 中，而不是 extra-data 中（Flatpak 的 extra-data 没有版本字段）。最新的 `<release version>` 是比较基准：`update-check` 每天运行 resolver，并且只在 resolver 的 `version` 与 metainfo 不同时才下载、重新固定、在开头添加新的 `<release>` 并新建 PR。维护者合并后，只会重新构建并发布该应用。

### Resolver 模板

GitHub release（选择正确的 asset）：

```sh
#!/usr/bin/env bash
set -euo pipefail
repo="owner/name"
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
url="$(jq -r '.assets[]|select(.name|test("linux.*x86_64.*\\.tar\\.gz$")).browser_download_url' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v,releaseDate:$d,sources:[{filename:"app.tar.gz",url:$u}]}'
```

厂商 JSON endpoint（版本位于一个字段，URL 位于另一个字段）：

```sh
#!/usr/bin/env bash
set -euo pipefail
meta="$(curl -fsSL https://vendor.example/latest.json)"
version="$(jq -r '.version' <<<"$meta")"
url="$(jq -r '.assets[]|select(.name|test("linux-x86_64\\.deb$")).url' <<<"$meta")"
date="$(jq -r '.published_at // ""' <<<"$meta" | cut -c1-10)"
jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v,releaseDate:$d,sources:[{filename:"app.deb",url:$u}]}'
```

只嵌入版本号的固定 URL：

```sh
#!/usr/bin/env bash
set -euo pipefail
version="$(curl -fsSL https://vendor.example/latest.txt)"
jq -n --arg v "$version" \
  '{version:$v,sources:[{filename:"app.bin",url:("https://vendor.example/app-"+$v+".bin")}]}'
```

## Sandbox 与权限

请使用仍能让应用核心功能正常工作的最严格 `finish-args`。FlatPark 会在每个应用的详情页面上展示权限，范围宽泛的授权会在审核中受到质疑。

**可选功能默认不授予权限。** 如果应用获得更宽泛的权限后可以使用更多功能——例如读取 host SSH 密钥、访问串口设备或整个主目录——请勿将其加入 `finish-args`，而应在文档中给出用于启用权限的 `flatpak override` 命令，让每位用户自行决定。请将该文档写入应用的 `metainfo.xml` description（它会显示在应用页面上），并在 PR 正文中解释该功能为何存在。请参考 [`org.electerm.Electerm`](https://github.com/flatpark/flatpark/tree/main/registry/org.electerm.Electerm) 的写法：

```xml
<p>A few optional capabilities are not granted by default; enable the ones you
   need with "flatpak override":</p>
<ul>
  <li>Reuse your existing host SSH keys: <code>flatpak override --user --filesystem=~/.ssh:ro org.electerm.Electerm</code></li>
  <li>Serial-port connections: <code>flatpak override --user --device=all org.electerm.Electerm</code></li>
</ul>
```

如果某项权限确实是应用正常运行所必需的，请将其保留在 `finish-args` 中；若风险较高，则将其列入 `policy.dangerous_permissions`，并在 PR 中说明理由。默认会拒绝可逃逸 sandbox 的权限（`--filesystem=host`、`--filesystem=/`、`--talk-name=org.freedesktop.Flatpak`）；唯一可能通过的方式，是在 `policy.dangerous_permissions` 中声明该权限并充分说明理由，使其进入人工审核而非自动通过（Enpass 是唯一使用这类权限的软件包）。

## 我们审核的内容（以及 PR 被拒绝的原因）

每个 PR 都会按照完整的[审核 runbook](https://github.com/flatpark/flatpark/blob/main/docs/pr-review.md)检查。为避免常见的拒绝原因，请确保你的提交：

- **确实已经安装并运行**——新建 PR 前，请构建应用，使用 `flatpak install` 将其安装到上面的隔离测试 installation 中，启动应用，并确认核心功能正常。仅让 manifest 通过 `--verify` 并不算完成测试。请在 PR 正文中记录测试过的内容以及无法测试的内容（真实 session 中的 GUI 渲染、登录流程、硬件路径）。
- **默认不授予任何可选权限**——范围宽泛的功能应在 metainfo 中记录为可选启用的 `flatpak override` 命令，而不是直接写入 `finish-args`；保留在 `finish-args` 中的所有权限都必须在 PR 中说明理由。
- **固定每个 remote source**——`extra-data`/`archive` 需要 `sha256`（`extra-data` 还需非零 `size`）；`git` 需要不可变的 `commit`。（打包文件使用的 `type: file` 无需固定。）
- **只从官方渠道下载**——使用厂商自己的域名或真正的 upstream repo，绝不使用个人账户或 mirror。
- **未经修改地重新打包官方构建**——`build-commands` 只安装 wrapper/desktop/metainfo/icon，以及用于解压下载产物的 `apply_extra`；不要 patch、重新编译或改变应用行为。可以*从外部*让应用适配 sandbox——例如 wrapper 环境变量、作为额外 module 构建的缺失库、`PATH` shim（参见上文的 cc-switch 和 Enpass）——前提是实际运行的仍然是厂商自己的内容。
- **使用普通 resolver**——`update.command` 应是简单的相对脚本路径，例如 `./resolve-update.sh`（它会在 CI 中运行）。
- **声明 `policy`**——如实设置 `proprietary`，并在 `dangerous_permissions` 中列出所有高风险权限。
- **不会获取并运行任意代码**——厂商自己的 self-updater 写入应用数据目录没有问题；下载并执行未固定的第三方代码则不可接受。
- **避免可逃逸 sandbox 的权限**——不得使用 `--filesystem=host`、`--filesystem=/` 或 `--talk-name=org.freedesktop.Flatpak`，除非已在 `policy.dangerous_permissions` 中声明并说明理由。
- **提供可接受的产物**——tarball、`.deb`、`.rpm`、zip、官方安装程序，或 AppImage（离线解包，绝不执行）。
- **用途正当**——non-FOSS 没有问题；盗版、恶意软件和商标冒充则不被接受。

Non-FOSS 商业应用（例如 broker）同样受欢迎，并采用相同标准：来源官方、未经修改、已经固定。
