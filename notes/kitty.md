# kitty

`link` 模式。2026-08-23 首次纳入，只收 5 个手写文件，其余全部排除。

## 收什么、不收什么（2026-08-23 判断）

`~/.config/kitty` 有 13 项，进仓库的只有 5 个：`kitty.conf`、`theme-overrides.conf`、
`toggle-bg.sh`、`switch-icon.py`、`README.md`。约 21 KB；不排除的话是 7.1 MB。

排除项和理由都写在 `tools/kitty/.dofignore` 里（那份文件是给「以后想改规则的人」看的，
比这里详细）。这里只记**为什么这么判**，免得下次重推一遍：

| 排除项 | 判断 |
|---|---|
| `backgrounds/`（6.8 MB） | 40 倍膨胀，图片不可移植也不共享。后果刻意保留：新机器上 `theme-overrides.conf` 指向不存在的图，kitty 静默不画背景、不报错 |
| `icons/` + `kitty.app.png` | 同为图片素材。且 `switch-icon.py` 会 `shutil.copy` 覆写 `kitty.app.png`：link 模式下等于每次换图标都往仓库塞一个 128 KB 二进制 |
| 四个主题文件 | 见下，单独一节 |
| `kitty.conf.bak` | 纳入版本控制之前的手工备份。内建的 `*.dof-bak-*` 匹配不到 `.bak` |

> 2026-11-18 订正 `backgrounds/` 那一行的后果：2026-08-30 起 `theme-overrides.conf` 不再设背景图
> （那一行注释掉了），新机器上没有任何东西指向缺失的图；`backgrounds/` 不在，只是 Ctrl+中键找不到 PNG、
> 脚本直接退出。`tools/kitty/.dofignore` 里早就是这么写的，这张表没跟上。

> 2026-11-19 订正 `kitty.app.png` 那一行的理由：这个文件删了，`switch-icon.py` 也不再写它，
> 「每次换图标都往仓库塞一个二进制」不再成立。`.dofignore` 里那条留着，理由换成 Mac：
> 那边这个文件名管 Dock 图标，在 Mac 上 adopt 时不能把它收进公开仓库。见文末那一节。

## 主题文件为什么不收

`current-theme.conf`、`dark-theme.auto.conf`、`light-theme.auto.conf`、
`no-preference-theme.auto.conf`。**四个都逐字节核实过**（2026-08-23）：

```
dark-theme.auto.conf 前 81 行  ==  kitten themes --dump-theme Catppuccin-Mocha
light-theme.auto.conf 前 81 行 ==  kitten themes --dump-theme Catppuccin-Frappe
current-theme.conf             ==  dark-theme.auto.conf
no-preference-theme.auto.conf  ==  light-theme.auto.conf
```

即前 81 行都是上游 Catppuccin（MIT）原样输出，本地改动只有追加在末尾的两行

```
# 背景圖與標籤欄顏色（見 theme-overrides.conf 開頭的說明）
include theme-overrides.conf
```

且 `current-theme.conf` 与 `dark-theme.auto.conf` **逐字节相同**。收进来 = 同一份第三方
配色存四遍，只为一行真正属于自己的东西。主题名记在 README.md，重建是一条命令一个文件。

**附带好处**：`kitten themes` 重跑时写的是真文件，会把软链替换掉，`dof status` 会报
`UNLINKED`：这是反复发生的，不收就没有这个问题。

> **订正（2026-11-18）：这条附带好处不成立。** kitty 遇到软链会写进它指向的文件，不会把软链换成真文件：
> 0.42.2 起目标存在时就这样，0.50.0 起目标不存在也这样（0.50.0 在临时目录里实测过，更早的版本是看源码）。
> 当初记下的 `UNLINKED` 是怎么来的没查清。不收主题文件的理由只剩上面那条：同一份配色存四遍。

> 主题名里的 Frappe **不带重音符**：`Catppuccin-Frappe`。

## 部署注意事项

- **`dof pull kitty` 只对新开的窗口生效**，老窗口不会重载。
- 换完主题记得检查 include 链（README.md「坑 2」）：
  ```sh
  grep -L "include theme-overrides.conf" ~/.config/kitty/*-theme*.conf
  ```
  有输出就是那几个文件要把 include 加回去。
