# kitty 配置说明

这份配置**不是自包含的**。它依赖若干本目录之外的文件，本目录内部也有一部分
刻意不纳入 `~/.duotfiles` 同步。新机器上 `dof pull kitty` 之后，会得到一个
**配色回到默认、图标空白、没有背景图、字体回退**的 kitty。
下面列出需要手工补齐的部分，以及几个改配置时容易踩的坑。

进仓库的只有 5 个手写文件：`kitty.conf`、`theme-overrides.conf`、
`toggle-bg.sh`、`switch-icon.py` 和本文件。其余都是可重建的上游内容或
图片素材，排除规则和理由写在 `~/.duotfiles/tools/kitty/.dofignore` 里。

---

## 一、新机器上需要手工补齐的东西

按依赖顺序排列。

### 1. kitty 本体

官方二进制包装到 `~/.local/kitty.app`，并把 `kitty` / `kitten` 链接进 PATH：

```sh
curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
ln -sf ~/.local/kitty.app/bin/kitty ~/.local/kitty.app/bin/kitten ~/.local/bin/
```

### 2. 字体：JetBrainsMono Nerd Font

`kitty.conf` 的 `font_family` 指名要它。缺了会静默回退到别的等宽字体，
标签栏和 powerline 类字形会变成豆腐块。

本机装在 `~/.local/share/fonts/JetBrainsMono/`，装完记得 `fc-cache -f`。

### 3. 桌面入口 `~/.local/share/applications/kitty.desktop`

二进制包把所有东西装在 `~/.local/kitty.app`，而**这个路径不在
`XDG_DATA_DIRS` 里**，所以系统读不到包内自带的 desktop 文件和图标 ——
必须自己在 `~/.local/share/applications/` 放一份。关键内容：

```ini
[Desktop Entry]
Type=Application
Name=kitty
Exec=kitty
Icon=kitty
Categories=System;TerminalEmulator;
StartupWMClass=kitty
```

- `Icon=kitty` 是**图标主题名**，不是路径。保持这样，见下一条。
- `StartupWMClass=kitty` **不能少**。GNOME 靠它把运行中的窗口匹配到这个
  desktop 文件；缺了它，开着的窗口在 Dock 上会掉成通用图标。
  （kitty 官方自带的 desktop 文件里反而没有这一行。）

### 4. 图标：装进 hicolor 主题

GNOME Shell 把窗口匹配到 desktop 文件之后，**只用 desktop 文件里的
`Icon=`，完全忽略窗口自身的 `_NET_WM_ICON`**。所以本目录的
`kitty.app.png`（窗口图标）不足以让 Dock 显示正确图标，必须另外装：

```sh
~/.config/kitty/switch-icon.py nyan     # 从 icons/ 里选一个装进 hicolor
```

脚本会生成 16~512 共 8 个尺寸写进
`~/.local/share/icons/hicolor/<size>/apps/kitty.png` 并刷新缓存。
装完按 `Alt+F2` → 输入 `r` → 回车重启 GNOME Shell（X11 下安全，窗口不会丢）。

> 顺带一提：kitty 启动时会警告 `kitty.app.png` 对 X11 窗口图标而言过大
> （1024x1024，X11 上限 128x128）。这不影响 Dock 图标，可以忽略。

### 5. 主题文件：**不在仓库里**，用主题名重建

四个主题文件都**不纳入同步**。它们是上游 Catppuccin（MIT）的原样输出，
本地改动只有追加在末尾的两行（见坑 1、坑 2）—— 收进仓库等于把同一份
第三方配色存四遍（`current-theme.conf` 与 `dark-theme.auto.conf`
逐字节相同），只为一行真正属于自己的东西。

不收还顺带消掉了一个反复出现的麻烦：`kitten themes` 重跑时写的是真文件，
如果原文件是指向仓库的软链，软链会被替换掉。

