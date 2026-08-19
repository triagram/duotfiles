# Rime 配置設計記錄

> 環境：Ubuntu 24.04.3 LTS / GNOME 46 / X11 / fcitx5 5.1.7 / librime 1.10.0
> 現況：3 個方案 —— `double_pinyin_flypy`（鶴）、`luna_pinyin`（朙）、`japanese`（日）
> 最後更新：2026-08-09

這個目錄裡的檔案來自三處：上游 rime-ice、系統 rime-data、自己寫的。Rime 沒有任何機制
區分它們，全部平鋪在同一層。這份文檔記錄的是**如何在這個平鋪結構上強加秩序**，
以及每個決定背後的理由 —— 尤其是那些「看起來該這樣做，實際不能」的地方。

---

## 1 · 設計原則

### 原則一：只保存不可重建的資訊

判斷方法：問「重裝系統後，這個檔案能不能用腳本自動還原？」

- 能 → 記錄它的**來源和版本號**，不記錄內容
- 不能 → 這是資產，必須保存

按此標準，近 400 MB 的目錄裡真正的資產不到 400 KB：全部 `*.custom.yaml`、
`custom_phrase*.txt`、`lua/katakana_filter.lua`，加上 `sync/*/​*.userdb.txt`（打字累積的詞頻）。

> **一個容易誤判的地方**：小鶴雙拼掛載的是 `dictionary: rime_ice`，所以它的用戶詞典
> 叫 `rime_ice.userdb` —— 這**不是**已停用的 rime_ice 全拼方案的殘留，而是每天都在
> 寫入的活躍資料。`user.yaml` 裡 rime_ice 的 access time 停在 2025-05 指的是
> 「方案切換記錄」，與 userdb 無關。差點因此誤刪。

### 原則二：自訂內容絕不寫進上游檔案

Rime 提供 `*.custom.yaml` patch 機制，任何修改都走這條路。直接編輯上游檔案，
下次更新會被無聲覆蓋，而且你不會知道自己丟了什麼。

這條原則讓 2026-07-27 那次 rime-ice 整包覆蓋更新沒有沖掉任何自訂內容。

### 原則三：可逆優先

清理一律用 `mv` 到回收站目錄，不用 `rm`；確認無異常後再真正刪除。

不可逆操作需要人肉「確認」這一步，而人肉確認是會出錯的環節 ——
設計上應該消除它，而不是叮囑自己小心。

---

## 2 · 三層模型

```
┌─────────────────────────────────────────────────────┐
│  L3  狀態層   installation.yaml, user.yaml,          │
│               *.userdb/, build/                      │
│               每台機器不同，除 userdb 外可拋棄          │
├─────────────────────────────────────────────────────┤
│  L2  自訂層   *.custom.yaml, custom_phrase*.txt,     │
│               lua/katakana_filter.lua                │
│               ★ 唯一需要版本控制的層，< 10 KB          │
├─────────────────────────────────────────────────────┤
│  L1  上游層   rime-ice + gkovacs/rime-japanese       │
│               + 系統 rime-data，約 380 MB            │
│               鎖版本號，用腳本重新下載                  │
└─────────────────────────────────────────────────────┘
```

**劃分的意義**：版本庫只裝 L2，L1 用 lock 檔描述，L3 除 userdb 外全部忽略。

更根本的分界只有兩類 —— **配置**是宣告式、單向的（source → target），適合 git；
**狀態**（userdb）是雙向演化的，只有 Rime 原生 sync 懂得合併。
把 userdb 交給 chezmoi 這類宣告式工具，每次 apply 都會抹掉一台機器的學習成果。

---

## 3 · 為什麼不用現成方案

### 3.1 不 fork rime-ice

1. **體積失控**：含 45 MB `cn_dicts/` + 23 MB `cn_dicts_cell/`，fork 後每次上游更新
   詞庫都會在 git 歷史留下完整副本
2. **合併衝突**：你的修改和上游修改落在同一批檔案上，而 Rime 明明提供了
   `*.custom.yaml` 這種零衝突的 patch 機制
3. **語義錯誤**：fork 表達「我要維護一個分支」，實際需求是「在上游之上疊 10 KB 個人設定」，
   維護成本差三個數量級

### 3.2 不用 plum（rime-install）

它會在配置目錄留下 80 MB 的完整 checkout（清理前的實況），沒有 lock 檔概念因而
無法重現特定版本，且是 bash + Makefile，跨平台行為有差異。

