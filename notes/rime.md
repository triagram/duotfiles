# rime

`copy` 模式。数据分两条通道：**进仓库的配置** 与 **部署时从上游拉的词库数据**。

> **用户词库（`*.userdb/`）及其同步不在本仓库范围内。**
> 词库里有人名、地址、私人用语；同步方式也是机器相关的。
> 相关文件（`*.userdb*`、`sync/`、`rime-sync.sh`、`installation.yaml`）全部在 `.dofignore` 里，
> dof 不碰，也不进 git。这块请在本机自行维护。
>
> 同步的**设计推理**（两层机制的区分、为什么不走网盘、Syncthing `.stversions/` 的陷阱）
> 保留在 `tools/rime/common/devlog.md §7.5` —— 那是判断记录，值得留；
> 但**机制本身**（脚本、主机地址、词库文件）不进本仓库。

## ① 部署时从上游拉（不进仓库，约 92 MB）

这些在 `.dofignore` 里，dof 不管，新机器上**必须先手工拉**。
全部用 git blob SHA 核对过：要么逐字节相同，要么只是版本差，**没有任何个人修改**，
所以直接用上游最新版即可。

| 文件 | 出处 | 大小 | 核对结果 |
|---|---|---|---|
| `cn_dicts/`（7 个） | `github.com/iDvel/rime-ice` | 45 MB | 版本差 |
| `radical_pinyin.dict.yaml` | `github.com/iDvel/rime-ice` | 2.1 MB | — |
| `essay.txt` | `github.com/rime/rime-essay` | 5.6 MB | 版本差 |
| `luna_pinyin.dict.yaml` | `github.com/rime/rime-luna-pinyin` | 891 KB | 版本差 |
| `stroke.dict.yaml` | `github.com/rime/rime-stroke` | 2.1 MB | 版本差 |
| `japanese.{schema,dict,kana.dict,mozc.dict,jmdict.dict}.yaml` | `github.com/gkovacs/rime-japanese` | 36 MB | **逐字节相同** |

日语方案的选型理由见 `tools/rime/common/devlog.md §6.3`（对比过 DreamAfar，选了 star 更多、维护更新的 gkovacs）。

拉取（Rime 用户目录记作 `$R`）：

```bash
R=~/.local/share/fcitx5/rime        # macOS: R=~/Library/Rime
C=~/.cache/rime-upstream; mkdir -p "$C"

git clone --depth 1 https://github.com/iDvel/rime-ice          "$C/rime-ice"
git clone --depth 1 https://github.com/rime/rime-essay         "$C/essay"
git clone --depth 1 https://github.com/rime/rime-luna-pinyin   "$C/luna"
git clone --depth 1 https://github.com/rime/rime-stroke        "$C/stroke"
git clone --depth 1 https://github.com/gkovacs/rime-japanese   "$C/japanese"

cp -r "$C/rime-ice/cn_dicts"                 "$R/"
cp    "$C/rime-ice/radical_pinyin.dict.yaml" "$R/"
cp    "$C/essay/essay.txt"                   "$R/"
cp    "$C/luna/luna_pinyin.dict.yaml"        "$R/"
cp    "$C/stroke/stroke.dict.yaml"           "$R/"
cp    "$C/japanese/japanese."*.yaml          "$R/"
```

**顺序很重要：先铺上游，再 `dof pull rime`**，让你的 `*.custom.yaml` 盖在上面。
Rime 的 patch 机制本来就是这么设计的：上游给 schema，你用 custom 打补丁，从不改上游文件
（`devlog.md` 的「原則二」）。

> 例外：`custom_phrase.txt` 是**你改过的上游文件**（注释掉了 `噷/呣/呒`，加了
> `啊对对对`、`不不不` 和邮箱短语）。它在仓库里，`dof pull` 会覆盖上游那份 —— 这正是要的效果。

## ② 仓库里的 common/ 与 linux/ 怎么分

**`common/`（6 个，52 KB）—— 两个平台逐字节相同、且与平台无关的：**

