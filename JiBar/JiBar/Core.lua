local addonName, ns = ...

ns.name = addonName
ns.title = "JiBar"
ns.MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"

-------------------------------------------------------------------------------
-- Media
-------------------------------------------------------------------------------

-- Fonts the bar text can use. LibSharedMedia fonts are appended at startup.
ns.FONTS = {
    { key = "Homizio", name = "Homizio Bold (FuBar)", path = ns.MEDIA .. "HomizioBold.ttf" },
    { key = "Friz", name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { key = "ArialN", name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    { key = "Morpheus", name = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
    { key = "Skurri", name = "Skurri", path = "Fonts\\SKURRI.TTF" },
}

ns.OUTLINES = {
    { key = "", name = "None" },
    { key = "OUTLINE", name = "Outline" },
    { key = "THICKOUTLINE", name = "Thick outline" },
    { key = "MONOCHROME,OUTLINE", name = "Monochrome outline" },
}

-- Bar backgrounds: FuBar's default plus the FuTextures skins. Bordered skins
-- have a coloured line along the top row of the texture.
ns.SKINS = {
    { key = "Default", name = "FuBar (default)", file = "Default" },
    { key = "Solid", name = "Solid colour" },
    { key = "Tree", name = "Tree", file = "tree" },
    { key = "Ripple", name = "Ripple", file = "ripple" },
    { key = "Brushed", name = "Brushed", file = "brushed" },
    { key = "BlackYellow", name = "Black, yellow border", file = "blackyellow" },
    { key = "BlackOrange", name = "Black, orange border", file = "blackorange" },
    { key = "BlackRed", name = "Black, red border", file = "blackred" },
    { key = "BlackViolet", name = "Black, violet border", file = "blackviolet" },
    { key = "BlackBlue", name = "Black, blue border", file = "blackblue" },
    { key = "BlackCyan", name = "Black, cyan border", file = "blackcyan" },
    { key = "BlackGreen", name = "Black, green border", file = "blackgreen" },
    { key = "BlackBlack", name = "Black, no border", file = "blackblack" },
    { key = "RedSandstone", name = "Red sandstone", file = "redsandstone" },
    { key = "Sandstone", name = "Sandstone", file = "sandstone" },
    { key = "Titan", name = "Titan alternative", file = "titanalternative" },
    { key = "Patchwork", name = "Patchwork", file = "patchwork" },
}

-- Visible columns of JiBar's own icons (left, right as fractions of the
-- texture width). The files have different transparent margins; icons are
-- cropped to their pixels so every plugin gets the same gap before its text.
ns.ICON_BOUNDS = {
    gold = { 2 / 16, 12 / 16 },
    honor = { 0, 25 / 32 },
    performance = { 0, 15 / 16 },
    quests = { 4 / 16, 15 / 16 },
    repair = { 0, 1 },
    transporter = { 1 / 16, 1 },
}

function ns.IconBounds(texture)
    local name = type(texture) == "string" and texture:match("Media\\Icons\\(%w+)$")
    return name and ns.ICON_BOUNDS[name]
end

-- Separators between the parts of a plugin's text ("0 HONOR • 8-5").
ns.SEPARATORS = {
    { key = "•", name = "• (bullet)" },
    { key = "·", name = "· (middle dot)" },
    { key = "|", name = "| (bar)" },
    { key = "/", name = "/ (slash)" },
    { key = "-", name = "- (dash)" },
    { key = "", name = "None (space only)" },
}

ns.STRATAS = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG" }
ns.SIDES = { "LEFT", "CENTER", "RIGHT" }
ns.SIDE_NAMES = { LEFT = "Left", CENTER = "Centre", RIGHT = "Right" }

function ns.FindByKey(list, key)
    for i, entry in ipairs(list) do
        if entry.key == key then return entry, i end
    end
end

function ns.FontPath(key)
    local font = ns.FindByKey(ns.FONTS, key) or ns.FONTS[1]
    return font.path
end

-------------------------------------------------------------------------------
-- Settings. Plugin settings live in db.plugins[id]; each plugin declares its
-- own defaults (see Plugin.lua), which are merged in at startup.
-------------------------------------------------------------------------------

ns.defaults = {
    locked = true,
    font = "Homizio",
    fontSize = 12,
    outline = "",
    shadow = true,
    textColor = { 1, 1, 1 },
    textAlpha = 0.75,
    hoverColor = { 0.64, 0.19, 0.79 },
    iconSize = 16,
    iconGap = 6.5,      -- between an icon's visible edge and the text
    separator = "•",
    tooltip = { scale = 1, alpha = 0.92, fontSize = 12 },
    bars = {
        {
            attach = "BOTTOM",  -- TOP, BOTTOM or FLOAT
            x = 0,              -- left edge as a fraction of the screen width
            y = 0.5,            -- FLOAT only: bottom edge as a fraction of the screen height
            width = 1,          -- fraction of the screen width
            height = 28,
            scale = 1,
            strata = "MEDIUM",
            skin = "Default",
            bgColor = { 1, 1, 1 },
            bgAlpha = 1,
            edgeLine = false,
            edgeColor = { 0, 0, 0 },
            autoHide = false,
            autoHideAlpha = 0,
            hideInCombat = false,
            padding = 6,
            spacing = { LEFT = 10, CENTER = 16, RIGHT = 14 },
        },
    },
    plugins = {},
    debug = false,
}

-- Copied when a bar is added, so new bars look like the default one.
ns.BAR_TEMPLATE = ns.DeepCopy(ns.defaults.bars[1])

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

local floor = math.floor

function ns.Hex(r, g, b)
    return string.format("ff%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

function ns.Color(text, r, g, b)
    return "|c" .. ns.Hex(r, g, b) .. tostring(text) .. "|r"
end

-- Joins the parts of a plugin's text with the chosen separator. A "|"
-- separator is escaped, since "|" starts an escape code in WoW text.
function ns.Join(parts)
    local sep = ns.db and ns.db.separator or "•"
    if sep == "|" then sep = "||" end
    local kept = {}
    for _, part in ipairs(parts) do
        if part ~= nil and part ~= "" then kept[#kept + 1] = part end
    end
    return table.concat(kept, sep == "" and " " or (" " .. sep .. " "))
end

-- Crayon-style threshold colour: red at worst, through orange and yellow, to
-- green at best. The thresholds may run downwards (worst > best).
function ns.ThresholdColor(q, worst, bad, neutral, good, best)
    worst, bad, neutral, good, best = worst or 0, bad or 0.25, neutral or 0.5, good or 0.75, best or 1
    if worst > best then
        q, worst, bad, neutral, good, best = -q, -worst, -bad, -neutral, -good, -best
    end
    if q ~= q then q = worst end -- NaN
    if q <= worst then return 1, 0, 0 end
    if q <= bad then return 1, (q - worst) / (bad - worst) * 0.5, 0 end
    if q <= neutral then return 1, 0.5 + (q - bad) / (neutral - bad) * 0.5, 0 end
    if q <= good then return 1 - (q - neutral) / (good - neutral) * 0.5, 1, 0 end
    if q <= best then return 0.5 - (q - good) / (best - good) * 0.5, 1, 0 end
    return 0, 1, 0
end

function ns.ThresholdHex(...)
    return ns.Hex(ns.ThresholdColor(...))
end

-- "1h 05m", "4m 12s", "38s"; long = "1 hr 5 min" style isn't needed here.
function ns.FormatDuration(seconds)
    seconds = math.max(0, floor(seconds or 0))
    local d = floor(seconds / 86400)
    local h = floor(seconds / 3600) % 24
    local m = floor(seconds / 60) % 60
    local s = seconds % 60
    if d > 0 then return string.format("%dd %dh", d, h) end
    if h > 0 then return string.format("%dh %02dm", h, m) end
    if m > 0 then return string.format("%dm %02ds", m, s) end
    return string.format("%ds", s)
end

-- Money with coloured g/s/c letters: "123g 96s 57c". Negative amounts get a minus.
local COIN = { g = "ffd700", s = "c7c7cf", c = "eda55f" }
function ns.FormatCoins(copper, opts)
    copper = floor(tonumber(copper) or 0)
    local sign = copper < 0 and "-" or ""
    copper = math.abs(copper)
    local g, s, c = floor(copper / 10000), floor(copper / 100) % 100, copper % 100
    local colored = not opts or opts.colored ~= false
    local function L(letter)
        return colored and ("|cff" .. COIN[letter] .. letter .. "|r") or letter
    end
    local parts = {}
    if g > 0 then
        parts[#parts + 1] = (BreakUpLargeNumbers and BreakUpLargeNumbers(g) or tostring(g)) .. L("g")
    end
    if g > 0 or s > 0 then parts[#parts + 1] = s .. L("s") end
    if not (opts and opts.noCopper and g > 0) then parts[#parts + 1] = c .. L("c") end
    return sign .. table.concat(parts, " ")
end

-- Days since 1970-01-01 for a calendar date (Howard Hinnant's days_from_civil).
local function DaysFromCivil(y, m, d)
    if m <= 2 then y = y - 1 end
    local era = floor(y / 400)
    local yoe = y - era * 400
    local doy = floor((153 * ((m + 9) % 12) + 2) / 5) + d - 1
    return era * 146097 + yoe * 365 + floor(yoe / 4) - floor(yoe / 100) + doy - 719468
end

-- Today's local date as a day number, used as keys for daily statistics.
function ns.Today()
    local t = date("*t")
    return DaysFromCivil(t.year, t.month, t.day)
end

function ns.Debug(...)
    if ns.db and ns.db.debug then ns.Print("|cff999999debug|r", ...) end
end

-- Inserts text into the open chat edit box, or prints it if none is open.
function ns.InsertChatText(text)
    local get = (ChatFrameUtil and ChatFrameUtil.GetActiveWindow) or ChatEdit_GetActiveWindow
    local box = get and get()
    if box then
        box:Insert(text)
    else
        ns.Print(text)
    end
end

-- Inserts a link into the open chat edit box (shift-click behaviour).
function ns.InsertChatLink(link)
    local insert = (ChatFrameUtil and ChatFrameUtil.InsertLink) or ChatEdit_InsertLink
    if link and insert then return insert(link) end
end

function ns.CoinTextureString(copper)
    local fn = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString) or GetCoinTextureString
    return fn and fn(copper)
end

-- Runs fn now, or after combat if a protected change is blocked right now.
local afterCombat = {}
function ns.OutOfCombat(key, fn)
    if InCombatLockdown() then
        afterCombat[key] = fn
        return false
    end
    fn()
    return true
end

-------------------------------------------------------------------------------
-- Startup
-------------------------------------------------------------------------------

-- Pulls in LibSharedMedia fonts when that library is around.
local function AddSharedMediaFonts()
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    if not lsm then return end
    local known = {}
    for _, f in ipairs(ns.FONTS) do known[f.path:lower()] = true end
    for _, name in ipairs(lsm:List("font") or {}) do
        local path = lsm:Fetch("font", name)
        if path and not known[path:lower()] then
            known[path:lower()] = true
            ns.FONTS[#ns.FONTS + 1] = { key = "LSM:" .. name, name = name, path = path }
        end
    end
end

ns:OnLoad(function()
    ns.db = ns.LoadSavedVariables("JiBarDB", ns.defaults)
    -- Bars saved by an earlier version may lack newer keys.
    for _, bar in ipairs(ns.db.bars) do ns.CopyDefaults(ns.BAR_TEMPLATE, bar) end
    if #ns.db.bars == 0 then ns.db.bars[1] = ns.DeepCopy(ns.BAR_TEMPLATE) end

    AddSharedMediaFonts()
    ns.InitPlugins()
    ns.Bars:Build()
    ns.Plugins:PlaceAll()

    ns.Widgets.RegisterSettingsPanel({
        title = ns.title,
        description = "FuBar-style information bars. Type /jibar to open the options,\n/jibar unlock to move bars and plugins.",
        icon = 134400,
        open = function() ns.Options:Toggle() end,
    })
end)

ns:RegisterEvent("PLAYER_LOGIN", function()
    ns.Plugins:EnableAll()
end)

ns:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    ns.Plugins:UpdateAll()
    ns.Bars:LayoutAll()
end)

ns:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    local pending = afterCombat
    afterCombat = {}
    for _, fn in pairs(pending) do fn() end
end)

ns:RegisterEvent("UI_SCALE_CHANGED", function() if ns.db then ns.Bars:LayoutAll() end end)
ns:RegisterEvent("DISPLAY_SIZE_CHANGED", function() if ns.db then ns.Bars:LayoutAll() end end)

-------------------------------------------------------------------------------
-- Slash commands
-------------------------------------------------------------------------------

local function Usage()
    ns.Print("/jibar - options, /jibar lock | unlock, /jibar reset,")
    ns.Print("/jibar custom add <name> ### <lua> | custom remove <name>")
end

SLASH_JIBAR1 = "/jibar"
SLASH_JIBAR2 = "/jb"
SlashCmdList.JIBAR = function(msg)
    msg = strtrim(msg or "")
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "" or cmd == "options" or cmd == "config" then
        ns.Options:Toggle()
    elseif cmd == "lock" or cmd == "unlock" then
        ns.Bars:SetLocked(cmd == "lock")
    elseif cmd == "reset" then
        ns.ResetSavedVariables("JiBarDB", ns.defaults)
        ns.Print("Settings reset. Type /reload to finish.")
    elseif cmd == "custom" and ns.plugins.CustomMenu then
        ns.plugins.CustomMenu:Command(rest)
    elseif cmd == "debug" then
        ns.db.debug = not ns.db.debug
        ns.Print("debug", ns.db.debug and "on" or "off")
    else
        Usage()
    end
end
