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

## 〔搁置〕光标拖尾 —— 等装了 Neovim 再议（2026-08-24）

kitty 有内建的 `cursor_trail`，Ghostty 没有对应配置项。查证过的结论，不用重查：

**Ghostty 内建版没有可等的东西。** 追踪 issue `ghostty-org/ghostty#1934`（2024-07 开）
**已关闭**，无 assignee 无 milestone；discussion #4199 维护者最后一句是
「已在 #7648 实现」—— 指的就是着色器方案。本机 Ghostty 1.3.1 的 `cursor-*`
只有 6 个选项，没有 trail。

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