| 文件 | 主题名 |
|---|---|
| `current-theme.conf` | `Catppuccin-Mocha` |
| `dark-theme.auto.conf` | `Catppuccin-Mocha` |
| `light-theme.auto.conf` | `Catppuccin-Frappe` |
| `no-preference-theme.auto.conf` | `Catppuccin-Frappe` |

重建（`--dump-theme` 把主题原样打到 stdout，不碰 `kitty.conf`）：

```sh
cd ~/.config/kitty
kitten themes --dump-theme Catppuccin-Mocha  > current-theme.conf
kitten themes --dump-theme Catppuccin-Mocha  > dark-theme.auto.conf
kitten themes --dump-theme Catppuccin-Frappe > light-theme.auto.conf
kitten themes --dump-theme Catppuccin-Frappe > no-preference-theme.auto.conf

# 四个文件都要把 include 追加回去，否则背景图和标签栏颜色不生效（坑 1、坑 2）
for f in current-theme.conf *-theme.auto.conf; do
  printf '\n# 背景圖與標籤欄顏色（見 theme-overrides.conf 開頭的說明）\ninclude theme-overrides.conf\n' >> "$f"
done
```

注意主题名里的 Frappe **不带重音符**（`Catppuccin-Frappe`，不是 `Frappé`）。

### 6. 背景图：**不在仓库里**

`backgrounds/` 目录下的图片体积约 7M，刻意不纳入同步。
`theme-overrides.conf` 里的 `background_image` 指向 `backgrounds/` 下的文件，
图不在就是没有背景（kitty 不会报错）。

要恢复：把图放进 `backgrounds/`，然后确认 `theme-overrides.conf`
里的文件名对得上。

**必须是 PNG。** kitty 只捆绑了 `libpng`，JPEG/WEBP 等格式要靠外部
ImageMagick 解码；没装 ImageMagick 的机器上，非 PNG 的背景图会
**静默不显示、且不报任何错**。转换：

```sh
python3 -c "
import gi; gi.require_version('GdkPixbuf','2.0')
from gi.repository import GdkPixbuf
GdkPixbuf.Pixbuf.new_from_file('in.jpg').savev('out.png','png',[],[])
"
```

### 7. 日夜主题切换所依赖的外部定时器

`*-theme.auto.conf` 只负责「系统说现在是深色/浅色，就用哪套配色」，
**它不会自己按时间切换**。GNOME 也没有内建的定时深浅色功能
（Night Light 调的是色温，不动 `color-scheme`）。

实际驱动它的是 `~/.local/bin/auto-dark-mode` 配合
`~/.config/systemd/user/auto-dark-mode.{service,timer}`：按日出日落算出
应该是什么，写进 GNOME 的 `color-scheme`，再由 xdg-desktop-portal
广播给 kitty 和 fcitx5。

**这三个文件目前也没有纳入同步。** 缺了它们，kitty 的配色只会在你手动
改 GNOME 深浅色时才变。

### 8. Claude Code 的通知设置

`~/.claude/settings.json` 里的 `"preferredNotifChannel": "terminal_bell"`。

Claude Code 默认**只在 Ghostty / kitty / iTerm2 里发桌面通知**（因为只有
这几个终端支持转发），每次需要你决策时都会弹窗。这行把它改成响铃。

`~/.duotfiles` 明确不同步 `~/.claude`，换机器要手工加回。

---

## 二、改配置时的坑

### 坑 1：`.auto.conf` 会覆盖背景图和标签栏颜色

启用自动深浅色主题之后，`background_image` / `background_image_layout` /
`background_tint` 和 `active_tab_*` / `inactive_tab_*` / `tab_bar_background`
这些设置，**写在 `kitty.conf` 里不生效** —— 会被主题文件覆盖。

kitty 文档写明：主题文件里的颜色**连命令行 `--override` 都压得住**。

这就是 `theme-overrides.conf` 存在的原因。它由四个主题文件各自 include：

