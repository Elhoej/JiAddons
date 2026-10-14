local _, ns = ...

-- Turns game events into loot entries for the display. Every parser works off
-- Blizzard's own global format strings, so it is locale independent, and every
-- chat payload is checked for secret values before it is touched.

local Sources = {}
ns.Sources = Sources

local QUALITY_KEYS = {
    [0] = "poor", "common", "uncommon", "rare", "epic", "legendary", "artifact", "heirloom", "artifact",
}

-- Display order when sorting by type (higher = closer to the anchor).
Sources.PRIO = {
    money = -1,
    quest = 7,
    currency = 9,
    honor = 9,
    rep = 10,
}

local QUEST_CLASS = Enum and Enum.ItemClass and Enum.ItemClass.Questitem or 12
local WEAPON_CLASS = Enum and Enum.ItemClass and Enum.ItemClass.Weapon or 2
local ARMOR_CLASS = Enum and Enum.ItemClass and Enum.ItemClass.Armor or 4

local ICON_GOLD, ICON_SILVER, ICON_COPPER = 133784, 133786, 133788
local ICON_REP_MODERN, ICON_REP_LEGACY = 236681, 2056011
local ICON_HONOR = 132486

local function Duration(key)
    local d = ns.db.durations[key]
    return tonumber(d) or 5
end

-------------------------------------------------------------------------------
-- De-duplication between sources (chat loot vs. encounter loot events)
-------------------------------------------------------------------------------

local recent = {}

-- Returns true when the same thing was already reported by a different source
-- within the last couple of seconds.
local function SeenFromOtherSource(key, source)
    local now = GetTime()
    for k, v in pairs(recent) do
        if now - v.time > 3 then recent[k] = nil end
    end
    local prev = recent[key]
    if prev and prev.source ~= source and now - prev.time <= 3 then
        return true
    end
    recent[key] = { time = now, source = source }
    return false
end

-------------------------------------------------------------------------------
-- Items
-------------------------------------------------------------------------------

local SOCKET_ICONS = {
    { "EMPTY_SOCKET_META", 136257 },
    { "EMPTY_SOCKET_RED", 136258 },
    { "EMPTY_SOCKET_YELLOW", 136259 },
    { "EMPTY_SOCKET_BLUE", 136256 },
    { "EMPTY_SOCKET_PRISMATIC", 458977 },
    { "EMPTY_SOCKET_DOMINATION", 4095404 },
    { "EMPTY_SOCKET_CYPHER", 407324 },
}

local TERTIARY = {
    { "ITEM_MOD_CR_AVOIDANCE_SHORT", "Avoidance" },
    { "ITEM_MOD_CR_LIFESTEAL_SHORT", "Leech" },
    { "ITEM_MOD_CR_SPEED_SHORT", "Speed" },
    { "ITEM_MOD_CR_STURDINESS_SHORT", "Indestructible" },
}

