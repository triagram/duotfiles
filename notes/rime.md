# rime

`copy` 模式。数据分两条通道：**进仓库的配置** 与 **部署时从上游拉的词库数据**。

> **用户词库（`*.userdb/`）及其同步不在本仓库范围内。**
> 词库里有人名、地址、私人用语；同步方式也是机器相关的。
> 相关文件（`*.userdb*`、`sync/`、`rime-sync.sh`、`installation.yaml`）全部在 `.dofignore` 里，
> dof 不碰，也不进 git。这块请在本机自行维护。

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

日语方案的选型理由见 `tools/rime/linux/designLog.md §6.3`（对比过 DreamAfar，选了 star 更多、维护更新的 gkovacs）。

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
（`designLog.md` 的「原則二」）。

> 例外：`custom_phrase.txt` 是**你改过的上游文件**（注释掉了 `噷/呣/呒`，加了
> `啊对对对`、`不不不` 和邮箱短语）。它在仓库里，`dof pull` 会覆盖上游那份 —— 这正是要的效果。

## ② 仓库里的 common/ 与 linux/ 怎么分

**`common/`（22 个，23 MB）—— 只剩出处查不到的一组：**

`cn_dicts_cell/` 22 个细胞词库。搜狗细胞词库转换而来，具体来源已不可考 ——
不在 rime-ice 的 git 仓库里，也不在它的 release zip（`all_dicts.zip` / `full.zip`）里。
将来想重建可以用 `github.com/lewangdev/scel2txt` 从搜狗重新转换。

放 `common/` 而不是 `linux/` 的原因：**词库是平台无关的**。放 common 里只存一份，
macOS `dof adopt rime` 时不会再复制一份，`linux/` ↔ `macos/` 的比对也不会被它们淹没。

> 这一条是 `dof adopt` 的内建行为：目标文件若与 `common/` 里的同名文件逐字节相同，
> 直接跳过，不进平台层。

**`linux/`（63 个，1.9 MB）—— 其余一切：**

你自己写的 10 个（5 个 `*.custom.yaml`、`custom_phrase.txt`、`custom_phrase_double.txt`、
`japanese_custom_phrase.txt`、`designLog.md`、**`lua/katakana_filter.lua`**），
加上上游的小文件（`lua/` 31、`opencc/` 3、`en_dicts/` 10、各 schema、`symbols*.yaml`）。

上游小文件也留在仓库里，是刻意的：它们总共才 1.9 MB，而**万一你哪天改了其中一个
（比如 `opencc/emoji.txt`），严格白名单会静默丢掉你的修改**。宁可多收，不可漏收。

> `lua/katakana_filter.lua` 是你自己写的（强制转片假名，等同 IME 的 F7，15 行 Lua 零数据文件，
> 见 `designLog.md §6.8`），由 `japanese.custom.yaml:40` 的 `lua_filter@*katakana_filter`
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

`tools/rime/linux/designLog.md` 是你自己的设计记录，比这份笔记详细得多：
三层模型、为什么不 fork rime-ice、皮肤系统的四种前端差异、日语方案的演进、体积账。
本文件只记「duotfiles 怎么管 rime」，设计判断以 designLog 为准。

## 平台差异

| 配置项 | linux | macos | 能否合并 | 判断日期 |
|---|---|---|---|---|
| （等 macOS 侧配置进仓库后再填） | | | | |
