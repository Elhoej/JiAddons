local _, ns = ...

-- FuXPFu: a thin experience bar (or watched reputation) along the edge of
-- the bar, with the rested part in another colour and a glowing spark. In
-- JiBar the plugin shows text ("XP 62% (+15%)") where FuXP had an icon.

local floor = math.floor

local P = ns.RegisterPlugin({
    id = "Experience",
    title = "Experience",
    place = { bar = 1, side = "RIGHT", order = 2 },
    defaults = {
        mode = "AUTO",
        prefix = true,
        decimals = 0,
        showValues = false,
        showRested = true,
        showRemaining = false,
        showBar = true,
        thickness = 2,
        sparkAlpha = 1,
        shadow = true,
        xpColor = { 0, 0.4, 0.9 },
        restColor = { 1, 0.2, 1 },
        emptyColor = { 0.3, 0.3, 0.3 },
        emptyAlpha = 0,
    },
})

local MODES = {
    { key = "AUTO", name = "Reputation when watching a faction" },
    { key = "XP", name = "Always experience" },
    { key = "REP", name = "Always reputation" },
}

P.options = {
    { type = "select", key = "mode", label = "Show", values = MODES },
    { type = "header", label = "Text" },
    { type = "toggle", key = "prefix", label = "\"XP\" / \"Rep\" label" },
    { type = "select", key = "decimals", label = "Percent decimals", values = {
        { key = 0, name = "62%" }, { key = 1, name = "62.4%" }, { key = 2, name = "62.41%" } } },
    { type = "toggle", key = "showValues", label = "Current / needed" },
    { type = "toggle", key = "showRested", label = "Rested experience" },
    { type = "toggle", key = "showRemaining", label = "Amount still needed" },
    { type = "header", label = "Bar along the edge" },
    { type = "toggle", key = "showBar", label = "Show the bar" },
    { type = "range", key = "thickness", label = "Thickness", min = 1, max = 8, step = 0.5, presets = { 1, 1.5, 2, 3, 4, 6, 8 } },
    { type = "range", key = "sparkAlpha", label = "Spark brightness", min = 0, max = 1, step = 0.05,
      presets = { 0, 0.25, 0.5, 0.75, 1 }, fmt = function(v) return floor(v * 100 + 0.5) .. "%" end },
    { type = "toggle", key = "shadow", label = "Shadow" },
    { type = "color", key = "xpColor", label = "Experience colour" },
    { type = "color", key = "restColor", label = "Rested colour" },
    { type = "color", key = "emptyColor", label = "Empty colour" },
    { type = "range", key = "emptyAlpha", label = "Empty opacity", min = 0, max = 1, step = 0.05,
      presets = { 0, 0.25, 0.5, 0.75, 1 }, fmt = function(v) return floor(v * 100 + 0.5) .. "%" end },
}

local function N(v)
    if ns.IsSecret(v) or type(v) ~= "number" then return 0 end
    return v
end

local function AtMaxLevel()
    if IsPlayerAtEffectiveMaxLevel then return IsPlayerAtEffectiveMaxLevel() end
    local max = GetMaxPlayerLevel and GetMaxPlayerLevel() or 60
    return UnitLevel("player") >= max
end

-- { name, standing, min, max, value } for the watched faction, or nil.
local function WatchedFaction()
    if C_Reputation and C_Reputation.GetWatchedFactionData then
        local d = C_Reputation.GetWatchedFactionData()
        if type(d) == "table" and d.name and d.name ~= "" then
            return { name = d.name, standing = d.reaction, min = N(d.currentReactionThreshold),
                max = N(d.nextReactionThreshold), value = N(d.currentStanding) }
        end
    elseif GetWatchedFactionInfo then
        local name, standing, min, max, value = GetWatchedFactionInfo()
        if name then return { name = name, standing = standing, min = min, max = max, value = value } end
    end
end

-- Current data: { kind = "XP"|"REP"|"MAX", ... }.
function P:Data()
    local mode = self.db.mode
    local faction = mode ~= "XP" and WatchedFaction()
    if faction and (mode == "REP" or mode == "AUTO") then
        local span = math.max(1, faction.max - faction.min)
        return { kind = "REP", name = faction.name, standing = faction.standing,
            cur = faction.value - faction.min, max = span, rested = 0 }
    end
    if AtMaxLevel() or (IsXPUserDisabled and IsXPUserDisabled()) then
        return { kind = "MAX", cur = 0, max = 1, rested = 0 }
    end
    return { kind = "XP", cur = N(UnitXP("player")), max = math.max(1, N(UnitXPMax("player"))),
        rested = N(GetXPExhaustion and GetXPExhaustion() or 0) }