local function DescribeGear(link)
    local stats = ns.GetItemStats(link)
    if type(stats) ~= "table" then return nil, nil end

    local sockets = ""
    for _, s in ipairs(SOCKET_ICONS) do
        local n = tonumber(stats[s[1]])
        if n and n > 0 then
            sockets = sockets .. string.rep("|T" .. s[2] .. ":0|t", n)
        end
    end
    if sockets ~= "" then
        sockets = sockets .. "|cffff00ffSocket|r"
    end

    local tertiary = {}
    for _, t in ipairs(TERTIARY) do
        if stats[t[1]] then
            local label = _G[t[1]] or t[2]
            tertiary[#tertiary + 1] = "|cff00ffff" .. label .. "|r"
        end
    end

    return (#tertiary > 0) and table.concat(tertiary, " ") or nil,
        (sockets ~= "") and sockets or nil
end

local function ProfessionQualityAtlas(link)
    if C_TradeSkillUI and C_TradeSkillUI.GetItemReagentQualityByItemInfo then
        local ok, tier = pcall(C_TradeSkillUI.GetItemReagentQualityByItemInfo, link)
        if ok and tonumber(tier) and tier > 0 then
            return "Professions-Icon-Quality-Tier" .. tier .. "-Small"
        end
    end
end

function Sources:BuildItemEntry(link, count)
    local name, _, quality, _, _, _, _, _, equipLoc, icon, sellPrice, classID =
        ns.GetItemInfo(link)
    if not name then return nil end

    local itemID = ns.GetItemInfoInstant(link)
    quality = tonumber(quality) or 1
    local isQuest = classID == QUEST_CLASS
    local isGear = (classID == WEAPON_CLASS or classID == ARMOR_CLASS)
        and equipLoc ~= nil and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE"

    local durationKey = isQuest and "quest" or QUALITY_KEYS[quality] or "common"
    local displayQuality = isQuest and 7 or quality
    local _, _, _, hex = ns.QualityColor(displayQuality)

    local entry = {
        kind = "item",
        key = "item:" .. link,
        link = link,
        itemID = itemID,
        name = name,
        icon = icon,
        quality = displayQuality,
        colorHex = hex,
        count = count,
        unitPrice = tonumber(sellPrice) or 0,
        duration = Duration(durationKey),
        prio = isQuest and Sources.PRIO.quest or quality,
        isGear = isGear,
        profQuality = ProfessionQualityAtlas(link),
    }

    if isGear then
        entry.ilvl = ns.GetDetailedItemLevel(link)
        entry.tertiary, entry.sockets = DescribeGear(link)
    end
    return entry
end

function Sources:AddItem(link, count, source)
    if not ns.db.enabled then return end
    count = tonumber(count) or 1
    local itemID = ns.GetItemInfoInstant(link)
    if ns:IsBlacklisted("items", itemID) then return end
    if SeenFromOtherSource("item:" .. (itemID or link), source) then return end

    local function Build(tries)
        local entry = Sources:BuildItemEntry(link, count)
        if entry then
            if entry.duration > 0 then
                ns.Display:Push(entry)
            end
        elseif tries < 10 then
            -- Item data not cached yet; ask for it and retry shortly.
            if C_Item and C_Item.RequestLoadItemDataByID and itemID then
                C_Item.RequestLoadItemDataByID(itemID)
            end
            C_Timer.After(0.2, function() Build(tries + 1) end)
        end
    end
    Build(0)
end

local LOOT_FORMATS = {
    { "LOOT_ITEM_SELF_MULTIPLE", kind = "loot" },
    { "LOOT_ITEM_SELF", kind = "loot" },
    { "LOOT_ITEM_BONUS_ROLL_SELF_MULTIPLE", kind = "loot" },
    { "LOOT_ITEM_BONUS_ROLL_SELF", kind = "loot" },
    { "LOOT_ITEM_PUSHED_SELF_MULTIPLE", kind = "pushed" },
    { "LOOT_ITEM_PUSHED_SELF", kind = "pushed" },
    { "LOOT_ITEM_CREATED_SELF_MULTIPLE", kind = "created" },
    { "LOOT_ITEM_CREATED_SELF", kind = "created" },
    { "LOOT_ITEM_REFUND_MULTIPLE", kind = "pushed" },
    { "LOOT_ITEM_REFUND", kind = "pushed" },
}

function Sources:ParseLootMessage(msg)
    for _, fmt in ipairs(self.lootFormats) do
        local args = ns.MatchFormat(fmt, msg)
        if args then
            local link = ns.ExtractItemLink(args[1])
            if link then
                return link, tonumber(args[2]) or 1, fmt.kind
            end
        end
    end
end

function Sources:CHAT_MSG_LOOT(msg)
    msg = ns.SafeString(msg)
    if not msg then return end
    local link, count, kind = self:ParseLootMessage(msg)
    if not link then return end
    if kind == "created" and not ns.db.showCreated then return end
    if kind == "pushed" and not ns.db.showPushed then return end
    self:AddItem(link, count, "chat")
end

function Sources:ENCOUNTER_LOOT_RECEIVED(_, itemID, itemLink, quantity, playerName)
    itemLink = ns.SafeString(itemLink)
    playerName = ns.SafeString(playerName)
    if not itemLink or not playerName then return end
    local me = UnitName("player")
    if ns.IsSecret(me) or Ambiguate(playerName, "short") ~= me then return end
    self:AddItem(itemLink, quantity, "encounter")
end

-------------------------------------------------------------------------------
-- Money
-------------------------------------------------------------------------------

function Sources:PLAYER_MONEY()
    local money = GetMoney()
    if ns.IsSecret(money) then return end
    local last = self.lastMoney
    self.lastMoney = money
    if not last or not ns.db.enabled or not ns.db.showMoney then return end
    local delta = money - last
    if delta <= 0 then return end
    local duration = Duration("money")
    if duration <= 0 then return end
    ns.Display:Push({
        kind = "money",
        key = "money",
        name = MONEY or "Money",
        icon = ICON_GOLD,
        quality = 1,
        colorHex = "ffffffff",
        count = 1,
        value = delta,
        duration = duration,
        prio = Sources.PRIO.money,
    })
end

function Sources.MoneyIcon(value)
    if value >= 10000 then return ICON_GOLD end
    if value >= 100 then return ICON_SILVER end
    return ICON_COPPER
end

-------------------------------------------------------------------------------
-- Currencies
-------------------------------------------------------------------------------

local currencyCache = {}

local function GetCurrencyInfo(id)
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        return C_CurrencyInfo.GetCurrencyInfo(id)
    end
end

function Sources:CacheCurrencies()
    if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize) then return end
    for i = 1, C_CurrencyInfo.GetCurrencyListSize() do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)
        local link = C_CurrencyInfo.GetCurrencyListLink and C_CurrencyInfo.GetCurrencyListLink(i)
        local id = link and tonumber(link:match("currency:(%d+)"))
        if info and id and not info.isHeader then
            currencyCache[id] = info.quantity
        end
    end
