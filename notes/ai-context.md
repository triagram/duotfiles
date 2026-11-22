# ai-context - 全局与项目级的 AI 指令文件

## 名字对照

| 层级 | 路径 | 中文 | 英文 |
|---|---|---|---|
| 全局（用户级） | `~/.claude/CLAUDE.md`、`~/.gemini/config/AGENTS.md`、`~/.codex/AGENTS.md` | 全局指令 / 全局记忆 | user memory |
| 项目级 | 项目根的 `AGENTS.md` / `CLAUDE.md` / `GEMINI.md` | 项目指令 / 项目记忆 | project memory |

`AGENTS.md` 是跨厂商的中立约定，多家 AI 编码工具都读它。本仓库自己就是这么做的：
根目录 `AGENTS.md` 是真身，`CLAUDE.md` 是指向它的软链。

## Claude Code 只认两个路径（2026-08-25 查证）

官方文档写死了，别猜：

> **Claude Code reads `CLAUDE.md`, not `AGENTS.md`.**

> **订正（2026-11-14）：项目级这条已经过时。** 2.1.277（2026-09-18 上 npm）起，Claude Code
> 用一个默认开启的内置插件 `cc-plugin-agents-md` 读项目的 `AGENTS.md`（2.1.285 之前插件 ID
> 叫 `agents-md@builtin`）。上面那句 2026-08-25 查证时是对的，当时功能还没发布。
> 来源：`code.claude.com/docs/en/memory.md`、仓库 `anthropics/claude-code` 的 `CHANGELOG.md`。
>
> - **默认规则**：工作目录和它的所有上级目录里都没有 `CLAUDE.md`、`.claude/CLAUDE.md`、
>   `CLAUDE.local.md` 时，才读这些目录里的 `AGENTS.md` 和 `.claude/AGENTS.md`；只要有一个，
>   `AGENTS.md` 就整个不读。`~/.claude/CLAUDE.md` 不算项目自己的（文档如此，本机也实测了）。
>   **`CLAUDE.local.md` 算**：放一份私人笔记就会把 `AGENTS.md` 关掉。
> - **开关**：`/config` 的「Project instructions」，或用户设置里的
>   `pluginConfigs["cc-plugin-agents-md@builtin"].options.instructionFiles`，取值 `claude-md`、
>   `claude-md-or-agents-md`（默认）、`claude-md-and-agents-md`、`managed-only`。
>   **写在项目的 `.claude/settings.json` 里无效**：官方故意不让克隆来的仓库改它。
> - **本仓库「`CLAUDE.md` 软链到 `AGENTS.md`」照常有效，不会读两遍**：有 `CLAUDE.md` 时插件不动，
>   内容经软链读一次。文档原话：「nothing, or delete the symlink. Either way Claude reads the
>   content once」。
> - 不读的：`AGENTS.local.md`、`AGENTS.override.md`、`.agents/` 目录。
>
> 2026-11-14 在 Linux 的 2.1.325 上实测（`claude -p --model haiku`，每个目录一个暗号）：
>
> | 目录里有 | 读到的 |
> |---|---|
> | 只有 `CLAUDE.md`（对照组） | `CLAUDE.md` |
> | 只有 `AGENTS.md`，在 `/tmp` 下 | `AGENTS.md` |
> | 只有 `AGENTS.md`，在家目录下（`~/.claude/CLAUDE.md` 存在） | `AGENTS.md` |
> | 两个都有 | 只有 `CLAUDE.md` |
> | `CLAUDE.md` 软链到 `AGENTS.md` | 读到（经 `CLAUDE.md`） |
>
> 怎么确认读没读：`claude --debug` 之后看 `~/.claude/debug/` 里的日志，有
> `no CLAUDE.md found; AGENTS.md loaded: <路径>` 一行（2.1.325 只写进调试日志，对话里看不到）。
>
> **macOS 没测。** 有一个还开着的用户报告（anthropics/claude-code#103458，2.1.302，macOS）说
> `~/.claude/CLAUDE.md` 会让家目录下所有项目都读不到 `AGENTS.md`；本机 2.1.325 不复现。
> 要依赖「只放 `AGENTS.md`」之前，先在 macOS 上照上表测一次。

