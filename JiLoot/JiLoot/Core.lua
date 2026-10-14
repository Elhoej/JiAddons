local addonName, ns = ...

ns.name = addonName
ns.title = "JiLoot"

-------------------------------------------------------------------------------
-- Defaults
-------------------------------------------------------------------------------

ns.defaults = {
    enabled = true,
    locked = true,
    point = { "TOPLEFT", "CENTER", 220, 180 },

    -- Layout
    growUp = false,
    sortMode = 1,          -- 1 = by type/quality, 2 = newest first, 3 = oldest first
    maxRows = 10,
    width = 400,
    height = 40,
    spacing = 5,
    scale = 1,
    fontSize = 12,
    bgAlpha = 0.66,
    showTimerBar = true,
    showTooltip = true,
    clickThrough = false,
    animations = true,

    -- Display durations in seconds. 0 hides that kind of loot entirely.
    durations = {
        poor = 3,
        common = 5,
        uncommon = 10,
        rare = 15,
        epic = 20,
        legendary = 40,
        artifact = 15,
        heirloom = 15,
        quest = 15,
        currency = 15,
        money = 5,
        rep = 15,
        honor = 10,
    },

    -- Sources
    showMoney = true,
    showCurrency = true,
    showRep = true,
    showHonor = true,
    showCreated = true,    -- "You create: ..."
    showPushed = true,     -- "You receive item: ..." (quest rewards, purchases, mail)
    invCount = true,
    maxNameLength = 35,

    -- Blizzard loot window
    hideLootWindow = true, -- keep it hidden while auto-looting non-BoP loot

    -- Prices
    stackPriceMode = 1,    -- 1 = unit + stack, 2 = unit only, 3 = stack replaces unit
    ahMode = 2,            -- 1 = off, 2 = unit AH price, 3 = stack AH price
    ahSource = 1,          -- 1 = Auctionator, 2 = TSM
    tsmSource = 2,         -- 1 = dbmarket, 2 = dbminbuyout
    ahJunk = true,
    hideSmallCoins = false,
    coinIcons = false,
    ahColor = { 0.35, 1, 0.35 },
    stackColor = { 1, 1, 1 },

    -- Highlighting
    highlight = true,
    highlightSound = false,
    highlightUnit = 3,     -- 1 = copper, 2 = silver, 3 = gold
    thresholds = { 20, 200, 1000 },
    highlightColors = {
        { 1, 1, 1 },
        { 1, 0.6, 0 },
        { 1, 0.1, 0.1 },
    },

    blacklist = {
        items = {},        -- [itemID] = true
        currencies = {},   -- [currencyID] = true
        factions = {},     -- [faction name] = true
    },
}

-------------------------------------------------------------------------------
-- Saved variables
-- Generic helpers (API compatibility, formatting, events, widgets) come from
-- the embedded Shared/ files, synced from JiAddons/shared.
-------------------------------------------------------------------------------

function ns:InitDB()
    self.db = ns.LoadSavedVariables("JiLootDB", self.defaults)
end

-- Resets every setting but keeps the blacklist.
function ns:ResetDB()
    self.db = ns.ResetSavedVariables("JiLootDB", self.defaults, { "blacklist" })
end

-- Money text using the player's coin display settings.
function ns.Money(copper, digitHex)
    return ns.FormatMoney(copper, digitHex, {
        icons = ns.db and ns.db.coinIcons,
        hideSmall = ns.db and ns.db.hideSmallCoins,
    })
end

ns:OnLoad(function()
    ns:InitDB()
    if ns.Display then ns.Display:Init() end
    if ns.Sources then ns.Sources:Init() end
    if ns.LootWindow then ns.LootWindow:Init() end
    if ns.Options then ns.Options:Init() end
end)

-------------------------------------------------------------------------------
-- Blacklist
-------------------------------------------------------------------------------

ns.BLACKLIST_KINDS = { "items", "currencies", "factions" }

function ns:IsBlacklisted(kind, key)
    if key == nil then return false end
    local list = self.db and self.db.blacklist and self.db.blacklist[kind]
    return list and list[key] or false
