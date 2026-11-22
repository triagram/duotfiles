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

> **更正（2026-11-22 晚）**：用户照做了，并没有「回到原样」。X11 下登录后头 90 秒桌面门户卡死，
> 这段时间里开的 kitty 拿不到输入法；这从 7 月起每次 X11 登录都有，只是以前很少碰上。
> 见下面「2026-11-22 晚」一节。

### 全面转向 Wayland 要付出什么（2026-11-22 评估，用户还没定）

本机实测：

- 两台显示器都接在 NVIDIA 卡上（`card1`，nvidia-drm）。Wayland 在 NVIDIA 上的前提都满足：
  `nvidia-suspend/resume/hibernate.service` 都是 enabled，`PreserveVideoMemoryAllocations: 1`。
  以前「只能用 X11」不是硬性不兼容，是 GDM 的规则替这台挑了 Xorg。
- 用户手动启动 fcitx5 之后，它顶替了 GNOME 拉起的 ibus-daemon（之后没有任何 ibus 进程），
  `busctl --user call org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1 DebugInfo` 显示输入上下文在
  `wayland` 组、`frontend:ibus`：原生 Wayland 程序（kitty 也是原生 Wayland）的输入经 GNOME 按 ibus 协议转给 fcitx5。
- fcitx5-guard 只用 `gdbus monitor`（GNOME ScreenSaver、logind）和 `fcitx5-remote`，与会话类型无关。
- Ubuntu 的 mutter 46.2 故意关掉了显式同步协议（changelog：`wayland-Disable-linux-drm-syncobj-v1.patch`，
  「to avoid enabling major new features in Noble updates」），XWayland 23.2.6 也没有。NVIDIA 上 XWayland 程序
  因此可能闪烁或掉帧，这是风险，用户还没观察到（用了不到一小时）。

要做的事（fcitx 官方 wiki「Using Fcitx 5 on Wayland」的 GNOME 节）：

1. fcitx5 开机自启：`~/.config/autostart/` 放一份 `org.fcitx.Fcitx5.desktop`。wiki：自启的 fcitx5 会替换已有的 ibus-daemon。
2. 环境变量：XWayland 程序 `XMODIFIERS=@im=fcitx`，Qt `QT_IM_MODULE=fcitx`。GNOME 现在把它们设成 ibus，
   写进 `~/.config/environment.d/` 能不能压过 GNOME 的值，没试。
3. 候选框位置：wiki 说 GNOME Wayland 下候选框盖不到 GNOME Shell 的界面上、原生 Wayland 窗口里位置也拿不准，
   「Only solution is to use Kimpanel」（GNOME 扩展，要装）。
4. Chrome：wiki 建议走 XWayland 并设 `GTK_IM_MODULE=fcitx`；原生 Wayland 要加 `--enable-wayland-ime` 一类参数。

会丢的：Alt+F2 r（Wayland 下不能原地重启 GNOME Shell，`switch-icon.py` 换完图标要注销）；以前排查用的 `xprop`、
`XGetImage` 看不到原生 Wayland 窗口。kitty 只对 X11 生效的选项（`--position`、`remember_window_position`）本来就没用。
会得到的：kitty 新窗口闪一下别处画面的问题按协议不会出现（见 `notes/kitty.md` 那节，没在 Wayland 下实测）。

推荐（同日给用户的）：先切回「Ubuntu on Xorg」，一个点击、零配置；想要 Wayland 再单独做上面 1 到 4，
重点在逐类程序试输入法和观察 NVIDIA 下 XWayland 程序有没有闪烁。
（更正：「零配置」不成立，X11 也要改 fcitx5 的启动方式，见下一节。第 1 步的自启动 .desktop 有竞速问题，也见下一节。）

## 2026-11-22 晚：切回 Xorg 后，登录头 90 秒桌面门户卡死，期间开的 kitty 拿不到输入法

用户 19:46 在登录界面选了「Ubuntu on Xorg」（`Type=x11`，`DESKTOP_SESSION=ubuntu-xorg`），反馈两条：
输入法用不了；比 Wayland 慢很多。

**实测到的链条**（本次开机的用户日志）：

1. 19:46:50.388，`fcitx5 -d` 通过 D-Bus 激活了 `xdg-desktop-portal`。这个 fcitx5 是 Xsession.d 经 `im-launch`
   拉起的（`23_fcitx5.rc` 的 `IM_CONFIG_PHASE=2`），比 gnome-session 早。
