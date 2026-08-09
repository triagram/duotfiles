# duotfiles

[English](README.md) · [中文](README.zh-CN.md)

跨机器管理配置文件。**按软件为单位**部署和回收，Linux 与 macOS 各存各的、
按需融合。没有一键部署，没有自动同步 —— 每一次生效都是你按下的。

设计原因见 [DESIGN.md](DESIGN.md)。

---

## 现在管着什么

| 软件 | 部署方式 | Linux | macOS |
|---|---|---|---|
| tmux | link | `~/.config/tmux` | `~/.config/tmux` |
| kitty | link | `~/.config/kitty` | `~/.config/kitty` |
| ghostty | link | `~/.config/ghostty` | `~/.config/ghostty` |
| claude | link | `~/.claude` | `~/.claude` |
| agy | link | `~/.gemini` | `~/.gemini` |
| rime | copy | `~/.local/share/fcitx5/rime` | `~/Library/Rime` |

加新软件 = 在 [`manifest`](manifest) 里加一行，然后 `mkdir tools/<名字>/{common,linux,macos}`。

---

## 仓库放在哪

**推荐 `~/.duotfiles`**，每台机器都用同一个路径。

和普通 git 仓库不同，这个仓库的位置不是随便挑的。四条理由：

1. **link 模式建立的是指向本仓库的绝对软链。** `dof pull tmux` 之后，
   `~/.config/tmux/tmux.conf` 是一个指针，里面存的字面内容就是
   `/home/you/.duotfiles/tools/tmux/linux/tmux.conf`。仓库一挪，所有指针失效。
   （可以修复 —— 重跑 `dof pull <软件>` —— 但没必要给自己找事。）
2. **必须在 `$HOME` 下面。** 两个平台的家目录绝对路径不同
   （`/Users/you` vs `/home/you`），但**相对 home 的路径**可以完全一致。
   放在 home 之外（比如 `/projects/...`）在 macOS 上根本建不出来 ——
   系统根卷是只读的，得改 `/etc/synthetic.conf` 再重启。
3. **绝对不要放进云盘同步目录**（iCloud / OneDrive / Dropbox）。
   同步引擎和 `.git` 目录互相破坏是经典事故。你已经有 git 做同步了，
   不需要在下面再叠一层。
4. **不要放会被清理的位置**（`/tmp`、Downloads）。link 模式下，
   这个仓库里存的是你配置的**唯一一份真身**。

想用可见目录 `~/duotfiles` 也完全可以，保持两台机器一致就行。

---

## 快速开始

### 在一台新机器上

```bash
git clone <你的仓库地址> ~/.duotfiles
cd ~/.duotfiles

./bin/dof list                       # 看有哪些软件、本机是什么状态
./bin/dof pull tmux                  # 只部署你现在需要的
./bin/dof pull claude
```

已存在的同名文件会被自动备份成 `xxx.dof-bak-<时间戳>`，不会丢。

### 让 `dof` 可以直接调用（可选）

`dof` 不需要安装。三种方式挑一个：

| 方式 | 怎么做 | 说明 |
|---|---|---|
| **什么都不做** | `~/.duotfiles/bin/dof status` | 零配置，永远正确。日常其实很少用到 `dof` —— link 模式下改配置只要 `git commit` |
| **加进 PATH**（推荐） | `echo 'export PATH="$HOME/.duotfiles/bin:$PATH"' >> ~/.zshrc` | 一行，每台机器一次。等 shell 配置本身也被 duotfiles 管起来，这行就在仓库里了 |
| **软链到已在 PATH 的目录** | `ln -s ~/.duotfiles/bin/dof ~/.local/bin/dof` | Linux 上 `~/.local/bin` 通常已在 PATH；macOS 默认不在，还是得加一行 |

`dof` 会先解开 `$0` 上的符号链接再定位仓库，所以第三种方式不会把仓库算错。
仓库不在脚本旁边时，用 `DOF_REPO=<仓库路径> dof …` 覆盖。

**不建议打包成 brew / apt**：`dof` 与仓库是一体的（靠自身位置找仓库），
包管理器装的是脱离仓库的副本，反而要额外配置才能用。

### 把一台机器上现有的配置收进仓库

