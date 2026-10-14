local _, ns = ...

-- Colours, money, truncation and locale-independent chat message parsing.

function ns.ColorHex(c)
    local r, g, b = c[1] or c.r or 1, c[2] or c.g or 1, c[3] or c.b or 1
    return string.format("ff%02x%02x%02x",
        math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

function ns.Colorize(hex, text)
    if not hex then return tostring(text) end
    return "|c" .. hex .. tostring(text) .. "|r"
end

local GOLD, SILVER, COPPER = "ffffff00", "ffb0b0b0", "ffd17c4b"

-- Formats copper as "1g 85s 17c" with coloured coin letters.
--   digitHex      optional "ffrrggbb" tint for the digits
--   opts.icons    use coin icons (GetCoinTextureString) instead of letters
--   opts.hideSmall drop silver/copper when the value is at least 1 gold
function ns.FormatMoney(copper, digitHex, opts)
    copper = math.floor(tonumber(copper) or 0)
    if copper <= 0 then return "" end
    local gold = math.floor(copper / 10000)
    local silver = math.floor(copper / 100) % 100
    local cop = copper % 100
    local hideSmall = opts and opts.hideSmall and gold > 0

    if opts and opts.icons and GetCoinTextureString then
        local text = GetCoinTextureString(hideSmall and gold * 10000 or copper)
        return digitHex and ns.Colorize(digitHex, text) or text
    end

    local function D(n)
        if n == gold and gold > 0 and BreakUpLargeNumbers then
            n = BreakUpLargeNumbers(n)
        end
        return digitHex and ns.Colorize(digitHex, n) or tostring(n)
    end

    local parts = {}
    if gold > 0 then
        parts[#parts + 1] = D(gold) .. "|c" .. GOLD .. "g|r"
    end
    if not hideSmall then
        if gold > 0 or silver > 0 then
            parts[#parts + 1] = D(silver) .. "|c" .. SILVER .. "s|r"
        end
        parts[#parts + 1] = D(cop) .. "|c" .. COPPER .. "c|r"
    end
    return table.concat(parts, " ")
end

-- UTF-8 aware truncation so accented names never get cut mid-character.
function ns.Truncate(text, maxChars)
    if not text or not maxChars or maxChars <= 0 then return text or "" end
    local chars, i, len = 0, 1, #text
    while i <= len do
        chars = chars + 1
        if chars > maxChars then
            return text:sub(1, i - 1) .. "..."
        end
        local byte = text:byte(i)
        if byte >= 240 then
            i = i + 4
        elseif byte >= 224 then
            i = i + 3
        elseif byte >= 192 then
            i = i + 2
        else
            i = i + 1
        end
    end
    return text
end

-- Visible character count of a string with colour, texture and atlas escapes removed.
function ns.VisibleLength(s)
    if not s or s == "" then return 0 end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "X"):gsub("|A.-|a", "X")
    return #s
end

-- Converts a Blizzard format string (e.g. LOOT_ITEM_SELF_MULTIPLE) into a Lua
-- pattern. Returns the pattern plus, for each capture, the argument position
-- and type so localised strings with reordered arguments ("%2$d") still work.
function ns.FormatToPattern(fmt)
    if type(fmt) ~= "string" or fmt == "" then return nil end
    local positions, types, n = {}, {}, 0
    local s = fmt:gsub("%%%%", "\001")
    s = s:gsub("%%(%d*)%$?[%d%.]*([sdfi])", function(pos, t)
        n = n + 1
        positions[n] = tonumber(pos) or n
        types[n] = (t == "i") and "d" or t
        return "\002" .. types[n]
    end)
    s = s:gsub("[%^%$%(%)%.%[%]%*%+%-%?]", "%%%0")
    s = s:gsub("\002s", "(.-)")
    s = s:gsub("\002d", "(%%-?[%%d,%%.]+)")
    s = s:gsub("\002f", "(%%-?[%%d,%%.]+)")
    s = s:gsub("\001", "%%%%")
    return "^" .. s .. "$", positions, types
end

-- Matches msg against a compiled format and returns its arguments indexed by
-- their position in the original format string (numbers already converted).
function ns.MatchFormat(compiled, msg)
    local caps = { msg:match(compiled.pattern) }
    if caps[1] == nil then return nil end
    local args = {}
    for i, pos in ipairs(compiled.positions) do
        local v = caps[i]
        if v and compiled.types[i] == "d" then
            v = tonumber((v:gsub("[,%.]", ""))) or v
        elseif v and compiled.types[i] == "f" then
            v = tonumber(v) or tonumber((v:gsub(",", "."))) or v
        end
        args[pos] = v
    end
    return args
end

-- Compiles a list of { "GLOBAL_STRING_NAME", extra = fields } entries. Globals
-- missing on this client are skipped. Extra string keys are copied onto each
-- compiled entry. Longer patterns come first so "%s." never swallows "%sx%d.".
function ns.CompileFormats(list)
    local compiled = {}
    for _, entry in ipairs(list) do
        local pattern, positions, types = ns.FormatToPattern(_G[entry[1]])
        if pattern then
            local c = { pattern = pattern, positions = positions, types = types, key = entry[1] }
            for k, v in pairs(entry) do
                if type(k) == "string" then c[k] = v end
            end
            compiled[#compiled + 1] = c
        end
    end
    table.sort(compiled, function(a, b) return #a.pattern > #b.pattern end)
    return compiled
end

-- Pulls the first item hyperlink out of a chat message, including the modern
-- "|cnIQ4:" quality colour prefix.
function ns.ExtractItemLink(text)
    if not text then return nil end
    return text:match("(|c[^|]*|Hitem:.-|h.-|h|r)") or text:match("(|Hitem:.-|h.-|h)")
end