end

local function IsHonor(id, name)
    local honorID = Constants and Constants.CurrencyConsts and Constants.CurrencyConsts.HONOR_CURRENCY_ID
    return (honorID and id == honorID) or (HONOR and name == HONOR)
end

function Sources.CurrencySuffix(info)
    if not info or not info.quantity then return nil end
    local qty, max, earned = info.quantity, tonumber(info.maxQuantity) or 0, info.totalEarned
    local capped
    local inner
    if info.useTotalEarnedForMaxQty and earned and max > 0 then
        capped = earned >= max
        inner = qty .. "  " .. earned .. " / " .. max
    elseif max > 0 then
        capped = qty >= max
        inner = qty .. " / " .. max
    else
        inner = tostring(qty)
    end
    if capped then inner = "|cffff0000" .. inner .. "|r" end
    return " |cffffffff(|r" .. inner .. "|cffffffff)|r"
end

function Sources:CURRENCY_DISPLAY_UPDATE(currencyID, quantity, quantityChange)
    if ns.IsSecret(currencyID) or ns.IsSecret(quantity) or ns.IsSecret(quantityChange) then return end
    currencyID = tonumber(currencyID)
    if not currencyID then return end

    local info = GetCurrencyInfo(currencyID)
    local newQty = tonumber(quantity) or (info and info.quantity)
    local delta = tonumber(quantityChange)
    if not delta and newQty and currencyCache[currencyID] then
        delta = newQty - currencyCache[currencyID]
    end
    if newQty then currencyCache[currencyID] = newQty end

    if not delta or delta <= 0 or not info or not ns.db.enabled then return end
    if ns:IsBlacklisted("currencies", currencyID) then return end

    local honor = IsHonor(currencyID, info.name)
    if honor then
        if not ns.db.showHonor or SeenFromOtherSource("honor", "currency") then return end
    elseif not ns.db.showCurrency then
        return
    end

    local duration = Duration(honor and "honor" or "currency")
    if duration <= 0 then return end

    local quality = tonumber(info.quality) or 6
    if quality < 1 then quality = 6 end
    local _, _, _, hex = ns.QualityColor(honor and 6 or quality)
    ns.Display:Push({
        kind = "currency",
        key = honor and "honor" or ("currency:" .. currencyID),
        currencyID = currencyID,
        name = info.name,
        icon = info.iconFileID,
        quality = quality,
        colorHex = hex,
        count = delta,
        suffix = Sources.CurrencySuffix(info),
        duration = duration,
        prio = Sources.PRIO.currency,
    })
end

-------------------------------------------------------------------------------
-- Honor (classic-style honor messages)
-------------------------------------------------------------------------------

local HONOR_FORMATS = {
    { "COMBATLOG_HONORGAIN" },
    { "COMBATLOG_HONORGAIN_NO_RANK" },
    { "COMBATLOG_HONORGAIN_EXHAUSTION1" },
    { "COMBATLOG_HONORAWARD" },
}