end

function ns:SetBlacklisted(kind, key, value)
    local list = self.db.blacklist[kind]
    if not list or key == nil or key == "" then return false end
    list[key] = value and true or nil
    if ns.Options and ns.Options.RefreshBlacklist then
        ns.Options:RefreshBlacklist()
    end
    return true
end

-- Accepts an item link, "item:123", a bare ID or a name depending on kind.
function ns:ParseBlacklistInput(kind, text)
    text = text and strtrim(text) or ""
    if text == "" then return nil end
    if kind == "factions" then
        return text
    end
    local id = text:match("|H%a+:(%d+)") or text:match("%a+:(%d+)") or text:match("^(%d+)$")
    return tonumber(id)
end

-------------------------------------------------------------------------------
-- Slash commands
-------------------------------------------------------------------------------

local function Help()
    ns.Print("commands:")
    print("  /jiloot  - open options")
    print("  /jiloot test  - show example rows")
    print("  /jiloot unlock | lock  - move the frame")
    print("  /jiloot reset  - reset frame position")
    print("  /jiloot clear  - remove all rows")
    print("  /jiloot toggle  - enable/disable the frame")
    print("  /jiloot bl <item|currency|rep> <id, link or name>  - toggle blacklist entry")
    print("  /jiloot bl list  - show the blacklist")
end

local KIND_ALIASES = {
    item = "items", items = "items", i = "items",
    currency = "currencies", currencies = "currencies", cur = "currencies", c = "currencies",
    rep = "factions", reputation = "factions", faction = "factions", factions = "factions", r = "factions",
}

local function BlacklistCommand(rest)
    local sub, arg = rest:match("^(%S*)%s*(.-)$")
    sub = (sub or ""):lower()
    if sub == "" or sub == "list" then
        ns.Print("blacklist:")
        local any = false
        for _, kind in ipairs(ns.BLACKLIST_KINDS) do
            for key in pairs(ns.db.blacklist[kind]) do
                any = true
                local label = key
                if kind == "items" then
                    label = select(2, ns.GetItemInfo(key)) or ("item " .. key)
                end
                print("  " .. kind .. ": " .. tostring(label))
            end
        end
        if not any then print("  (empty)") end
        return
    end
    local kind = KIND_ALIASES[sub]
    if not kind then
        Help()
        return
    end
    local key = ns:ParseBlacklistInput(kind, arg)
    if key == nil then
        ns.Print("could not read", kind, "from", arg)
        return
    end
    local now = not ns:IsBlacklisted(kind, key)
    ns:SetBlacklisted(kind, key, now)
    ns.Print(now and "blacklisted" or "removed from blacklist", kind, tostring(key))
end

SLASH_JILOOT1 = "/jiloot"
SLASH_JILOOT2 = "/jloot"
SlashCmdList.JILOOT = function(input)
    input = input and strtrim(input) or ""
    local cmd, rest = input:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "" or cmd == "options" or cmd == "config" then
        ns.Options:Toggle()
    elseif cmd == "test" then
        ns.Display:Test()
    elseif cmd == "unlock" then
        ns.Display:SetLocked(false)
    elseif cmd == "lock" then
        ns.Display:SetLocked(true)
    elseif cmd == "reset" then
        ns.db.point = ns.DeepCopy(ns.defaults.point)
        ns.Display:ApplySettings()
        ns.Print("position reset")
    elseif cmd == "clear" then
        ns.Display:Clear()
    elseif cmd == "toggle" then
        ns.db.enabled = not ns.db.enabled
        if not ns.db.enabled then ns.Display:Clear() end
        ns.Print(ns.db.enabled and "enabled" or "disabled")
    elseif cmd == "bl" or cmd == "blacklist" then
        BlacklistCommand(rest)
    elseif cmd == "debug" then
        ns.db.debug = not ns.db.debug
        ns.Print("debug", ns.db.debug and "on" or "off")
    else
        Help()
    end
end