end

function P:Percent(value, max)
    return string.format("%." .. (self.db.decimals or 0) .. "f%%", value / max * 100)
end

local function Short(n)
    if n >= 1000000 then return string.format("%.1fM", n / 1000000) end
    if n >= 10000 then return string.format("%.1fk", n / 1000) end
    return tostring(floor(n))
end

function P:UpdateText()
    local db = self.db
    local d = self:Data()
    self.data = d
    local parts = {}
    if d.kind == "MAX" then
        parts[1] = (db.prefix and "XP " or "") .. "max"
    else
        local label = d.kind == "XP" and "XP" or "Rep"
        -- Rested experience belongs to the percentage: "XP 62% +15%".
        local percent = (db.prefix and (label .. " ") or "") .. self:Percent(d.cur, d.max)
        if d.kind == "XP" and db.showRested and d.rested > 0 then
            local c = db.restColor
            percent = percent .. " " .. ns.Color("+" .. self:Percent(d.rested, d.max), c[1], c[2], c[3])
        end
        parts[#parts + 1] = percent
        if db.showValues then parts[#parts + 1] = Short(d.cur) .. "/" .. Short(d.max) end
        if db.showRemaining then parts[#parts + 1] = Short(d.max - d.cur) .. " to go" end
    end
    self:SetText(ns.Join(parts))
    self:UpdateBar()
end

function P:OnEnable()
    self:RegisterEvent("PLAYER_XP_UPDATE", "Update")
    self:RegisterEvent("UPDATE_EXHAUSTION", "Update")
    self:RegisterEvent("PLAYER_LEVEL_UP", "Update")
    self:RegisterEvent("UPDATE_FACTION", "Update")
    self:RegisterEvent("PLAYER_UPDATE_RESTING", "Update")
end

-------------------------------------------------------------------------------
-- The bar along the edge of the JiBar bar
-------------------------------------------------------------------------------

local TEX = ns.MEDIA .. "XP\\"

function P:CreateBar()
    local b = CreateFrame("Frame", nil, UIParent)
    b.empty = b:CreateTexture(nil, "BACKGROUND")
    b.xp = b:CreateTexture(nil, "ARTWORK")
    b.rest = b:CreateTexture(nil, "ARTWORK")
    for _, t in ipairs({ b.empty, b.xp, b.rest }) do t:SetTexture(TEX .. "texture") end
    b.spark = b:CreateTexture(nil, "OVERLAY")
    b.spark:SetTexture(TEX .. "glow")
    b.spark:SetBlendMode("ADD")
    b.spark2 = b:CreateTexture(nil, "OVERLAY")
    b.spark2:SetTexture(TEX .. "glow2")
    b.spark2:SetBlendMode("ADD")
    b.shadow = b:CreateTexture(nil, "BACKGROUND")
    b.shadow:SetTexture(TEX .. "border")
    b.shadow:SetVertexColor(0, 0, 0, 1)
    self.edgeBar = b
    return b
end

-- Anchors the edge bar to the inner edge of the plugin's bar (the edge facing
-- the middle of the screen).
function P:OnBarLayout(bar)
    local b = self.edgeBar or self:CreateBar()
    local db = self.db
    if not (db.enabled and db.showBar and bar) then
        b:Hide()
        return
    end
    b:SetParent(bar.frame)
    b:SetFrameLevel(bar.frame:GetFrameLevel() + 5)
    b:ClearAllPoints()
    local top = bar.data.attach == "TOP"
    local edge = top and "BOTTOM" or "TOP"
    local away = top and "TOP" or "BOTTOM"
    b:SetPoint(away .. "LEFT", bar.frame, edge .. "LEFT", 0, 0)
    b:SetPoint(away .. "RIGHT", bar.frame, edge .. "RIGHT", 0, 0)
    b:SetHeight(db.thickness)
    b.shadow:ClearAllPoints()
    b.shadow:SetPoint(away .. "LEFT", b, edge .. "LEFT")
    b.shadow:SetPoint(away .. "RIGHT", b, edge .. "RIGHT")
    b.shadow:SetHeight(5)
    if top then b.shadow:SetTexCoord(1, 0, 0, 1) else b.shadow:SetTexCoord(1, 0, 1, 0) end
    b.shadow:SetShown(db.shadow and true or false)
    b.width = bar.width or bar.frame:GetWidth() or 0
    b:Show()
    self:UpdateBar()
end

function P:OnPlaced()
    if self.bar then self:OnBarLayout(self.bar) end
end

function P:OnSettingChanged()
    if self.bar then self:OnBarLayout(self.bar) end
end

function P:OnDisable()
    if self.edgeBar then self.edgeBar:Hide() end
end

function P:UpdateBar()
    local b = self.edgeBar
    if not b or not b:IsShown() then return end
    local db = self.db
    local d = self.data or self:Data()
    local total = b.width or 0
    local xc, rc, ec = db.xpColor, db.restColor, db.emptyColor
    local xpW = math.min(total, total * d.cur / d.max)
    local restW = math.min(total - xpW, total * (d.rested or 0) / d.max)
    if d.kind == "MAX" then xpW, restW = 0, 0 end
    local function Seg(tex, x, w, c, a)
        tex:ClearAllPoints()
        if w < 0.5 then
            tex:Hide()
            return
        end
        tex:SetPoint("TOPLEFT", b, "TOPLEFT", x, 0)
        tex:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", x, 0)
        tex:SetWidth(w)
        tex:SetVertexColor(c[1], c[2], c[3], a)
        tex:Show()
    end
    Seg(b.xp, 0, xpW, xc, 1)
    Seg(b.rest, xpW, restW, rc, 1)
    Seg(b.empty, xpW + restW, total - xpW - restW, ec, db.emptyAlpha or 0)
    local showSpark = xpW >= 1 and (db.sparkAlpha or 0) > 0
    for _, s in ipairs({ b.spark, b.spark2 }) do
        s:ClearAllPoints()
        s:SetSize(128, db.thickness * 8)
        s:SetPoint("RIGHT", b, "LEFT", xpW + 11, 0)
        s:SetAlpha(db.sparkAlpha or 1)
        s:SetShown(showSpark)
    end
    b.spark:SetVertexColor(xc[1], xc[2], xc[3], 1)
end

-------------------------------------------------------------------------------
-- Tooltip and click
-------------------------------------------------------------------------------

local function Standing(id)
    return _G["FACTION_STANDING_LABEL" .. tostring(id)] or "?"
end

function P:OnTooltip(tip)
    local d = self.data or self:Data()
    if d.kind == "REP" then
        tip:AddTitle(d.name)
        tip:AddLine("Standing", Standing(d.standing))
        tip:AddLine("Reputation", ("%s / %s (%s)"):format(BreakUpLargeNumbers(d.cur), BreakUpLargeNumbers(d.max), self:Percent(d.cur, d.max)))
        tip:AddLine("To the next standing", BreakUpLargeNumbers(d.max - d.cur))
        tip:SetHint("Click to put your reputation into chat.")
    elseif d.kind == "MAX" then
        tip:AddTitle("Experience")
        tip:AddLine("Level " .. UnitLevel("player"), "maximum")
        tip:SetHint("Watch a faction to show its reputation instead.")
    else
        tip:AddTitle("Experience")
        tip:AddLine("Level", UnitLevel("player"))
        tip:AddLine("Experience", ("%s / %s (%s)"):format(BreakUpLargeNumbers(d.cur), BreakUpLargeNumbers(d.max), self:Percent(d.cur, d.max)))
        tip:AddLine("To level", BreakUpLargeNumbers(d.max - d.cur))
        if d.rested > 0 then
            tip:AddLine("Rested", ("%s (%s)"):format(BreakUpLargeNumbers(d.rested), self:Percent(d.rested, d.max)),
                nil, { colors = { nil, { self.db.restColor[1], self.db.restColor[2], self.db.restColor[3] } } })
        end
        if IsResting and IsResting() then tip:AddLine("Resting", "yes") end
        tip:SetHint("Click to put your experience into chat.")
    end
end

function P:OnClick()
    local d = self.data or self:Data()
    local text
    if d.kind == "REP" then
        text = ("%s: %d/%d (%s), %s, %d to go"):format(d.name, d.cur, d.max, self:Percent(d.cur, d.max),
            Standing(d.standing), d.max - d.cur)
    elseif d.kind == "XP" then
        text = ("Level %d: %d/%d XP (%s), %d to go"):format(UnitLevel("player"), d.cur, d.max,
            self:Percent(d.cur, d.max), d.max - d.cur)
    else
        text = ("Level %d"):format(UnitLevel("player"))
    end
    ns.InsertChatText(text)
end