| 文件 | 是什么 |
|---|---|
| `devlog.md` | 设计记录，两边共用一份（见「延伸阅读」） |
| `custom_phrase.txt` | 自定义短语，2026-08-24 两边合并而来 |
| `double_pinyin_flypy.custom.yaml` | 改显示名为「鶴」 |
| `luna_pinyin.custom.yaml` | 改显示名为「朙」 |
| `melt_eng.custom.yaml` | 改显示名为「EN」，并让寄生的英文方案用双拼 algebra |

进 `common/` 的判据是**两边逐字节相同 + 内容与平台无关**，不是「文件小」。
`dof adopt` 会跳过与 `common/` 同名且逐字节相同的目标文件，所以平台层不会出现重复。

> **`cn_dicts_cell/`（22 个，23 MB）已于 2026-08-24 删除。** 三条实测结论：
> 上游 rime-ice 的 clone 里 `git ls-files | grep cn_dicts_cell` 为 0 笔（不是它的东西）；
> `rime_ice.dict.yaml` 的 `import_tables` 只挂 `cn_dicts/` 下五项，**全仓库与两台机器零引用**；
> 不可重建，只能用 `github.com/lewangdev/scel2txt` 从搜狗重转。
> 既然不影响任何输入行为，就没有理由让每次 clone 多下 23 MB。
>
> **它们已不在 git 历史里了**（2026-09-03，仓库转 public 前重写历史时一并移除，
> 理由是搜狗细胞词库来源不可考、重新分发的授权状态未知）。**没有备份，取不回来。**
> 真要用只能用 `github.com/lewangdev/scel2txt` 从搜狗重新转换。

**`linux/`（63 个，1.9 MB）—— 其余一切：**

你自己写的 10 个（5 个 `*.custom.yaml`、`custom_phrase.txt`、`custom_phrase_double.txt`、
`japanese_custom_phrase.txt`、`devlog.md`、**`lua/katakana_filter.lua`**），
加上上游的小文件（`lua/` 31、`opencc/` 3、`en_dicts/` 10、各 schema、`symbols*.yaml`）。

上游小文件也留在仓库里，是刻意的：它们总共才 1.9 MB，而**万一你哪天改了其中一个
（比如 `opencc/emoji.txt`），严格白名单会静默丢掉你的修改**。宁可多收，不可漏收。

> `lua/katakana_filter.lua` 是你自己写的（强制转片假名，等同 IME 的 F7，15 行 Lua 零数据文件，
> 见 `devlog.md §6.8`），由 `japanese.custom.yaml:40` 的 `lua_filter@*katakana_filter`
> 接入、绑定 `F7`。第一版白名单差点把它丢掉 —— 这就是改用黑名单的直接原因。

## 为什么用 copy 而不是 link

Rime 每次「重新部署」都会在用户目录里生成 `build/` 编译产物，还会改写词库。
整目录托管给 link 会把这些产物拽进仓库。

## 目录位置

```
macOS  (Squirrel)     ~/Library/Rime/
Linux  (fcitx5-rime)  ~/.local/share/fcitx5/rime/
Linux  (ibus-rime)    ~/.config/ibus/rime/         ← 用 ibus 的话改 manifest
```

> 本机 `~/.local/share/fcitx5/rime` 是指向 `~/.config/fcitx5/rime` 的软链（你自己设的）。
> manifest 里指的是前者，那是 fcitx5 的标准位置，新机器上会直接存在。

## 延伸阅读

`tools/rime/common/devlog.md` 是你自己的设计记录，比这份笔记详细得多：
三层模型、为什么不 fork rime-ice、皮肤系统的四种前端差异、日语方案的演进、体积账。
本文件只记「duotfiles 怎么管 rime」，设计判断以 devlog 为准。

## 平台差异

| 配置项 | linux | macos | 能否合并 | 判断日期 |
|---|---|---|---|---|
| （等 macOS 侧配置进仓库后再填） | | | | |
