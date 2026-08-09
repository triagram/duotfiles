# rime

Rime 是本仓库里唯一走 `copy` 模式、且唯一有「一部分数据根本不进 git」的软件。

## 三类数据，三条通道

| 数据 | 通道 | 原因 |
|---|---|---|
| `*.custom.yaml` / `*.schema.yaml` / `*.dict.yaml` / 自定义短语 | **本仓库（git）** | 纯文本，可 diff 可合并 |
| 上游方案（rime-ice 等） | **部署时现拉，不进仓库** | 几百个文件，进仓库会淹没你自己的改动 |
| 用户词库 `*.userdb/` | **Rime 自带同步**，绝不进 git | 二进制 LevelDB，git 只会看到冲突 |

## 为什么用 copy 而不是 link

Rime 每次「重新部署」都会在用户目录里生成 `build/` 编译产物，还会改写词库。
整目录托管给 link 会把这些产物拽进仓库。

## 目录位置（三个平台内部结构相同，只是位置不同）

```
macOS  (Squirrel)     ~/Library/Rime/
Linux  (fcitx5-rime)  ~/.local/share/fcitx5/rime/
Linux  (ibus-rime)    ~/.config/ibus/rime/         ← 如果你用 ibus，改 manifest
```

## 上游方案：部署时现拉

```bash
git clone --depth 1 https://github.com/iDvel/rime-ice ~/.cache/rime-ice
# 然后把它的内容铺进 Rime 用户目录，再 dof pull rime 把你的 *.custom.yaml 盖上去
```

顺序很重要：**上游先铺，你的 `*.custom.yaml` 后铺**。Rime 的 patch 机制本来就是
「上游给 schema，你用 custom 打补丁」，永远不改上游文件。

> 这一步目前是手工的。等重复烦了，再考虑给 dof 加一个 `upstream` 子命令。

## 用户词库同步（每台机器配一次）

不是实时的，也不是点对点。机制是「两台机器往同一个文件夹投快照，各自去取并合并」。

**第一次配置** —— 编辑 Rime 用户目录下的 `installation.yaml`：

```yaml
installation_id: "mac-mini"      # 每台机器不同！这就是同步目录下的文件夹名
sync_dir: "/Users/you/Library/Mobile Documents/com~apple~CloudDocs/RimeSync"
```

`sync_dir` 两台机器指向同一个可同步的目录（iCloud / OneDrive / Syncthing 都行），
用绝对路径。这个文件已在 `.gitignore` 里，每台机器各自维护。

**日常同步** —— 两边各触发一次：

```bash
# macOS: 菜单栏【ㄓ】→「同步用户数据」，或
/Library/Input\ Methods/Squirrel.app/Contents/MacOS/Squirrel --sync

# Linux (fcitx5-rime): 输入法菜单里的「同步」，或
fcitx5-curl /config/addon/rime/sync -X POST -d '{}'
```

触发后 Rime 会：把本机词库导出成 `sync_dir/<本机 id>/*.userdb.txt` → 读取其他
`installation_id` 文件夹里的快照 → **按词条合并**进本机词库。

所以完整链路是：**A 机同步 → 网盘搬运 → B 机同步**。

## 平台差异

| 配置项 | linux | macos | 能否合并 | 判断日期 |
|---|---|---|---|---|
| （等两边配置都进仓库后再填） | | | | |