| 层级 | 唯一路径 |
|---|---|
| Managed policy | `/Library/Application Support/ClaudeCode/CLAUDE.md`（Linux: `/etc/claude-code/`） |
| **用户级指令** | **`~/.claude/CLAUDE.md`** |
| **用户级 rules** | **`~/.claude/rules/*.md`** |
| 项目级 | `./CLAUDE.md` 或 `./.claude/CLAUDE.md` |

**没有任何 XDG 路径。** `~/.config/agents/AGENTS.md` 不会被读：位置不在列表里，
文件名也不对，两条都不满足。放成 `~/.claude/AGENTS.md` 同样不读。

> **订正（2026-11-14）：用户级仍然没有 `AGENTS.md`，但「不读」说得不准。** 文档列的用户级指令
> 文件只有 `~/.claude/CLAUDE.md`。插件则是从文件系统根往下逐级找 `AGENTS.md` 和
> `.claude/AGENTS.md`，所以在家目录下开会话、项目又没有 `CLAUDE.md` 时，`~/.claude/AGENTS.md`
> 会被当成**项目级**文件顺带读进来（依据是文档写的查找规则和几份用户报告，本机没测：测就得在真的
> `~/.claude` 里建文件）。这靠不住：项目有 `CLAUDE.md` 就不读，家目录以外的项目也不读。
> **所以全局指令照旧走 `~/.claude/CLAUDE.md` 软链，2 跳枢纽不用改。**

> 这个坑实际踩过：`tools/agents` 部署到 `~/.config/agents/`，
> `dof status agents` 三个 ✓ 全绿，但 Claude Code 一个字都没读到。
> **`dof` 说部署成功 ≠ 目标程序会去读那个位置。**

> **⚠ 不要因此把 `agents` 从 manifest 删掉。** `~/.config/agents/` 不是给厂商读的，
> 它是**中立枢纽**（见下一节）：没有工具直接读它，但所有厂商的软链都指向它。

## 落地方式：2 跳（2026-08-31 决定）

```
仓库  tools/agents/common/AGENTS.md
  │
  │  dof pull agents          ← manifest 管这一跳
  ▼
~/.config/agents/AGENTS.md    ← 中立枢纽
  │
  │  每台机器手工建一次        ← 下面这几条命令
  ├─────────────▶ ~/.claude/CLAUDE.md
  ├─────────────▶ ~/.claude/rules
  ├─────────────▶ ~/.gemini/config/AGENTS.md
  └─────────────▶ ~/.codex/AGENTS.md
```

新机器上的引导步骤（`~/.claude` 已在 2026-08-19 那次「claude: stop syncing ~/.claude」提交里决定不同步，所以这几条进不了 manifest）：

```bash
dof pull agents                                      # 先铺好枢纽
ln -s ~/.config/agents/AGENTS.md ~/.claude/CLAUDE.md
ln -s ~/.config/agents/rules     ~/.claude/rules
ln -s ~/.config/agents/AGENTS.md ~/.gemini/config/AGENTS.md
ln -s ~/.config/agents/AGENTS.md ~/.codex/AGENTS.md
```

**注意这几条命令里没有仓库路径。** 这是 2 跳最主要的好处，下面详述。

> **订正（2026-11-15）：上面括号里的理由过时了，结论没变。** 2026-09-13 起 `~/.claude` 又回到了
> manifest，但 `tools/claude/.dofkeep` 只放行 `statusline.sh`，`CLAUDE.md` 和 `rules` 刻意不收
> （理由在 `.dofkeep` 的注释和 `notes/claude.md`）。所以这几条软链仍然每台机器手工建。

> 2026-11-18：加了 codex 这一条。codex-cli 读 `$CODEX_HOME/AGENTS.md`（默认 `~/.codex/`）当全局指令，
> 有 `AGENTS.override.md` 时改读那个（这台没有）。之前这台装着 codex 却没接，codex 会话拿不到全局指令。
> macOS 上装了 codex 的话也建这一条。

### 为什么不是 1 跳（直接链到仓库）

1 跳看起来更直观：和仓库里其他工具一样，「配置只有一份在仓库里，别处链过来」。
2026-08-31 认真考虑过，最后否掉，三条理由：

**① 引导命令里不含仓库路径，仓库怎么挪都不影响厂商那几条链。**
这不是推演，是当天实测的：把仓库从 `~/.duotfiles` 改名成 `~/duotfiles` 之后，
13 条指向仓库的软链断了 11 条，**而 4 条厂商软链一条都没断**：它们指向
`~/.config/agents/`，压根不含仓库路径。dof 管的那 11 条一句 `dof pull` 就全好了。
1 跳的话，这 4 条会跟着一起断，而且每台机器都要手工重建。

