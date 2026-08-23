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