- `README.md` 是刻意收的：`.dofignore` 里排除 `backgrounds/` 的注释直接指向它。
  文档不跟着配置走的话，新机器上「背景图为什么没了、怎么补」就只留在旧机器上。

## 平台差异

macOS 侧还没进仓库，`tools/kitty/{common,macos}/` 仍是空的。

> **所以现在在 Mac 上跑 `dof pull kitty` 是个空操作**：`resolve_sources` 只走
> `common/` 和 `<platform>/`，两边都只有 `.gitkeep`（还会被 `BUILTIN_IGNORE` 滤掉），
> 结果是「0 file(s) updated」，不报错也不部署任何东西。Mac 上要先
> `dof adopt kitty` 把本机配置收进来，才有东西可比对、可部署。

| 配置项 | linux | macos | 能否合并 | 判断日期 |
|---|---|---|---|---|
| （等 macOS 侧 `dof adopt kitty` 之后再填） | | | | |

届时用 kitty 自带的 `include ${KITTY_OS}.conf` 表达平台差异（`KITTY_OS` 是 kitty 内置变量），
不引入模板引擎：见 `AGENTS.md`。**在能真正比对之前，不要往 `common/` 搬东西。**

## custom shader（2026-09-24 判断）

kitty 0.49.0 起支持 `custom_shaders`（GPU 滤镜）。本机当天从 0.42.2 升到 0.49.1。

**选了什么**：只开「非当前分屏压暗」（最终用的是自定义版，见本节末尾）。光标拖尾保留内建样式，
不换 `cursor-trail-blaze` / `cursor-trail-lightning`；动态背景、鼠标效果、复古屏幕暂不开。
用户的原话是「先应用 dim，有问题再调」。

**已经查清、不要重推的几点**：

- **dim 不省电。** 本机是液晶屏，背光恒定，画面暗不省电。它不增加重绘次数，
  但每次重绘多一道全屏处理。`background_opacity 0.95` 本来就让 kitty 走分层绘制，
  所以额外开销只剩那一道。
- **`dim-inactive-windows` 和 `focus-highlight` 是同一个 `focus-highlight.slang`**，
  只是 pipeline 不同：前者常驻、静态（`animation_step 0`）；后者只在切分屏 / 切 tab 后
  跑 0.75 秒，平时零开销。
- **`crt` / `crt-blue` / `tft` / `water` 会一直每 50 ms 重绘**，不看焦点也不看空闲：
  它们没有带停止条件的 pipeline。要用就自写 `animation_step 0` 的 pipeline
  （crt、tft 的画面本来就不随时间变）。
- 换成拖尾滤镜后 `cursor_trail_color` 不生效，颜色和时长由滤镜自己的 `var` 参数决定。
- 与 Ghostty 的功耗差别在机制：Ghostty 聚焦时固定 8 ms 一帧、不检测空闲
  （实测见 `notes/ghostty.md`）；kitty 默认 50 ms 一帧，空闲超过 `cursor_stop_blinking_after`
  （15 秒）或失焦就停。**kitty 侧还没实测功耗。**

**用的是自定义的 `shaders/dim-inactive-panes.pipeline`，不是内建的 `dim-inactive-windows`**
（同日改的）。内建版实测（测试窗口截图取样）连 tab 栏（`17,17,27 → 5,5,11`）和当前分屏
四周的留白（`30,30,46 → 13,13,22`）也一起压暗，当前分屏像多了一圈暗框，用户看不习惯。
自定义版只比内建版多两个 `var`（取自官方文档的 dim-gray 例子）：
`DIM_CENTRAL_AREA_ONLY = true` 放过 tab 栏，`INCLUDE_WINDOW_PADDING = true` 让当前分屏的
留白不变暗。实测 tab 栏、当前分屏留白都回到原色，非当前分屏仍是 `13,13,22`。

- 取名刻意避开内建名：`shaders/` 下的同名文件会悄悄盖掉内建版，事后很难看出来。
- 这个文件随 `kitty.conf` 一起进仓库。不收的话，别的机器上 `kitty.conf` 会引用一个
  不存在的 pipeline。

**关掉只能删掉那一行。** `custom_shaders` 写成空值（包括 `-o custom_shaders=`）会被当作
无效行忽略（日志 `Ignoring invalid config line`），滤镜照样从 kitty.conf 加载。

