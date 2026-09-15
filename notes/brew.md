# brew

macOS 的 Homebrew 包清单，`tools/brew/macos/Brewfile`，link 到 `~/.homebrew/Brewfile`。
Linux 不部署（manifest 是 `-`）：Linux 版 Homebrew 没有 cask，`brew bundle` 会在第一个
`cask` 行直接失败，不是「那边不用」这么简单。

## 为什么是 `~/.homebrew/`（2026-09-15）

`brew bundle --global` 的查找顺序：`$HOMEBREW_BUNDLE_FILE_GLOBAL` → `$XDG_CONFIG_HOME/homebrew/Brewfile`
（仅当变量已设）→ `~/.homebrew/Brewfile` → `~/.Brewfile`。本机两个变量都没设，
`~/.homebrew/` 是个专属目录，manifest 直接指过去，不用像 zsh 那样以 `~` 为 target 再靠 `.dofkeep` 挡。

**两个实测都过了才定的 link 模式**：`brew bundle check --global` 报的正是 `brew outdated`
里那几个（说明读到了）；`brew bundle dump --global --force` 之后 inode 不变、`dof status` 绿
（Ruby 写穿软链，不是 write-temp-then-rename）。

## 维护方式：手写为主，dump 只用来看漂移

文件没有抬头注释，是刻意的 —— 这样 `dump --force` 直接覆盖也不丢东西，两种工作流都行：

- **加软件**：`brew install x` 之后手动加一行，或者 `brew bundle dump --global --force` 再看 `git diff`
- **新机器**：`brew bundle install --global`
- **看漂移**：`brew bundle check --global`（注意它把「有新版本」也算不满足，先 `brew outdated` 对一眼）
- **清理**：`brew bundle cleanup --global` 不带 `--force` 就是 dry-run，只列「Would remove」；
  加 `--force` 才真卸载清单外的东西（已实测，2026-09-15 时无一包在名单里）

dump 只列顶层（`brew leaves` + 全部 cask），依赖不进来 —— 17 个 formula 里只有 5 个在清单里，正常。

## 内容审阅（2026-09-15）

人眼过了一遍：无路径、无邮箱、无机构名。`clickshare`（Barco 会议室投屏客户端）
**从清单里去掉了** —— 它只在当前机构的会议室有用，不属于「新机器要装」的东西。
本机装着的不受影响；**唯一后果是 `brew bundle cleanup --force` 会把它当多余的卸掉**。
