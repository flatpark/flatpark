---
description: 在发布工作流里加五行，每次 GitHub 发版几分钟内就送到 FlatPark 用户手里。
order: 2
---

# 用 publish-action 即时推送更新

什么都不做，你的新版本也会在半天内到达 FlatPark：FlatPark 每天检查两次所有应用的发布。如果你在 GitHub 上发版，[publish-action](https://github.com/flatpark/publish-action) 能把这个时间缩短到几分钟：发布一上线，你的发布工作流就通知 FlatPark，更新马上被检查并发布。

不需要令牌，不需要密钥，也没有别的东西要维护。

## 设置

你的应用要先在 FlatPark 上架，并且来源登记的是你的 GitHub 仓库。然后在发版时运行的工作流里加一个 job：

```yaml
# .github/workflows/release.yml
on:
  release:
    types: [published]

jobs:
  flatpak:
    runs-on: ubuntu-latest
    # FlatPark 这边出问题不应该让你的发布失败。
    continue-on-error: true
    steps:
      - uses: flatpark/publish-action@v1
        with:
          app-id: com.example.MyApp
```

`app-id` 填你的应用在 FlatPark 上的 id，应用页面上有。

### 如果你的发布是由工作流创建的

由默认的 `GITHUB_TOKEN` 触发的事件，GitHub 不会再启动新的工作流。如果你的发布是工作流创建的（`tauri-action`、`softprops/action-gh-release` 之类），上面那个 `on: release` 工作流根本不会运行，也不会有任何报错。这时把 job 加到创建发布的那个工作流里，放在发布完成之后，并显式传入 tag：

```yaml
jobs:
  release:
    # … 构建并发布 GitHub release …

  flatpak:
    needs: release
    runs-on: ubuntu-latest
    continue-on-error: true
    steps:
      - uses: flatpark/publish-action@v1
        with:
          app-id: com.example.MyApp
          tag: ${{ github.ref_name }}
```

这个 job 运行时，发布必须已经是**已发布**状态（不是草稿），Linux 文件也已经上传。如果 Linux 文件晚一点才传上来，每天两次的检查会接上。

## 发版之后会发生什么

1. action 把你的 app id、tag 和仓库名发给 FlatPark。
2. FlatPark 核对：应用已上架、你的仓库就是它登记的来源、这个 tag 是已发布的 release。
3. 找到新的 Linux 文件，固定它的校验和与大小，按安装时的方式解包一遍。
4. 解包成功的话，更新会直接合并并发布，不等人工，通常几分钟内完成。用户用 `flatpak update` 就能拿到。

如果新文件的解包结果和软件包的预期对不上（二进制改名、压缩包结构变了），更新就停在这一步。之前的版本照常可用，FlatPark 会手动修好软件包。

## 为什么不需要密钥

请求里的内容一样都不直接采信。FlatPark 会拿公开的事实逐项核对：它自己的应用目录，以及 GitHub 上的 release。所以没人能用这个 action 去替别人的仓库发布版本，你的工作流里也从来不需要保存 FlatPark 的任何凭据。