function Sources:CHAT_MSG_COMBAT_HONOR_GAIN(msg)
    msg = ns.SafeString(msg)
    if not msg or not ns.db.enabled or not ns.db.showHonor then return end
    local amount
    for _, fmt in ipairs(self.honorFormats) do
        local args = ns.MatchFormat(fmt, msg)
        if args then
            -- Honor points are the last numeric argument in every variant.
            for i = #fmt.positions, 1, -1 do
                local v = args[fmt.positions[i]]
                if type(v) == "number" then
                    amount = v
                    break
                end
            end
            if amount then break end
        end
    end
    if not amount then
        amount = tonumber(msg:match("(%d+)[^%d]*$"))
    end
    if not amount or amount <= 0 then return end
    if SeenFromOtherSource("honor", "chat") then return end
    local duration = Duration("honor")
    if duration <= 0 then return end
    local _, _, _, hex = ns.QualityColor(6)
    ns.Display:Push({
        kind = "honor",
        key = "honor",
        name = HONOR or "Honor",
        icon = ICON_HONOR,
        quality = 6,
        colorHex = hex,
        count = amount,
        duration = duration,
        prio = Sources.PRIO.honor,
    })
end

-------------------------------------------------------------------------------
-- Reputation
-------------------------------------------------------------------------------

local REP_FORMATS = {
    { "FACTION_STANDING_INCREASED", sign = 1 },
    { "FACTION_STANDING_INCREASED_ACH_BONUS", sign = 1 },
    { "FACTION_STANDING_INCREASED_BONUS", sign = 1 },
    { "FACTION_STANDING_INCREASED_DOUBLE_BONUS", sign = 1 },
    { "FACTION_STANDING_INCREASED_ACCOUNT_WIDE", sign = 1 },
    { "FACTION_STANDING_INCREASED_ACH_BONUS_ACCOUNT_WIDE", sign = 1 },
    { "FACTION_STANDING_INCREASED_GENERIC", sign = 1 },
    { "FACTION_STANDING_DECREASED", sign = -1 },
    { "FACTION_STANDING_DECREASED_ACCOUNT_WIDE", sign = -1 },
    { "FACTION_STANDING_DECREASED_GENERIC", sign = -1 },
}

local factions = {} -- [name] = { factionID, index, earned, bottom, top, reaction, label }

local function ReadFaction(index)
    if C_Reputation and C_Reputation.GetFactionDataByIndex then
        local d = C_Reputation.GetFactionDataByIndex(index)
        if not d or not d.name then return nil end
        return {
            name = d.name,
            factionID = d.factionID,
            isHeader = d.isHeader and not d.isHeaderWithRep,
            reaction = d.reaction,
            earned = d.currentStanding,
            bottom = d.currentReactionThreshold,
            top = d.nextReactionThreshold,
        }
    elseif GetFactionInfo then
        local name, _, standing, bottom, top, earned, _, _, isHeader, _, hasRep, _, _, factionID =
            GetFactionInfo(index)
        if not name then return nil end
        return {
            name = name,
            factionID = factionID,
            isHeader = isHeader and not hasRep,
            reaction = standing,
            earned = earned,
            bottom = bottom,
            top = top,
        }
    end
end

local function NumFactions()
    if C_Reputation and C_Reputation.GetNumFactions then
        return C_Reputation.GetNumFactions()
    elseif GetNumFactions then
        return GetNumFactions()
    end
    return 0
end

function Sources:ScanFactions()
    for i = 1, NumFactions() do
        local f = ReadFaction(i)
        if f and not f.isHeader then
            factions[f.name] = f
        end
    end
end

local function ExpandFactionHeaders()
    if C_Reputation and C_Reputation.ExpandAllFactionHeaders then
        C_Reputation.ExpandAllFactionHeaders()
    elseif ExpandAllFactionHeaders then
        ExpandAllFactionHeaders()
    end
end

local function StandingLabel(reaction)
    reaction = tonumber(reaction)
    if not reaction then return "" end
    local label
    if GetText then
        label = GetText("FACTION_STANDING_LABEL" .. reaction, UnitSex("player"))
    end
    return label or _G["FACTION_STANDING_LABEL" .. reaction] or ""
end

