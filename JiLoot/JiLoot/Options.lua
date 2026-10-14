local _, ns = ...

-- Options window, built with the shared widget toolkit (Shared/Widgets.lua).

local Options = {}
ns.Options = Options

local W = ns.Widgets
local WIDTH, HEIGHT = 640, 580
local CONTENT_WIDTH = WIDTH - 48
local window

local function db() return ns.db end

local function Opt(key)
    return function() return db()[key] end, function(v) db()[key] = v end
end

local function Pct(v) return math.floor(v * 100 + 0.5) .. "%" end

local function QualityLabel(q, text)
    return "|c" .. select(4, ns.QualityColor(q)) .. text .. "|r"
end

function Options:BuildContent(content)
    local L = W.NewLayout(content, CONTENT_WIDTH)
    local c = content
    local S = self.set

    L:Header("General")
    L:Row(S:Checkbox(c, "Enable loot frame", "Show loot, money, currency and reputation rows.", Opt("enabled")),
        S:Checkbox(c, "Lock frame", "Unlock to drag the frame around.",
            function() return db().locked end, function(v) ns.Display:SetLocked(v) end))
    L:Row(S:Checkbox(c, "Animations", "Fade and slide rows in and out.", Opt("animations")),
        S:Checkbox(c, "Timer bar", "Show a thin bar with the time left on each row.", Opt("showTimerBar")))
    L:Row(S:Checkbox(c, "Tooltips on hover", "Show the item tooltip when hovering a row. Hovering always pauses the timer.",
            Opt("showTooltip")),
        S:Checkbox(c, "Click-through", "Rows ignore the mouse (no tooltips, dismissing or linking).", Opt("clickThrough")))
    L:Row(S:Cycle(c, "Grow direction", { "Down", "Up" }, nil,
            function() return db().growUp and 2 or 1 end, function(v) db().growUp = (v == 2) end),
        S:Cycle(c, "Sort rows", { "By type and quality", "Newest first", "Oldest first" },
            "By type puts reputation, currencies and the best items nearest the anchor, money last.",
            Opt("sortMode")))
    L:Row(S:Slider(c, "Max rows", 1, 25, 1, Opt("maxRows")),
        S:Slider(c, "Scale", 0.5, 2, 0.05, function() return db().scale end, function(v) db().scale = v end, Pct))
    L:Row(S:Slider(c, "Row width", 200, 700, 10, Opt("width")),
        S:Slider(c, "Row height", 20, 64, 1, Opt("height")))
    L:Row(S:Slider(c, "Font size", 8, 24, 1, Opt("fontSize")),
        S:Slider(c, "Background opacity", 0, 1, 0.05, function() return db().bgAlpha end,
            function(v) db().bgAlpha = v end, Pct))
    L:Row(S:Slider(c, "Row spacing", 0, 20, 1, Opt("spacing")),
        S:Slider(c, "Max name length", 0, 60, 1,
            function() return db().maxNameLength end, function(v) db().maxNameLength = v end,
            function(v) return v == 0 and "no limit" or tostring(v) end))

    L:Header("Sources")
    L:Row(S:Checkbox(c, "Money", "Show gold gained from looting, quests and selling.", Opt("showMoney")),
        S:Checkbox(c, "Currencies", nil, Opt("showCurrency")))
    L:Row(S:Checkbox(c, "Reputation", "Show reputation gains and losses with your current standing.", Opt("showRep")),
        S:Checkbox(c, "Honor", nil, Opt("showHonor")))
    L:Row(S:Checkbox(c, "Crafted items", "Items you create yourself.", Opt("showCreated")),
        S:Checkbox(c, "Received items", "Quest rewards, purchases and other items pushed into your bags.",
            Opt("showPushed")))
    L:Row(S:Checkbox(c, "Show bag count", "Append how many of a non-gear item you now have in your bags.",
        Opt("invCount")))

    L:Header("Loot window")
    L:Row(S:Checkbox(c, "Hide loot window when auto-looting",
        "With auto-loot on, take everything and keep Blizzard's loot window out of sight. It still appears for bind-on-pickup items, loot rolls, or when something can't be looted (e.g. full bags).",
        Opt("hideLootWindow")))

    L:Header("Display duration (seconds, 0 hides)")
    local function D(q, key, text)
        local label = q and QualityLabel(q, text) or text
        return S:Input(c, label, 150, nil, function() return db().durations[key] end,
            function(v) db().durations[key] = v end, true)
    end
    L:Row(D(0, "poor", "Poor"), D(1, "common", "Common"), D(2, "uncommon", "Uncommon"))
    L:Row(D(3, "rare", "Rare"), D(4, "epic", "Epic"), D(5, "legendary", "Legendary"))
    L:Row(D(6, "artifact", "Artifact"), D(7, "heirloom", "Heirloom"), D(7, "quest", "Quest items"))
    L:Row(D(6, "currency", "Currencies"), D(nil, "money", "|cffffff00Money|r"), D(7, "rep", "Reputation"))
    L:Row(D(6, "honor", "Honor"))

    L:Header("Prices")
    L:Row(S:Cycle(c, "Vendor price", { "Unit and stack", "Unit only", "Stack replaces unit" },
            "What vendor prices to show when you loot more than one of an item.", Opt("stackPriceMode")),
        S:Cycle(c, "Auction price", { "Off", "Unit price", "Stack price" },
            "Needs Auctionator (or TradeSkillMaster) with price data.", Opt("ahMode")))
    L:Row(S:Cycle(c, "Auction data from", { "Auctionator", "TradeSkillMaster" }, nil, Opt("ahSource")),
        S:Cycle(c, "TSM value", { "Market value", "Min buyout" }, nil, Opt("tsmSource")))
    L:Row(S:Checkbox(c, "Auction price for junk", nil, Opt("ahJunk")),
        S:Checkbox(c, "Hide silver/copper above 1g", nil, Opt("hideSmallCoins")))
    L:Row(S:Checkbox(c, "Use coin icons", "Show prices with coin icons instead of g/s/c letters.", Opt("coinIcons")))
    L:Row(S:ColorSwatch(c, "Auction price colour", function() return db().ahColor end),
        S:ColorSwatch(c, "Stack price colour", function() return db().stackColor end))

    L:Header("Highlight valuable loot")
    L:Note("Rows glow when the loot is worth at least a threshold (highest of vendor or auction value, times the stack size). A threshold of 0 is off.")
    L:Row(S:Checkbox(c, "Highlight valuable loot", nil, Opt("highlight")),
        S:Checkbox(c, "Play sound at tier 3", nil, Opt("highlightSound")))
    L:Row(S:Cycle(c, "Threshold unit", { "Copper", "Silver", "Gold" }, nil, Opt("highlightUnit")))
    for tier = 1, 3 do
        L:Row(S:Input(c, "Tier " .. tier .. " threshold", 150, nil,
                function() return db().thresholds[tier] end, function(v) db().thresholds[tier] = v end, true),
            S:ColorSwatch(c, "Tier " .. tier .. " glow colour", function() return db().highlightColors[tier] end))
    end

    L:Header("Blacklist")
    L:Note("Blacklisted loot never shows. Alt + right-click a row to blacklist it, or add it here: items and currencies by ID or link, reputations by faction name.")
    local kinds = { "Item", "Currency", "Reputation" }
    local kind = 1
    local kindCycle = S:Cycle(c, "Type", kinds, nil, function() return kind end, function(v) kind = v end)
    local input = S:Input(c, "ID, link or name", 170, nil, nil, nil, false)
    local add = CreateFrame("Frame", nil, c)
    add:SetSize(120, 26)
    local addButton = W.Button(add, "Add", 100, function()
        local listKind = ns.BLACKLIST_KINDS[kind]
        local key = ns:ParseBlacklistInput(listKind, input.box:GetText())
        if key ~= nil then
            ns:SetBlacklisted(listKind, key, true)
            input.box:SetText("")
        end
    end)
    addButton:SetPoint("TOPLEFT", 2, 0)
    L:Row(kindCycle, input)
    L:Row(add)

    self.blacklistTop = L.y
    self.content = c
    self.blacklistRows = {}
    self:RefreshBlacklist()