**② 保住 manifest 里 `agents` 那条的意义。** 1 跳的话 dof 部署到 `~/.config/agents`
就没人经过了，你会想把它从 manifest 删掉：于是 `tools/agents/` 变成唯一一个
不在 manifest 里的 `tools/` 目录，比现在更不齐整，不是更齐整。

**③ `~/.config/agents/` 是社区正在标准化的位置。**
[agentsmd/agents.md#91](https://github.com/agentsmd/agents.md/issues/91) 提的就是这个路径，
理由是遵循 XDG、且**目录形式便于将来扩展 `rules/`、`commands/`**。
提案还开着没被采纳（各家现在仍各走各的：Claude Code `~/.claude/CLAUDE.md`、
Codex `~/.codex/AGENTS.md`、droid `~/.factory/AGENTS.md`、Amp `~/.config/AGENTS.md`），
所以今天软链仍然必需。但哪天被采纳，**位置和结构都已经对上了，软链直接删掉即可**。

### 为什么用软链而不是 `@` 导入

软链是同一个 inode，`/memory` 里编辑会**穿透写进仓库文件**，改动自然进 git；
`@` 导入则写进那个本机指针文件，内容变成永远不同步的孤儿。代价是将来想加
「只给 Claude 看、不给 Gemini 看」的指令时得改用导入形式：真有这个需求再换。

> 2026-11-15 补：Claude 自己的 Edit / Write 工具不一定肯穿过软链写。anthropics/claude-code#66559
> （还开着）里协作者在 2.1.234 上复现了：`CLAUDE.md -> AGENTS.md` 时 Edit 和 Write 都失败。
> 所以在会话里让 Claude 改全局指令，直接让它改仓库里的 `tools/agents/common/AGENTS.md`。
> `~/.claude/CLAUDE.md` 这条全局软链没单独测。

> **两者都在 Cowork 会话里失效**（软链的 `~/.claude/CLAUDE.md` 被跳过；
> 指向工作目录之外的导入也被跳过）。这一条不构成两种做法的区别。

## 两条 `CLAUDE.md` 软链先不删（2026-11-15 决定）

仓库根的 `CLAUDE.md → AGENTS.md`，和机器上的 `~/.claude/CLAUDE.md → ~/.config/agents/AGENTS.md`，都留着。

**理由：留着没有代价，删掉才有风险。** 默认设置下内容只读一次（见上面 2026-11-14 的订正）。删的话：

- **全局那条**删了就什么都不读：文档列的用户级指令文件只有 `~/.claude/CLAUDE.md`。请求用户级
  `AGENTS.md` 的 anthropics/claude-code#95795 还开着，官方没回复（2026-11-15 查）。
- **仓库那条**要赌两台机器的版本：项目级支持才两个月，插件 ID 在 2.1.285 改过名，设置键也从
  `projectInstructions` 换成了 `instructionFiles`；macOS 上还有没关的 #103458，那台的版本没核对。

**当时问过「半年后 `CLAUDE.md` 会不会成历史」：查不到这样的计划，所以按条件回头看，不按日期。**
2.1.325 的 `/init` 仍然生成 `CLAUDE.md`（程序里的提示词和文档都这么写）；文档和更新日志里没有任何
废弃 `CLAUDE.md` 的说法；官方默认是 `CLAUDE.md` 优先、`AGENTS.md` 兜底。下面的条件是 Claude 提的，
不是官方承诺：

| 软链 | 什么时候可以删 |
|---|---|
| `~/.claude/CLAUDE.md` | 文档把 `AGENTS.md` 列进用户级指令文件（比如 #95795 以「已实现」关闭） |
| 仓库根 `CLAUDE.md` | macOS 上照 2026-11-14 那张 5 行表测过、全对。删时一起改两份 README 里介绍 `AGENTS.md` 的那一行，和 `DESIGN.md` 目录树里的说明 |

> 2026-11-16：macOS 上的 Claude Code 也是 2.1.325，和 Linux 一样；那张 5 行表还没在 macOS 上测。

仓库根原来还有一条 `GEMINI.md` 软链，情况不同，2026-11-16 删了，理由见「Gemini（Antigravity）侧」一节。

## rules 的 frontmatter 是 Claude 专有的

`rules/matlab.md`、`rules/python.md` 都写了：

```yaml
---
paths:
  - "**/*.py"
  - "**/pyproject.toml"
---
```

**没有 `paths` 的 rule 每次会话都载入**，占上下文。语言/框架专属的规则一律加上，
让它只在你真的读到那类文件时才进来。

> **但这套语法只有 Claude Code 认。** Antigravity（agy）用的键是
> `trigger: always_on | model_decision`，完全不同的词汇：这是不把 rules 链给
> Gemini 的直接原因，见下一节。
>
> （2026-11-15：agy 现在有四种 `trigger`，其中 `glob` 能按文件匹配，见下一节末尾的订正。）

## Gemini（Antigravity）侧：AGENTS.md 已接，rules 刻意不接

**已接好的：**

```
~/.gemini/config/AGENTS.md → ~/.config/agents/AGENTS.md → 仓库
```

两处细节和直觉不一样，别记错：

- 全局位置是 **`~/.gemini/config/`**，不是 `~/.gemini/`
  （依据是本机 antigravity-cli 自带文档 `builtin/skills/agy-customizations/SKILL.md`，
  它把 `~/.gemini/config/` 列为 Global Configuration）
- 文件名是 **`AGENTS.md`**，不是 `GEMINI.md`
  （它自己的文档建议把 legacy 的 `GEMINI.md` 改名成 `AGENTS.md`）

> **订正（2026-11-15，agy 1.5.9）：这两条说得太死。** 全局指令认四个位置：`~/.gemini/AGENTS.md`、
> `~/.gemini/GEMINI.md`、`~/.gemini/config/AGENTS.md`、`~/.gemini/config/GEMINI.md`（官方文档
> `antigravity.google/docs/rules/`；agy 程序里内嵌的更新日志 1.2.15 条目也点名了这四个）。
> 现在用的 `~/.gemini/config/AGENTS.md` 照样有效。自带文档里 `GEMINI.md` 和 `AGENTS.md` 是平级的
> 两个名字，「建议把 legacy 的 `GEMINI.md` 改名」这句在现在的自带文档里找不到。
> **要防的是多出来的一份**：哪台机器上留着 Gemini CLI 时代的 `~/.gemini/GEMINI.md`，agy 会把它当成
> 第二份全局指令一起读。Linux 这台另外三个位置都没有文件，macOS 用这条查：
> `ls -la ~/.gemini/GEMINI.md ~/.gemini/AGENTS.md ~/.gemini/config/GEMINI.md ~/.gemini/config/AGENTS.md`
>
> **仓库根的 `GEMINI.md → AGENTS.md`**：agy 用不上它。项目级从当前目录往上到仓库根，每层两个名字都读，
> 自带文档写明按真实路径去重，所以这条软链按文档只读一次（没实测）。只有 Gemini CLI 需要它：这台没装
> （以前用过，`~/.gemini/config/.migrated` 的日期是 2026-06-09），它的 README 说个人免费和 Google AI
> Pro/Ultra 的使用 2026-06-18 起转到了 Antigravity CLI。删不删等 macOS 上 `command -v gemini` 的结果，待定。
>
> **2026-11-16 决定：删掉了。** 两台都没有 Gemini CLI（macOS 上 `command -v gemini` 也找不到），它的个人用户
> 已经整体转到 agy，而 agy 直接读 `AGENTS.md`，这条软链没有工具需要。`README.md` 里提到它的那一行一起改了。
> 同一天在 macOS 上查过 `~/.gemini/`：四个位置里只有 `config/AGENTS.md`（指向枢纽），没有多出来的一份。

**刻意不接 rules（2026-08-31）。** 曾经建过 `~/.gemini/config/rules` 这条链，当天摘掉了，
两条理由：

1. **frontmatter 的键对不上。** 我们的文件用 `paths:`，Antigravity 用 `trigger:`。
   按它文档「只有 `always_on` 无条件载入」的措辞，一个没有它认识的 trigger 的规则
   最可能被当成常驻规则**每次会话都载入**：正是加 `paths:` 想避免的事。
   Claude 那边省下的上下文，在 Gemini 这边又赔回去。
2. **全局 `rules/` 目录能不能被发现，文档没写死。** 它列的 rules 发现路径是
   `GEMINI.md`、`AGENTS.md`、`.agents/rules/*.md`，最后那个明确归在**工作区层级**
   （从 CWD 往上走到 git root）。全局那节只写了 `~/.gemini/config/`，没点名 `rules/`。

**要改主意的话先验证**：在一个 `.py` 项目里开 agy，问一句只有 `rules/python.md` 里
才有的约定（比如「布尔值要读成谓词 is/has/should」），看它知不知道。

> **订正（2026-11-15，agy 1.5.9）：上面两条理由都变了，决定本身没动。**
>
> 1. **键对不上**：`trigger` 现在有四种：`always_on`、`model_decision`、`glob`、`manual`。`glob` 配
>    `globs:`（逗号分隔的通配串），和 Claude 的 `paths:` 是同一类功能，只是键名不同。文档还写明每个
>    `rules/*.md` 都必须有合法的 `trigger`，没有 frontmatter 或 trigger 写错的会被**静默丢弃**，不是当
>    常驻规则载入。只有 `paths:`、没有 `trigger` 的文件（就是现在这两份）文档没点名，程序里的提示文字是
>    「no valid trigger in the frontmatter, so the rule never applies」：大概率不生效，也就不占上下文（没实测）。
>    Claude Code 那边 `paths` 是唯一读的字段，别的键忽略、不报错，所以一份文件同时写 `paths:` 和
>    `trigger: glob` + `globs:`，纸面上两边都能用。
> 2. **全局 `rules/` 目录**：现在写明了，`~/.gemini/config/rules/*.md` 是全局规则（官方文档
>    `antigravity.google/docs/rules/`；程序内嵌更新日志 1.2.15 条目）。
>
> 真要接，先在临时仓库的 `.agents/rules/` 里放两份 `python.md`：一份原样，一份加上 `trigger: glob` 和
> `globs: "**/*.py, **/pyproject.toml"`。开 agy 读一个 `.py` 文件，再看哪份生效。两份的结果分别回答
> 「原样会怎样」和「两套 frontmatter 写在一起行不行」。

## 验证方式

**Claude**：改完开**新会话**（指令文件在启动时加载），然后 `/context` 看
**Memory files** 一栏：`~/.claude/CLAUDE.md` 出现了才算生效。
`dof status` 是查不出这个问题的。

**Gemini**：同上思路，问一句只有 `AGENTS.md` 里才有的约定。

## 项目级模板：不要做成脚本

> **还没做**（2026-11-22 核实）：下面的 `commands/init-agents.md` 和 `rubric/agents-md.md`
> 从没进过仓库，两台机器上也都没有，见文末「待办」。这一节是设想的落点，不是现成的步骤：
> 文件写出来之前别建 `~/.claude/commands` 那条软链，否则它指向一个不存在的目录。

你想要的是「进一个新项目 → 根据一份规范生成这个项目的 AGENTS.md」。
这件事是「读规范 + 理解项目 + 写文档」，是 AI 的活，shell 脚本做不了。

正确的落地形式是 **Claude Code 自定义命令**。落点跟着 `tools/agents/` 走：

```
tools/agents/common/commands/init-agents.md   →  ~/.claude/commands/init-agents.md
tools/agents/common/rubric/agents-md.md       →  「一份好的项目 AGENTS.md 该有什么」
```

然后在任何新项目里输入 `/init-agents` 即可。部署方式与 `CLAUDE.md` / `rules/` 相同：
**再加一条本机软链，同样走枢纽、不写仓库路径**：

```bash
ln -s ~/.config/agents/commands ~/.claude/commands
```

> 旧版本这里写的是 `tools/claude/common/commands/`，并说「`~/.claude/commands/`
> 本来就在同步清单里」。**这两句都不成立**：`tools/claude` 已在 2026-08-19 那次
> 「claude: stop syncing ~/.claude」提交里整个删除，`~/.claude` 不再由 dof 管理。命令要生效必须靠上面那条手动软链。
>
> **订正（2026-11-15）**：`tools/claude` 在 2026-09-13 又加回来了，只为 `statusline.sh` 一个文件，
> `.dofkeep` 不放行 `commands/`。所以「要靠手动软链」这个结论照旧成立，只是理由换了。

（Claude Code 自带的 `/init` 也能生成 CLAUDE.md，你这个相当于带自己标准的版本。）

## 待办

- [ ] 写 `rubric/agents-md.md`：项目级 AGENTS.md 的验收标准
- [ ] 写 `commands/init-agents.md`：读 rubric、扫项目、生成并软链 CLAUDE.md
- [ ] 若要给 Gemini 接 rules，先按上面的办法验证它到底读不读
