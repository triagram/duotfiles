# ghostty

macOS 侧的终端（Linux 侧对应 kitty，见 `notes/kitty.md`）。

**已收进仓库（2026-09-12）**，link 模式，四个文件：`config`、`toggle-shader.sh`、
`shaders/cursor_tail.glsl`、`shaders/LICENSE`。其余按 `tools/ghostty/.dofkeep` 的理由排除，
最重要的两条：`shader.conf` 是开关状态不是配置，收了每按一次快捷键 git 就脏；
`shaders/` 是上游 clone，只收改过的那一个。

> `~/.config/ghostty/shaders/.git/` 现在是**残留物** —— 文件已从仓库软链过去，
> 在那里 `git pull` 会跟软链打架。想试别的着色器就重新 clone 上游到别处。
>
> `config-file = ?shader.conf` 按**配置文件的给定路径**解析（`~/.config/ghostty/`），
> 不是按软链目标（仓库）解析 —— 验过 `+show-config`。这一点成立，分片机制才能和 link 模式共存。

## 透明度：blur 才是主要杠杆，不是 opacity（2026-08-24 判断）

现象：kitty 那边 `background_opacity 0.95` 看起来比 Ghostty 的 `0.90` **更透**，
数值反直觉。

原因是模糊，不是不透明度：

| | 不透明度 | 模糊半径 |
|---|---|---|
| kitty (linux) | 0.95 | `background_blur 1` —— 半径 1，约等于关闭 |
| Ghostty (macos) | 0.85 | `background-blur-radius 5` |

macOS 的毛玻璃会把背景采样后混进一层浓重底色，视觉上是**磨砂**而不是**透光**。
半径的影响远大于那几个百分点的不透明度差。想更透先调 blur。

> `background-blur-radius` 是别名，解析后等于 `background-blur`。
> 用 `ghostty +show-config` 看解析结果，别看配置文件里写了什么。

## 窗口默认尺寸：和 kitty 同一个坑

`window-save-state = always` 会记住上次拖拽的尺寸并盖掉 `window-width/height`，
必须设 `never` 才能让默认尺寸生效。代价是不再沿用上次的窗口大小。

这与 `kitty.conf` 里 `remember_window_size no` 是**完全同一个陷阱**，两个终端各踩一次。

## 改配置的验证方式

```bash
G=/Applications/Ghostty.app/Contents/MacOS/ghostty
"$G" +validate-config              # 没有输出 = 通过
"$G" +show-config | grep <键名>    # 看解析后的实际值，不是文件里写的值
```

> `+validate-config` 的**退出码恒为 0**，输出才是信号。写个非法值试一次就知道 ——
> 它会打印错误并列出合法取值集合（例如 `cursor-style` 的 `bar, block, underline, block_hollow`）。

## 功耗：闪烁是噪声，着色器是十倍（2026-09-11 现状）

| 改动 | 结论 | 证据强度 |
|---|---|---|
| `cursor-style-blink = false` | **没用，已回退** | 2.65% → 2.30%，差 0.35 个点，在噪声里 |
| `custom-shader` (`cursor_tail`) | **代价确凿** | 0.81% → 8.18% → 关回 0.96%，可逆 |
| GPU 那一半 | **+350 mW，22×** | `powermetrics` 三轮交错，+328/+370/+352，见下 |

官方基准值（维护者 Mitchell）最有参考价值：

> "Ghostty idles at **0% unfocused and 1 to 4% focused** depending on config."

本机空窗口基线 0.81%，落在下沿；开着色器后 8.18%，**远在区间之外**。

### 闪烁那次为什么不算数

`#10397` 声称 ProMotion 上闪烁让 idle CPU 从 ~1.5% 涨到 10–15%，实测差 0.35 个点。
**但真正的问题是仪器用错了** —— `top` 的 `%CPU` 抓不到 GPU，更抓不到
「ProMotion 被钉在高刷新率」的显示链路能耗，而那才是关键。
社区也没数字：`#5063` 无瓦特无方法论，至今 `needs-confirmation`；
维护者原话 *"This is very, very hard to measure. I have doubts."*

**教训：别凭 issue 里的传闻改配置。**

### 着色器那次为什么算数

差值 7.3 个点是组内标准差（0.07 / 0.48）的十几倍，**而且关掉就回基线** ——
A′ 那一组才是关键，它排除了漂移和后台任务撞车。

测法有四个必须，每一个都曾经搞砸过一次：

1. **必须隔离实例**。macOS 上 Ghostty 单进程，多开窗口隔离不了任何东西：
   `open -n -a Ghostty --args --config-default-files=false --config-file=<独立配置>`。
   `config-default-files` **只能从命令行设**，写进配置文件无效（官方文档原话）。
