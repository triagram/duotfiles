# claude — 只同步一个文件

`~/.claude` 在 manifest 里，但 `.dofkeep` 只放行 **`statusline.sh`**，别的一律不收。

## 为什么范围这么窄（2026-09-13 决定）

`~/.claude` 顶层 27 个条目，绝大部分是本机状态。而剩下那几个「看起来像配置」的
里面，只有 `statusline.sh` 值得版本控制：

| | 收不收 | 理由 |
|---|---|---|
| `statusline.sh` | ✅ | 350 行自己写的程序，行为稳定，两台该长一样 |
| `settings.json` | ❌ | **不够稳定**。分机器不同，而且同一台机器上**按任务、按会话**都在变 —— model、effortLevel、permissions、attribution。收进来等于提交噪声，还要为本来就不该一致的值解冲突 |
| `CLAUDE.md` | ❌ | 它是指向 `~/.config/agents/AGENTS.md` 的软链（`notes/ai-context.md` 的 2 跳枢纽）。收进来会复制一份内容，给一个已有唯一真相源的文件造出第二个源 —— 和 `tools/agy/.dofkeep` 里 `config/AGENTS.md` 那条同一个理由 |
| `commands/` `skills/` `agents/` `hooks/` `output-styles/` `scripts/` | ❌ | 本机还没有这些。**列不存在的文件**正是 agy 白名单长出幽灵 `GEMINI.md` 条目的原因 —— 等真有东西了再加行 |
| 其余 | ❌ | 凭据、会话记录、缓存、daemon 状态。`.dofignore` 是第二道闸门 |

> 早先（`22e6584`）曾把整个 `~/.claude` 从 manifest 移除，理由是配置与状态混在一起。
> 现在加回来，**只为 `statusline.sh` 一个文件** —— 那个理由仍然成立，所以白名单只有一行。

## 白名单是承重的，实测过

`~/.claude` 里有 `.credentials.json`。造了假 `$HOME`（`AGENTS.md` 规定的办法）放进
凭据、会话记录、`plugins/*.sh`、`shell-snapshots/*.sh`、`settings.json`、`CLAUDE.md`
各一份诱饵，然后跑**不限定范围**的 `dof adopt claude`（最坏情况）：

```
· CLAUDE.md         (not in .dofkeep allow-list)
· .credentials.json (excluded by .dofignore)
· settings.json     (not in .dofkeep allow-list)
+ statusline.sh
· 6 path(s) skipped: 4 by .dofignore, 2 not in .dofkeep
```

只有 `statusline.sh` 进来了。日常仍然应该带路径（`dof adopt claude statusline.sh`）——
白名单过滤的是 `find` 的**结果**，挡不住它先遍历整个 `~/.claude`。

## `statusline.sh` 放 `common/` 的依据

跨平台预检的结论（早先做的，留档）：**它本身没有移植问题** —— 没有写死的家目录路径
（`settings.json` 里用的是 `bash ~/.claude/statusline.sh`）、没有 GNU 专属参数、
自包含不引用其他文件、可执行位正常。

用到 2 处 `jq`。**macOS 上零外部依赖** —— `jq` 自 macOS 15 起随系统附带，
实测 `/usr/bin/jq` 是 `jq-1.7.1-apple`。只有 macOS 14 及更早需要 `brew install jq`。

## 它读得到哪些字段（2026-09-12 实测抓的）

想加显示内容时不用猜。往脚本开头临时插一行把 stdin 写文件，等它刷新一次再撤掉，
抓到的顶层键是：

```
session_id  transcript_path  cwd  prompt_id  effort  session_name  model
workspace   version  output_style  cost  context_window  exceeds_200k_tokens
fast_mode   thinking
```

`.effort.level`（`high` / `xhigh` 等）、`.model.id`、`.model.display_name`、
`.thinking.enabled`、`.output_style.name` 都在里面。

**加字段时拼进 `$model` 变量**，别在下游拼 —— 那个变量同时被渲染和**宽度计算**使用
（`r2_p="${model}${sep_p}"`），在别处拼接会让实际宽度超出裁剪逻辑的认知，窄终端下折行出错。

## 附带产出

收编 `~/.claude` 时踩出了一个 `bin/dof` 的真 bug：`.dofkeep` 里的 `*.sh` 把
`shell-snapshots/`、`jobs/`、`plugins/` 里 36 个脚本全收了，因为 shell 的 `case`
通配符里 `*` 会跨越 `/`。修复后匹配改为分段语义（见 `bin/dof` 的 `path_matches`），
这个修复对所有工具都生效。

## 别在笔记里写死 commit SHA

这份笔记上一版写着「配套的 `.dofkeep` / `.dofignore` 在 `e10e834` 的历史里，
`git show` 取回」。**转 public 前重写过历史，那个 SHA 已经不存在了** ——
内容还在（换了新 SHA），但照着笔记敲会得到 `Not a valid object name`。

要指向历史内容就描述它，比如「`git log --all --diff-filter=A -- 'tools/claude/*'`
找那次导入的提交」，而不是记一串会变的哈希。
