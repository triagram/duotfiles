-- katakana_filter.lua
--
-- 為每個平假名候選附加一個片假名孿生候選。
--
-- 原理：ひらがな U+3041–U+3096 與 カタカナ U+30A1–U+30F6 在 Unicode 中
-- 是嚴格對齊的兩個區塊，差值恆為 +0x60。因此不需要任何映射表，也不需要
-- 把詞典擴充一倍——這是本方案不硬編碼片假名的原因。
--
-- 開關 katakana（方案選單）控制的是「順序」而非「有無」：
--   OFF → ひらがな 在前，カタカナ 在後
--   ON  → カタカナ 在前，ひらがな 在後
-- 兩者始終都可選，只是誰佔第一候選的位置不同。

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
    local kata_first = env.engine.context:get_option("katakana")

    for cand in input:iter() do
        local kata, changed = hira_to_kata(cand.text)

        if not changed then
            -- 不含平假名（標點、already 片假名、英數字等），原樣通過
            yield(cand)
        else
            local twin = Candidate("katakana", cand.start, cand._end, kata, "片")
            twin.quality = cand.quality

            if kata_first then
                yield(twin)
                yield(cand)
            else
                yield(cand)
                yield(twin)
            end
        end
    end
end
