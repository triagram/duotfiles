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

## 省电：查了一圈，没有可信证据（2026-09-10）

**结论：什么都没改。** 试过 `cursor-style-blink = false` + `shell-integration-features = no-cursor`，
实测之后回退了。

### 为什么回退

`ghostty-org/ghostty#10397` 说 ProMotion 上光标闪烁让 idle CPU 从 ~1.5% 涨到 10–15%。
本机实测（pid 685，20 次采样取收敛值）：

| | 中位 |
|---|---|
| 闪烁开 | 2.65% |
| 闪烁关 | 2.30% |

差 0.35 个百分点，在噪声里。**而且这个测法本身不合格** —— `top` 的 `%CPU` 只算进程 CPU，
抓不到 GPU，更抓不到「ProMotion 被钉在高刷新率」的显示链路能耗，而那才是关键。
**我在用错误的仪器测这个问题。**

### 社区也没有数字

`#5063`（12 小时功耗比 alacritty/kitty 高 2–3 倍）**没有任何具体数值**，无瓦特无方法论。
维护者 Mitchell 的回应：*"This is very, very hard to measure. I have doubts."* ——
并指出测量必然把终端里跑的程序算进去，必须 "exact same shell-only zero input setup"。
讨论至今标 `needs-confirmation`，未解决。`#10397` 同样是用户自报、无方法论。

**他给的官方基准值反而最有用**：

> "Ghostty idles at **0% unfocused and 1 to 4% focused** depending on config."

本机测到 1.7–2.9%，**正落在这个区间**。所以这台机器表现完全正常，没有异常耗电可省。

### 真要测只有一条路

```bash
sudo powermetrics --samplers cpu_power,gpu_power -i 1000 -n 20
```
瓦特级，需要 sudo。做对照要：拔电源、Ghostty 聚焦、零输入，两组配置各跑一轮。
**没做过。哪天真觉得费电了再说，别凭 issue 里的传闻改配置。**

### 关于 `cursor-style-blink` 的一个事实（留着，将来有用）

`cursor-style-blink = false` **挡不住程序强制闪烁**。官方文档：设成非 null 值只让
DEC mode 12 被忽略，**`DECSCUSR`（`CSI q`）仍然生效**。Ghostty 自带 shell 集成的
`cursor` 特性（"Set the cursor to a bar at the prompt"）就在发它，要一并关需要
`shell-integration-features = no-cursor`。但 zsh 主题和 TUI 自己发的序列仍然管不住。

## 着色器的 CPU 开销：十倍，已实测（2026-09-11）

和闪烁那次不一样 —— **这次效应是真的，而且大得不用统计检验**。

空闲测试窗口，聚焦，光标不闪，零输入：

| | 均值 | 标准差 | n |
|---|---|---|---|
| A 无着色器 | 0.81% | 0.07 | 12 |
| B `cursor_tail` | **8.18%** | 0.48 | 12 |
| A′ 关回去 | 0.96% | 0.10 | 12 |

**A′ 是重点**：关掉就回到基线，所以这不是漂移、不是后台任务撞车，
就是着色器本身。差值约 7.3 个百分点，是组内标准差的十几倍。
对比闪烁那次的 0.35 个百分点、标准差同量级 —— 那是噪声，这不是。

注意基线 0.81% 落在官方说的 "1 to 4% focused" 下沿（因为这个测试窗口什么都没跑），
而开着色器后的 8.18% **远在官方区间之外**。

### 测法（可复现，且这次是合格的）

1. **必须隔离实例**。macOS 上 Ghostty 单进程，多开窗口隔离不了任何东西：
   ```bash
   open -n -a Ghostty --args --config-default-files=false --config-file=<独立配置>
   ```
   `config-default-files` **只能从命令行设**，配置文件里写没用（官方文档原话）。
   然后确认拿到两个不同 pid，再只对新 pid 发信号 —— 中止条件，不满足就别测。

2. **必须聚焦**。`custom-shader-animation = true` 只驱动**聚焦**那个 surface 的动画循环；
   窗口不在前台，macOS 直接把渲染挂起，两组都测出 0.0%，什么也看不出来。
   上一次测量就是卡在这里。

