local _, ns = ...

-- HonorFu: honour earned today and your battleground score ("0 HONOR |
-- 8-5 (62%)"). The tooltip adds honourable kills, honour totals and the
-- score per battleground. Honour is read from the honour currency when the
-- client has one, otherwise counted from the honour chat messages.

local floor = math.floor

local P = ns.RegisterPlugin({
    id = "Honor",
    title = "Honor",
    icon = ns.MEDIA .. "Icons\\honor",
    place = { bar = 1, side = "CENTER", order = 2 },
    defaults = {
        showHonor = true,
        showScore = true,
        showKills = false,
        showPvP = false,
        factionIcon = false,
        honor = {},      -- [day] = honour earned that day
        wins = 0, losses = 0,
        battlegrounds = {}, -- [name] = { wins, losses }
    },
})

-- The group finder (battleground queues), or the character window with its
-- honour tab, through Blizzard's buttons (see Plugin.lua).
P.clickTargets = { { target = { "LFDMicroButton", "CharacterMicroButton" } } }

P.options = {
    { type = "toggle", key = "showHonor", label = "Honour today" },
    { type = "toggle", key = "showScore", label = "Battleground score" },
    { type = "toggle", key = "showKills", label = "Honourable kills today" },
    { type = "toggle", key = "showPvP", label = "PvP flag and timer" },
    { type = "toggle", key = "factionIcon", label = "Faction icon", tip = "Off: FuBar's honour icon." },
    { type = "execute", label = "Reset battleground score", func = function(p) p:ResetScore() end },
}

local function HonorCurrencyID()
    return Constants and Constants.CurrencyConsts and Constants.CurrencyConsts.HONOR_CURRENCY_ID or 1792
end

-- Current honour from the currency, or nil when there is no honour currency.
local function CurrencyHonor()
    if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return nil end
    local info = C_CurrencyInfo.GetCurrencyInfo(HonorCurrencyID())
    if type(info) ~= "table" or not info.name or info.name == "" then return nil end
    local q = info.quantity
    if ns.IsSecret(q) or type(q) ~= "number" then return nil end
    return q, info.maxQuantity
end

function P:Today()
    local day = ns.Today()
    for d in pairs(self.db.honor) do
        if d < day - 7 then self.db.honor[d] = nil end
    end
    return day
end

function P:AddHonor(amount)
    if not amount or amount <= 0 then return end
    local day = self:Today()
    self.db.honor[day] = (self.db.honor[day] or 0) + amount
    self:Update()
end

function P:OnEnable()
    self.lastHonor = CurrencyHonor()
    self.formats = ns.CompileFormats({
        { "COMBATLOG_HONORGAIN" }, { "COMBATLOG_HONORGAIN_NO_RANK" }, { "COMBATLOG_HONORAWARD" },
    })
    self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "OnCurrency")
    self:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN", "OnHonorMessage")
    self:RegisterEvent("PLAYER_PVP_KILLS_CHANGED", "Update")
    self:RegisterEvent("PLAYER_FLAGS_CHANGED", "Update")
    self:RegisterEvent("UNIT_FACTION", "Update")
    self:RegisterEvent("PVP_MATCH_COMPLETE", "CheckMatchEnd")
    self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS", "CheckMatchEnd")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function(p) p.matchRecorded = false end)
    self:UpdateIcon()
end

function P:OnCurrency()
    local now = CurrencyHonor()
    if not now then return end
    if self.lastHonor and now > self.lastHonor then self:AddHonor(now - self.lastHonor) end
    self.lastHonor = now
    self:Update()
end

-- Only used when there is no honour currency to diff.
function P:OnHonorMessage(_, msg)
    if self.lastHonor or not ns.SafeString(msg) then return end
    for _, f in ipairs(self.formats) do
        local args = ns.MatchFormat(f, msg)
        if args then
            local amount
            for _, v in pairs(args) do
                if type(v) == "number" then amount = v end
            end
            self:AddHonor(amount)
            return
        end
    end
end

-- Records a finished battleground once: win if the winning team is ours.
function P:CheckMatchEnd()
    if self.matchRecorded or not GetBattlefieldWinner then return end
    local winner = GetBattlefieldWinner()
    if winner == nil then return end
    local inInstance, kind = IsInInstance()
    if not inInstance or kind ~= "pvp" then return end
    self.matchRecorded = true
    local mine = GetBattlefieldArenaFaction and GetBattlefieldArenaFaction()
    if mine == nil then
        mine = UnitFactionGroup("player") == "Alliance" and 1 or 0
    end
    local won = winner == mine
    local name = GetInstanceInfo and GetInstanceInfo() or GetZoneText()
    local bg = self.db.battlegrounds[name] or { wins = 0, losses = 0 }
    self.db.battlegrounds[name] = bg
    if won then
        self.db.wins, bg.wins = self.db.wins + 1, bg.wins + 1
    else
        self.db.losses, bg.losses = self.db.losses + 1, bg.losses + 1
    end
    self:Update()