2. **必须聚焦**。`custom-shader-animation = true` 只驱动**聚焦**那个 surface 的动画循环，
   窗口不在前台 macOS 直接挂起渲染，两组都读 0.0%。上一次就卡死在这。
3. **焦点要机器验证**，别靠自己以为 —— 独立配置里写 `title = SHADER-TEST`，配合
   `osascript -e 'tell application "System Events" to tell (first process whose frontmost is true) to get name of front window'`
   采样前后各查一次。这同时验证了隔离配置**确实被读进去了**（标题变了就是读到了）。
4. `top -pid X -l N -s 1` 的**第一帧是生命周期均值，必须丢掉**。

踩到的坑：`+show-config` **不接受任何附加参数**，加了就静默输出空、不报错，
所以没法用它预检隔离配置；`pgrep -x ghostty` 找不到进程（comm 是全路径），
用 `ps -Axo pid,comm | grep '/Ghostty.app/'`；`screencapture` 无屏幕录制权限，
想截图看拖尾这条路走不通。

### 不要再试 ioreg 那条路（2026-09-12）

看起来很诱人：电池放电时 `ioreg -rn AppleSmartBattery` 的
`InstantAmperage × Voltage` 就是**整机**瞬时功率，含 GPU 和显示链路，还不用 sudo。

**但它 ~50 秒才更新一次。** 实测每 5 秒采一次、连采 90 秒，只出现 **2 个**不同取值。
要凑够样本每组得跑十分钟，那个时长里背景噪声早就盖过信号了。

两个解析陷阱一并记下：`InstantAmperage` 是 **64 位补码**（放电时是个接近 2⁶⁴ 的大数，
要减 `2**64`），而且 awk 的双精度存不下这个量级 —— 用 python 读。

**结论：GPU 功率只能靠 `sudo powermetrics`。**

### GPU 那一半 —— 已测（2026-09-12）

`sudo powermetrics --samplers cpu_power,gpu_power -i 1000 -n 20`，开/关交错三轮，
在主实例上用开关脚本切换，Ghostty 聚焦、零输入：

| | GPU 功率 | GPU 活跃 | CPU 功率 | 合计 |
|---|---|---|---|---|
| 关 | **16 mW** ± 7 | 2.9% | 8712 mW | 8728 mW |
| 开 | **366 mW** ± 28 | 34.6% | 9444 mW | 9811 mW |
| 差 | **+350 mW（22×）** | +32 个点 | +732 mW | **+1083 mW** |

三轮 GPU 差值 **+328 / +370 / +352** —— 方向一致、幅度一致，没有漂移。
组内标准差 7–28 mW，信号是噪声的十几倍。

**换算**：合计约 **1.08 W**。电池 80 Wh，按实测 5.2 W 的电池空闲功耗，
不开着色器约 15 h、开着约 13 h —— **聚焦终端时每小时多耗约 1.35% 电量**。
切到别的 App 就是零（未聚焦的 surface 不跑动画循环）。

**瑕疵要记**：关闭组 CPU 功率 8.7 W，机器当时**不是**空闲的（M 系列空闲 CPU 封装
应在几百 mW），测量期间有重负载在跑。这污染 CPU 差值（+732 mW 只有 1.5 个标准差），
**不污染 GPU 差值** —— GPU 基线 16 mW 干净得很。着色器的大头本来就在 GPU，结论稳。

原始数据在 scratchpad，解析脚本的坑：CPU 那条正则不要带 `^`（或者带上 `re.M`），
否则全解析成空、`statistics.mean` 直接报错。

## SIGUSR2 热重载 —— macOS 上已实测（2026-09-10）

```bash
kill -USR2 <pid>
```

**官方发布说明只把这条列在 GTK（Linux）下，但 macOS 同样支持。**
线索是二进制里 `reloading configuration in response to SIGUSR2` 夹在
`Error requesting badge authorization: %@` 和 `application will restore window state`
这两个 AppKit 专属字符串中间。

### 怎么安全地测

风险：**SIGUSR2 若不被处理，默认行为是终止进程**。而 macOS 上 Ghostty 单进程，
所有窗口共用一个 pid —— 「开个新窗口试」隔离不了任何东西，信号一发全部一起没。

```bash
ps -Axo pid,comm | grep '/Ghostty.app/'   # 记下原 pid
open -n -a Ghostty                        # -n 强制新实例
ps -Axo pid,comm | grep '/Ghostty.app/'   # ★ 必须看到两个不同 pid，否则立刻放弃
kill -USR2 <新 pid>                       # 只打新的
```