**验证方法**（下次调参沿用）：
`kitty --debug-rendering --class ShaderTest --session <两分屏、两 tab 的 session 文件>`，
日志里看 `Custom shaders: N program(s)` 和 `has_active_shaders: 0 -> 1`；
对照组用去掉那一行的配置副本 `--config` 启动。截图用系统 Python（`/usr/bin/python3`，
pyenv 那个没有 `gi`）的 GdkX11 按窗口 XID 截，再取像素比较。

## 背景图开关的键盘快捷键（2026-10-21 判断）

**起因**：在 Claude Code 里按 `Ctrl+中键` 会粘贴，而不是开关背景。Claude Code 一启动就
打开鼠标上报，`ungrabbed` 的手势不触发，点击交给了 Claude Code（机制同 README「坑 4b」的 tmux）。

**选了什么**：加 `map ctrl+shift+i`（开关）和 `map ctrl+shift+alt+i`（换下一张），
鼠标手势保持 `ungrabbed` 不动。用户原话「就 Ctrl + shift +i 好了」。
代价：在 Claude Code 里手滑按到 `Ctrl+中键`，仍会粘贴一次（不会发送）。

**没选的**：「加键盘+吞中键」，即加 `mouse_map ctrl+middle press grabbed discard_event`
并把手势改成 `ungrabbed,grabbed`。这会推翻 2026-08-30 保持 `ungrabbed` 的决定，
用户这次没选它。

**为什么是 `i`**（2026-10-20 查过，不要重推）：

- 必须带 Shift：单按 Ctrl+字母是 shell 和程序的，而且 kitty 把 `ctrl+i` 和 Tab 都发成 `\t`。
  `ctrl+shift+i` 发的是 `\x1b[105;6u`。
- kitty 0.49.1 默认的 `ctrl+shift+字母` 只空着 d、i、m、y；上游 master 的
  `definition.py` 里 `i` 一次都没出现，升级不会撞。
- 不选 `m`：Rime `japanese.schema.yaml` 原文绑了 `Control+Shift+m`（还有 n/k/v/j/l），
  只是 `japanese.custom.yaml` 把 `key_binder` 换成了默认预设，`build/` 里才没有；
  覆盖一改就会撞。不选 `y`：kitty 文档拿 `kitty_mod+y` 当示例。
  最好记的 `b`（background）被内建的 `move_window_backward` 占了。
- 不用单个 F 键：那是终端里程序的键（htop 的 F9 是杀进程）。

**冲突检查结果**（`Ctrl+Shift+I` 和 `Ctrl+Shift+Alt+I` 都查了，都没有）：GNOME 全部
gsettings 快捷键和自定义快捷键；fcitx5 实际生效的热键；Rime `build/`；Claude Code 2.1.304
程序文件（只有 `ctrl+shift+c`、`ctrl+shift+b`）；仓库里其他软件的配置。

> fcitx5 的 `EnumerateForwardKeys=Control+Shift_L`（切输入法）看着像冲突，其实不是：
> 它在 Shift 松开时才触发，而且中间只要按了别的键就作废（fcitx5 `instance.cpp`
> 里 `keyReleased_` 每个按键事件都清零）。平时 `Ctrl+Shift+C/V` 不切输入法也是这个原因。

## 重启后恢复窗口：不做（2026-10-21 判断）

> 2026-11-18 改判：开了 0.50.0 自带的 `restore_session_after_logout`（见本节末尾两小节）。
> 下面 2026-10-21 否掉的定时自动保存、按键保存，仍然不做。

**选了什么**：「算了」。不做定时自动保存（systemd timer），也不做按键保存 / 恢复
（F7 s / F7 r）。用户原话「这种需求不是那么多,每次完全手动也行」。

**已经查清、不要重推的几点**（2026-10-20）：

- kitty 0.43.0 起自带 `save_as_session` 动作，可以用
  `kitty @ --to unix:@kitty-<PID> action save_as_session --save-only --use-foreground-process <文件>`
  调用（0.49.1 实测）。它连分屏布局一起存。
- 它只存收到命令的那**一个** kitty 进程。Ctrl+Alt+T 跑的是 `kitty`，每按一次就多一个进程。
- `--use-foreground-process` 把 shell 里手敲的命令原样存下、恢复时重跑
  （实测 `sleep 600` 存成 `cmd_at_shell_startup`）。所以手敲的 `claude` 回来是新对话；
  `rm` 之类也会被重跑，官方文档有警告。