2. 12 ms 后 systemd 报 `Dependency failed for xdg-desktop-portal-gnome.service`：这个单元是
   `Requisite=graphical-session.target`，而该 target 19:46:51.527 才到。
3. `xdg-desktop-portal` 于是一直等 GNOME 后端（每次 `StartServiceByName` 25 秒超时），19:48:20 被 systemd
   按 90 秒启动超时杀掉；19:48:50 再次被激活时 target 早已到达，一切正常。
4. 这 90 多秒里，凡是问门户的程序都要等满 25 秒：每个 kitty 进程启动多花 26 秒（`get_color_scheme`、
   `process_desktop_settings` 都是 NoReply），Telegram 的 `Settings.ReadAll` 也一样。
5. 同一段时间里，kitty 向 fcitx5 的 IBus 前端发 `CreateInputContext` 也是 NoReply。当时活着的三个 kitty 进程
   都在 19:46:58 到 19:47:24 之间启动（登录后恢复的窗口），全部失败。**fcitx5 为什么在门户卡住时不回应，没查实**；
   只知道四次 X11 开机里，kitty 的 IBus 失败都只出现在门户卡住的区间内。

**不是这次才有的**：7 月 28 日、10 月 20 日、11 月 2 日三次 X11 开机的日志里是同一条链（发起者都是 `fcitx5 -d`，
都是 `Dependency failed` 加 90 秒超时，前两次 kitty 也有 IBus 失败）。以前一次开机用几周，很少撞上；今天重启了
四次，而 `restore_session_after_logout` 让 kitty 在登录后几秒内开窗，正好落进卡死区间，于是每次登录都中招。

**Wayland 下为什么没事**：Wayland 会话不跑 Xsession.d，fcitx5 不会早启动。今天两次 Wayland 开机，最早问门户的是
GNOME 自启动的 nautilus / gnome-software，比 target 早约 46 ms，门户的 GNOME 后端仍然起来了。这是**刚好赢了竞速**，
不是有顺序保证。

**「放一份自启动 .desktop」的方案因此有风险**：gnome-session 拉起 XDG 自启动程序的时刻比 `graphical-session.target`
早 0.10 到 0.34 秒（三次开机都是）。fcitx5 用 `~/.config/autostart/` 自启动，会和 nautilus 一样处在竞速里。
有顺序保证的写法是 systemd 用户单元 `After=graphical-session.target`，`fcitx5-lock-guard.service` 已经这样挂。
（GNOME 自己的 `org.freedesktop.IBus.session.GNOME.service` 也是 systemd 用户单元，但它挂在
`gnome-session-initialized.target` 之后、`gnome-session.target` 之前；ibus-daemon 不碰门户，所以没问题。）

**当时的状态**（19:55 前后实测）：门户和 fcitx5 的 IBus 前端都在 4 ms 内回应；从 shell 起一个临时 kitty，
IBus 输入上下文立刻建立（`DebugInfo` 里 `frontend:ibus` 从 1 个变 2 个，stderr 没有报错）。所以「X11 下输入法
用不了」只针对登录头 90 秒里开的窗口。另外 fcitx5 在 19:50:56 被换成了 `fcitx5 -r`（父进程 1，多半是托盘的
「重新启动」），这正是上面「绝不要跑 `fcitx5 -r`」那条说的锁屏隐患。

**「慢」只量到了一部分**：量到的是登录后头两分钟的 25 秒超时。渲染、拖窗口、滚动这类持续性的快慢没有测；
用户在 X11 下一共只用了约 8 分钟。

**决定（2026-11-22，用户）：继续用 X11（「Ubuntu on Xorg」），不转 Wayland。**
用户说的「X11 慢」是「登录后开程序要很久」，就是上面那 90 秒。除此之外 Wayland 在这台上没有实质优势
（核对过的）：两台显示器都是 1920x1080、60 Hz、同尺寸，用不上 Wayland 的分屏缩放和混合刷新率；
24.04 标准支持到 2029-05-31（本机 `/usr/share/distro-info/ubuntu.csv`），不升级就不会被迫转；
在 24.04 上 Wayland 反而要多做输入法那四件事，还有 NVIDIA 下 XWayland 闪烁的风险。
没量过的：系统开销、画面顺滑度。Wayland 仍有、但不改变结论的两点：程序之间的输入和画面隔离；
kitty 新窗口闪一下别处画面的问题按协议不会出现（没实测，该线程用户搁置中）。
下一步：fcitx5 改由 `After=graphical-session.target` 的 systemd 用户单元启动，`~/.xinputrc` 只保留设环境变量的
第一阶段（具体文件内容待用户确认）。