-- Refreshes one faction, applying friendship / renown / paragon overrides when
-- the client supports them. Returns the faction record or nil.
function Sources:UpdateFaction(name)
    local before = factions[name]
    self:ScanFactions()
    if not factions[name] then
        ExpandFactionHeaders()
        self:ScanFactions()
    end
    local f = factions[name]
    if not f then return nil, before end

    f.label = StandingLabel(f.reaction)
    local id = f.factionID
    if id and id > 0 then
        if C_GossipInfo and C_GossipInfo.GetFriendshipReputation then
            local fr = C_GossipInfo.GetFriendshipReputation(id)
            if fr and fr.friendshipFactionID and fr.friendshipFactionID > 0 then
                f.bottom, f.top, f.earned = fr.reactionThreshold, fr.nextThreshold, fr.standing
                f.label = fr.reaction or f.label
            end
        end
        if C_Reputation and C_Reputation.IsMajorFaction and C_Reputation.IsMajorFaction(id)
            and C_MajorFactions and C_MajorFactions.GetMajorFactionData then
            local mf = C_MajorFactions.GetMajorFactionData(id)
            if mf and mf.renownLevelThreshold then
                f.bottom, f.top, f.earned = 0, mf.renownLevelThreshold, mf.renownReputationEarned
                f.label = (RENOWN_LEVEL_LABEL and RENOWN_LEVEL_LABEL:format(mf.renownLevel))
                    or ("Renown " .. tostring(mf.renownLevel))
            end
        end
        if C_Reputation and C_Reputation.IsFactionParagon and C_Reputation.IsFactionParagon(id) then
            local value, threshold, _, pending = C_Reputation.GetFactionParagonInfo(id)
            if value and threshold and threshold > 0 then
                local level = math.floor(value / threshold) - (pending and 1 or 0)
                f.bottom, f.top, f.earned = 0, threshold, value - level * threshold
                f.label = "Paragon " .. level
            end
        end
    end
    return f, before
end

function Sources.FactionSuffix(f)
    if not f or not f.earned or not f.bottom or not f.top then return nil end
    local have = f.earned - f.bottom
    local need = f.top - f.bottom
    local text = " |cffffffff(" .. have .. " / " .. need .. ")|r"
    if f.label and f.label ~= "" then
        text = text .. " |cffb0b0b0" .. f.label .. "|r"
    end
    return text
end

function Sources:CHAT_MSG_COMBAT_FACTION_CHANGE(msg)
    msg = ns.SafeString(msg)
    if not msg or not ns.db.enabled or not ns.db.showRep then return end

    local faction, amount
    for _, fmt in ipairs(self.repFormats) do
        local args = ns.MatchFormat(fmt, msg)
        if args and type(args[1]) == "string" then
            faction = args[1]
            amount = tonumber(args[2])
            if amount then amount = amount * fmt.sign end
            break
        end
    end
    if not faction then return end
    if ns:IsBlacklisted("factions", faction) then return end

    local f, before = self:UpdateFaction(faction)
    if not amount and f and before and f.earned and before.earned then
        amount = f.earned - before.earned
    end
    if not amount or amount == 0 then return end

    local duration = Duration("rep")
    if duration <= 0 then return end
    local _, _, _, hex = ns.QualityColor(7)
    ns.Display:Push({
        kind = "rep",
        key = "rep:" .. faction,
        factionName = faction,
        name = faction .. " " .. (REPUTATION_ABBR or "Rep"),
        icon = (C_Reputation and C_Reputation.GetFactionDataByIndex) and ICON_REP_MODERN or ICON_REP_LEGACY,
        quality = 7,
        colorHex = hex,
        count = amount,
        suffix = Sources.FactionSuffix(f),
        duration = duration,
        prio = Sources.PRIO.rep,
    })
end

-------------------------------------------------------------------------------
-- Setup
-------------------------------------------------------------------------------

function Sources:Init()
    self.lootFormats = ns.CompileFormats(LOOT_FORMATS)
    self.repFormats = ns.CompileFormats(REP_FORMATS)
    self.honorFormats = ns.CompileFormats(HONOR_FORMATS)

    local function Bind(event)
        ns:RegisterEvent(event, function(_, ...) Sources[event](Sources, ...) end)
    end
    Bind("CHAT_MSG_LOOT")
    Bind("ENCOUNTER_LOOT_RECEIVED")
    Bind("PLAYER_MONEY")
    Bind("CURRENCY_DISPLAY_UPDATE")
    Bind("CHAT_MSG_COMBAT_FACTION_CHANGE")
    Bind("CHAT_MSG_COMBAT_HONOR_GAIN")

    ns:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        local money = GetMoney()
        if not ns.IsSecret(money) then Sources.lastMoney = money end
        Sources:ScanFactions()
        Sources:CacheCurrencies()
    end)
end
