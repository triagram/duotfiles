# claude

`~/.claude` 是本仓库里配置与本机状态混得最厉害的一个目录：
顶层 22 个条目，只有 2 个该进仓库。所以它有两道闸。

## 两道闸

| 闸 | 文件 | 作用 |
|---|---|---|
| ① 白名单 | `tools/claude/.dofkeep` | 决定什么能进 —— 只有列出的才收 |
| ② 黑名单 | `tools/claude/.dofignore` | 兜底 —— 将来白名单放宽了，也扫不进本机状态 |

实测 `dof adopt claude` 的结果：**收 2 个，跳过 638 个**。

```
+  settings.json
+  statusline.sh
·  .credentials.json / history.jsonl / daemon.* / .last-* / stats-cache.json  （顶层，逐条列出）
·  638 path(s) skipped                                                        （深层，只计数）
```

## 匹配语义的坑（踩过一次）

`.dofkeep` 里原本写了 `*.sh`，结果把 **`shell-snapshots/`（你的 shell 环境快照，含 env 与别名）、
`jobs/`、`plugins/` 里的 36 个脚本**全收进了仓库。

原因是 shell 的 `case` 通配符里 `*` **会跨越 `/`**，所以 `*.sh` 命中了任意深度的 `.sh`。

现在 `bin/dof` 的 `path_matches` 改成分段匹配：

```
settings.json   只匹配顶层    → 不会命中 plugins/settings.json
*.sh            只匹配顶层    → 不会命中 shell-snapshots/x.sh
commands/       整个子树
*.userdb/       子树，首段可带通配
```

## 不同步什么

`plugins/`（430 个文件）—— 官方 marketplace 装的插件，换机器重装即可，不是配置。
`projects/`、`sessions/`、`file-history/`、`shell-snapshots/` —— 会话记录与环境快照，
既是隐私也是本机状态。`.credentials.json`、`.claude.json` —— 凭据。

## statusline 跨平台预检（已通过）

`settings.json` 的配置：

```json
"statusLine": { "type": "command", "command": "bash ~/.claude/statusline.sh", "refreshInterval": 2 }
```

| 检查项 | 结果 |
|---|---|
| 写死的家目录路径（`/home/…`、`/Users/…`） | ✓ 没有 —— 用的是 `~`，两个平台都成立 |
| GNU 专属参数（`date -d`、`stat -c`、`sed -i` 无后缀、`readlink -f`、`grep -P`） | ✓ 没有 |
| 可执行位 | ✓ 有（`-rwxrwxr-x`），git 会记录，link 模式下权限跟随源文件 |
| 引用的其他文件 | ✓ 没有，350 行自包含 |

**外部依赖**（350 行里用到的）：

| 命令 | macOS 上 |
|---|---|
| `git` ×12 | 自带（Xcode CLT） |
| `awk` ×4 | 自带（BSD awk，用法兼容） |
| `tput` / `stty` | 自带 |
| **`jq` ×2** | **不自带 → `brew install jq`** |

所以在 macOS 上只需要装 `jq`，其余开箱即用。

## 到新机器上的验证

```bash
dof status claude                      # 链接是否健康
ls -l ~/.claude/statusline.sh          # 有 x 权限、且是 -> ~/.duotfiles/...
echo '{}' | bash ~/.claude/statusline.sh   # 独立跑一次，缺 jq 会直接报错
```

`settings.json` 值得留意：Claude Code 的 `/config` 会写这个文件。
若哪天 `dof status claude` 报它 `UNLINKED`，说明它用的是「写临时文件 + rename」，
把 manifest 里 claude 改成 copy 模式。

## 平台差异

| 配置项 | linux | macos | 能否合并 | 判断日期 |
|---|---|---|---|---|
| （等 macOS 侧配置进仓库后再填） | | | | |
