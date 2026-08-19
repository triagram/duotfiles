# fcitx5-guard

锁屏/休眠前把 fcitx5 强制切回英文的守卫，外加 `rime-reload`。
设计过程与故障史见 `tools/rime/linux/devlog.md §7.6`。

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

- 改完 rime 配置**绝不要跑 `fcitx5 -r`**，用 `rime-reload`。原因见 devlog §7.6：
  换掉 fcitx5 进程会孤立 gnome-shell 那条从登录起就没重建过的输入法连接，
  锁屏会重新出中文，而 guard 日志看起来完全正常。已经踩了就 `Alt+F2` → `r`。
