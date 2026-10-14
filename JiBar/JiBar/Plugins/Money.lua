local _, ns = ...

-- MoneyFu: your gold, plus a tooltip with money gained and spent this
-- session, today, yesterday and over the last seven days (per character or
-- for the whole realm), and every character's gold on the realm.

local floor = math.floor

local P = ns.RegisterPlugin({
    id = "Money",
    title = "Money",
    icon = ns.MEDIA .. "Icons\\gold",
    place = { bar = 1, side = "CENTER", order = 5 },
    defaults = {
        showIcon = false,
        style = "LETTERS",
        coloredLetters = false,
        trackByRealm = true,
        showPerHour = true,
        simpleTooltip = false,
        -- realms[realm] = { chars = { [name] = copper }, days = { [day] = { gained, spent, time } } }
        -- chars[realm .. name] = { days = { ... } }
        realms = {},
        chars = {},
    },
})

-- The bags through Blizzard's backpack button (see Plugin.lua).
P.clickTargets = { { target = "MainMenuBarBackpackButton" } }

local STYLES = {
    { key = "LETTERS", name = "123g 45s 67c" },
    { key = "COINS", name = "Coin icons" },
    { key = "GOLD", name = "Gold only (123g)" },
    { key = "SHORT", name = "Short (123.4g)" },
}

P.options = {
    { type = "select", key = "style", label = "Text style", values = STYLES },
    { type = "toggle", key = "coloredLetters", label = "Colour the g, s and c" },
    { type = "toggle", key = "trackByRealm", label = "Cash flow for the whole realm",
      tip = "Off: only this character's cash flow." },
    { type = "toggle", key = "showPerHour", label = "Show amounts per hour" },
    { type = "toggle", key = "simpleTooltip", label = "Simple tooltip", tip = "Only the characters and the total." },
    { type = "execute", label = "Reset this session", func = function(p) p:ResetSession() end },
}

local KEEP_DAYS = 7

local function Key() return (GetRealmName and GetRealmName() or "Realm") end
local function Player() return ns.SafeString((UnitName("player"))) or "Player" end

function P:Stores()
    local realm = Key()
    local db = self.db
    db.realms[realm] = db.realms[realm] or { chars = {}, days = {} }
    local charKey = realm .. "-" .. Player()
    db.chars[charKey] = db.chars[charKey] or { days = {} }
    return db.realms[realm], db.chars[charKey]
end

local function Day(store, day)
    local d = store.days[day]
    if not d then
        d = { gained = 0, spent = 0, time = 0 }
        store.days[day] = d
    end
    return d
end

local function Prune(store, today)
    for day in pairs(store.days) do
        if day <= today - KEEP_DAYS then store.days[day] = nil end
    end
end

function P:ResetSession()
    self.session = { gained = 0, spent = 0, start = time() }
    self:Update()
end

function P:OnEnable()
    self.lastMoney = GetMoney()
    self.lastSave = time()
    self:ResetSession()
    local realm, char = self:Stores()
    local today = ns.Today()
    Prune(realm, today)
    Prune(char, today)
    realm.chars[Player()] = self.lastMoney
    self:RegisterEvent("PLAYER_MONEY", "OnMoney")
    self:RegisterEvent("PLAYER_TRADE_MONEY", "OnMoney")
    self:RegisterEvent("TRADE_MONEY_CHANGED", "OnMoney")
    self:RegisterEvent("SEND_MAIL_MONEY_CHANGED", "OnMoney")
    self:RegisterEvent("SEND_MAIL_COD_CHANGED", "OnMoney")
end

-- Adds played time to today's record, so per-hour figures are honest.
function P:SaveTime()
    local now = time()
    local realm, char = self:Stores()
    local today = ns.Today()
    local delta = now - (self.lastSave or now)
    Day(realm, today).time = Day(realm, today).time + delta
    Day(char, today).time = Day(char, today).time + delta
    self.lastSave = now
end

