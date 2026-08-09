-- katakana_filter.lua
--
-- 強制轉片假名。等同於 Mozc / Google 日本語入力 / macOS 內建日文輸入 /
-- Windows MS-IME 的 F7 功能。
--
-- 原理：ひらがな U+3041–U+3096 與 カタカナ U+30A1–U+30F6 在 Unicode 中是
-- 嚴格對齊的兩個區塊，差值恆為 +0x60。因此不需要任何映射表，也不需要把
-- 詞典擴充一倍。
--
-- 語義（由 katakana 開關控制）：
--   OFF（預設）→ 原樣通過。
--                japanese 方案的詞典本身已含 29.7 萬條片假名詞條，
--                打 terebi 直接就出 テレビ，不需要本濾鏡介入。
--   ON         → 片假名版排第一，原候選緊隨其後。
--                用於詞典裡沒有的詞：人名、擬聲詞、強調用法等。
--
-- 開關可在方案選單（F4）看見，也可用 F7 直接切換 —— 前者保證想不起來時
-- 找得到，後者符合各家日文輸入法的通用慣例。

local HIRA_LO, HIRA_HI, OFFSET = 0x3041, 0x3096, 0x60

local function hira_to_kata(s)
    local buf, changed = {}, false
    for _, cp in utf8.codes(s) do
        if cp >= HIRA_LO and cp <= HIRA_HI then
            cp = cp + OFFSET
            changed = true
        end
        buf[#buf + 1] = utf8.char(cp)
    end
    return table.concat(buf), changed
end

return function(input, env)
    -- 開關關閉時完全不介入，避免污染候選列表
    if not env.engine.context:get_option("katakana") then
        for cand in input:iter() do
            yield(cand)
        end
        return
    end

    for cand in input:iter() do
        local kata, changed = hira_to_kata(cand.text)
        if changed then
            local twin = Candidate("katakana", cand.start, cand._end, kata, "片")
            twin.quality = cand.quality
            yield(twin)
        end
        yield(cand)
    end
end
