# ai-context — 全局与项目级的 AI 指令文件

## 名字对照

| 层级 | 路径 | 中文 | 英文 |
|---|---|---|---|
| 全局（用户级） | `~/.claude/CLAUDE.md`、`~/.gemini/GEMINI.md` | 全局指令 / 全局记忆 | user memory |
| 项目级 | 项目根的 `AGENTS.md` / `CLAUDE.md` / `GEMINI.md` | 项目指令 / 项目记忆 | project memory |

`AGENTS.md` 是跨厂商的中立约定，多家 AI 编码工具都读它。本仓库自己就是这么做的：
根目录 `AGENTS.md` 是真身，`CLAUDE.md` 是指向它的软链。

## 全局那份在本仓库的位置

```
tools/claude/common/CLAUDE.md      → 部署到 ~/.claude/CLAUDE.md
tools/agy/common/GEMINI.md         → 部署到 ~/.gemini/GEMINI.md
```

**如果你希望两者内容完全一致**，把其中一个做成仓库内的软链：

```bash
cd tools/agy/common && ln -s ../../claude/common/CLAUDE.md GEMINI.md
```

git 会正常记录软链，两个 `dof pull` 都会部署同一份内容。
**如果你希望两者有差异**（比如对不同模型的提示措辞不同），就保持两个独立文件。
先各写各的，等你确认它们该一致了再合并 —— 和本仓库处理平台差异的原则一样。

## 项目级模板：不要做成脚本

你想要的是「进一个新项目 → 根据一份规范生成这个项目的 AGENTS.md」。
这件事是「读规范 + 理解项目 + 写文档」，是 AI 的活，shell 脚本做不了。

正确的落地形式是 **Claude Code 自定义命令**：

```
tools/claude/common/commands/init-agents.md      → 部署到 ~/.claude/commands/init-agents.md
tools/claude/common/rubric/agents-md.md          → 「一份好的项目 AGENTS.md 该有什么」
```

然后在任何新项目里输入 `/init-agents` 即可。

好处：`~/.claude/commands/` 本来就在本仓库的同步清单里，
**这个能力会自动跟着 dotfiles 部署到每一台新机器**。

（Claude Code 自带的 `/init` 也能生成 CLAUDE.md，你这个相当于带自己标准的版本。）

## 待办

- [ ] 写 `rubric/agents-md.md`：项目级 AGENTS.md 的验收标准
- [ ] 写 `commands/init-agents.md`：读 rubric、扫项目、生成并软链 CLAUDE.md
