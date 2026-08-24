# ai-context — 全局与项目级的 AI 指令文件

## 名字对照

| 层级 | 路径 | 中文 | 英文 |
|---|---|---|---|
| 全局（用户级） | `~/.claude/CLAUDE.md`、`~/.gemini/GEMINI.md` | 全局指令 / 全局记忆 | user memory |
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

## 落地方式：两个软链（本机手动建，不进 manifest）

```bash
ln -s ~/duotfiles/tools/agents/common/AGENTS.md ~/.claude/CLAUDE.md
ln -s ~/duotfiles/tools/agents/common/rules     ~/.claude/rules
```

`~/.claude` 已在 `22e6584` 决定不同步，所以这两条是**每台新机器手动敲一次**的引导步骤。
内容仍然只有一份、在仓库里、跟着 git 走。

**为什么用软链而不是 `@~/.config/agents/AGENTS.md` 导入**：软链是同一个 inode，
`/memory` 里编辑会**穿透写进仓库文件**，改动自然进 git；`@` 导入则写进那个本机指针文件，
内容变成永远不同步的孤儿。代价是将来想加「只给 Claude 看、不给 Gemini 看」的指令时
得改用导入形式 —— 真有这个需求再换，一条命令的事。

> **两者都在 Cowork 会话里失效**（软链的 `~/.claude/CLAUDE.md` 被跳过；
> 指向工作目录之外的导入也被跳过）。这一条不构成两种做法的区别。

## rules 要带 paths frontmatter

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

## 验证方式

改完开**新会话**（指令文件在启动时加载），然后 `/context` 看 **Memory files** 一栏 ——
`~/.claude/CLAUDE.md` 出现了才算生效。`dof status` 是查不出这个问题的。

## Gemini 侧还没做

`tools/agy/` 目前只有 `.dofkeep`，没有 GEMINI.md。真要做的时候，
仓库内软链是可行的（git 正常记录软链）：

```bash
cd tools/agy/common && ln -s ../../agents/common/AGENTS.md GEMINI.md
```

**如果你希望两者有差异**（对不同模型的措辞不同），就保持两个独立文件 ——
先各写各的，等确认该一致了再合并，和本仓库处理平台差异的原则一样。

## 项目级模板：不要做成脚本

你想要的是「进一个新项目 → 根据一份规范生成这个项目的 AGENTS.md」。
这件事是「读规范 + 理解项目 + 写文档」，是 AI 的活，shell 脚本做不了。

正确的落地形式是 **Claude Code 自定义命令**。落点跟着 `tools/agents/` 走：

```
tools/agents/common/commands/init-agents.md   →  ~/.claude/commands/init-agents.md
tools/agents/common/rubric/agents-md.md       →  「一份好的项目 AGENTS.md 该有什么」
```

然后在任何新项目里输入 `/init-agents` 即可。

部署方式与 `CLAUDE.md` / `rules/` 相同 —— **再加一条本机软链**：

```bash
ln -s ~/duotfiles/tools/agents/common/commands ~/.claude/commands
```

> 旧版本这里写的是 `tools/claude/common/commands/`，并说「`~/.claude/commands/`
> 本来就在同步清单里」。**这两句现在都不成立** —— `tools/claude` 已在 `22e6584`
> 整个删除，`~/.claude` 不再由 dof 管理。命令要生效必须靠上面那条手动软链。

（Claude Code 自带的 `/init` 也能生成 CLAUDE.md，你这个相当于带自己标准的版本。）

## 待办

- [ ] 写 `rubric/agents-md.md`：项目级 AGENTS.md 的验收标准
- [ ] 写 `commands/init-agents.md`：读 rubric、扫项目、生成并软链 CLAUDE.md