一個 20 行的 `install.sh` + 一個 lock 檔在可重現性上完勝。lock 是**清單（資料）**、
install.sh 是**執行器（動作）**，分開的理由是升級時只改一行版本號、不碰邏輯 ——
類比 `package-lock.json` 與 `npm install`。

### 3.3 Rime 內建 sync 只用於 userdb

- ✅ **適合 userdb**：Rime 為多機合併而設計，每台機器一個 `installation_id`，
  同步時掃描 sync_dir 下所有 UUID 子目錄並**合併**詞頻（累加，不是二選一）
- ❌ **不適合 config**：雲端同步沒有版本歷史、沒有 diff、沒有回滾

---

## 4 · 方案清單

```yaml
# default.custom.yaml
schema_list:
  - double_pinyin_flypy    # 鶴 —— 主力
  - luna_pinyin            # 朙 —— 全拼退路
  - japanese               # 日 —— 漢字變換
```

### 英文方案是「寄生」的，不需要獨立條目

小鶴雙拼內部已掛載 `table_translator@melt_eng`（英文）和 `table_translator@cn_en`
（中英混合詞，如「Excel表格」），**直接打字母就出英文候選**，不需切方案。

⚠️ 但 `melt_eng.custom.yaml` 必須保留 —— 寄生的那份仍需要它的雙拼 algebra 適配
（`__include: melt_eng.schema.yaml:/algebra_double_pinyin_flypy`），
否則英文裡的數字/符號派生規則會停留在全拼鍵位。移除的只是 `schema_list` 條目。

### 全拼與雙拼重疊

功能確實重疊，保留全拼作為「一時想不起雙拼鍵位」的退路，屬個人偏好。

---

## 5 · 皮膚系統

### 5.1 關鍵事實：四種前端讀完全不同的檔案

| 前端 | 平台 | 外觀來源 |
|---|---|---|
| **fcitx5** | Linux（現用） | `~/.config/fcitx5/conf/classicui.conf` + `~/.local/share/fcitx5/themes/*/theme.conf` |
| Squirrel 鼠鬚管 | macOS | `squirrel.custom.yaml`（`preset_color_schemes`） |
| ibus-rime | Linux | `ibus_rime.custom.yaml` |
| Weasel 小狼毫 | Windows | `weasel.custom.yaml` |

**Rime 目錄裡的 `preset_color_schemes` / `font_face` / `horizontal`，fcitx5 一個都不讀。**

原本有一份 100 行、4 套配色的 `ibus_rime.custom.yaml` 在此完全空轉。因決定
「macOS 與 Linux 兩端各自獨立、不做跨平台配色同步」，該檔案已刪除，
其中僅存於此的兩套色票（宮牆紅、徽州灰）轉存於 §8.4。

### 5.2 暗色自動切換

fcitx5 透過 xdg-desktop-portal 監聽 `org.freedesktop.appearance color-scheme`，
所以**任何能翻動 GNOME `color-scheme` 的東西都會讓輸入法跟著切換**，不需要對 fcitx5 做任何事。

```
腳本 → gsettings color-scheme → portal → fcitx5 classicui → 候選框配色
```

**當初「切換不工作」的真相**：配置本身完全正確，是系統從未進入深色模式 ——
portal 回報 `uint32 0`（no preference），fcitx5 只在收到 `1`（prefer-dark）時才切換。
不是壞了，是條件從沒滿足。

現以 systemd user timer 按**日出日落**自動切換（見 §7.4）。

> 順帶：fcitx5 啟動日誌裡的 `portal Error.NotFound` 是查詢 **`accent-color`**
> （GNOME 未提供），與 `color-scheme` 無關，可忽略。

### 5.3 BGR / RGB 陷阱

Rime YAML 用 `0xBBGGRR`（**BGR**），fcitx5 theme.conf 用 `#RRGGBB`（**RGB**），
位元組序相反。例如宮牆紅的主色在 Rime 裡是 `0x232B99`，在 fcitx5 裡是 `#992B23`。

手動轉換極易出錯 —— 原 `ibus_rime.custom.yaml` 的註解寫 RGB、值寫 BGR，
值其實是對的，但看起來自相矛盾。跨前端搬配色時務必用程式翻轉。

---

## 6 · 日語方案的演進

這是整個配置裡設計歷程最長的部分，也是踩坑最多的部分。