3. **焦点要用机器验证，不要靠自己以为**：
   ```bash
   osascript -e 'tell application "System Events" to tell (first process whose frontmost is true) to get name of front window'
   ```
   配合独立配置里的 `title = SHADER-TEST`，采样前后各查一次。
   这条同时**验证了隔离配置确实被读进去了** —— 标题变了就是读到了。

4. `top -pid X -l N -s 1` 的**第一帧是生命周期均值，必须丢掉**，
   后续帧才是区间值。上次的错误之一就在这。

### 踩到的坑

- **`+show-config` 不接受任何附加参数**。加了 `--config-file` 或 `--font-size`
  就静默输出空、不报错。所以没法用它预先验证隔离配置，只能发射后用标题验。
- **`pgrep -x ghostty` 找不到进程**，因为 comm 是全路径。用 `ps -Axo pid,comm | grep '/Ghostty.app/'`。
- `screencapture` 在这个环境里报 "could not create image from display"（没有屏幕录制权限），
  想靠截图看拖尾这条路走不通。

### 还没测到的：GPU

**上面全是 CPU，全屏片段着色器的大头在 GPU，那部分仍然没有数字。**
要瓦特得 `sudo powermetrics --samplers cpu_power,gpu_power`，需要密码。
脚本已经写好（A/B 交错三轮、原始输出分组落盘、跑之前自检焦点），
但**还没跑过**。所以现在能说的是：**CPU 开销确凿且十倍，总功耗的绝对值未知**。

电池 `DesignCapacity` 6249 mAh @ ~12.8 V ≈ **80 Wh**，拿到瓦特数就能换算成续航分钟。

### 这对「插电开 / 断电关」的意义

十倍 CPU 已经足够支撑那套逻辑了 —— 不需要等 GPU 数字。
机制侧也齐了：SIGUSR2 能**热切换着色器**（本次顺带验证，见下一节），
所以切换不用重开窗口、不影响正在跑的会话。

## SIGUSR2 能重载配置 —— macOS 上已实测（2026-09-10）

```bash
kill -USR2 $(pgrep -x ghostty)
```

**官方发布说明把这条只列在 GTK（Linux）下，但 macOS 同样支持**，已实测确认。
线索是 macOS 二进制里那个字符串夹在 AppKit 专属字符串中间：

```
Error requesting badge authorization: %@       ← Objective-C 格式符
reloading configuration in response to SIGUSR2
application will restore window state          ← NSApplication 生命周期
```

### 怎么安全地测（这个方法本身值得记）

风险在于：**若不被处理，SIGUSR2 的默认行为是终止进程**。而 macOS 上 Ghostty 是
**单进程** —— 所有窗口共用一个 pid，所以「开个新窗口试」没有任何隔离作用，
信号一发全部窗口一起没。

隔离办法是开**第二个独立实例**：

```bash
pgrep -x ghostty                    # 记下原 pid
open -n -a Ghostty                  # -n 强制新实例（Info.plist 无 LSMultipleInstancesProhibited）
pgrep -x ghostty                    # ★ 安全阀：必须看到两个不同 pid，否则立刻放弃
kill -USR2 <新 pid>                 # 只打新的
```

**判定**：进程存活 = 被处理；进程消失 = 不支持（且只损失测试窗口）。

存活还不等于真的重载了。系统日志抓不到（Ghostty 默认日志级别不输出，
`log show --predicate 'process CONTAINS "ghostty"'` 返回 0 条），所以做了功能验证：
临时把 `background-opacity` 改成 1.0、只对测试实例发信号，
**测试窗口变成完全不透明而原有窗口仍半透明** —— 重载确认。

