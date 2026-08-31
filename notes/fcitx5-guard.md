# fcitx5-guard

锁屏/休眠前把 fcitx5 强制切回英文的守卫，外加 `rime-reload`。
设计过程与故障史见 `tools/rime/common/devlog.md §7.6`。

## 平台差异

| 配置项 | linux | macos | 能否合并 | 判断日期 |
|---|---|---|---|---|
| 整个工具 | ✅ | ❌ 不部署 | ❌ 依赖 GNOME ScreenSaver / logind / fcitx5，macOS 无对应物 | 2026-08-19 |

## 部署注意事项

- manifest 目标是 `~/.local`，一条覆盖两处：`bin/` 和 `share/systemd/user/`。
  后者是 systemd 合法的用户单元搜索路径（`systemd-analyze --user unit-paths`），
  所以 service 不必单独开一条 manifest 条目。
- **`dof pull` 不会 enable 服务**，新机器上要补一句：

  ```bash
  systemctl --user enable --now fcitx5-lock-guard.service
  ```

- **仓库移动之后，光跑 `dof pull` 不够，还要 `systemctl --user reenable`。**
  2026-08-31 把仓库从 `~/.duotfiles` 改名成 `~/duotfiles` 时实测到的：
  `systemctl --user enable` 建的两条链（`~/.config/systemd/user/` 下的单元链，
  和 `graphical-session.target.wants/` 下的 enable 链）**解析到仓库真实路径**，
  不是停在 dof 部署的 `~/.local/share/systemd/user/` 那一层，所以会跟着断，
  而 dof 管不到它们。

  症状很误导：`is-active` 仍然是 `active`（跑着的进程握着已打开的文件），
  但 `is-enabled` 变成 **`not-found`**，一重启就起不来。

  ```bash
  dof pull fcitx5-guard                                  # 先修 dof 管的那层
  systemctl --user daemon-reload
  systemctl --user reenable --now fcitx5-lock-guard.service
  systemctl --user is-enabled fcitx5-lock-guard.service  # 应为 enabled
  ```

  > 顺带清掉一处历史遗留：`~/.config/systemd/user/fcitx5-lock-guard.service`
  > 曾经有一份**手工建的**副本直接指向仓库。它是多余的（`~/.local/share/systemd/user/`
  > 本身就是合法搜索路径），而且 `.config` 优先级更高，会遮蔽 dof 部署的那份。
  > 现在这条由 `systemctl enable` 自己生成，不要再手工建。

- 改完 rime 配置**绝不要跑 `fcitx5 -r`**，用 `rime-reload`。原因见 devlog §7.6：
  换掉 fcitx5 进程会孤立 gnome-shell 那条从登录起就没重建过的输入法连接，
  锁屏会重新出中文，而 guard 日志看起来完全正常。已经踩了就 `Alt+F2` → `r`。
