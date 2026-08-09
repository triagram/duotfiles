# claude

`~/.claude` 是本仓库里唯一「配置和本机状态混在同一个目录」的软件，
所以它有 `.dofkeep` 白名单。

## 同步 / 不同步

| 同步 | 不同步（也不该存在于仓库） |
|---|---|
| `CLAUDE.md`（全局指令） | `.credentials.json` |
| `settings.json` | `.claude.json`（配置+状态+凭据混合） |
| `keybindings.json` | `projects/`（**所有会话的完整记录**） |
| `commands/` `skills/` `agents/` `hooks/` | `todos/` `shell-snapshots/` `statsig/` |
| `output-styles/` | `history*` `*.jsonl` |
| `statusline.sh` / `*.sh` / `scripts/` | |

## 状态栏（statusline）需要同步的东西

不是只有脚本本身。一个能在另一台机器上真正跑起来的状态栏，需要这几样：

1. **`statusline.sh`** —— 脚本本体
2. **`settings.json` 里的 `statusLine` 配置块** —— 没有它，脚本躺在那儿不会被调用
3. **可执行位** —— git 记录 exec bit，`dof` 的 link 模式权限直接跟随源文件，
   copy 模式的 `cp` 也保留。所以只要你在源机器上 `chmod +x` 过就没问题
4. **脚本引用的其他文件** —— 配色定义、图标映射、辅助脚本。
   检查一遍：`grep -nE '(source|\.|cat|read).*\.(sh|conf|json|txt)' ~/.claude/statusline.sh`

## 跨平台断点（statusline 脚本最容易踩的三个）

**① 硬编码的家目录路径**

```bash
/home/mengyuan/.claude/...     # ❌ 到 macOS 就断
$HOME/.claude/...              # ✅
```

**② BSD 与 GNU 工具的参数不兼容** —— macOS 自带的是 BSD 版本：

| 命令 | Linux (GNU) | macOS (BSD) |
|---|---|---|
| `date` | `date -d '1 hour ago'` | 不支持 `-d`，要用 `date -v-1H` |
| `stat` | `stat -c '%Y' f` | `stat -f '%m' f` |
| `sed -i` | `sed -i 's/a/b/'` | `sed -i '' 's/a/b/'`（必须给备份后缀） |
| `readlink -f` | 有 | 老版本没有（新版 macOS 才有） |

躲开的办法：状态栏脚本尽量只用 POSIX 子集，或者把平台判断写进脚本里
（`case "$(uname -s)" in Darwin) ... ;; esac`）。这属于「脚本自己处理平台差异」，
比在 duotfiles 里拆两份更省事。

**③ 外部依赖** —— statusline 脚本通常用 `jq` 解析 Claude Code 从 stdin 传进来的
会话 JSON。另一台机器没装 `jq`，状态栏就是空的。

在这里记下你的脚本依赖哪些命令：

- [ ] jq
- [ ] git
- [ ] （其他）

**④ 字体** —— 如果状态栏用了 Nerd Font 图标，另一台机器的终端必须装同一套字体，
否则显示成方框。字体不归 duotfiles 管（那是系统安装的事），但要记得装。

## 验证方法

部署到新机器后：

```bash
dof status claude                  # 链接是否健康
ls -l ~/.claude/statusline.sh      # 有没有 x 权限、是不是 -> 仓库
echo '{}' | ~/.claude/statusline.sh    # 能不能独立跑起来，缺依赖会直接报错
```

`settings.json` 值得留意：Claude Code 的 `/config` 会写这个文件。
如果哪天 `dof status claude` 报它 `UNLINKED`，说明它用的是「写临时文件 + rename」，
把 manifest 里 claude 改成 copy 模式。

## 平台差异

| 配置项 | linux | macos | 能否合并 | 判断日期 |
|---|---|---|---|---|
| （等两边配置都进仓库后再填） | | | | |
