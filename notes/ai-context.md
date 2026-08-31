# ai-context — 全局与项目级的 AI 指令文件

## 名字对照

| 层级 | 路径 | 中文 | 英文 |
|---|---|---|---|
| 全局（用户级） | `~/.claude/CLAUDE.md`、`~/.gemini/config/AGENTS.md` | 全局指令 / 全局记忆 | user memory |
| 项目级 | 项目根的 `AGENTS.md` / `CLAUDE.md` / `GEMINI.md` | 项目指令 / 项目记忆 | project memory |

`AGENTS.md` 是跨厂商的中立约定，多家 AI 编码工具都读它。本仓库自己就是这么做的：
根目录 `AGENTS.md` 是真身，`CLAUDE.md` 是指向它的软链。

## Claude Code 只认两个路径（2026-08-25 查证）

官方文档写死了，别猜：

> **Claude Code reads `CLAUDE.md`, not `AGENTS.md`.**

| 层级 | 唯一路径 |
|---|---|
| Managed policy | `/Library/Application Support/ClaudeCode/CLAUDE.md`（Linux: `/etc/claude-code/`） |
| **用户级指令** | **`~/.claude/CLAUDE.md`** |
| **用户级 rules** | **`~/.claude/rules/*.md`** |
| 项目级 | `./CLAUDE.md` 或 `./.claude/CLAUDE.md` |

**没有任何 XDG 路径。** `~/.config/agents/AGENTS.md` 不会被读 —— 位置不在列表里，
文件名也不对，两条都不满足。放成 `~/.claude/AGENTS.md` 同样不读。

> 这个坑实际踩过：`tools/agents` 部署到 `~/.config/agents/`，
> `dof status agents` 三个 ✓ 全绿，但 Claude Code 一个字都没读到。
> **`dof` 说部署成功 ≠ 目标程序会去读那个位置。**

> **⚠ 不要因此把 `agents` 从 manifest 删掉。** `~/.config/agents/` 不是给厂商读的，
> 它是**中立枢纽**（见下一节）—— 没有工具直接读它，但所有厂商的软链都指向它。

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
  └─────────────▶ ~/.gemini/config/AGENTS.md
```

新机器上的引导步骤（`~/.claude` 已在 `22e6584` 决定不同步，所以这几条进不了 manifest）：

```bash
dof pull agents                                      # 先铺好枢纽
ln -s ~/.config/agents/AGENTS.md ~/.claude/CLAUDE.md
ln -s ~/.config/agents/rules     ~/.claude/rules
ln -s ~/.config/agents/AGENTS.md ~/.gemini/config/AGENTS.md
```

**注意这几条命令里没有仓库路径。** 这是 2 跳最主要的好处，下面详述。

### 为什么不是 1 跳（直接链到仓库）

1 跳看起来更直观 —— 和仓库里其他工具一样，「配置只有一份在仓库里，别处链过来」。
2026-08-31 认真考虑过，最后否掉，三条理由：

**① 引导命令里不含仓库路径，仓库怎么挪都不影响厂商那几条链。**
这不是推演，是当天实测的：把仓库从 `~/.duotfiles` 改名成 `~/duotfiles` 之后，
13 条指向仓库的软链断了 11 条，**而 4 条厂商软链一条都没断** —— 它们指向
`~/.config/agents/`，压根不含仓库路径。dof 管的那 11 条一句 `dof pull` 就全好了。
1 跳的话，这 4 条会跟着一起断，而且每台机器都要手工重建。

**② 保住 manifest 里 `agents` 那条的意义。** 1 跳的话 dof 部署到 `~/.config/agents`
就没人经过了，你会想把它从 manifest 删掉 —— 于是 `tools/agents/` 变成唯一一个
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
「只给 Claude 看、不给 Gemini 看」的指令时得改用导入形式 —— 真有这个需求再换。

> **两者都在 Cowork 会话里失效**（软链的 `~/.claude/CLAUDE.md` 被跳过；
> 指向工作目录之外的导入也被跳过）。这一条不构成两种做法的区别。

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
> `trigger: always_on | model_decision`，完全不同的词汇 —— 这是不把 rules 链给
> Gemini 的直接原因，见下一节。

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

**刻意不接 rules（2026-08-31）。** 曾经建过 `~/.gemini/config/rules` 这条链，当天摘掉了，
两条理由：

1. **frontmatter 的键对不上。** 我们的文件用 `paths:`，Antigravity 用 `trigger:`。
   按它文档「只有 `always_on` 无条件载入」的措辞，一个没有它认识的 trigger 的规则
   最可能被当成常驻规则**每次会话都载入** —— 正是加 `paths:` 想避免的事。
   Claude 那边省下的上下文，在 Gemini 这边又赔回去。
2. **全局 `rules/` 目录能不能被发现，文档没写死。** 它列的 rules 发现路径是
   `GEMINI.md`、`AGENTS.md`、`.agents/rules/*.md`，最后那个明确归在**工作区层级**
   （从 CWD 往上走到 git root）。全局那节只写了 `~/.gemini/config/`，没点名 `rules/`。

**要改主意的话先验证**：在一个 `.py` 项目里开 agy，问一句只有 `rules/python.md` 里
才有的约定（比如「布尔值要读成谓词 is/has/should」），看它知不知道。

## 验证方式

**Claude**：改完开**新会话**（指令文件在启动时加载），然后 `/context` 看
**Memory files** 一栏 —— `~/.claude/CLAUDE.md` 出现了才算生效。
`dof status` 是查不出这个问题的。

**Gemini**：同上思路 —— 问一句只有 `AGENTS.md` 里才有的约定。

## 项目级模板：不要做成脚本

你想要的是「进一个新项目 → 根据一份规范生成这个项目的 AGENTS.md」。
这件事是「读规范 + 理解项目 + 写文档」，是 AI 的活，shell 脚本做不了。

正确的落地形式是 **Claude Code 自定义命令**。落点跟着 `tools/agents/` 走：

```
tools/agents/common/commands/init-agents.md   →  ~/.claude/commands/init-agents.md
tools/agents/common/rubric/agents-md.md       →  「一份好的项目 AGENTS.md 该有什么」
```

然后在任何新项目里输入 `/init-agents` 即可。部署方式与 `CLAUDE.md` / `rules/` 相同 ——
**再加一条本机软链，同样走枢纽、不写仓库路径**：

```bash
ln -s ~/.config/agents/commands ~/.claude/commands
```

> 旧版本这里写的是 `tools/claude/common/commands/`，并说「`~/.claude/commands/`
> 本来就在同步清单里」。**这两句都不成立** —— `tools/claude` 已在 `22e6584`
> 整个删除，`~/.claude` 不再由 dof 管理。命令要生效必须靠上面那条手动软链。

（Claude Code 自带的 `/init` 也能生成 CLAUDE.md，你这个相当于带自己标准的版本。）

## 待办

- [ ] 写 `rubric/agents-md.md`：项目级 AGENTS.md 的验收标准
- [ ] 写 `commands/init-agents.md`：读 rubric、扫项目、生成并软链 CLAUDE.md
- [ ] 若要给 Gemini 接 rules，先按上面的办法验证它到底读不读
