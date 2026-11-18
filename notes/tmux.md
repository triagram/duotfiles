# tmux

## 还没收进仓库（2026-11-18 决定）

`manifest` 里有 tmux 这一行，两份 README 的表里标着「还没收」，但 `tools/tmux/` 下只有占位的 `.gitkeep`：
2026-08-09 建骨架时就列进来了，一直没 adopt（`dof status tmux` 报 `no files for this tool in the repo yet`）。

**manifest 那行留着**：打算不久后开始学 tmux，到时候直接 adopt，不用再加条目。

Linux 这台现在的 tmux 配置是 oh-my-tmux，两个文件都链到仓库外：

- `~/.config/tmux/tmux.conf` → `~/tpmIni/oh-my-tmux/.tmux.conf`（oh-my-tmux 本体，第三方）
- `~/.config/tmux/tmux.conf.local` → `~/tpmIni/.tmux.conf.local`（自己的改动放这里）

真要收的时候先想清楚收哪个。oh-my-tmux 本体是上游原样的文件，按 ghostty 着色器那条的做法
（没改过的第三方文件不进仓库，记下出处），大概只值得收 `.tmux.conf.local`；
`~/.config/tmux/plugins/` 是插件目录，不该进仓库。macOS 那台的 tmux 配置还没看过。
