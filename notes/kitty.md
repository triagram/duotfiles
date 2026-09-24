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
| `icons/` + `kitty.app.png` | 同为图片素材。且 `switch-icon.py` 会 `shutil.copy` 覆写 `kitty.app.png` —— link 模式下等于每次换图标都往仓库塞一个 128 KB 二进制 |
| 四个主题文件 | 见下，单独一节 |
| `kitty.conf.bak` | 纳入版本控制之前的手工备份。内建的 `*.dof-bak-*` 匹配不到 `.bak` |

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
`UNLINKED` —— 这是反复发生的，不收就没有这个问题。

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

> **所以现在在 Mac 上跑 `dof pull kitty` 是个空操作** —— `resolve_sources` 只走
> `common/` 和 `<platform>/`，两边都只有 `.gitkeep`（还会被 `BUILTIN_IGNORE` 滤掉），
> 结果是「0 file(s) updated」，不报错也不部署任何东西。Mac 上要先
> `dof adopt kitty` 把本机配置收进来，才有东西可比对、可部署。

| 配置项 | linux | macos | 能否合并 | 判断日期 |
|---|---|---|---|---|
| （等 macOS 侧 `dof adopt kitty` 之后再填） | | | | |

届时用 kitty 自带的 `include ${KITTY_OS}.conf` 表达平台差异（`KITTY_OS` 是 kitty 内置变量），
不引入模板引擎 —— 见 `AGENTS.md`。**在能真正比对之前，不要往 `common/` 搬东西。**

## custom shader（2026-09-24 判断）

kitty 0.49.0 起支持 `custom_shaders`（GPU 滤镜）。本机当天从 0.42.2 升到 0.49.1。

**选了什么**：只开 `dim-inactive-windows`（非当前分屏压暗）。光标拖尾保留内建样式，
不换 `cursor-trail-blaze` / `cursor-trail-lightning`；动态背景、鼠标效果、复古屏幕暂不开。
用户的原话是「先应用 dim，有问题再调」。

**已经查清、不要重推的几点**：

- **dim 不省电。** 本机是液晶屏，背光恒定，画面暗不省电。它不增加重绘次数，
  但每次重绘多一道全屏处理。`background_opacity 0.95` 本来就让 kitty 走分层绘制，
  所以额外开销只剩那一道。
- **`dim-inactive-windows` 和 `focus-highlight` 是同一个 `focus-highlight.slang`**，
  只是 pipeline 不同：前者常驻、静态（`animation_step 0`）；后者只在切分屏 / 切 tab 后
  跑 0.75 秒，平时零开销。
- **`crt` / `crt-blue` / `tft` / `water` 会一直每 50 ms 重绘**，不看焦点也不看空闲 ——
  它们没有带停止条件的 pipeline。要用就自写 `animation_step 0` 的 pipeline
  （crt、tft 的画面本来就不随时间变）。
- 换成拖尾滤镜后 `cursor_trail_color` 不生效，颜色和时长由滤镜自己的 `var` 参数决定。
- 与 Ghostty 的功耗差别在机制：Ghostty 聚焦时固定 8 ms 一帧、不检测空闲
  （实测见 `notes/ghostty.md`）；kitty 默认 50 ms 一帧，空闲超过 `cursor_stop_blinking_after`
  （15 秒）或失焦就停。**kitty 侧还没实测功耗。**

**实测副作用**（测试窗口截图取样）：dim 连 tab 栏（`17,17,27 → 5,5,11`）和当前分屏四周的
留白（`30,30,46 → 13,13,22`）也一起压暗，当前分屏像多了一圈暗框。要排除这两处，
写 `~/.config/kitty/shaders/<名字>.pipeline`，再把 `custom_shaders` 改成那个名字（**未实测**，
参数取自官方文档的 dim-gray 例子）：

```
startgroup
    animation_step 0
    var float HIGHLIGHT_INTENSITY = 0
    var float BORDER_WIDTH = 0
    var bool DIM_CENTRAL_AREA_ONLY = true
    var bool INCLUDE_WINDOW_PADDING = true
    shaders focus-highlight
endgroup
```

`shaders/` 目录不在 `.dofignore` 里，建了会被 dof 看到，届时决定收不收。

**关掉只能删掉那一行。** `custom_shaders` 写成空值（包括 `-o custom_shaders=`）会被当作
无效行忽略（日志 `Ignoring invalid config line`），滤镜照样从 kitty.conf 加载。

**验证方法**（下次调参沿用）：
`kitty --debug-rendering --class ShaderTest --session <两分屏、两 tab 的 session 文件>`，
日志里看 `Custom shaders: N program(s)` 和 `has_active_shaders: 0 -> 1`；
对照组用去掉那一行的配置副本 `--config` 启动。截图用系统 Python（`/usr/bin/python3`，
pyenv 那个没有 `gi`）的 GdkX11 按窗口 XID 截，再取像素比较。