### 6.1 起點：自建方案名不副實

原本有一個手寫的 `nihongo` 方案（225 行），實際能力止於「羅馬字 → ひらがな」：

- **零片假名**（`grep -c '[ァ-ヶ]'` = 0），零漢字變換
- 缺 `punctuator`，打不出 `、。「」`
- 缺 `switches`，狀態列無指示
- 資料汙染：`っ意	ssi` —— 打字時中文 IME 未關，把 し 打成了 意

連「カタカナ」「日本語」這幾個字，它自己都打不出來。

### 6.2 一道硬性版本牆

目前唯一具備**真・連文節変換**的方案 [rime-kagiroi](https://github.com/rimeinn/rime-kagiroi)
（Mozc + MeCab）要求 **librime ≥ 1.11.2**，而 Ubuntu 24.04 只有 **1.10.0**。

> 這個版本落差也在影響中文輸入：rime-ice 是 2026-02 版，配置中用到的
> `navigator/no_loop`（需 ≥1.16）、`set_ascii_mode`（≥1.14）、`digit_separators`（≥1.13）
> 在 1.10.0 上全部靜默失效。

**決定不升級 librime** —— 為單一方案手動編譯會讓整個環境脫離 apt 管理，
與「可重建、最小化」的核心原則直接衝突。等 apt 源提供新版再說。

### 6.3 選定 gkovacs/rime-japanese

| | gkovacs | DreamAfar |
|---|---|---|
| Stars | 397 | 16 |
| 最後更新 | 2024-07 | 2023-04（且本就借鑑自 gkovacs） |

它用 `script_translator` 而非 table，具句子級かな漢字変換；詞典 Mozc(30 MB) +
JMdict(6.4 MB)，**不依賴 lua / MeCab**，故 librime 1.10 可跑。

**拆除的部分**（`japanese.custom.yaml`）：

- 三組反查 —— 依賴的 `terra_pinyin.extended`、`hannomPS`、`hangyl` 本機皆不存在
- 中文簡繁 `simplifier` —— 套在日文上會把日本漢字轉成簡體中文字形，語種錯誤
- 上游 `key_binder` 綁定了 korean / vietnamese 等不存在的方案，且未 `import_preset`，
  會少掉翻頁等基本鍵位

### 6.4 羅馬字方案衝突（最大的一個坑）

上游採**嚴格ヘボン式**，且**把訓令式拼法挪去表示外來音**：

| 訓令式習慣 | 上游實際輸出 | 標準假名在上游的編碼 |
|---|---|---|
| `si` → し | **すぃ**（スィ） | `shi` |
| `ti` → ち | **てぃ**（ティ） | `chi` |
| `tu` → つ | **とぅ**（トゥ） | `tsu` |
| `hu` → ふ | **ほぅ** | `fu` |
| `zi` → じ | **ずぃ**（ズィ） | `ji` |

詞典正文亦全為 Hepburn（`寿司 sushi`、`新聞 shinbun`、`東京 toukyou`）。
Mozc / MS-IME 的預設是**兩種都收**，上游只收一種。

已在 `speller/algebra` 補上 14 條訓令式派生。`derive` 只**增加**可接受拼法、
不移除既有的，所以外來音仍可輸入。

### 6.5 促音的兩種寫法

| 情境 | 寫法 | 例 |
|---|---|---|
| **詞中** | **雙輔音**（詞典原生編碼） | 一生懸命 `isshoukenmei`、学校 `gakkou`、切手 `kitte` |
| **單獨的っ** | `xtu` / `ltu` / `xtsu` / `ltsu` | あっ |

上游只給了 `_tsu` 一條，已補上各家慣用寫法。
**詞中的促音不要用 `xtu` 拼** —— 詞典裡沒有那樣的編碼，拼不出詞。

### 6.6 候選臃腫的真相

上游設 `translator/spelling_hints: 5`，把讀音附在候選後面 —— 但**只對音節數 ≤5 的詞生效**，
所以表現為「有時出現、有時不出現」，看起來像隨機。已設為 `0`。

> 建置後的 schema 裡還有一個 `spelling_hints: 10`，屬於已拆除的
> `putonghua_to_kanji_reverse_lookup` 孤兒區塊，引擎不會實例化，無成本。

### 6.7 單假名排序

`si` 同時匹配「すぃ」（**原生**拼寫）與「し」（**派生**拼寫），Rime 讓原生優先，
導致罕用外來音排第一。用 `japanese_custom_phrase.txt` +
`table_translator@custom_phrase`（`initial_quality: 99`）把 16 個常用單假名釘在首位。

此法**不影響 prism**，外來音仍留在候選列表後段。

### 6.8 片假名：15 行 Lua，零數據檔

ひらがな `U+3041–U+3096` 與 カタカナ `U+30A1–U+30F6` 是嚴格對齊的兩個區塊，
差值恆為 **+0x60**。因此不需要任何映射表，也不需要把詞典擴充一倍。

語義由 `katakana` 開關控制：
- **OFF（預設）→ 完全不介入**。詞典本身已含 29.7 萬條片假名，
  打 `terebi` 直接出 テレビ，常駐附加只會讓候選列表翻倍
- **ON → 片假名排第一**。用於詞典裡沒有的詞：人名、擬聲詞、強調用法

**可發現性由選單保證，效率由 F7 保證**：開關列在 `switches` 裡，按 F4 就能看見
「ひら/カタ」；同時綁 F7 —— 那是 Mozc / Google 日本語入力 / macOS 內建 / MS-IME
的共同慣例，不是本配置私設。這解決了「幾個月後忘記快捷鍵」的問題。

### 6.9 終局：刪除 nihongo

`japanese` 經上述四項修正後，假名層已完全覆蓋自建方案的能力，且多出漢字變換。
2026-08-08 刪除 `nihongo.{schema,dict,custom}.yaml`。
`lua/katakana_filter.lua` 保留 —— 它現在服務於 `japanese` 的 F7。

### 6.10 prism 體積的取捨

派生規則會把每條詞的可接受拼法展開，乘上 1.4M 條詞：

| 規則組合 | prism | 增量 |
|---|---|---|
| 上游原始 | 50 MB | — |
| **＋訓令式 14 條**（採用） | **90 MB** | +40 MB |
| ＋小假名 l 前綴、促音寫法（採用） | 90 MB | +0（只影響約 2000 條含 `_` 的條目） |
| ＋拗音小假名分解 7 條（**已停用**） | 143 MB | +53 MB |

**拗音分解規則停用的理由不是省空間，而是它解決的不是實際需求。**
「x + ya/yu/yo 打**單獨**小假名」靠的是上游原有的 `derive/_/x/`；那 7 條只負責
「在**詞中**用分解寫法」（`toukixyou` → 東京），而平常直接打 `kya` 即可。
規則以註解形式保留在 `japanese.custom.yaml`，附了實測代價，需要時取消註解即可。

---

## 7 · 特殊考量與已知限制

### 7.1 `sync/` 的 48 MB 刪不掉

`sync/` 除了 `*.userdb.txt`（350 KB，真資產）之外，還有配置檔與**詞典的完整副本**。

| 觸發者 | 是否重新填滿 |
|---|---|
| `rime_deployer --build` | ❌ 不會 |
| **fcitx5 啟動** | ✅ **會**（fcitx5-rime 啟動時自動同步） |

librime 1.10 沒有排除清單，這個重複是結構性的。

**解法（2026-08-09 實施）**：不改 `sync_dir`，在傳輸層用白名單擋掉。
見 §7.5。實測效果：48 MB 的目錄裡只有 4 個檔案、349 KB 進入同步範圍。

### 7.5 userdb 跨機同步

**兩層完全獨立的機制，不要混為一談：**

```
┌─────────────────────────────────────────────┐
│  Rime 的同步（懂詞庫語義，但不碰網路）           │
│  導出 userdb → 文字；讀其他 UUID 的檔案 → 合併  │
└──────────────────┬──────────────────────────┘
                   │  sync_dir 這個資料夾
┌──────────────────┴──────────────────────────┐
│  Syncthing（懂網路，但不懂詞庫）                │
│  把資料夾點對點搬到另一台機器                    │
└─────────────────────────────────────────────┘
```

Rime 的同步**沒有品牌名**，就是 librime 內建功能（fcitx5 動作名 `fcitx-rime-sync`，
選單顯示「Rime Sync user data」）。它從頭到尾只做本機檔案操作。

**為什麼非它不可**：每台機器有自己的 `installation_id`，同步時 Rime 掃描 `sync_dir`
下所有 UUID 子目錄並**逐條合併**詞頻（依提交次數與時間戳累加）。
同一個詞在兩台各被選過 5 次和 3 次，合併後是 8 次 ——
任何通用同步工具都做不到，它們只會讓一個檔案覆蓋另一個。

**傳輸層採用 `rsync over ssh`**（`rime-sync.sh`），`sync_dir` 保持預設不動。

```
./rime-sync.sh pull      取回對端詞庫
<在輸入法選單點「同步」>    Rime 合併並重新導出
./rime-sync.sh push      送出自己的詞庫
```

順序不能顛倒：先 pull 才有東西可合併，先合併才有更新後的內容可 push。

腳本兩端通用（依 `uname` 自動判定 `~/Library/Rime` 或 `~/.config/fcitx5/rime`），
並用 rsync 過濾只傳 `*.userdb.txt` —— 實測從 48 MB 的目錄中只挑出 4 個檔案共 357 KB。

**兩個防呆設計**：

- `pull` 加 `--exclude=<自己的UUID>/` —— **永不把自己的目錄拉回來**。
  否則對端存著的是你上次 push 的舊版，拉回來會覆蓋本機較新的學習成果
- `push` 只推 `sync/<自己的UUID>/` 這一個目錄，**絕不碰對端的**

**為什麼不用 Syncthing**：試過並配置完成（含 `.stignore` 白名單），但它需要常駐
背景服務、兩台同時開機才同步。既然已有 ssh 可用，rsync 是更少活動元件的選擇 ——
不需要守護進程、不需要配對、沒有 `.stversions` 那類陷阱（見下）。

**為什麼不用 GitHub**：`userdb.txt` 是 8019 行明文，記錄你打過的每一個被學習的詞句
—— 人名、地址、私人用語都在裡面。放 GitHub 必須是 private repo，且仍存在第三方
伺服器上；ssh 直連不經任何中間方。次要理由是 git 的版本歷史對機器生成的詞頻統計
毫無意義 —— 你永遠不會去看 `git log` 裡的詞頻變化。

> **一個曾經差點踩到的陷阱**（若日後改用 Syncthing 需注意）：
> 不要啟用它的檔案版本控制。`.stversions/` 會建在同步資料夾內，裡面**裝著舊版的
> `*.userdb.txt`**；Rime 掃描 `sync_dir` 時把子目錄當作 installation ID，
> 會把這些舊版本當成「另一台機器的詞庫」merge 進來。

> **注意**：Rime 的同步是**手動觸發**。忘了點不會壞，只是不會合併。

### 7.2 `essay.txt`（5.7 MB）的不確定性

沒有任何建置產物，schema 裡也沒有 `grammar` 引用，看起來像孤兒 ——
但 librime 可能在造句時隱式使用它，而**無法用命令列證明「刪了不影響中文造句品質」**。
5.7 MB 換一個無法驗證的風險，不划算，故保留。

同理 `rime_ice.schema.yaml`（20 KB）也是孤兒（flypy 只在註解裡提到它），
但它是上游檔案，刪了會與上游產生分歧，收益只有 20 KB。

### 7.3 五筆畫的相容鍵位

五筆畫用 `h s p n z` 代表橫豎撇捺折，但同一筆形有兩套叫法：
「丶」有人叫**捺**、有人叫**點**；「一」挑起來的有人叫**提**。系統原版為此加了：

```yaml
key_binder:
  bindings:
    - { when: always, accept: "d", send: "n" }   # 點 diǎn
    - { when: always, accept: "t", send: "h" }   # 提 tí
```

本地曾有一份**刪掉了這兩行**的副本，等於拔掉兩個同義詞按鍵。已刪除本地副本，
改由 `/usr/share/rime-data/stroke.schema.yaml` 接手。

### 7.4 自動深色腳本

**這個腳本與輸入法無關**，只翻動 `org.gnome.desktop.interface color-scheme`，
fcitx5 只是眾多跟隨者之一。它不放在本目錄，而應歸屬 dotfiles 倉庫。

```
~/.local/bin/auto-dark-mode                        純 stdlib（math + datetime）
~/.config/systemd/user/auto-dark-mode.service
~/.config/systemd/user/auto-dark-mode.timer        每 15 分鐘冪等檢查
```

設計要點：
- **座標寫死 56°N / 4°W（取整到度），不做網路請求，座標不離開本機** ——
  比啟用 GeoClue 定位服務更保守。GNOME 自己的 `Sunrise/Sunset` 屬性實測回傳 `-1.0`，
  代表 GeoClue 無定位資料，那條路走不通
- **不用固定時間**：此緯度日出擺幅 04:29–08:45、日落 15:42–22:06，超過 4 小時，
  固定 20:00/06:00 在夏冬兩季都嚴重偏離
- **用輪詢而非精確排程**：精確排程要每天重算並重建 timer，在休眠／時區變更／
  夏令時切換時容易錯過。15 分鐘輪詢對這些天然免疫，代價是最多延遲 15 分鐘 ——
  而日出日落本就是漸變過程，這個延遲在感知上無意義

> **踩到的坑**：NOAA 日出日落公式的經度參數是「**西經為正**」，而腳本內部用
> 「東經為正」。符號寫反會讓日出日落**整體平移 2×|經度|**（在 4°W 即 32 分鐘），
> 但**日照時數仍然完全正確** —— 只驗算時數會漏掉這個錯誤，
> 必須拿真實日出時刻對照才發現。修正後四季誤差均在 1–2 分鐘內。

### 7.6 絕不用 `fcitx5 -r` 套用設定（2026-08-19）

**症狀**：改完 `default.custom.yaml` 後，鎖屏密碼框又開始出中文。表面看像是
`fcitx5-lock-guard.sh` 壞了，但它其實**每次都正常開火並且打中**——日誌裡
`-> fcitx5-remote reports: 1`（1 = inactive = 英文）。guard 和 YAML 都是無辜的。

**真因**：套用設定時執行了 `fcitx5 -r`（replace）。它換掉整個 fcitx5 進程，
而 **gnome-shell 在一次登入內永不重啟**（當時該實例已跑 21 天），它持有的
輸入法連線就此成為孤兒。**具體斷在哪一層沒有深究**，但因果鏈是閉合的：
`fcitx5` 重啟於 8-18 17:46:33、`gnome-shell` 起於 7-28 23:11、guard 每次都
打中（`reports: 1`）、密碼框照樣出中文、原地重啟 gnome-shell 後立即恢復。

**修法**：改用 `~/.local/bin/rime-reload`，它呼叫
`org.fcitx.Fcitx.Controller1.ReloadAddonConfig("rime")` 讓 librime **在進程內
重新部署**，不換進程、不斷任何客戶端連線（等同托盤選單的「重新部署」）。

**已經踩下去了怎麼救**：`Alt+F2` → `r` → Enter，X11 下原地重啟 gnome-shell，
**所有視窗和終端都保留**（Wayland 沒有這功能）。注銷也行但會殺掉整個會話。

**版控位置**：這三個檔案已收進 `~/.duotfiles` 的 `fcitx5-guard` 工具
（2026-08-19），manifest 一行搞定：

```
fcitx5-guard link ~/.local  -
```

`~/.local` 同時涵蓋 `bin/` 與 `share/systemd/user/`——後者是 systemd 合法的
用戶單元搜尋路徑（`systemd-analyze --user unit-paths` 可驗證），所以不必為了
service 檔另開一條 manifest 條目。**換機器時**：

```bash
dof pull fcitx5-guard
systemctl --user enable --now fcitx5-lock-guard.service   # dof 不管 enable
```

**定位手法（可移植到任何「改完設定就壞了」的排查）**：先別看設定內容，
用 `ps -eo pid,lstart,cmd` 比對**進程年齡**——找出那一分鐘裡除了設定還重啟了
什麼、以及哪些長命進程比它更老。本例中 `fcitx5` 啟動於 8-18 17:46:33、
`gnome-shell` 啟動於 7-28 23:11，21 天的落差就是答案。
「100% 必現」排除競態，只可能是某個持續存在的壞狀態。

---

## 8 · 附錄

### 8.1 環境事實

| 項目 | 值 |
|---|---|
| OS / 桌面 | Ubuntu 24.04.3 LTS / GNOME 46 / X11 |
| fcitx5 | 5.1.7 |
| librime | 1.10.0+dfsg1-2build2（apt 唯一候選版本） |
| librime 外掛 | lua ✓ / octagram ✓ / charcode ✓ |
| 上游 rime-ice | config_version 2026-02-06 |
| 上游日語方案 | gkovacs/rime-japanese（2024-07） |
| 主力方案 | `double_pinyin_flypy`，用戶詞典為 `rime_ice.userdb` |

### 8.2 體積帳

| 階段 | 大小 |
|---|---|
| 整理前 | 266 MB（build 92M + plum 80M + sync 14M + 詞庫 68M） |
| 清理後 | ~172 MB（淨移除 plum + sync + 冗餘檔 ≈ −95 MB） |
| 加入日語漢字方案 | **389 MB**（來源詞典 37M + 編譯產物 94M） |

目前構成：`build/` 226M（可重建）、`sync/` 48M（自動備份）、`cn_dicts*/` 68M、
日語詞典 37M、`essay.txt` 5.7M，其餘 < 2M。

**對版本控制的影響為零** —— 需要版控的仍然只有約 10 KB。

### 8.3 驗證命令速查

```bash
# 某檔案是否只是系統版的副本
cmp -s /usr/share/rime-data/FILE ~/.config/fcitx5/rime/FILE && echo "完全相同，可刪"

# 暗色觸發鏈的當前狀態
gsettings get org.gnome.desktop.interface color-scheme
gdbus call --session --dest org.freedesktop.portal.Desktop \
  --object-path /org/freedesktop/portal/desktop \
  --method org.freedesktop.portal.Settings.Read \
  org.freedesktop.appearance color-scheme

# 離線重建（不驚動執行中的輸入法，可看見完整錯誤）
rime_deployer --build ~/.config/fcitx5/rime /usr/share/rime-data ~/.config/fcitx5/rime/build
grep -v "Encode failure" /tmp/rime.tools.WARNING     # Encode failure 是上游既有的全角詞條警告

# 目前載入了哪些方案
gdbus call --session --dest org.fcitx.Fcitx5 --object-path /rime \
  --method org.fcitx.Fcitx.Rime1.ListAllSchemas

# 套用設定變更（絕不用 fcitx5 -r，理由見 7.6）
rime-reload

# 「改完設定就壞了」的第一手排查：比對進程年齡，找出誰在那一分鐘被換掉了
ps -eo pid,lstart,cmd | grep -E "[f]citx5|[g]nome-shell"

# guard 每次鎖屏到底打中沒有（1 = 英文，2 = 中文，空 = 完全落空）
journalctl --user -u fcitx5-lock-guard.service -n 10 --no-pager

# 區分上游檔案與自己改過的（權限位是可靠線索）
find . -maxdepth 1 -perm 644 -name "*.yaml"   # 通常是自己動過的
find . -maxdepth 1 -perm 664 -name "*.yaml"   # 通常是整包解壓來的
```

### 8.4 備用色票

原僅存於已刪除的 `ibus_rime.custom.yaml`。色值已翻轉為 fcitx5 的 RGB 格式，
建成 `~/.local/share/fcitx5/themes/<名稱>/theme.conf` 即可用，
Margin 等版面參數照抄現有的 `vermilion_ink/theme.conf`。

```ini
# 宮牆紅 / Palace Red —— 紫禁城紅牆琉璃瓦
[InputPanel]
NormalColor=#2C2C2C
HighlightCandidateColor=#FFFFFF
HighlightColor=#992B23
HighlightClickColor=#992B23
LabelColor=#8E8E8E
[InputPanel/Background]
Color=#F4E3EF
BorderColor=#E2D2B3
[InputPanel/Highlight]
Color=#992B23
```

```ini
# 徽州灰 / Huizhou Gray —— 水墨徽派粉牆黛瓦
[InputPanel]
NormalColor=#2B2B2B
HighlightCandidateColor=#FFFFFF
HighlightColor=#3E4145
HighlightClickColor=#3E4145
LabelColor=#8E8E8E
[InputPanel/Background]
Color=#F7F7F7
BorderColor=#E0E0E0
[InputPanel/Highlight]
Color=#3E4145
```

現用配色：`vermilion_ink`（朱砂印，亮）/ `ink_bamboo_dark`（墨竹夜間，暗）。

### 8.5 參考連結

- [iDvel/rime-ice](https://github.com/iDvel/rime-ice) —— 中文方案上游
- [gkovacs/rime-japanese](https://github.com/gkovacs/rime-japanese) —— 日語方案上游
- [rimeinn/rime-kagiroi](https://github.com/rimeinn/rime-kagiroi) —— 未來升級目標（需 librime ≥ 1.11.2）
- [ayaka14732/awesome-rime](https://github.com/ayaka14732/awesome-rime) —— 方案總覽
