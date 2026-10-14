local _, ns = ...

-- The five second rule on the player's mana bar, after the "Player frame mana
-- regen" WeakAura (wago.io/tbc-mana-ticker). Spending mana stops spirit regen
-- for 5 seconds: a white spark crosses the bar in those 5 seconds. After that,
-- while mana isn't full, a fainter mana-coloured spark crosses it every
-- 2 seconds, timed to the regen ticks. In cat and bear form the spark runs on
-- the druid mana bar instead.
--
-- Ticks are found by watching mana go up, which needs plain mana values. When
-- the client makes the player's mana secret, the 5 second spark still works:
-- it then goes by the spell's mana cost instead of the mana drop.

local U = ns.Unit
local IsSecret = ns.IsSecret

local S = {}
ns.ManaSpark = S

local RULE = 5          -- seconds without spirit regen after spending mana
local TICK = 2          -- seconds between regen ticks
local CAST_WINDOW = 0.5 -- a mana drop this close to a finished cast is its cost
local SAME_TICK = 1.5   -- gains this soon after a tick are part of it, or aren't ticks
local MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0

S.RULE_COLOR = { 1, 1, 1, 1 }
S.TICK_COLOR = { 0.6, 1, 1, 0.7 }

local state = {
    ruleStart = nil,  -- when the last 5 second rule began
    tickAt = nil,     -- time of a seen regen tick (the 2 second cadence)
    mana = nil,       -- last plain mana value
    dropAt = nil,     -- last time mana went down
    castAt = nil,     -- last time a cast finished
}
S.state = state

-- Whether casts spend mana, read when they're sent (see UNIT_SPELLCAST_SENT).
local pending = {}

-- Bars that can carry the spark: { bar, spark, showsMana = fn }. The first
-- one shown and showing mana gets it.
local hosts = {}

local function Mana()
    local cur, max = UnitPower("player", MANA), UnitPowerMax("player", MANA)
    if IsSecret(cur) or IsSecret(max) then return nil end
    return cur, max
end

local function Positive(v)
    return v ~= nil and not IsSecret(v) and v > 0
end

-- Fallback for secret mana: does the spell cost mana right now? Shapeshifts
-- cost a percentage of base mana, so any of the cost fields counts.
local function CostsMana(spellID)
    if spellID == nil or IsSecret(spellID) or not (C_Spell and C_Spell.GetSpellPowerCost) then return false end
    local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellID)
    if not ok or type(costs) ~= "table" then return false end
    for _, c in ipairs(costs) do
        local kind, name, aura = c.type, c.name, c.requiredAuraID
        local isMana = (not IsSecret(kind) and kind == MANA) or (not IsSecret(name) and name == "MANA")
        local applies = not IsSecret(aura) and (not aura or aura == 0 or c.hasRequiredAura == true)
        if isMana and applies
            and (Positive(c.cost) or Positive(c.minCost) or Positive(c.costPercent) or Positive(c.costPerSec)) then
            return true
        end
    end
    return false
end

-------------------------------------------------------------------------------
-- Drawing
-------------------------------------------------------------------------------

-- Where the spark is (0..1 across the bar), its colour and its host, or nil
-- to hide it.
local function Current(now)
    if not ns.db.manaSpark then return nil end
    if ns.Frames and ns.Frames.testMode then
        -- Unlocked frames loop the sweep so it can be seen without casting.
        return (now % RULE) / RULE, S.RULE_COLOR, hosts[1]
    end
    if U.Bool(UnitIsDeadOrGhost("player")) then return nil end
    local host
    for _, h in ipairs(hosts) do
        if h.bar:IsVisible() and h.showsMana() then
            host = h
            break
        end
    end
    if not host then return nil end
    if state.ruleStart and now < state.ruleStart + RULE then
        return (now - state.ruleStart) / RULE, S.RULE_COLOR, host
    end
    state.ruleStart = nil
    if ns.db.manaTicks and state.tickAt then
        local cur, max = Mana()
        if cur and cur < max then
            return ((now - state.tickAt) % TICK) / TICK, S.TICK_COLOR, host
        end
    end
    return nil