```bash
dof adopt tmux                       # 复制到 tools/tmux/<当前平台>/
git status                           # review：删掉不该进来的
git add -A && git commit -m "tmux(linux): 导入现有配置"
dof pull tmux                        # 改成链接托管（可选，但推荐）
```

---

## 日常操作

### 改了配置，想同步到另一台

**link 模式（tmux / kitty / ghostty / claude / agy）** —— 你改的就是仓库里的文件：

```bash
vim ~/.config/tmux/tmux.conf         # 或者用任何方式改
git status                           # 立刻能看到改动，不需要任何"上传"动作
git add -A && git commit -m "tmux(macos): 前缀键改成 C-a"
git push
```

**copy 模式（rime）** —— 需要一次显式回收：

```bash
dof diff rime                        # 先看本机和仓库差在哪
dof push rime                        # 把本机的改动拷回仓库
git add -A && git commit -m "rime: 加了几条自定义短语"
git push
```

### 在另一台拉取

```bash
git pull
dof diff tmux                        # 可选：先看会改动什么
dof pull tmux                        # 应用
```

### 定期体检

```bash
dof status                           # 所有软件；或 dof status claude 看单个
```

重点看有没有 `UNLINKED` —— 那说明某个软件把符号链接顶掉了，
它的改动已经不再进仓库。处理方式见 [DESIGN.md](DESIGN.md#linkcopy-的判据)。

---

## 命令参考

| 命令 | 作用 |
|---|---|
| `dof list` | 所有软件在本机的部署状态一览 |
| `dof status [软件]` | 逐文件检查，含链接健康检测 |
| `dof pull <软件>` | 仓库 → 本机（部署）。覆盖前自动备份 |
| `dof push <软件>` | 本机 → 仓库（回收）。link 模式不需要，会提示你 |
| `dof diff <软件>` | 仓库与本机的差异 |
| `dof adopt <软件> [子路径]` | 把本机现有配置收进仓库（首次导入） |

---

## 目录结构

```
tools/<软件>/
├── common/     两个平台共用（融合之后才会有东西）
├── linux/      Linux 专属
├── macos/      macOS 专属
├── .dofignore  可选：这些路径完全不参与搬运
└── .dofkeep    可选：只有这些路径能被 adopt 收编（白名单）
```

部署时 `common/` 打底、`<当前平台>/` 覆盖，同名文件平台层胜出。

**起步时不要建 `common/`** —— 两个平台各存一份完整配置，等你比对过、
确认某部分该共享了，再手工把文件移进 `common/`。

---

## 各软件注意事项

**rime** —— 唯一走 copy 模式的。用户词库（`*.userdb/`）**绝不进 git**，
走 Rime 自带的同步机制；上游方案（rime-ice）部署时现拉，不进仓库。
每台新机器要手工配一次 `installation.yaml`。完整说明见 [notes/rime.md](notes/rime.md)。

**claude / agy** —— `~/.claude` 和 `~/.gemini` 里配置和本机状态是混在一起的，
靠 `.dofkeep` 白名单只收编该收的。`~/.claude/projects/` 是你所有会话的完整记录，
永远不要让它进仓库。全局指令文件的组织见 [notes/ai-context.md](notes/ai-context.md)。

**kitty / ghostty / tmux** —— 都自带 include 机制（`include ${KITTY_OS}.conf`、
`config-file = ?platform-macos.conf`、`source-file -q`），
将来做平台融合时用它们，不需要模板引擎。

---

## 安全须知

推到公开仓库前，确认这些**从来没有**被 commit 过：

- `~/.claude/.credentials.json`、`~/.claude/projects/`（会话记录）
- 任何 `*.key` / `*.pem` / 含 token 的文件
- Rime 的 `installation.yaml`（含本机路径）

[`.gitignore`](.gitignore) 已经按「宁可误伤」的方向拦了这些。
被误伤的正常文件用 `git add -f` 单独放行。

---

## 延伸阅读

| 文档 | 回答什么 |
|---|---|
| [DESIGN.md](DESIGN.md) | 为什么这么设计：原则、框架、关键取舍 |
| [AGENTS.md](AGENTS.md) | AI 在这个仓库里干活的规矩（`CLAUDE.md` 是它的软链） |
| [notes/](notes/) | 一个软件一个文件：为什么这里必须分平台 |