- kitty 0.50.0（未发布）会有 `restore_session_after_logout`：注销 / 重启时自动存、下次启动恢复，
  但不重启 shell 以外的程序。Linux 上依赖 Inhibit portal v3，本机是 v3。
  **它发布后，如果还想要「像 Chrome 那样」，先看它。**
- 网上的现成工具（dflock/kitty-save-session、kitty-utils、几篇 systemd timer 的做法）
  都不处理「接着原来的 Claude 对话」。要做的话：`~/.claude/sessions/<PID>.json` 里有
  `sessionId`，可以写成 `claude --resume <sessionId>`（内部文件，无文档）。
- 存下来的 session 文件里有项目目录名，**只能放在 `~/.local/share/kitty/sessions/`，不进仓库**。

### 0.50.0 的 `restore_session_after_logout`：开了（2026-11-18 决定，还没实测）

上面「它发布后先看它」那条的条件满足了：0.50.0 在 2026-11-03 发布，本机装的就是 0.50.0；Inhibit portal 是
第 3 版（`busctl --user get-property org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop
org.freedesktop.portal.Inhibit version` 返回 `u 3`）。2026-11-18 把下面这些讲给了用户，用户说下一轮对话再定。
**在那之前，上面「不做」的决定不变。**

本机文档原文的要点（`~/.local/kitty.app/share/doc/kitty/html/sessions.html#restore-after-logout`）：

- **开法**：`kitty.conf` 里一行 `restore_session_after_logout yes`。
- **存什么**：注销、重启或关机时，存**每个** kitty 实例的状态：每个窗口的大小、位置、状态，和每个窗口的
  回滚内容。上面 `save_as_session` 只存一个进程的局限，它没有。
- **怎么恢复**：下次启动 kitty 时，命令行参数相同的那个实例原地恢复，其余的各自另起一个 kitty，带着原来的
  参数、工作目录和环境变量。先恢复回滚内容，再启动 shell，下面加一行保存时间。只恢复文字、格式和链接。
  **shell 以外的程序不重新启动**：`claude`、`nvim` 回不来，`rm` 之类也不会被重跑。
- **Linux 上不加密**：存在 kitty 的缓存目录里，只有自己能读，和 shell 历史一样；回滚里出现过的内容都会落盘。
  macOS 上是加密的。
- **什么时候存**：只在桌面通知「会话要结束了」时存，注销被取消就删掉；断电、强制关机不存。
  出错信息写到 kitty 的 stderr。

**怎么试**（`kitty.conf` 是配置文件，改之前先问）：在仓库的 `tools/kitty/linux/kitty.conf` 里加上那一行，
link 模式下改的就是 `~/.config/kitty/kitty.conf`。已经开着的 kitty 是按旧配置启动的，保险起见关掉、新开几个窗口，
再注销重登，看窗口和回滚有没有回来。不要了就删掉那一行。接着原来的 Claude 对话这件事它不管，
上面 `claude --resume` 那条仍然是唯一的线索。

#### 第二轮核实（2026-11-18，0.50.0 源码 + 本机实测；用户还没定）

**实现**（`glfw/linux_session_monitor.c`、`kitty/logout_session.py`）：Linux 上 kitty 注销时不会被叫去退出，
只会被杀掉，所以它向 Inhibit portal 订阅会话状态（`CreateMonitor`）。链条是
gnome-session 发 `QueryEndSession` → portal 发 `StateChanged`（session-state 2）→ 每个 kitty 当场同步存盘
→ 回 `QueryEndResponse` → 注销继续。kitty 只认回复过它 `CreateMonitor` 的那个 portal、只认自己那个监视会话，
别的程序伪造不了「要注销了」。注销被取消（状态回到 1）就删掉刚存的快照。

- **portal 只等 1 秒**：xdg-desktop-portal-gtk 1.15.1 `inhibit.c` 里是 `g_timeout_add (1000, ...)`。
  超时的后果是那个实例回不来，不是恢复出半份：快照先写进临时目录，写完才改名。
  5 个实例各 10000 行回滚存不存得完，**没测**。
