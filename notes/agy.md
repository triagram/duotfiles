# agy

Antigravity CLI（Gemini 侧）。manifest 目标是**整个 `~/.gemini`**，
因为它的文件散落在这个目录各处 —— 但那里几乎没有东西该进 git，
所以靠 `.dofkeep` 白名单收口。实测 `dof adopt agy`：**收 1 个，跳过 47 个**。

## 收什么、不收什么（2026-08-31 判断）

仓库里只有一个文件：`antigravity-cli/settings.json`，而且只收它的配置字段（见下）。

不收的几类，理由写在 `.dofkeep` 的注释里，这里只记最容易反复的两条：

**`config/AGENTS.md` 刻意不收。** 它确实存在于 `~/.gemini/config/AGENTS.md`，
但只是一条指向 `~/.config/agents/` 枢纽的软链（见 `notes/ai-context.md` 的 2 跳模型）。
收进来会把内容复制一份，给一个已经有唯一真相源的文件造出第二个源。

**`config/config.json` 当凭据处理**（mode 0600），连同 `oauth_creds.json`、
`google_accounts.json`、`installation_id`、`projects.json` 一起排除。

## settings.json 里的 trustedWorkspaces —— 不收（2026-09-03 推翻了原判断）

这个文件是配置与本机状态的混合体：

```json
{ "colorScheme": "tokyo night",           ← 真配置，值得同步
  "model": "Gemini 3.6 Flash (High)",     ← 真配置
  "trustedWorkspaces": [ ... ] }          ← 本机状态，一串绝对路径
```

**最初（2026-08-31）决定整份收**，依据是两个实测数字：文件 35 天没被写过（git 噪声
有限），且列表里其余路径都在家目录之下（另一台覆盖掉只是重新点一次信任提示）。
那两条测量本身没错。

**但 2026-09-03 转 public 时推翻了这个决定。** 原判断只权衡了「同步噪声」，
漏了一整个维度：**那串绝对路径会泄露身份**。实际内容里有机构云盘目录名和一个
具体的研究项目目录名 —— 前者等于公开机构归属，后者等于公开在做什么课题。
仓库还是 private 时这不构成问题，转 public 时它比之前清理掉的提交邮箱更敏感。

所以现在只收两个真配置字段，`trustedWorkspaces` **整个字段不进仓库**。
代价是每台机器要自己点一次信任提示 —— 这正是原判断算过的、可接受的那点代价。

### 连带把 agy 改成 `copy` 模式

**只删字段不够。** `link` 模式下仓库文件就是机器文件，agy 一运行就把路径
重新写回去，直接落进仓库 —— 下次 `git add` 就带出去了。靠人每次提交前检查
是不可靠的。

改成 `copy` 之后，机器上是独立副本，agy 怎么写都碰不到仓库。代价是要手工
`dof push agy` 才能收集改动 —— 而这正好是想要的：**收集变成一个显式、可审阅
的动作，而不是自动发生。**

> `dof push agy` 之前先看一眼输出，别把 `trustedWorkspaces` 又收回来。

## 部署注意事项

`copy` 模式（2026-09-03 从 `link` 改的，理由见上一节）。

改成 copy 顺带解决了原本记在这里的另一个风险：`settings.json` 是应用运行时会写的
文件，若 agy 用「写临时文件 + rename」的写法，link 模式下会把软链替换成普通文件，
`dof status` 报 `UNLINKED`。copy 模式下这个问题不存在。
（同样的坑在 `notes/claude.md` 里对 `~/.claude/settings.json` 记过一次。）

全局指令不走这个工具，走 `agents` —— 见 `notes/ai-context.md`。

## 平台差异

| 配置项 | linux | macos | 能否合并 | 判断日期 |
|---|---|---|---|---|
| `antigravity-cli/settings.json` | 未收 | 已收（仅配置字段） | ❌ 天然分平台；`trustedWorkspaces` 整个字段不进仓库 | 2026-09-03 |
| `config/AGENTS.md` | 软链到枢纽 | 软链到枢纽 | ✓ 已经是同一份，不需要进仓库 | 2026-08-31 |
| `rules/` | ❌ 刻意不接 | ❌ 刻意不接 | frontmatter 键与 Claude Code 不兼容，见 `notes/ai-context.md` | 2026-08-31 |