**存活 ≠ 重载成功。** 日志抓不到（`log show --predicate 'process CONTAINS "ghostty"'`
返回 0 条），所以做功能验证：把测试实例的 `background-opacity` 改成 1.0 再发信号，
**测试窗口变不透明而原有窗口仍半透明** —— 这才叫确认。

### `custom-shader` 也能热切换（2026-09-11）

这条**不是自动成立的**：`background-opacity` 是渲染器每帧读的值，
而着色器要重建 GLSL 管线，完全可能只在 surface 创建时做一次。
实测证伪了这个担心 —— 同一实例反复开关，CPU 在 0.81% 和 8.18% 之间干净来回跳。

**CPU 数字本身就是激活的证据。** 别靠肉眼找拖尾：`cursor_tail` 只在光标移动时才画得出来，
空闲窗口就算着色器活着也看不见东西，**肉眼验证会得出假阴性**。

### 快捷键必须来自 Ghostty 之外

`ghostty +list-actions` 共 **85 个动作，没有一个能执行外部命令**
（`toggle_command_palette` 是 Ghostty 自己的面板，不是 shell）。
所以「按一下键切换着色器」这件事 Ghostty 内部做不到，得靠 Raycast 脚本命令、
macOS 快捷指令或 skhd 这类外部工具触发。

### 手动开关已建（2026-09-12）

**没有常驻进程。** 三样东西：

| | 位置 |
|---|---|
| 开关分片（空 = 关） | `~/.config/ghostty/shader.conf` |
| 主配置里的一行 | `config-file = ?shader.conf` |
| 开关脚本 | `~/.config/ghostty/toggle-shader.sh` |

脚本改分片再对所有 Ghostty 进程发 `SIGUSR2`，顺带在电池供电时打一行提示。
文件头带 Raycast 脚本命令的元数据（对 bash 只是注释），所以同一个文件既能直接跑、
也能被 Raycast 当命令用。

分片路径**相对配置目录**解析 —— 验证方法是往分片里塞个非法键，
`+validate-config` 会报 `unknown field`，报错就说明读到了。

> **这三样都还不在仓库里**（`tools/ghostty/` 是空的）。收不收等配置整体收编时一起定。

### 电源联动：四个环节全通，但没接起来

| 环节 | 手段 | 验证状态 |
|---|---|---|
| 查电源 | `pmset -g batt` | ✓ |
| 分片配置 | `config-file = ?power-current.conf` | ✓ include 会跟进（分片里放非法值主配置校验会报），`?` 缺文件时安静忽略 |
| 改文件 | 脚本 | — |
| 触发重载 | `kill -USR2` | ✓ 含着色器热切换 |

> **未实施。** 2026-09-10 的理由是「没有证据表明有电可省」，
> 那个理由 2026-09-11 已经不成立了（10× CPU），2026-09-12 又补了 GPU：+350 mW，合计 +1.08 W。
> 现在只是还没动手，不是不该做。**先用手动开关一段时间再决定。**

## `window-colorspace` 是「怎么解读色值」，不是「输出更宽色域」

官方原文：*The color space to use when **interpreting** terminal colors.*

| | 同一个 `#RRGGBB` |
|---|---|
| `srgb`（默认） | 按 sRGB 解读 —— 主题作者设计的那个颜色 |
| `display-p3` | 按 P3 解读 —— 同样数值落在更宽色域上，**明显更饱和** |

Catppuccin 和几乎所有终端主题都按 sRGB 画，用 P3 解读会比作者设计的更艳。
**是口味，不是修正**，严格说反而更不忠实。默认别动。

（2026-09-09 曾一度写成「默认 srgb 等于自我限制」，那是误读，已订正。）

## 光标拖尾 —— 已装 `cursor_tail.glsl`，手动开关（2026-09-12）

**现状**：着色器装在 `~/.config/ghostty/shaders/cursor_tail.glsl`，靠开关分片启用，
Raycast 快捷键切换。功耗数字见上面。Neovim 那条线（`smear-cursor.nvim`）**仍然开着**，
装了 Neovim 之后可以在编辑器内用更省电的方式拿到同样效果，两者不互斥。

### 和 kitty 参数对齐 —— 只有一个能对，且有一个对不上

| kitty | 着色器 | 结论 |
|---|---|---|
| `cursor_trail_start_threshold 2`（格） | `THRESHOLD_MIN_DISTANCE`（光标宽 = 格） | **同单位，已对齐** 1.5 → 2.0 |
| `cursor_trail_decay 0.1 0.4`（秒） | `DURATION 0.09`（秒） | **刻意不对齐**，见下 |
| `cursor_trail 20`（静止 ≥20ms 后的跳转才画） | 无 | **做不到** —— 着色器只拿到 `iTimeCursorChange`，没有「之前静止了多久」 |
| — | `MAX_TRAIL_LENGTH 0.2`（大跳只画尾） | kitty 无对应，保持 |

