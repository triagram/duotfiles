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

  > 2026-11-14 又出过一次锁屏输入问题，查到的和没查实的（2026-11-16 记）：
  >
  > - 那天 19:46 fcitx5 自己重启过一次（新进程是 `fcitx5 -r`，父进程是 1）。已知会这样重启的是托盘菜单的
  >   「重新启动」和 fcitx5 的配置工具，所以 **`fcitx5 -r` 不一定是手敲的**。点没点过不记得了。
  > - 从 D-Bus 看，gnome-shell 已经连上了新的 fcitx5，不像 8 月那次连接没重建的样子；之后几次解锁有没有
  >   出拼音也不记得了。原因没查实。
  > - `Alt+F2` → `r` 之后一直没再出现。碰到了照旧这么救。

## 覆盖哪些锁屏路径（2026-11-16）

所有路径都经过守护：Super+L、闲置超时、合盖、系统菜单的「锁定」、`loginctl lock-session`，
外加任何来源的休眠。Super+L 是 GNOME 自带的锁屏键（`media-keys` 的 `screensaver`），
自定义快捷键只有 Kitty 一个。脚本注释原来写「补 Super+L 包装脚本管不到的路径」，
那个包装脚本仓库里从来没有过，大概是建仓库之前有、后来撤掉了，注释已改。

## 2026-11-22：登录变成 Wayland 会话，fcitx5 不再自启动（还没决定怎么处理）

**现象**：11-22 装更新重启后，fcitx5 开机不自己起来，要手动开。`loginctl show-session <id> -p Type` 是
`wayland`；会话环境变量是 `XMODIFIERS=@im=ibus`、`QT_IM_MODULE=ibus`，GNOME 自己拉起了 ibus。

**原因**（本机实测 + 读本机脚本）：

1. 这台以前一直是 X11：更新前那次开机的用户日志里有 7881 行 `gdm-x-session`，更新后两次开机一行都没有。
   登录界面记的会话是 `ubuntu`（AccountsService），24.04 上这个名字既有 X11 版也有 Wayland 版，
   由 GDM 按显卡规则挑；X11 版的名字是 `ubuntu-xorg`。
2. 11-22 那次更新把 gdm3 从 46.2-1ubuntu1~24.04.6 升到 ~24.04.9，中间的 ~24.04.7 是
   「Fix incorrect setting preferred display server (LP: #2143015)」。上游补丁（salsa gdm MR 39）同时删了
   NVIDIA 混合显卡笔记本、NVIDIA 挂起服务这两类「禁用 Wayland」的规则；本机现在的 `61-gdm.rules` 里确实没有了。
   这台是 AMD 核显 + NVIDIA 580 open 驱动。旧规则里具体是哪条让它走 X11，已经没法回看（`/run/gdm3` 只有 root 能读，
   旧规则文件被覆盖了），所以「gdm3 更新导致变成 Wayland」是按时间和改动推的，不是逐条核实的。
3. fcitx5 在 X11 下是 `/etc/X11/Xsession.d/70im-config_launch` 拉起的（读 `~/.xinputrc` 的 `run_im fcitx5`）。
   Wayland 会话不跑 Xsession.d；自启动项 `im-launch.desktop` 虽然在 Wayland 下会往下走，但
   `IM_CONFIG_PHASE=1` 只在那个 Xsession.d 脚本里设，Wayland 下没有，`im-launch` 就什么也不做
   （`/usr/bin/im-launch`、`/usr/share/im-config/data/23_fcitx5.rc`）。

**推荐的处理**（待用户定）：在登录界面右下角齿轮里选「Ubuntu on Xorg」。这会把 AccountsService 里的会话
记成 `ubuntu-xorg`，以后不再由 GDM 的显卡规则决定，fcitx5 和其他按 X11 写的设置（kitty 的 X11 选项、Alt+F2 r）
都回到原样。不改任何配置文件。