**2026-09-11 补：`custom-shader` 也能热切换。** 这条不是自动成立的 ——
`background-opacity` 是渲染器每帧读的值，而着色器要重建 GLSL 管线，
完全可能只在 surface 创建时做一次。实测证伪了这个担心：对同一个实例
反复 加着色器→USR2→测 / 去着色器→USR2→测，CPU 在 0.81% 和 8.18% 之间
干净地来回跳（见上一节）。**CPU 数字本身就是激活的证据**，
不需要靠肉眼找拖尾 —— 何况 `cursor_tail` 只在光标移动时才画得出来，
空闲窗口就算着色器活着也看不见东西，用肉眼验证反而会得出假阴性。

### 这解锁了什么

电源联动（插电开特效／电池关特效）四个环节现在全通：

| 环节 | 手段 |
|---|---|
| 查电源 | `pmset -g batt` |
| 分片配置 | `config-file = ?power-current.conf` |
| 改文件 | 脚本 |
| 触发重载 | `kill -USR2` |

分片机制也实测过：`config-file` 会跟进 include（在分片里放非法值，主配置校验会报出来），
`?` 前缀缺文件时安静忽略。

> **2026-09-10 时的判断：未实施，因为没有证据表明有电可省。**
>
> **2026-09-11 更新：证据有了一半，理由不再成立。** 着色器实测 10× CPU
> （0.81% → 8.18%），效应大到不需要 powermetrics 就能支撑「插电开 / 断电关」。
> 剩下的只是 GPU 那部分的绝对瓦特数还没测，那影响的是「省了多少」，
> 不影响「该不该做」。要建的时候上面四个环节全是通的。

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

kitty 有内建的 `cursor_trail`，Ghostty 没有对应配置项。查证过的结论，不用重查：

> **订正（2026-09-10）：上面这段的结论是错的，保留原文见下。**
> 官方 1.2.0 发布说明原文写着：*"We do eventually plan to add a first-party
> animated cursor, so that users don't need to take on the additional
> performance cost of a custom shader just to have a cursor that's easier to
> follow as it moves"* —— **官方明确计划做内建动画光标，理由正是省掉着色器开销。**
> 只是 "eventually"，没有时间表。
>
> 当初错在哪：只查了 issue 和 discussion，看到 #1934 已关闭、维护者说
> 「已在 #7648 实现」，就推断官方认为着色器是终点。**没去读发布说明。**
> 教训是 issue 的关闭状态不等于路线图。
>
> **2026-09-11：官方那句「额外性能开销」现在有数字了 —— 10× CPU
> （0.81% → 8.18%，见上面的着色器测量）。所以他们说的不是客套话。
> 但仍然只是 "eventually"，等不等是另一回事。这条线程维持搁置状态。**

~~**Ghostty 内建版没有可等的东西。** 追踪 issue `ghostty-org/ghostty#1934`（2024-07 开）
**已关闭**，无 assignee 无 milestone；discussion #4199 维护者最后一句是
「已在 #7648 实现」—— 指的就是着色器方案。~~
（事实部分仍然成立：本机 Ghostty 1.3.1 的 `cursor-*` 只有 6 个选项，没有 trail。）

**两条可行路线：**

| | Ghostty `custom-shader` | `sphamba/smear-cursor.nvim` |
|---|---|---|
| 原理 | GPU 后处理，Shadertoy 兼容，光标位置由 uniform 传入 | 纯 Lua + 块状 Unicode 字符，不用 GPU |
| 作用域 | 任何地方（shell / REPL / TUI 输入行） | 只在 Neovim 内 |
| 空闲开销 | **常驻** —— Ghostty 无法内省 GLSL 有无动画，一律按 vsync 每帧重绘 | **零** —— 定时器在距离与速度低于阈值后 `stop_animation()` |
| 失效场景 | 隐藏硬件光标、自绘假光标的程序（官方点名 Helix） | 拖尾周围有文字阴影（Neovim 无法叠加字符，作者称固有限制） |
| 要求 | Ghostty ≥ 1.2 | Neovim ≥ 0.10.2 |

**功耗差距的真正来源是空闲时段**，不是动画时段：着色器每帧重绘会把 ProMotion
钉死在 120Hz，阻止显示链路降频。社区反馈集中在「电池掉得快」而非「卡」——
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
