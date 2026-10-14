local _, ns = ...

-- Unit data helpers that cope with Forever's secret values.
--
-- UnitHealth is always secret for addons. Max health, power, NPC names,
-- creature types and aura fields turn secret for NPCs or in combat. Widget
-- setters (SetText, SetFormattedText, SetValue, SetMinMaxValues, SetAlpha,
-- colours, SetTexture) accept secrets, but Lua arithmetic, comparisons,
-- concatenation and truth tests on them throw. So: plain values may be
-- inspected, secret ones only ever get handed straight to a widget.

local U = {}
ns.Unit = U

local IsSecret = ns.IsSecret

-- Returns v when it's a plain value, fallback when it's secret.
function U.Plain(v, fallback)
    if IsSecret(v) then return fallback end
    return v
end

-- True when v is present: a secret counts as present, since nil is never secret.
function U.Has(v)
    return IsSecret(v) or (v ~= nil and v ~= "")
end

-- Plain boolean from an API that might return a secret one.
function U.Bool(v)
    if IsSecret(v) then return false end
    return v and true or false
end

-- pcall wrapper for APIs whose secret handling isn't verified in game yet.
-- Errors print once per tag with /jiuf debug.
local reported = {}
function U.Try(tag, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and ns.db and ns.db.debug and not reported[tag] then
        reported[tag] = true
        ns.Print("|cffff6060" .. tag .. ":|r " .. tostring(err))
    end
    return ok
end

-------------------------------------------------------------------------------
-- Colours
-------------------------------------------------------------------------------

local function Hex(r, g, b)
    return string.format("ff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5))
end
U.Hex = Hex

-- Nurfed's power colours: brighter than Blizzard's (mana is cyan).
U.POWER_COLORS = {
    MANA = { 0, 1, 1 },
    RAGE = { 1, 0, 0 },
    FOCUS = { 1, 0.7, 0 },
    ENERGY = { 1, 1, 34 / 255 },
}

function U.PowerColor(unit)
    local _, token = UnitPowerType(unit)
    token = U.Plain(token)
    local c = token and U.POWER_COLORS[token]
    if c then return c[1], c[2], c[3] end
    c = token and PowerBarColor and PowerBarColor[token]
    if c and c.r then return c.r, c.g, c.b end
    return 0, 1, 1
end

function U.ClassColor(classFile)
    local c = classFile and ((C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(classFile))
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]))
    if c and c.r then return c.r, c.g, c.b end
    return 1, 1, 1
end

function U.UnitClassFile(unit)
    local _, file = UnitClass(unit)
    return U.Plain(file)
end

-- Nurfed_HealthPercColor: green above 60%, yellow to orange down to 20%,
-- then dark red.
function U.HealthGradient(p)
    if p > 0.6 then
        return 0, 1, 0
    elseif p > 0.2 then
        local d = (0.6 - p) * 100
        local r = math.min(1, (255 + d * 128 / 40) / 255)
        local g = math.max(0, (204 - d * 89 / 40) / 255)
        local b = math.max(0, (1 - d * 136 / 40) / 255)
        return r, g, b
    end
    return 206 / 255, 17 / 255, 17 / 255
end

-- Name colour: class colour for players, reaction colour for NPCs (grey when
-- tapped by someone else).
function U.NameColor(unit)
    if U.Bool(UnitIsPlayer(unit)) then
        return U.ClassColor(U.UnitClassFile(unit))
    end
    if U.Bool(UnitIsTapDenied(unit)) then
        return 0.5, 0.5, 0.5
    end
    local reaction = U.Plain(UnitReaction(unit, "player"))
    local c = reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

-------------------------------------------------------------------------------
-- Curves. UnitHealthPercent(unit, usePredicted, curve) evaluates a curve on
-- the secret health percentage and returns a (secret) result widgets accept.
-------------------------------------------------------------------------------

local curves

local HEALTH_COLOR_POINTS = {
    { 0, 206 / 255, 17 / 255, 17 / 255 },
    { 0.2, 206 / 255, 17 / 255, 17 / 255 },
    { 0.2001, 1, 0.45, 0 },
    { 0.6, 1, 0.8, 0 },
    { 0.6001, 0, 1, 0 },
    { 1, 0, 1, 0 },
}

