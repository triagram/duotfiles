# ghostty

macOS 侧的终端（Linux 侧对应 kitty，见 `notes/kitty.md`）。

> **配置目前不在仓库里。** manifest 有 `ghostty` 这一行，但 `tools/ghostty/` 是空的，
> 配置还躺在 `~/.config/ghostty/config`。要收进来跑 `dof adopt ghostty`。

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
| GPU 那一半 | **仍未知** | 需要 `sudo powermetrics`，没跑过 |

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

### GPU 那一半

全屏片段着色器的大头在 GPU，那部分**没有数字**。要瓦特得
`sudo powermetrics --samplers cpu_power,gpu_power`。
电池 `DesignCapacity` 6249 mAh @ ~12.8 V ≈ **80 Wh**，有了瓦特就能换算成续航分钟。

不过这个缺口**不影响决策**：10× CPU 已经足够支撑「插电开 / 断电关」，
GPU 数字只决定「省了多少」，不决定「该不该做」。

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

### 电源联动：四个环节全通，但没接起来

| 环节 | 手段 | 验证状态 |
|---|---|---|
| 查电源 | `pmset -g batt` | ✓ |
| 分片配置 | `config-file = ?power-current.conf` | ✓ include 会跟进（分片里放非法值主配置校验会报），`?` 缺文件时安静忽略 |
| 改文件 | 脚本 | — |
| 触发重载 | `kill -USR2` | ✓ 含着色器热切换 |

> **未实施。** 2026-09-10 的理由是「没有证据表明有电可省」，
> 那个理由 2026-09-11 已经不成立了（见上面的 10× CPU）。
> 现在只是还没动手，不是不该做。

## `window-colorspace` 是「怎么解读色值」，不是「输出更宽色域」

官方原文：*The color space to use when **interpreting** terminal colors.*

| | 同一个 `#RRGGBB` |
|---|---|
| `srgb`（默认） | 按 sRGB 解读 —— 主题作者设计的那个颜色 |
| `display-p3` | 按 P3 解读 —— 同样数值落在更宽色域上，**明显更饱和** |

Catppuccin 和几乎所有终端主题都按 sRGB 画，用 P3 解读会比作者设计的更艳。
**是口味，不是修正**，严格说反而更不忠实。默认别动。

（2026-09-09 曾一度写成「默认 srgb 等于自我限制」，那是误读，已订正。）

## 〔搁置〕光标拖尾 —— 等装了 Neovim 再议（2026-08-24）

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
| 光标拖尾 | `cursor_trail 20` 内建 | 无内建，需着色器或 Neovim 插件 | ❌ 搁置中，见上 | 2026-08-24 |
| 背景图开关 | `toggle-bg.sh` + `listen_on` 远程控制 | ❌ Ghostty 无远程控制协议，做不到运行时切换 | ❌ 不可移植 | 2026-08-24 |
| 分屏布局 | `enabled_layouts splits/stack/tall/grid` | ❌ 只有手动分屏，无布局引擎 | ❌ 不可移植 | 2026-08-24 |
| 标签栏样式 | `tab_bar_style fade` + 模板 | ❌ macOS 原生标签页，无 powerline 样式 | ❌ 不可移植 | 2026-08-24 |