- **存在哪、存什么**：`~/.cache/kitty/saved-at-logout/<pid>/` 下的 `session.kitty-session`（相当于
  `save_as_session --os-window-geometry`，不带 `--use-foreground-process`）、`scrollback/<窗口 id>`
  （带颜色和链接的文字，当前那行提示符去掉）、`process.json`（argv、cwd、kitty 启动时的**全部**环境变量）。
  目录 0700、文件 0600。
- **恢复**：注销后第一个不带 `--session`、不带命令启动的 kitty 认领全部快照：argv 相同的那份恢复在它自己身上，
  其余每份另起一个 kitty，用原来的 argv、cwd 和环境变量（DISPLAY、DBUS、SSH_AUTH_SOCK 这类登录会话变量换成新的）。
  回滚只放行 SGR、OSC 8、OSC 66 三种转义，旧输出里别的转义重放时不起作用。恢复完就删；恢复失败两次的也删。
- **关掉**：删掉那一行之后，下一次不带 `--config` / `-o` 的正常启动会删光所有快照（`main.py`
  `logout_snapshot_to_restore`）。
- **已开着的窗口**：0.47.0 起 `auto_reload_config` 默认 0.1 秒，0.47.1 起跟得住软链（`tools/watch/api.go`
  解析到仓库里的真实文件、监视那个目录）；重载会调 `monitor_desktop_session_if_needed()`。
  所以 0.50.0 的实例改完配置就开始监视，不用重开（源码，没实测）。

**本机实测**：

- Inhibit 由 xdg-desktop-portal-gtk 1.15.1 提供（`gnome.portal` 里没有 Inhibit，`gtk.portal` 里有），
  它在 gnome-session 里注册成客户端 `org.freedesktop.portal`。
- 照 kitty 的参数直接调 `CreateMonitor`：响应码 0，随即收到 session-state 1（运行中）。
  监视存在期间 `busctl --user tree org.freedesktop.portal.Desktop` 列得出 `.../session/<连接名>/<token>`，
  进程一退就没了。kitty 的 token 是 `glfw_session_monitor`。
- **当天开着的 5 个 kitty 都是 11-02 启动的，`/proc/<pid>/exe` 显示 `(deleted)`**：跑的是 11-03 升级前的二进制，
  没有这个选项，开不开它，注销后都回不来（和现在一样）。0.49.1 读到不认识的键只往 stderr 写
  `Ignoring unknown config key`，不弹窗（`kitty/conf/utils.py`）。所以不必先关它们；试的时候至少要有一个
  升级之后新开的 kitty。注销前的检查：`glfw_session_monitor` 的行数应该等于 exe 不带 `(deleted)` 的 kitty 进程数。
- Ctrl+Alt+T 是自定义快捷键，命令就是不带参数的 `kitty`；5 个进程的 argv 也都为空。所以重登后按一次就全回来。
- 从 GNOME 启动的 kitty，stderr 是接到 systemd 日志的 socket：错误看
  `journalctl --user -b -g 'Inhibit portal|logout'`（重启过就用 `-b -1`）。kitty 这几条报错都含
  `Inhibit portal` 或 `logout`，例如 `Failed to save the session at logout`、`saved for a cancelled logout`。
- **暴露面**：快照明文落在本地盘上，和 shell 历史同一级别。环境变量里没有密钥类的值，
  真正要在意的是回滚：屏幕上出现过的东西，从注销到下次打开 kitty 之间都躺在盘上。

**没核实**：从终端 `systemctl reboot`、IT 远程重启会不会走 gnome-session 的 QueryEnd。
文档只承诺「桌面说会话要结束」时存，所以只把 GNOME 菜单里的注销、重启、关机当成有效路径。

**接 Claude 对话的手动办法**：恢复出来的 shell 在原目录，`claude -c` 接这个目录最近一次对话；
同一目录开过几个对话就用 `claude -r` 挑。

#### 决定：开（2026-11-18）

用户原话「配置可以加,既然是官方特性那应该是可以的」。`tools/kitty/linux/kitty.conf` 第 13 节加了
`restore_session_after_logout yes`。**还没实测**：用户手头有几个正在开发的 Claude Code 会话，
等它们差不多收尾再注销试。用户接受的代价：注销时本来想关掉的窗口，下次打开 kitty 也会一起回来。