```
kitty.conf
  └─ include current-theme.conf ─┐
                                  ├─→ include theme-overrides.conf
  dark / light / no-preference   ─┘
       -theme.auto.conf
```

**以后凡是「改了没反应」的颜色/背景类设置，都往 `theme-overrides.conf` 里放。**

### 坑 2：重跑 theme kitten 会打断上面那条链

`kitten themes` 换配色时会**重新生成** `*-theme.auto.conf`，
里面的 `include theme-overrides.conf` 那一行会被抹掉，
于是背景图和标签栏颜色一起失效。

换完主题后检查一遍：

```sh
grep -L "include theme-overrides.conf" ~/.config/kitty/*-theme*.conf
```

有输出就说明那些文件需要把 include 加回去。

### 坑 3：GNOME 的浅色模式上报的是 `no-preference`

GNOME 在「深色样式」未启用时，通过 portal 上报的是 **`no-preference`
而不是 `light`**。所以 `no-preference-theme.auto.conf` 是必需的 ——
只有 `light-theme.auto.conf` 的话，白天会掉回 `current-theme.conf`。

本机的 `auto-dark-mode` 脚本白天设的正是 `default`（即 no-preference），
所以实际生效的是 `no-preference-theme.auto.conf`；
`light-theme.auto.conf` 反而永远轮不到。

### 坑 4：背景图 toggle 依赖两处设置

`Ctrl+中键` 开关背景、`Ctrl+Shift+中键` 换图，需要：

1. `kitty.conf` 里的 `listen_on unix:@kitty`
2. mouse_map 里的 **`--allow-remote-control`**

第 2 条尤其容易漏：`launch --type=background` 默认**不会**给子进程设置
`KITTY_LISTEN_ON`，只有显式加了 `--allow-remote-control` 才会
（kitty 文档明言）。漏了的话脚本能跑起来，但里面的 `kitty @`
找不到通道，静默失败。

改完 `listen_on` 只对**新开的窗口**生效，老窗口里手势不会有反应。

### 坑 5：`remember_window_size` 会覆盖初始尺寸

`initial_window_width` / `initial_window_height` 只有在
`remember_window_size no` 时才生效。单位默认是**像素**，
加 `c` 后缀才是字符格（`80c` = 80 列）。

代价是**每个**新窗口都固定这个大小，不再沿用上次拖拽的尺寸。

---

## 三、文件一览

「同步」列指是否进 `~/.duotfiles`。

| 文件 | 同步 | 作用 |
|---|---|---|
| `kitty.conf` | ✅ | 主配置。末尾 include 主题链 |
| `theme-overrides.conf` | ✅ | 背景图 + 标签栏颜色。**必须**由主题文件 include，见坑 1 |
| `toggle-bg.sh` | ✅ | 背景图开关 / 轮换，由 mouse_map 调用 |
| `switch-icon.py` | ✅ | 在 `icons/` 里选图标，装进 hicolor 主题 |
| `README.md` | ✅ | 本文件 |
| `current-theme.conf` | ❌ | theme kitten 生成；同时是没有 `.auto.conf` 匹配时的兜底。见上文第 5 条 |
| `dark-theme.auto.conf` | ❌ | 系统深色时生效 |
| `light-theme.auto.conf` | ❌ | 系统明确为 `prefer-light` 时生效（本机实际用不到，见坑 3） |
| `no-preference-theme.auto.conf` | ❌ | 系统未表态时生效 —— **GNOME 浅色模式走的是这个** |
| `kitty.app.png` | ❌ | 当前窗口图标（X11 `_NET_WM_ICON`），与 Dock 图标是两条独立通道。由 `switch-icon.py` 覆写 |
| `icons/` | ❌ | 图标库，供 `switch-icon.py` 选用 |
| `backgrounds/` | ❌ | 背景图。`.png` 是实际使用的，`.jpg` 是重裁用的源图 |
| `kitty.conf.bak` | ❌ | 纳入版本控制之前的手工备份，留着仅作参考 |
