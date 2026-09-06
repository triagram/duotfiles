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
| agy | link | `~/.gemini` | `~/.gemini` |
| rime | copy | `~/.local/share/fcitx5/rime` | `~/Library/Rime` |
| fcitx5-guard | link | `~/.local` | —（仅 Linux） |
| agents | link | `~/.config/agents` | `~/.config/agents` |

加新软件 = 在 [`manifest`](manifest) 里加一行，然后 `mkdir tools/<名字>/{common,linux,macos}`。

---

## 仓库放在哪

**`~/duotfiles`**，可见目录，每台机器都用同一个路径。

和普通 git 仓库不同，这个仓库的位置不是随便挑的。四条理由：

1. **link 模式建立的是指向本仓库的绝对软链。** `dof pull tmux` 之后，
   `~/.config/tmux/tmux.conf` 是一个指针，里面存的字面内容就是
   `/home/you/duotfiles/tools/tmux/linux/tmux.conf`。仓库一挪，所有指针失效。
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

**为什么可见，不用 `~/.duotfiles`。** 本仓库部署到的其他每一个路径，都是软件自己
选定的公认位置 —— `~/.config/kitty`、`~/.claude`。这个仓库不是：它是你天天进去改
东西的工作目录，位置也没有任何共识，所以需要更显眼。藏起来的代价是 `ls ~` 看不见、
Tab 补不出，以及 `rg` / `fd` 默认跳过点开头的目录。

2026-08-31 定的；此前推荐的是 `~/.duotfiles`，而且本文写着「两种都行」—— 那句话
正是两台机器分叉的源头。选一个，然后守住。

---

## 快速开始

### 在一台新机器上

```bash
git clone <你的仓库地址> ~/duotfiles
cd ~/duotfiles

# 两条一次性设置。本仓库是 public，这两条都是为了让它安全地保持 public，
# 各自的理由见 AGENTS.md。
git config --local user.name  "$(git log -1 --format=%an)"
git config --local user.email "$(git log -1 --format=%ae)"
git config core.hooksPath .githooks

./bin/dof list                       # 看有哪些软件、本机是什么状态
./bin/dof pull kitty                 # 只部署你现在需要的
```

身份那两行有必要，是因为本仓库的历史被改写成统一的作者地址；哪台机器要是
回退到 global 的或主机名兜底的地址，就会把它写进公开历史。`core.hooksPath`
打开下面那道隐私闸门 —— git 不会 clone 钩子，所以每台机器要自己开一次。

已存在的同名文件会被自动备份成 `xxx.dof-bak-<时间戳>`，不会丢。

### 让 `dof` 可以直接调用（可选）

`dof` 不需要安装。三种方式挑一个：

| 方式 | 怎么做 | 说明 |
|---|---|---|
| **什么都不做** | `~/duotfiles/bin/dof status` | 零配置，永远正确。日常其实很少用到 `dof` —— link 模式下改配置只要 `git commit` |
| **加进 PATH**（推荐） | `echo 'export PATH="$HOME/duotfiles/bin:$PATH"' >> ~/.zshrc` | 一行，每台机器一次。等 shell 配置本身也被 duotfiles 管起来，这行就在仓库里了 |
| **软链到已在 PATH 的目录** | `ln -s ~/duotfiles/bin/dof ~/.local/bin/dof` | Linux 上 `~/.local/bin` 通常已在 PATH；macOS 默认不在，还是得加一行 |

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

**本仓库是 public**，进去的东西就是公开的、永久的。三层防线，从粗到细：

**① `.gitignore`** 按「宁可误伤」拦掉长得像凭据的文件名 —— `*.key`、`*.pem`、
带 `token` 或 `secret` 字样的、Claude Code 的会话记录、Rime 的 `installation.yaml`。
被误伤的正常文件用 `git add -f` 单独放行。

**② 提交钩子**检查你**正要记录**的东西 —— 暂存区的内容和提交信息 —— 找邮箱、
家目录绝对路径、机构线索、密钥、token、公网 IP，发现就中止提交。每台机器启用一次：

```bash
git config core.hooksPath .githooks
```

**③ `bin/audit-privacy --full`** 扫工作区加每个文件的全部历史版本，约两秒。
**改仓库可见性之前、任何一次历史改写之后，必须跑一遍。**

被拦下时只有两条路：改掉内容，或者在 [`bin/audit-privacy`](bin/audit-privacy)
的 `ALLOW` 里加一条**并写明理由**。不要用 `git commit --no-verify` 绕过去。

抓不住的：长得像普通单词的泄露。一个恰好是未发表课题名的目录名会通过所有检查。
新增文件仍然要人看一眼 —— 见 [AGENTS.md](AGENTS.md)。

---

## 延伸阅读

| 文档 | 回答什么 |
|---|---|
| [DESIGN.md](DESIGN.md) | 为什么这么设计：原则、框架、关键取舍 |
| [AGENTS.md](AGENTS.md) | AI 在这个仓库里干活的规矩（`CLAUDE.md` 是它的软链） |
| [notes/](notes/) | 一个软件一个文件：为什么这里必须分平台 |

---

## 许可

本仓库的原创部分是 MIT，见 [LICENSE](LICENSE)。

`tools/rime/` 里还重新分发了第三方配置，绝大部分来自
[iDvel/rime-ice](https://github.com/iDvel/rime-ice)，许可是 **GPL-3.0-only**。
那些文件保持上游许可，MIT 不适用于它们。逐文件的归属见 [NOTICE](NOTICE)。
