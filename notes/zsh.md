# zsh

`~/.zshrc` 由 dof 以 link 模式部署，源文件是 `tools/zsh/common/.zshrc`。

## 一份文件，内部分支（2026-09-11 决定）

三个方案摆过，选了 b：

| | 做法 | 为什么没选 |
|---|---|---|
| a | `macos/.zshrc` + `linux/.zshrc`，`common/` 空着 | 共同的行重复两份，改一处要记得改两处 |
| **b** | **整份放 `common/`，内部 `case "$(uname -s)"`** | **选了这个** |
| c | `common/.zshrc` 里 `source` 一个平台片段 | 最干净，但要多管一个受控路径；对目前**只有一行**平台差异来说不划算 |

项目 `AGENTS.md` 的第 3 条说「平台差异优先用软件自带的 include 机制」，严格讲指向 c。
b 是在这条规矩下的**有意取舍**：差异只有 `FZF_BASE` 一行，
为它多引入一个文件和一条 `.dofkeep` 条目，认知负担反而更大。
**平台差异长到三五行以上就该转 c。**

### 平台块必须在 `source $ZSH/oh-my-zsh.sh` 之前

`FZF_BASE` 是 oh-my-zsh 的 fzf 插件在**加载过程中**读的，放文件末尾就太晚了。
所以那个 `case` 块夹在 `plugins=(...)` 上面，不在文件底部 —— 看起来位置奇怪，是有原因的。

### 新增配置该放哪一半

| 放平台块 | 放公共部分 |
|---|---|
| 提到 `$HOME` 以外的绝对路径 | 只用 `$HOME` |
| 提到包管理器（Homebrew / apt） | 两台都有的命令 |
| 提到某个 OS 专属工具 | 纯 zsh / oh-my-zsh 设置 |

**拿不准就放平台块。** 两个方向的错代价不对称：

- 放错平台块 → 另一台少这行，第一次用到就会发现
- 该进平台块的放进了公共部分 → **它会在 Linux 上执行，每次开 shell 都报错**

## `.dofkeep` 是承重的，且 adopt 必须限定范围

target 是 `~`（zsh 只认家目录下的启动文件，没有它肯读的 XDG 路径）。
`cmd_adopt` 在 target 下跑 `find`，所以：

```bash
dof adopt zsh .zshrc      # ★ 必须带路径
dof adopt zsh             # ✗ 会遍历整个家目录
```

`.dofkeep` 过滤的是 `find` 的**结果**，挡不住遍历本身。

## 怎么验证改动（两个都踩过）

**模拟另一个平台**：复制一份 `dof`、把 `Darwin) PLATFORM=macos` 改成 `linux`，
对着假 `$HOME` 跑。**必须带 `DOF_REPO=`** —— 否则它从自身位置推仓库路径，
直接报 `repo not found`，而你会把「什么都没发生」误读成「验证通过」。

**测 `case` 块要清干净继承的环境变量**：
`FZF_BASE` 在当前 shell 里已经导出了，不 `env -u FZF_BASE` 的话，
假装 `uname` 返回 Linux 也照样能读到值，看起来像分支失效。
第一次就是这么得出假结论的。

## 未决

- **`~/.zprofile` 里有一行同样写死家目录的 `.local/bin`**，和 `.zshrc` 里那行重复。
  没收进仓库 —— 它不在这次的范围内，顺手 adopt 正是状态文件混进 git 的路径。
- Linux 那台还没接进来。**流程不是 adopt** —— b 方案下 `dof adopt zsh .zshrc` 会把
  那台的文件复制成 `tools/zsh/linux/.zshrc`，平台层整个盖掉 `common/`，设计就废了。
  正确顺序：`git pull` → 读那台的 `~/.zshrc` → 把平台专属行**手填**进 `common/.zshrc`
  的 `Linux)` 分支（共享的行大概率已经在了）→ `dof pull zsh`（会先备份原文件）
  → 开个新 shell 验证 → commit → push。