end

function Options:RefreshBlacklist()
    if not self.content then return end
    for _, r in ipairs(self.blacklistRows) do r:Hide() end
    local labels = { items = "Item", currencies = "Currency", factions = "Reputation" }
    local y = self.blacklistTop
    local i = 0
    for _, kind in ipairs(ns.BLACKLIST_KINDS) do
        local keys = {}
        for key in pairs(db().blacklist[kind]) do keys[#keys + 1] = key end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, key in ipairs(keys) do
            i = i + 1
            local r = self.blacklistRows[i]
            if not r then
                r = CreateFrame("Frame", nil, self.content)
                r:SetSize(CONTENT_WIDTH - 40, 22)
                r.text = W.Font(r:CreateFontString(nil, "OVERLAY"), 12)
                r.text:SetPoint("LEFT", 4, 0)
                r.remove = W.Button(r, "Remove", 80)
                r.remove:SetPoint("RIGHT")
                self.blacklistRows[i] = r
            end
            local label = tostring(key)
            if kind == "items" then
                local name, link = ns.GetItemInfo(key)
                label = (link or name or "item") .. " |cff888888(" .. key .. ")|r"
            elseif kind == "currencies" and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
                local info = C_CurrencyInfo.GetCurrencyInfo(key)
                label = ((info and info.name) or "currency") .. " |cff888888(" .. key .. ")|r"
            end
            r.text:SetText("|cffffd100" .. labels[kind] .. ":|r " .. label)
            r.remove:SetScript("OnClick", function() ns:SetBlacklisted(kind, key, false) end)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 16, y)
            r:Show()
            y = y - 24
        end
    end
    if i == 0 then
        if not self.emptyText then
            self.emptyText = W.Font(self.content:CreateFontString(nil, "OVERLAY"), 12)
            self.emptyText:SetTextColor(0.6, 0.6, 0.6)
        end
        self.emptyText:SetPoint("TOPLEFT", 20, y)
        self.emptyText:SetText("Nothing blacklisted.")
        self.emptyText:Show()
        y = y - 24
    elseif self.emptyText then
        self.emptyText:Hide()
    end
    self.content:SetHeight(-y + 16)
    if self.UpdateScroll then self:UpdateScroll() end