加的时候 5 个旧进程都在 22:22:59 自动重载，各往日志写了一行
`Ignoring unknown config key: restore_session_after_logout`，都还活着；同一天 16:55 改 kitty.conf 时它们也重载过一次，
没出事。0.50.0 用 `kitty +runpy` 读这份配置，`restore_session_after_logout` 是 `True`。

**2026-11-22 装更新后重启，Ctrl+Alt+T 没恢复：不算失败，是那一刻没有能存的 kitty。** 日志（`journalctl --user -b -1`）：
11-19 测试用的那个 0.50.0 窗口 21:47 就关了；重启时还开着的 4 个 kitty 都是 11-02 启动的旧进程，
X server 一退它们就报 `XIO: fatal IO error` 退出，没有任何 `Inhibit portal` / `logout` 报错，
`~/.cache/kitty/saved-at-logout` 也不存在。真注销测试仍然没做成。重启之后开的 3 个 kitty 都是 0.50.0，
portal 监视也是 3 个，下一次 GNOME 的注销或重启就是第一次真测。
「软件更新器」装完点「立即重启」走的是 gnome-session：本机 `UpdateManager/Dialogs.py` 调
`org.gnome.SessionManager.RequestReboot()`，失败才退到 logind。所以这条路算数；这次是不是走的这条，日志里看不出来。

#### 什么时候存，什么时候不存（2026-11-18 查的，用户问到）

- **存**：GNOME 的结束流程。右上角菜单的注销、重启、关机；那个对话框 60 秒倒计时走完会自动按下确认
  （gnome-shell 46.0 `endSessionDialog.js` `_startTimer`）；短按电源键也是同一个对话框
  （本机 `power-button-action` 是 `interactive`，gnome-settings-daemon 46.0 调 gnome-session 的 `Shutdown`），
  但锁屏时短按不起作用。存的是那一刻还开着的全部窗口、tab、分屏。
- **不保证**：终端里 `sudo reboot`、`systemctl reboot`，或 IT 远程重启。gnome-session 收到 SIGTERM 也会走一遍
  强制注销、照样发出询问（gnome-session 46.0 `main.c` 和 `gsm-manager.c`），但 kitty 自己同时也收到 SIGTERM，
  收到就退出（`child-monitor.c` `handle_signal`），谁先谁后没保证。没实测。
- **不存**：断电、长按电源键、死机；注销前自己关掉的窗口（Ctrl+D、关窗口、kill）；升级前启动的 kitty 进程，
  包括在这些旧窗口里新开的 tab、分屏、新窗口（它们属于同一个旧进程）；注销被取消（刚存的快照会删掉，
  窗口本来就还开着）。某个窗口算新算旧，在里面跑 `readlink /proc/$KITTY_PID/exe`：结尾带 `(deleted)` 就是旧的。
  不能用 `kitty --version`，它跑的是盘上的新文件，旧窗口里也打印 0.50.0。
- **用不上**：锁屏、挂起、切换用户。会话没结束，窗口一直都在。
- **恢复的时机**：登录时不会自己弹出来，要等第一次不带参数启动 kitty（Ctrl+Alt+T 或 Dock）。
  不想要这一份，就在那之前 `rm -rf ~/.cache/kitty/saved-at-logout`（源码：恢复时只扫这个目录）。
- **还没见过真 kitty 注册上**：本机只验证了 portal 接受订阅请求。下次 Ctrl+Alt+T 开出第一个新进程时，
  跑一次注销前那两条计数命令，两个数都应该是 1。
  **2026-11-19 见到了**：用户在新开的窗口（0.50.0，21:34 启动）里跑，两个数都是 1。剩下没验证的只有真注销那一步。

## 新窗口里一闪而过别处的画面（2026-11-02 查明，还没决定修不修）

**现象**：Ctrl+Alt+T 开新终端，新窗口里先闪一下「左屏左上角」的内容（当时那里是最大化的
Chrome），约 0.2 秒后才变成正常终端。不管窗口最后落在哪个屏幕，闪的都是左上角那块。

**原因**（实测 + 源码核对，已查清，不要重推）：

1. mutter 先在 (0,32) 把窗口映射出来（kitty 请求的是 (0,0)，被顶栏推到 y=32），映射之后才把它
   放到鼠标所在的屏幕。xev 实测：map 之后约 1 ms 就移走了。