end

local function Draw(now)
    local progress, color, host = Current(now)
    for _, h in ipairs(hosts) do
        if h ~= host then h.spark:Hide() end
    end
    if not host then
        S.driver:Hide()
        return
    end
    local spark, bar = host.spark, host.bar
    spark:ClearAllPoints()
    spark:SetPoint("CENTER", bar, "LEFT", (bar:GetWidth() or 0) * progress, 0)
    spark:SetVertexColor(color[1], color[2], color[3], color[4])
    spark:Show()
end

-- Re-checks what to show and starts the animation if there's something.
function S:Update()
    if not self.driver then return end
    self.driver:Show()
    Draw(GetTime())
end

-- Lets a power bar carry the spark while showsMana() says it shows mana.
-- Returns the spark texture.
function S:Attach(bar, showsMana)
    local h = bar:GetHeight() or 10
    local spark = bar:CreateTexture(nil, "ARTWORK", nil, 7)
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:SetSize(h * 2, h * 2.5)
    spark:Hide()
    hosts[#hosts + 1] = { bar = bar, spark = spark, showsMana = showsMana }
    -- A bar appearing (the druid bar on shifting) may take the spark over.
    local holder = bar.holder or bar
    holder:HookScript("OnShow", function() S:Update() end)
    holder:HookScript("OnHide", function() S:Update() end)
    if not self.driver then
        -- Its own frame, so the OnUpdate stops when nothing moves.
        self.driver = CreateFrame("Frame", nil, UIParent)
        self.driver:SetScript("OnUpdate", function() Draw(GetTime()) end)
    end
    self:Update()
    return spark
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

local function StartRule(now)
    state.ruleStart = now
    S:Update()
end

local function Tick(now)
    if state.tickAt and now - state.tickAt < SAME_TICK then return end
    state.tickAt = now
end

ns:RegisterEvent("UNIT_POWER_FREQUENT", function(_, unit, powerType)
    if IsSecret(unit) or unit ~= "player" or powerType ~= "MANA" then return end
    local cur = Mana()
    if not cur then
        state.mana = nil
        return
    end
    local now = GetTime()
    if state.mana and cur < state.mana then
        state.dropAt = now
        if state.castAt and now - state.castAt <= CAST_WINDOW then StartRule(now) end
    elseif state.mana and cur > state.mana then
        Tick(now)
    end
    state.mana = cur
    S:Update()
end)

-- The cost is read when the cast is sent: by the time it succeeds a shapeshift
-- has changed form, and with it which costs apply.
ns:RegisterEvent("UNIT_SPELLCAST_SENT", function(_, unit, _, castGUID, spellID)
    if IsSecret(unit) or unit ~= "player" or castGUID == nil or IsSecret(castGUID) then return end
    pending[castGUID] = CostsMana(spellID)
end)

local function Forget(_, unit, castGUID)
    if not IsSecret(unit) and unit == "player" and castGUID ~= nil and not IsSecret(castGUID) then
        pending[castGUID] = nil
    end
end
ns:RegisterEvent("UNIT_SPELLCAST_FAILED", Forget)
ns:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET", Forget)
ns:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", Forget)

-- Starting a cast doesn't spend mana; finishing one (or starting a channel) does.
ns:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, castGUID, spellID)
    if IsSecret(unit) or unit ~= "player" then return end
    local now = GetTime()
    state.castAt = now
    local spends
    if castGUID ~= nil and not IsSecret(castGUID) then
        spends = pending[castGUID]
        pending[castGUID] = nil
    end
    if Mana() then
        -- Plain mana: the drop decides, so free casts (Clearcasting) don't
        -- count. The power event can arrive before or after this one.
        if state.dropAt and now - state.dropAt <= CAST_WINDOW then StartRule(now) end
    else
        if spends == nil then spends = CostsMana(spellID) end
        if spends then StartRule(now) end
    end
end)

ns:RegisterEvent("UNIT_DISPLAYPOWER", function(_, unit)
    if unit == "player" then S:Update() end
end)

ns:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    state.mana = Mana()
    wipe(pending)
    S:Update()
end)
