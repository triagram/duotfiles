# AGENTS.md

这是一个配置文件仓库，按软件为单位在 Linux / macOS 之间部署和回收。
结构和取舍见 `DESIGN.md`，用法见 `README.zh-CN.md`（`README.md` 是英文版，两者内容需保持一致）。

**这个仓库是 public。** 任何进入它的内容都是公开的、永久的。

## 红线

- **绝不 commit**：凭据、token、`~/.claude/projects/` 里的会话记录、
  Rime 的 `*.userdb*`、`installation.yaml`。发现这类文件出现在暂存区，停下来告诉用户。
- **绝不替用户做融合决策**。不要主动把文件从 `linux/` 或 `macos/` 移进 `common/`，
  也不要主动合并两个平台的配置 —— 那是用户的判断，不是可以顺手做掉的整理工作。
- **绝不引入外部依赖**。`bin/dof` 必须只用 bash 3.2（macOS 自带版本）+ POSIX 工具跑起来。
  不用关联数组，不用 GNU 专属选项。
  （`bin/audit-privacy` 不受这条约束，它用 python3 —— 那是开发期的检查工具，
  不参与部署。约束只针对 `dof`，因为它是把配置铺到机器上的那个东西。）

## 隐私检查（`bin/audit-privacy`）

仓库 public，所以有一道自动闸门。**每台新机器 clone 之后启用一次：**

```bash
git config core.hooksPath .githooks
```

之后 `git commit` 会自动检查暂存区和提交信息，发现邮箱、家目录绝对路径、
机构线索、密钥、token、公网 IP 就**中止提交**。三个模式：

```bash
bin/audit-privacy --staged        # 钩子自动跑，只看暂存区，快
bin/audit-privacy --message FILE  # 钩子自动跑，看提交信息
bin/audit-privacy --full          # 工作区 + 全部历史版本，约 2 秒
```

**`--full` 在这两个时刻必须跑：改仓库可见性之前、任何一次历史改写之后。**

被拦下时只有两条路：**改掉内容**，或者**在 `bin/audit-privacy` 的 `ALLOW` 里
加一条并写明理由**。不要用 `--no-verify` 绕过去 —— 那正是这道闸门要防的事。

> **它抓得住什么，抓不住什么。** 它抓「有形状」的值：地址有 `@`，路径以
> `/Users/` 开头，密钥有固定前缀。它抓不住看起来像普通单词的泄露 ——
> 一个恰好是未发表课题名的目录名会顺利通过所有检查。
> **新增文件仍然要人看一眼**，钩子的作用是保证你至少会注意到有新文件进来。

## 做「比对两个平台的配置」这类任务时

1. **先读 `notes/<软件>.md`**。里面记着用户已经做过的判断，
   比如「这几行不能合并，因为 macOS 的 Option 键在 Linux 上不存在」。
   不要重复提出已经被否掉的建议。
2. **输出提案，不直接改文件**。给出：建议怎么改 + 理由 + 风险，等用户确认。
3. **平台差异优先用软件自带的 include 机制**表达，不要引入模板引擎：
   - kitty：`include ${KITTY_OS}.conf`（`KITTY_OS` 是 kitty 内置变量）
   - Ghostty：`config-file = ?platform-macos.conf`（`?` = 文件不存在就忽略）
   - tmux：`source-file -q` / `if-shell`
4. 用户确认之后，把这次的判断补进 `notes/<软件>.md`，
   这样下次不用重新推理一遍。

## commit message

用 `<软件>(<平台>): <改了什么>`，融合类改动用 `merge(<软件>):`。

```
tmux(macos): 前缀键改成 C-a
rime: 加了几条自定义短语
merge(kitty): 把配色收敛到 common/，字号保持分平台
```

这样 `git log -- tools/kitty` 就是这个软件的完整演化史。

## 提交身份（每台新机器要设一次）

这个仓库是 public，提交邮箱会永久公开。**每台机器 clone 之后先设仓库级配置**，
不要依赖 global：

```bash
git config --local user.name  "$(git log -1 --format=%an)"
git config --local user.email "$(git log -1 --format=%ae)"
```

从现有历史里取，而不是把地址写死在这里 —— 这个文件本身也是公开的。

用 `--local` 是刻意的：global 那份是机构邮箱，其他仓库继续用它，只有这个仓库不用。
2026-09-03 转 public 前重写过历史统一身份，
**新提交如果沿用 global，就会把机构邮箱重新带进公开历史**。

> 两种翻车方式都实际发生过：一台沿用了 global 的机构邮箱；
> 另一台压根没设 `user.email`，git 拿主机名兜底编了个假地址出来。
> 两批都在那次重写里统一掉了，但配置不设好就会再来一次。

## 改 bin/dof 时

- 有改动就实际跑一遍验证：造一个假的 `$HOME`，`HOME=/tmp/xxx bin/dof …`
- 破坏性操作（覆盖、删除）必须先备份成 `xxx.dof-bak-<时间戳>`
- 不加 `--all` 之类的全局批量命令，那是刻意排除的（见 `DESIGN.md` 原则 8）
