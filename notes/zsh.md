# zsh

`~/.zshrc` 由 dof 以 link 模式部署，源文件是 `tools/zsh/common/.zshrc`。

## 三层，不是两层（2026-09-12 补）

```
进 git   tools/zsh/common/.zshrc
           ├── case (uname) 早块 ── FZF_BASE（oh-my-zsh 加载时就要读）
           ├── source oh-my-zsh.sh
           ├── 公共部分 ────────── 两台都安全的
           ├── case (uname) 晚块 ── 平台专属、但要在 oh-my-zsh 之后跑的
           └── [ -r ~/.zshrc.local ] && source ~/.zshrc.local

不进 git ~/.zshrc.local ───────── 工具自己管的块、$HOME 之外的绝对路径
```

**为什么要第三层 —— 别把 conda 块「顺手收进仓库」。**
`conda init zsh` / `mamba shell init` **改的就是 `~/.zshrc`**，实测过：

```
$ conda init zsh --dry-run
no change     /home/mengyuan/.zshrc      ← 它的目标
```

而 `~/.zshrc` 是指向仓库的软链，于是两种结局都不能接受：原地写入 → 直接进 git；
用「临时文件 + rename」写 → **软链被换成普通文件**，`dof status` 报 UNLINKED
（`notes/agy.md` 对 `settings.json` 记过同一个坑）。再加上两台机器的 `conda init`
会往同一份共享文件里写各自的绝对路径，互相覆盖。

`~/.zshrc.local` 不需要进 `.dofignore` —— `.dofkeep` 白名单只放行字面的 `.zshrc`，
`bin/dof` 的 `path_matches` 对不带斜杠的模式做顶层精确匹配，`.zshrc.local` 匹配不上。

## 新增配置的落点判断（2026-09-12 改进）

**默认加进平台块或 `~/.zshrc.local`；等发现另一台也加了同一行，再挪进公共部分。**

比「我猜这行可移植吗」好，因为判断依据从猜测变成事实。代价不对称那条仍然成立：
放错平台块 → 另一台少这行，第一次用到就发现；该分平台的放进公共部分
→ **它会在另一台执行，每次开 shell 报错**。

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

## Linux 那台已接入（2026-09-12）

走的正是下面「不是 adopt」那条路。收进公共部分的：nvm 三行（自带守卫）、
`ls --group-directories-first` 那段（自带 BSD 探测）、pyenv 三行
（**加了 `command -v pyenv` 守卫**，因为 Mac 迟早会装，届时不用再挪）。
进 `~/.zshrc.local` 的：conda、mamba、cowsay 横幅。

丢掉了两行：`alias ks='ls'`（不要了），以及 pipx 装时加的
`export PATH="$PATH:/home/mengyuan/.local/bin"` —— 公共部分已有
`$HOME/.local/bin` 的**前置**版本，比它更对且不写死家目录。

晚 `case` 块目前是空的：这台的平台专属行全是工具管的，都归 `~/.zshrc.local` 了。

## 接新机器的流程（不是 adopt）

`dof adopt zsh .zshrc` 会把那台的文件复制成 `tools/zsh/<平台>/.zshrc`，
平台层整个盖掉 `common/`，一份文件的设计就废了。正确顺序：

```
git pull → 读那台的 ~/.zshrc → 把可共享的行手填进 common/ 的公共部分
         → 工具管的块和绝对路径写进那台的 ~/.zshrc.local
         → dof pull zsh（会先备份）→ 开新 shell 验证 → commit → push
```

## 未决

- **`~/.zprofile` 有 2 行、`~/.profile` 有 2 行**都在往 PATH 塞 `.local/bin`，
  加上 `.zshrc` 那行，实测 PATH 里 **`.local/bin` 重复 7 次**（接入前是 8 次）。
  纯冗余、不报错，但该收拾。没顺手做：`.zprofile` 不在这次范围内，
  顺手 adopt 正是状态文件混进 git 的路径。
- Mac 上还没装 pyenv。装完不用改配置 —— 守卫会自己放行。

## cowsay 横幅：从 `.zshrc.local` 提升进公共部分（2026-09-13）

Linux 接入时把它放进了 `~/.zshrc.local`，那层的定位是「工具自己会改写的块」，
cowsay 不属于这类，是顺手放的。macOS 也要同一段文字之后，
「另一台也要同一行就提升进公共部分」那条规则触发 —— 现在在 `common/.zshrc`，
晚 `case` 块之后、`source ~/.zshrc.local` 之前。

**Linux 那台 pull 之后要删掉自己 `~/.zshrc.local` 里的那段**，否则两头牛。
macOS 这台的 `.zshrc.local` 删完只剩牛就空了，文件已删，`.zshrc` 里 `[ -r ]` 守着不会报错。

### 两个坑（macOS 上踩的，公共部分已带上）

- **要加 `[ -t 1 ]`**。Claude Code 的 Bash 工具每次调用起一个新 shell、读启动文件、
  捕获 stdout —— 不加这个守卫，每个工具结果开头都是一头牛。
- **cowsay 3.8.4（Perl）按字节算气泡宽度**，`—`（em dash）3 字节 1 列，右边框会歪 2 列。
  `PERL_UNICODE=SDA cowsay …` 让 Perl 按字符数，对齐，不用把破折号换成 `--`。
