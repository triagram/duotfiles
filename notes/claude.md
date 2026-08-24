# claude — 决定不同步

`~/.claude` 不在本仓库管理范围内。manifest 里没有这个条目。

## 为什么留着这份笔记

因为「不管」也是一个决定，不写下来的话下次还会被重新提出来。
真要恢复，manifest 加回一行即可：

```
claude     link   ~/.claude                         ~/.claude
```

配套的 `.dofkeep` / `.dofignore` 在 git 历史里（`e10e834`），需要时 `git show` 取回。

## 当时查清楚的事实（留档，省得重查）

`~/.claude` 顶层 22 个条目，真正算配置的只有 2 个：`settings.json`、`statusline.sh`。
其余全是本机状态：`projects/`（每次会话的完整记录）、`sessions/`、`file-history/`、
`shell-snapshots/`（shell 环境快照，含 env 与别名）、`daemon*`、`cache/`、
`.credentials.json`、`.claude.json`，以及 `plugins/`（430 个文件，marketplace 装的，
换机器重装即可）。

`statusline.sh`（350 行）做过跨平台预检，结论是**它本身没有移植问题**：
没有写死的家目录路径（`settings.json` 用的是 `bash ~/.claude/statusline.sh`）、
没有 GNU 专属参数、自包含不引用其他文件、可执行位正常。
用到 2 处 `jq`。**macOS 上零外部依赖** —— `jq` 自 macOS 15 起随系统附带，
本机 `/usr/bin/jq` 是 `jq-1.7.1-apple`，2026-08-09 实测通过。
只有 macOS 14 及更早才需要 `brew install jq`。

## 附带产出

收编 `~/.claude` 时踩出了一个 `bin/dof` 的真 bug：`.dofkeep` 里的 `*.sh` 把
`shell-snapshots/`、`jobs/`、`plugins/` 里 36 个脚本全收了，因为 shell 的 `case`
通配符里 `*` 会跨越 `/`。修复后匹配改为分段语义（见 `bin/dof` 的 `path_matches`），
这个修复对所有工具都生效。