2. X server 的 Composite 扩展在映射那一刻给窗口分配后备缓冲，**并且总是先拷一份屏幕缓冲区在
   那个位置的内容进去**（xorg-server 21.1.12 `composite/compalloc.c` 的 `compNewPixmap`；
   同深度、不同深度两个分支都拷，不看窗口背景）。之后只移动、不改尺寸，缓冲不重建，
   这份拷贝跟着窗口走到右屏。
3. kitty 的 GLFW 建窗口时不设背景色（`XCreateWindow` 只传
   `CWBorderPixel | CWColormap | CWEventMask`），所以没有东西盖掉这份拷贝；它也不支持
   `_NET_WM_SYNC_REQUEST`，mutter 不等首帧就显示（mutter 46.2 在 X11 下 `window_has_buffer`
   恒为真）。kitty 映射前那次清屏 swap 到不了映射时才建的缓冲。

实测（直接读窗口像素，不靠录屏）：先在屏幕缓冲区 (0,32) 处画四色块，新 kitty 窗口落在右屏
(2020,100)，前 185 到 205 ms（5 次里有 1 次 397 ms）像素与色块 100% 一致、alpha 全是 255
（不透明），之后才是 kitty 背景色。按 kitty 的方式建一个空白测试窗口，加上 `CWBackPixel`
之后一开始就是纯色，不加就是色块。

> 这组时长是在**锁屏、显示器关闭**时测的，亮屏时可能不同，还没复测。

**试过 / 查过、不要重推的**：

- `background_opacity 1` 没用：变成同深度，走 CopyArea 分支，照样拷。（源码）
- 关 GNOME 动画没用：mutter 有没有动画都立刻显示窗口，动画只决定它淡入多久。（源码）
- `kitty -1`（单实例）更糟：拷贝停留约 0.98 秒。（锁屏时测）
- 录屏看不到它：之前录的是左屏左上角，窗口其实落在右屏；GNOME 录屏 D-Bus 接口录全屏时
  连续两次 NoReply 崩掉。正确的观察方法是对新窗口直接 `XGetImage`。
- `XGetImage` / x11grab 读 root 全黑：那次是锁屏 + 显示器关了，不是驱动问题。
- kitty 的 issue、changelog（含未发布的 0.50）里没有同样的报告。GLFW 上游 2014 年删过一次
  黑色 `CWBackPixel`（GLFW #267，原因是 resize 闪烁）。

**能修的地方都不在 kitty.conf 里**：

- kitty 上游：`createNativeWindow` 加 `CWBackPixel`（ARGB visual 要带 alpha：背景色加
  `0xff000000`，或者 0 表示全透明，GTK 和 Chromium 用的是 0）；或者实现扩展版
  `_NET_WM_SYNC_REQUEST`，mutter 46.2 会冻结窗口直到首帧画好。
- 用户侧缓解：`kitty --position=1200x300`（写法是 `宽x高` 那种 `x`，不是逗号）。
  2026-11-03 实测 2 次（锁屏时，对照组是同一轮里的 2 次普通 `kitty`）：mutter 46.2 照办，
  映射前就把窗口配置到 (1200,300)，之后不再移动；前 187 到 197 ms 窗口里是**它自己所在位置**
  的拷贝，也就是它身后的画面，看起来像窗口晚出现 0.2 秒，而不是闪别处的内容。
  代价：每个新窗口都开在同一个位置，不再跟着鼠标所在的屏幕走。
  同一机制的另一种写法是 kitty.conf 的 `remember_window_position yes`（新窗口开在上一个关掉的
  窗口的位置），没测。两种都只在 X11 有效，kitty 文档写明在 Wayland 上从不生效。
- Wayland 会话里不会有这个问题：xdg-shell 规定窗口要等程序提交了自己的第一帧才算映射，
  没有 X server 先拷屏幕这一步。（协议原文，没在本机 Wayland 会话里实测）

## `kitty.app.png` 在本机不起作用（2026-11-18 查明，README 已改；2026-11-19 删了）

`tools/kitty/linux/README.md` 第 59-60、70-71、281 行和 `switch-icon.py` 第 2、57-60 行都把它说成
「当前的 X11 窗口图标」。kitty 确实是读它来当 X11 窗口图标的，但在本机两层都不生效：