-- Returns { percent (0-100), hideFull (1 below full, 0 at full), color } or nil.
function U.Curves()
    if curves ~= nil then return curves or nil end
    curves = false
    if not (C_CurveUtil and C_CurveUtil.CreateCurve and C_CurveUtil.CreateColorCurve and CreateColor) then
        return nil
    end
    U.Try("curves", function()
        local linear = Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear
        local function New(create)
            local c = create()
            if linear then c:SetType(linear) end
            return c
        end
        local c = {}
        -- Whole percents, rounded down like Nurfed: a step at every 1%.
        c.percent = C_CurveUtil.CreateCurve()
        local step = Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step
        if step then
            c.percent:SetType(step)
            for i = 0, 100 do c.percent:AddPoint(i / 100, i) end
        else
            c.percent:AddPoint(0, 0)
            c.percent:AddPoint(1, 100)
        end
        c.hideFull = New(C_CurveUtil.CreateCurve)
        c.hideFull:AddPoint(0, 1)
        c.hideFull:AddPoint(0.9999, 1)
        c.hideFull:AddPoint(1, 0)
        c.color = New(C_CurveUtil.CreateColorCurve)
        for _, p in ipairs(HEALTH_COLOR_POINTS) do
            c.color:AddPoint(p[1], CreateColor(p[2], p[3], p[4]))
        end
        curves = c
    end)
    return curves or nil
end

-------------------------------------------------------------------------------
-- Labels
-------------------------------------------------------------------------------

-- Level text and its difficulty colour: "60", "30+" for elites, "??" and
-- "Boss" in red.
function U.LevelText(unit)
    local level = U.Plain(UnitLevel(unit), 0)
    local class = U.Plain(UnitClassification(unit), "normal")
    local c = (GetCreatureDifficultyColor and GetCreatureDifficultyColor(level))
        or (GetQuestDifficultyColor and GetQuestDifficultyColor(level))
    local r, g, b = 1, 0.82, 0
    if c and c.r then r, g, b = c.r, c.g, c.b end
    if class == "worldboss" then
        return BOSS or "Boss", 1, 0, 0
    elseif level < 0 then
        return "??", 1, 0, 0
    elseif level == 0 then
        return "", r, g, b
    end
    local text = tostring(level)
    if class == "elite" or class == "rareelite" then text = text .. "+" end
    return text, r, g, b
end

local CLASSIFICATION = {
    rareelite = function() return (ITEM_QUALITY3_DESC or "Rare") .. "-" .. (ELITE or "Elite") end,
    rare = function() return ITEM_QUALITY3_DESC or "Rare" end,
    elite = function() return ELITE or "Elite" end,
}

-- What goes after the level: the class for players (class coloured), the
-- creature family or type for NPCs prefixed by elite/rare. Returns
-- prefix (plain), text (maybe secret), hex colour or nil; text may be nil.
function U.ClassLabel(unit)
    if U.Bool(UnitIsPlayer(unit)) then
        local name, file = UnitClass(unit)
        file = U.Plain(file)
        return "", name, file and Hex(U.ClassColor(file)) or nil
    end
    local classification = U.Plain(UnitClassification(unit))
    local prefix = CLASSIFICATION[classification] and CLASSIFICATION[classification]() or ""
    local family = UnitCreatureFamily and UnitCreatureFamily(unit)
    if U.Has(family) then return prefix, family, nil end
    local creature = UnitCreatureType(unit)
    if U.Has(creature) then return prefix, creature, nil end
    return prefix, nil, nil
end

-- Short label for a key binding: "SHIFT-F2" -> "S-F2".
local KEY_ABBREVIATIONS = {
    { "SHIFT%-", "S-" }, { "CTRL%-", "C-" }, { "ALT%-", "A-" }, { "META%-", "M-" },
    { "NUMPAD", "N" }, { "MOUSEWHEELUP", "WU" }, { "MOUSEWHEELDOWN", "WD" },
    { "BUTTON", "M" }, { "SPACE", "Sp" },
}
function U.BindingLabel(action)
    local key = GetBindingKey and GetBindingKey(action)
    if type(key) ~= "string" or key == "" then return nil end
    for _, rule in ipairs(KEY_ABBREVIATIONS) do
        key = key:gsub(rule[1], rule[2])
    end
    return key
end

-- Class icon: modern class atlas when the client has it, else the old
-- character-creation sheet Nurfed used.
local CLASS_COORDS = {
    WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.49609375, 0, 0.25 },
    ROGUE = { 0.49609375, 0.7421875, 0, 0.25 }, DRUID = { 0.7421875, 0.98828125, 0, 0.25 },
    HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 },
    PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 }, WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 },
    PALADIN = { 0, 0.25, 0.5, 0.75 },
}

function U.SetClassIcon(tex, classFile)
    if not classFile then
        tex:Hide()
        return
    end
    local atlas = "classicon-" .. classFile:lower()
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        tex:SetAtlas(atlas)
        tex:SetTexCoord(0, 1, 0, 1)
    else
        local coords = (CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]) or CLASS_COORDS[classFile]
        if not coords then
            tex:Hide()
            return
        end
        tex:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
        tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    end
    tex:Show()
end
