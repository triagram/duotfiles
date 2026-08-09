# AGENTS.md

这是一个配置文件仓库，按软件为单位在 Linux / macOS 之间部署和回收。
结构和取舍见 `DESIGN.md`，用法见 `README.zh-CN.md`（`README.md` 是英文版，两者内容需保持一致）。

## 红线

- **绝不 commit**：凭据、token、`~/.claude/projects/` 里的会话记录、
  Rime 的 `*.userdb*`、`installation.yaml`。发现这类文件出现在暂存区，停下来告诉用户。
- **绝不替用户做融合决策**。不要主动把文件从 `linux/` 或 `macos/` 移进 `common/`，
  也不要主动合并两个平台的配置 —— 那是用户的判断，不是可以顺手做掉的整理工作。
- **绝不引入外部依赖**。`bin/dof` 必须只用 bash 3.2（macOS 自带版本）+ POSIX 工具跑起来。
  不用关联数组，不用 GNU 专属选项。

## 做「比对两个平台的配置」这类任务时

1. **先读 `notes/<软件>.md`**。里面记着用户已经做过的判断，
   比如「这几行不能合并，因为 macOS 的 Option 键在 Linux 上不存在」。
   不要重复提出已经被否掉的建议。
2. **输出提案，不直接改文件**。给出：建议怎么改 + 理由 + 风险，等用户确认。
3. **平台差异优先用软件自带的 include 机制**表达，不要引入模板引擎：
   - kitty：`include ${KITTY_OS}.conf`（`KITTY_OS` 是 kitty 内置变量）
   - Ghostty：`config-file = ?platform-macos.conf`（`?` = 文件不存在就忽略）
   - tmux：`source-file -q` / `if-shell`
4. 用户确认之后，把这次的判断补进 `notes/<软件>.md`，
   这样下次不用重新推理一遍。

## commit message

用 `<软件>(<平台>): <改了什么>`，融合类改动用 `merge(<软件>):`。

```
tmux(macos): 前缀键改成 C-a
rime: 加了几条自定义短语
merge(kitty): 把配色收敛到 common/，字号保持分平台
```

这样 `git log -- tools/kitty` 就是这个软件的完整演化史。

## 改 bin/dof 时

- 有改动就实际跑一遍验证：造一个假的 `$HOME`，`HOME=/tmp/xxx bin/dof …`
- 破坏性操作（覆盖、删除）必须先备份成 `xxx.dof-bak-<时间戳>`
- 不加 `--all` 之类的全局批量命令，那是刻意排除的（见 `DESIGN.md` 原则 8）