1. **kitty 把它丢了，窗口上什么图标都没有。** X11 上 kitty 只收 128x128 以内的图（`kitty/glfw.c`
   `set_default_window_icon`，0.30.0 起），本机这张是 1024x1024，每次启动日志里都有
   `The window icon is too large (1024x1024)`。而且只要 `kitty.app.png` 在，kitty 就不再退回自带图标
   （`kitty/main.py` `set_window_icon`）。实测当天开着的 5 个窗口，`xprop -id <窗口> _NET_WM_ICON` 全是 `not found`；
   这 5 个跑的是升级前的二进制，0.50.0 这边的证据是日志里同一条报错（11-11 起每次启动都有）加源码。
   在 kitty 窗口里自己看：`xprop -id "$WINDOWID" _NET_WM_ICON`。
   上限的来由是 #6507：图太大时 X server 以 `BadLength`（`X_ChangeProperty`）拒掉请求，kitty 启动就崩，
   作者说 X11 能收的上限是 128x128 或 256x256，看服务器配置。
   报错里叫人放 `~/.config/kitty.app-128.png`，路径写错了：代码读的是 `~/.config/kitty/kitty.app-128.png`。
2. **就算设上了，GNOME Shell 46 也不显示它。** 46.0 源码 `src/shell-app.c` 的 `shell_app_get_icon`：
   有 desktop 文件就用它的 `Icon=`，没有就用通用的 `application-x-executable`，从不读窗口自己的图标。
   Dock、Alt+Tab、概览都走这条；只有 Ctrl+Alt+Tab 对找不到应用的 DOCK 类窗口才用窗口图标。
   （读的是上游 46.0。Alt+Tab 那段 JS 和本机装的 46.0-0ubuntu6~24.04.17 逐字相同；`shell-app.c` 编译在库里，
   Ubuntu 的补丁没查。）
   通知也一样：kitty 只在别无选择时把 `kitty.app.png` 当 `app_icon`，而 GNOME 认得出发送方
   （kitty 带了 `desktop-entry` 提示）时就不看 `app_icon`。

所以它在本机唯一的效果是日志里每次一行报错。会用到它的地方：读 `_NET_WM_ICON` 的别的桌面或窗口管理器；
以及 macOS，那边 config 目录里的 `kitty.app.png` / `kitty.app.icns` 管的是 Dock 图标（以后 Mac 侧 adopt 时要考虑）。

**README 怎么改的**（2026-11-18，用户定的口径）：只写两件事，kitty 在 X11 上只收 128x128 以内的图标，
GNOME 只按 desktop 文件的 `Icon=kitty` 去图标主题的路径里找。用户原话「readme只要最小加入内容就行」。
改了第 4 条的两处和文件一览表那一行，没写报错里那个错误路径，也没写 GNOME 源码的细节（都在上面）。

**删不删这张图**（2026-11-18 提的）：

> **2026-11-19 删了**，用户原话「删，删完一起推送」。文件放进了 GNOME 回收站（`gio trash`，找得回来）；
> `switch-icon.py` 去掉了复制那一步，在假 HOME 里换 nyan、whiskers 各一次，hicolor 照常生成，都没再写出它；
> README 文件一览表里那行删了；`.dofignore` 那条留着，只改了注释。下面是当时提议的理由。
>
> 删后实测（同日，删除之后新开的 0.50.0 窗口）：`xprop -id "$WINDOWID" _NET_WM_ICON` 返回
> `Icon (128 x 128)`，即 kitty 自带的图标；这个进程启动后日志里没有 `The window icon is too large`。

- 删了不丢东西：它和 `icons/nyan.png` 逐字节相同。删了之后 kitty 改用自带的 128 像素图标当窗口图标
  （GNOME 下照样看不见），日志里每次启动那行报错也没了。
- 光删文件不够：`switch-icon.py` 每次换图标都会把选中的图复制成 `kitty.app.png`（第 22 行和第 57-60 行），
  要一起去掉这一步。
- `tools/kitty/.dofignore` 里的 `kitty.app.png` 那行要留：`.dofignore` 是按软件放的，Mac 和 Linux 共用，
  Mac 上这个文件名管 Dock 图标，以后在 Mac 上 `dof adopt kitty` 时不能把它当二进制收进公开仓库。
  只是那段注释给的理由（`switch-icon.py` 会覆写它）要改。