**为什么 DURATION 不能跟 kitty 走 0.4 秒**：kitty 那条 `cursor_trail 20` 的用途
（kitty.conf 注释原话）是滤掉 Claude Code 这类 TUI 频繁重绘造成的满屏拖尾。
着色器没有这道门，**压制 TUI 噪声的唯一手段就是短 DURATION** —— 90ms 一闪即灭。
拉到 0.4 秒，TUI 里会满屏尾巴。**嫌吵调高阈值（3–4 格），别碰 DURATION。**

### 当初的查证（保留）

kitty 有内建的 `cursor_trail`，Ghostty 没有对应配置项（1.3.1 的 `cursor-*` 只有 6 个选项）。

**官方在做内建版，但没有时间表。** 1.2.0 发布说明原文：

> *"We do eventually plan to add a first-party animated cursor, so that users
> don't need to take on the additional performance cost of a custom shader
> just to have a cursor that's easier to follow as it moves"*

那句「额外性能开销」现在有数字了 —— 10× CPU（见上面的功耗一节），所以不是客套话。
但 "eventually" 就是 "eventually"，**这条线程维持搁置**。

> **这里错过两次，记下来省得重犯。** 先写成「官方没有可等的东西」——
> 依据是 issue `#1934` 已关闭、维护者说「已在 `#7648` 实现」。
> **只查了 issue 和 discussion，没读发布说明。**
> 教训：**issue 的关闭状态不等于路线图。**

**两条可行路线：**

| | Ghostty `custom-shader` | `sphamba/smear-cursor.nvim` |
|---|---|---|
| 原理 | GPU 后处理，Shadertoy 兼容，光标位置由 uniform 传入 | 纯 Lua + 块状 Unicode 字符，不用 GPU |
| 作用域 | 任何地方（shell / REPL / TUI 输入行） | 只在 Neovim 内 |
| 空闲开销 | **常驻** —— Ghostty 无法内省 GLSL 有无动画，聚焦窗口每帧重绘（实测 +7.3 个点 CPU）；未聚焦的窗口 macOS 会挂起渲染，不计费 | **零** —— 定时器在距离与速度低于阈值后 `stop_animation()` |
| 失效场景 | 隐藏硬件光标、自绘假光标的程序（官方点名 Helix） | 拖尾周围有文字阴影（Neovim 无法叠加字符，作者称固有限制） |
| 要求 | Ghostty ≥ 1.2 | Neovim ≥ 0.10.2 |

**功耗差距的真正来源是空闲时段**，不是动画时段：着色器在聚焦窗口上每帧重绘，
把 ProMotion 钉在高刷新率、阻止显示链路降频 —— 光标不动也一样付费。社区反馈集中在「电池掉得快」而非「卡」——
见 ghostty #10678（95% GPU 占用）、#11928（渲染器跑满帧率且不看电源状态）。

**两者不是替代关系**：插件是「在 Neovim 里更省电地拿到」，着色器是「哪里都有但一直付费」。

**搁置原因**：本机没装 Neovim（`nvim` / `~/.config/nvim` / 插件目录均不存在），
插件路线不可执行。装了 Neovim 之后再决定。

若届时决定只走着色器：选 `sahaj-b/ghostty-cursor-shaders` 的 `cursor_tail.glsl`
（MIT，明确对标 kitty 的彗星尾，`DURATION 0.09`）。同仓库的 `cursor_warp`
是 Neovide 那种四角独立形变的果冻感，`cursor_sweep` 是从旧位置收缩过去 ——
三者的区别看源码几何比看 README 清楚。

## 平台差异

| 配置项 | linux (kitty) | macos (ghostty) | 能否合并 | 判断日期 |
|---|---|---|---|---|
| 终端本身 | kitty | Ghostty | ❌ 不同软件，各自配置 | 2026-08-23 |
| 光标拖尾 | `cursor_trail 20` 内建 | `cursor_tail.glsl` + 手动开关 | ❌ 机制不同，阈值已对齐、时长刻意不对齐，见上 | 2026-09-12 |
| 背景图开关 | `toggle-bg.sh` + `listen_on` 远程控制 | ❌ Ghostty 无远程控制协议，做不到运行时切换 | ❌ 不可移植 | 2026-08-24 |
| 分屏布局 | `enabled_layouts splits/stack/tall/grid` | ❌ 只有手动分屏，无布局引擎 | ❌ 不可移植 | 2026-08-24 |
| 标签栏样式 | `tab_bar_style fade` + 模板 | ❌ macOS 原生标签页，无 powerline 样式 | ❌ 不可移植 | 2026-08-24 |