end

function P:ResetScore()
    self.db.wins, self.db.losses = 0, 0
    wipe(self.db.battlegrounds)
    self:Update()
end

function P:OnSettingChanged(key)
    if key == "factionIcon" then self:UpdateIcon() end
end

function P:UpdateIcon()
    local faction = UnitFactionGroup("player")
    if self.db.factionIcon and (faction == "Alliance" or faction == "Horde") then
        self:SetIcon("Interface\\FriendsFrame\\PlusManz-" .. faction)
    else
        self:SetIcon(self.icon)
    end
end

local function Score(wins, losses)
    if wins + losses == 0 then return "0-0", 1, 1, 1 end
    local p = wins / (wins + losses)
    local r, g, b = ns.ThresholdColor(p)
    return string.format("%d-%d (%.0f%%)", wins, losses, p * 100), r, g, b
end

function P:PvPStatus()
    if not UnitIsPVP("player") then return "Off", 0.3, 1, 0.3 end
    local ms = GetPVPTimer and GetPVPTimer()
    if IsPVPTimerRunning and IsPVPTimerRunning() and ms and ms > 0 then
        return ns.FormatDuration(ms / 1000), 1, 0.82, 0
    end
    return "On", 1, 0.2, 0.2
end

function P:UpdateText()
    local db = self.db
    local parts = {}
    if db.showHonor then
        parts[#parts + 1] = "|cffffffff" .. (db.honor[self:Today()] or 0) .. " HONOR|r"
    end
    if db.showScore then
        local text, r, g, b = Score(db.wins, db.losses)
        parts[#parts + 1] = ns.Color(text, r, g, b)
    end
    if db.showKills and GetPVPSessionStats then
        parts[#parts + 1] = "|cffffffff" .. (GetPVPSessionStats() or 0) .. " HK|r"
    end
    if db.showPvP then
        local text, r, g, b = self:PvPStatus()
        parts[#parts + 1] = ns.Color("PvP " .. text, r, g, b)
    end
    self:SetText(ns.Join(parts))
end

function P:OnTick()
    if self.db.showPvP and UnitIsPVP("player") then self:UpdateText() end
end

function P:OnTooltip(tip)
    local db = self.db
    tip:AddTitle("Honor")
    local today = self:Today()
    tip:AddHeader("Today")
    if GetPVPSessionStats then
        local hk, dk = GetPVPSessionStats()
        tip:AddLine("Honourable kills", hk or 0)
        if dk and dk > 0 then tip:AddLine("Dishonourable kills", dk) end
    end
    tip:AddLine("Honour earned", db.honor[today] or 0)
    tip:AddHeader("Yesterday")
    if GetPVPYesterdayStats then
        tip:AddLine("Honourable kills", (GetPVPYesterdayStats()) or 0)
    end
    tip:AddLine("Honour earned", db.honor[today - 1] or 0)
    local week = 0
    for day = today - 6, today do week = week + (db.honor[day] or 0) end

    tip:AddHeader("Totals")
    tip:AddLine("Honour, last 7 days", week)
    local current, max = CurrencyHonor()
    if current then
        tip:AddLine("Honour", (max and max > 0) and (current .. " / " .. max) or current)
    end
    if UnitHonorLevel and (UnitHonorLevel("player") or 0) > 0 then
        tip:AddLine("Honour level", UnitHonorLevel("player"))
    end
    if GetPVPLifetimeStats then
        tip:AddLine("Lifetime honourable kills", (GetPVPLifetimeStats()) or 0)
    end
    local status, r, g, b = self:PvPStatus()
    tip:AddLine("PvP", status, nil, { colors = { nil, { r, g, b } } })

    tip:AddHeader("Battlegrounds")
    local text
    text, r, g, b = Score(db.wins, db.losses)
    tip:AddLine("All", text, nil, { colors = { nil, { r, g, b } } })
    local names = {}
    for name in pairs(db.battlegrounds) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local bg = db.battlegrounds[name]
        text, r, g, b = Score(bg.wins, bg.losses)
        tip:AddLine(name, text, nil, { colors = { { 1, 1, 1 }, { r, g, b } } })
    end
    tip:SetHint("Click to open the group finder.")
end