function P:OnMoney()
    local money = GetMoney()
    local diff = money - (self.lastMoney or money)
    self.lastMoney = money
    local realm, char = self:Stores()
    realm.chars[Player()] = money
    local today = ns.Today()
    self:SaveTime()
    if diff > 0 then
        self.session.gained = self.session.gained + diff
        Day(realm, today).gained = Day(realm, today).gained + diff
        Day(char, today).gained = Day(char, today).gained + diff
    elseif diff < 0 then
        self.session.spent = self.session.spent - diff
        Day(realm, today).spent = Day(realm, today).spent - diff
        Day(char, today).spent = Day(char, today).spent - diff
    end
    self:Update()
end

function P:Format(copper)
    local style = self.db.style
    local coins = style == "COINS" and ns.CoinTextureString(math.abs(copper))
    if coins then
        return copper < 0 and ("-" .. coins) or coins
    elseif style == "GOLD" then
        local g = floor(math.abs(copper) / 10000)
        local text = (BreakUpLargeNumbers and BreakUpLargeNumbers(g) or tostring(g))
            .. (self.db.coloredLetters and "|cffffd700g|r" or "g")
        return copper < 0 and ("-" .. text) or text
    elseif style == "SHORT" then
        local g = copper / 10000
        if math.abs(g) >= 1 then
            return string.format("%.1f", g) .. (self.db.coloredLetters and "|cffffd700g|r" or "g")
        end
    end
    return ns.FormatCoins(copper, { colored = self.db.coloredLetters })
end

function P:UpdateText()
    self:SetText(self:Format(GetMoney()))
end

local function TipMoney(copper)
    return ns.FormatCoins(copper)
end

local function PerHour(amount, seconds)
    if not seconds or seconds < 60 then return nil end
    return TipMoney(floor(amount / seconds * 3600))
end

function P:OnTooltip(tip)
    self:SaveTime()
    tip:AddTitle("Money")
    local realm, char = self:Stores()
    local perHour = self.db.showPerHour
    if not self.db.simpleTooltip then
        local function Block(title, gained, spent, seconds)
            tip:AddHeader(title)
            local profit = gained - spent
            local function Row(label, amount, r, g, b)
                tip:AddLine(label, TipMoney(amount), perHour and PerHour(amount, seconds) or nil,
                    { colors = { { 1, 0.82, 0 }, { r, g, b }, { 0.7, 0.7, 0.7 } } })
            end
            Row("Gained", gained, 1, 1, 1)
            Row("Spent", spent, 1, 1, 1)
            if profit >= 0 then
                Row("Profit", profit, 0.3, 1, 0.3)
            else
                Row("Loss", -profit, 1, 0.3, 0.3)
            end
        end
        local s = self.session
        Block("This session", s.gained, s.spent, time() - s.start)
        local store = self.db.trackByRealm and realm or char
        local today = ns.Today()
        local t = Day(store, today)
        Block("Today", t.gained, t.spent, t.time)
        local y = store.days[today - 1] or { gained = 0, spent = 0, time = 0 }
        Block("Yesterday", y.gained, y.spent, y.time)
        local wg, ws, wt = 0, 0, 0
        for day = today - KEEP_DAYS + 1, today do
            local d = store.days[day]
            if d then wg, ws, wt = wg + d.gained, ws + d.spent, wt + d.time end
        end
        Block("Last 7 days", wg, ws, wt)
    end

    local names = {}
    for name in pairs(realm.chars) do names[#names + 1] = name end
    table.sort(names, function(a, b) return realm.chars[a] > realm.chars[b] end)
    local total = 0
    tip:AddHeader("Characters")
    for _, name in ipairs(names) do
        local copper = realm.chars[name]
        total = total + copper
        tip:AddLine(name, TipMoney(copper), nil, { colors = { name == Player() and { 0.3, 1, 0.3 } or { 1, 1, 1 } } })
    end
    tip:AddSpacer()
    tip:AddLine("Total", TipMoney(total), nil, { colors = { { 1, 1, 1 } } })
    tip:SetHint("Click to open your bags.")
end

function P:OnMenu(root)
    local realm = self:Stores()
    local purge = root:CreateButton("Forget a character")
    local any = false
    for name in pairs(realm.chars) do
        if name ~= Player() then
            any = true
            purge:CreateButton(name, function()
                realm.chars[name] = nil
                self:Update()
            end)
        end
    end
    if not any then purge:CreateTitle("No other characters") end
end