end

function Options:Sync()
    if not window then return end
    self.set:Refresh()
    if self.lockButton then
        self.lockButton:SetText(db().locked and "Unlock" or "Lock")
    end
end

function Options:UpdateScroll()
    if window then window:UpdateScroll() end
end

function Options:Build()
    self.set = W.NewSet(function() ns.Display:ApplySettings() end)
    local content
    window, content = W.CreateWindow({
        name = "JiLootOptionsFrame",
        title = "|cff33ff99JiLoot|r Loot Frame",
        width = WIDTH,
        height = HEIGHT,
        onShow = function() Options:Sync() end,
    })

    self:BuildContent(content)

    -- Footer buttons.
    local test = W.Button(window, "Test", 100, function() ns.Display:Test() end)
    test:SetPoint("BOTTOMLEFT", 12, 12)
    local lock = W.Button(window, "Unlock", 100, function() ns.Display:SetLocked(not db().locked) end)
    lock:SetPoint("LEFT", test, "RIGHT", 8, 0)
    self.lockButton = lock
    local clear = W.Button(window, "Clear rows", 100, function() ns.Display:Clear() end)
    clear:SetPoint("LEFT", lock, "RIGHT", 8, 0)
    local reset = W.Button(window, "Defaults", 100, function()
        if not IsShiftKeyDown() then
            ns.Print("shift-click Defaults to reset all settings (the blacklist is kept)")
            return
        end
        ns:ResetDB()
        ns.Display:ApplySettings()
        Options:Sync()
        ns.Print("settings reset to defaults")
    end)
    reset:SetPoint("BOTTOMRIGHT", -12, 12)
    W.AttachTooltip(reset, "Defaults", "Shift-click to reset every setting. The blacklist is kept.")
end

function Options:Show()
    if not window then self:Build() end
    window:Show()
end

function Options:Toggle()
    if window and window:IsShown() then
        window:Hide()
    else
        self:Show()
    end
end

function Options:Init()
    W.RegisterSettingsPanel({
        title = ns.title,
        description = "All options live in their own window. You can also type /jiloot.",
        icon = 133784,
        open = function() Options:Show() end,
        toggle = function() Options:Toggle() end,
    })
end
