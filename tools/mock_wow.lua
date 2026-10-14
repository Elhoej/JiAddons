-- Minimal World of Warcraft API mock, just enough to load and drive the
-- JiAddons outside the game. Unknown frame methods are no-ops so UI code can run.

local M = {}

M.now = 1000
M.timers = {}
M.printed = {}
M.secret = setmetatable({}, { __mode = "k" })
M.secretValues = setmetatable({}, { __mode = "k" })
M.frames = {}

-------------------------------------------------------------------------------
-- Frames
-------------------------------------------------------------------------------

local FrameMethods = {}

local function NewObject(kind, name, parent)
    local o = setmetatable({
        _kind = kind, _name = name, _parent = parent, _scripts = {}, _shown = true,
        _points = {}, _w = 0, _h = 0, _text = "", _alpha = 1, _events = {},
        _min = 0, _max = 1, _value = 0, _checked = false, _level = 1,
    }, { __index = function(t, k)
        if FrameMethods[k] then return FrameMethods[k] end
        -- Any other method is a no-op; plain fields stay nil.
        if type(k) == "string" and k:match("^%u") then return function() end end
    end })
    M.frames[#M.frames + 1] = o
    if name then _G[name] = o end
    return o
end
M.NewObject = NewObject

function FrameMethods:SetScript(s, f) self._scripts[s] = f end
function FrameMethods:GetScript(s) return self._scripts[s] end
function FrameMethods:HookScript(s, f)
    local old = self._scripts[s]
    self._scripts[s] = function(...)
        if old then old(...) end
        f(...)
    end
end
function FrameMethods:Fire(s, ...)
    local f = self._scripts[s]
    if f then return f(self, ...) end
end
-- Like the client, OnShow/OnHide fire only when the shown state changes.
function FrameMethods:SetShown(v)
    v = v and true or false
    if v == self._shown then return end
    self._shown = v
    self:Fire(v and "OnShow" or "OnHide")
end
function FrameMethods:Show() self:SetShown(true) end
function FrameMethods:Hide() self:SetShown(false) end
function FrameMethods:IsShown() return self._shown end
-- Shown and every parent shown, like the client.
function FrameMethods:IsVisible()
    if not self._shown then return false end
    local parent = self._parent
    if parent and parent.IsVisible then return parent:IsVisible() end
    return true
end
-- Widget setters accept secret values like the client does: they unwrap them
-- and remember that a secret passed through (self._secret).
local function Reveal(self, ...)
    local n = select("#", ...)
    local out = {}
    for i = 1, n do
        local v = select(i, ...)
        if M.secret[v] then
            self._secret = true
            v = M.secretValues[v]
        end
        out[i] = v
    end
    return unpack(out, 1, n)
end
M.RevealFor = Reveal

function FrameMethods:SetText(t)
    t = Reveal(self, t)
    self._text = t == nil and "" or tostring(t)
end
function FrameMethods:GetText() return self._text end
function FrameMethods:SetFormattedText(fmt, ...) self._text = fmt:format(Reveal(self, ...)) end
function FrameMethods:SetFont(path, size, flags) self._font = { path, size, flags }; return true end
function FrameMethods:SetFontObject(f) self._fontObject = f end
function FrameMethods:GetFontObject() return self._fontObject end
function FrameMethods:SetTextColor(...) self._color = { Reveal(self, ...) } end
function FrameMethods:SetVertexColor(...) self._color = { Reveal(self, ...) } end
function FrameMethods:SetStatusBarColor(...) self._color = { Reveal(self, ...) } end
function FrameMethods:SetTexture(t) self._texture = Reveal(self, t) end
function FrameMethods:SetAtlas(a) self._atlas = a end
function FrameMethods:SetScale(s) self._scale = s end
function FrameMethods:GetScale() return self._scale or 1 end
function FrameMethods:SetAttribute(k, v) self._attrs = self._attrs or {}; self._attrs[k] = v end
function FrameMethods:GetAttribute(k) return self._attrs and self._attrs[k] end
function FrameMethods:GetStatusBarTexture()
    self._barTexture = self._barTexture or NewObject("Texture", nil, self)
    return self._barTexture
end
function FrameMethods:CreateAnimationGroup()
    local group = NewObject("AnimationGroup", nil, self)
    group._shown = false
    function group:CreateAnimation() return NewObject("Animation", nil, group) end
    function group:Play() self._shown = true end
    function group:Stop() self._shown = false end
    function group:IsPlaying() return self._shown end
    return group
end
function FrameMethods:CreateTexture() return NewObject("Texture", nil, self) end
function FrameMethods:CreateFontString() return NewObject("FontString", nil, self) end
function FrameMethods:SetSize(w, h) self._w, self._h = w, h end
function FrameMethods:SetWidth(w) self._w = w end
function FrameMethods:SetHeight(h) self._h = h end
function FrameMethods:GetWidth() return self._w end
function FrameMethods:GetHeight() return self._h end
function FrameMethods:GetStringHeight() return 14 end
function FrameMethods:GetCenter() return 500, 400 end
function FrameMethods:GetEffectiveScale() return 1 end
function FrameMethods:GetFrameLevel() return self._level end
function FrameMethods:SetPoint(...) self._points[#self._points + 1] = { ... } end
function FrameMethods:ClearAllPoints() self._points = {} end
function FrameMethods:SetAllPoints(rel)
    rel = rel or self._parent
    self._points = { { "TOPLEFT", rel, "TOPLEFT" }, { "BOTTOMRIGHT", rel, "BOTTOMRIGHT" } }
end
function FrameMethods:GetPoint(i)
    local p = self._points[i or 1]
    if not p then return nil end
    return p[1], p[2], p[3], p[4] or 0, p[5] or 0
end
function FrameMethods:SetAlpha(a) self._alpha = Reveal(self, a) end
function FrameMethods:GetAlpha() return self._alpha end
function FrameMethods:RegisterEvent(e)
    if M.unknownEvents and M.unknownEvents[e] then error("unknown event " .. e) end
    self._events[e] = true
end
function FrameMethods:UnregisterEvent(e) self._events[e] = nil end
-- Unit events store the units they accept; H.Fire checks the first argument.
function FrameMethods:RegisterUnitEvent(e, ...)
    if M.unknownEvents and M.unknownEvents[e] then error("unknown event " .. e) end
    local units = {}
    for i = 1, select("#", ...) do units[(select(i, ...))] = true end
    self._events[e] = units
end
function FrameMethods:UnregisterAllEvents() self._events = {} end
function FrameMethods:SetGradient(orientation, from, to) self._gradient = { orientation, from, to } end
function FrameMethods:SetReverseFill(v) self._reverseFill = v and true or false end
-- Like the client, a duration object holding secrets is accepted; M.refuseTimers
-- makes it throw instead.
function FrameMethods:SetTimerDuration(duration, interpolation, direction)
    if M.refuseTimers then error("SetTimerDuration refused") end
    self._timer = { duration, interpolation, direction }
end
function FrameMethods:SetMinMaxValues(a, b)
    self._min, self._max = Reveal(self, a, b)
end
function FrameMethods:GetMinMaxValues() return self._min, self._max end
function FrameMethods:SetValue(v, interpolation)
    v = Reveal(self, v)
    self._interpolation = interpolation
    if v < self._min then v = self._min end
    if v > self._max then v = self._max end
    local changed = v ~= self._value
    self._value = v
    if changed or self._kind == "Slider" then self:Fire("OnValueChanged", v, false) end
end
function FrameMethods:GetValue() return self._value end
function FrameMethods:SetChecked(v) self._checked = v and true or false end
function FrameMethods:GetChecked() return self._checked end
function FrameMethods:GetThumbTexture()
    self._thumb = self._thumb or NewObject("Texture", nil, self)
    return self._thumb
end
function FrameMethods:IsOwned(f) return self._owner == f end
function FrameMethods:SetOwner(f) self._owner = f; self._lines = {} end
function FrameMethods:AddLine(t) self._lines = self._lines or {}; self._lines[#self._lines + 1] = t end
function FrameMethods:SetHyperlink(l) self._lines = { "HYPERLINK " .. l } end
function FrameMethods:GetParent() return self._parent end
function FrameMethods:SetBackdrop(b) self._backdrop = b end
function FrameMethods:GetName() return self._name end

function CreateFrame(kind, name, parent, template)
    local f = NewObject(kind, name, parent)
    f._template = template
    if template and template:find("BackdropTemplate") then
        f.SetBackdrop = FrameMethods.SetBackdrop
    end
    return f
end

-------------------------------------------------------------------------------
-- Globals
-------------------------------------------------------------------------------

UIParent = NewObject("Frame", "UIParent")
UIParent._w, UIParent._h = 1920, 1080
GameTooltip = NewObject("GameTooltip", "GameTooltip")
ColorPickerFrame = NewObject("Frame", "ColorPickerFrame")
function ColorPickerFrame:SetupColorPickerAndShow(info) self._info = info end
function ColorPickerFrame:GetColorRGB() return 0.1, 0.2, 0.3 end
BackdropTemplateMixin = {}
function Mixin(t, ...) for i = 1, select("#", ...) do for k, v in pairs((select(i, ...))) do t[k] = v end end return t end
UISpecialFrames = {}
SlashCmdList = {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
SOUNDKIT = { RAID_WARNING = 8959 }
M.sounds = {}
function PlaySound(id) M.sounds[#M.sounds + 1] = id end

Settings = {
    RegisterCanvasLayoutCategory = function(panel, name) return { panel = panel, name = name } end,
    RegisterAddOnCategory = function(cat) M.settingsCategory = cat end,
}

function GetTime() return M.now end
C_Timer = { After = function(d, f) M.timers[#M.timers + 1] = { at = M.now + d, f = f } end }

function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function BreakUpLargeNumbers(n)
    local s = tostring(n)
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end
function tContains(t, v) for _, x in ipairs(t) do if x == v then return true end end end

local realPrint = print
function print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    M.printed[#M.printed + 1] = table.concat(parts, " ")
    if M.echo then realPrint(...) end
end

-- Secret values are boxes that error on arithmetic, comparison, concatenation
-- and tostring, like the client's. Widget setters unwrap them (see Reveal).
local SECRET_MT = {
    __tostring = function() error("attempt to use a secret value") end,
    __index = function() error("attempt to index a secret value") end,
}
function issecretvalue(v) return M.secret[v] == true end
function M.MakeSecret(v)
    local box = setmetatable({}, SECRET_MT)
    M.secret[box] = true
    M.secretValues[box] = v
    return box
end

M.modifiers = {}
function IsShiftKeyDown() return M.modifiers.shift end
function IsAltKeyDown() return M.modifiers.alt end
function IsControlKeyDown() return M.modifiers.ctrl end
function HandleModifiedItemClick(link) M.linked = link end

M.playerName = "Jiloot"
function UnitSex() return 2 end
function Ambiguate(name) return (name:gsub("%-.*$", "")) end

M.money = 0
function GetMoney() return M.money end

Enum = { ItemClass = { Weapon = 2, Armor = 4, Questitem = 12 }, PowerType = { Mana = 0, Rage = 1, Focus = 2, Energy = 3 } }
Constants = { CurrencyConsts = { HONOR_CURRENCY_ID = 1792 } }

-- Global strings (enUS modern client)
LOOT_ITEM_SELF = "You receive loot: %s."
LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
LOOT_ITEM_PUSHED_SELF = "You receive item: %s."
LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d."
LOOT_ITEM_CREATED_SELF = "You create: %s."
LOOT_ITEM_CREATED_SELF_MULTIPLE = "You create: %sx%d."
LOOT_ITEM_BONUS_ROLL_SELF = "You receive bonus loot: %s."
LOOT_ITEM_BONUS_ROLL_SELF_MULTIPLE = "You receive bonus loot: %sx%d."
LOOT_ITEM_REFUND = "You are refunded: %s."
LOOT_ITEM_REFUND_MULTIPLE = "You are refunded: %sx%d."
LOOT_ITEM = "%s receives loot: %s."
FACTION_STANDING_INCREASED = "Reputation with %s increased by %d."
FACTION_STANDING_DECREASED = "Reputation with %s decreased by %d."
FACTION_STANDING_INCREASED_ACH_BONUS = "Reputation with %s increased by %d. (+%.1f bonus)"
FACTION_STANDING_INCREASED_GENERIC = "Reputation with %s increased."
FACTION_STANDING_DECREASED_GENERIC = "Reputation with %s decreased."
COMBATLOG_HONORGAIN = "%s dies, honorable kill Rank: %s (Estimated Honor Points: %d)"
COMBATLOG_HONORGAIN_NO_RANK = "%s dies, honorable kill (Estimated Honor Points: %d)"
COMBATLOG_HONORAWARD = "You have been awarded %d honor points."
MONEY = "Money"
HONOR = "Honor"
FACTION_STANDING_LABEL4 = "Neutral"
FACTION_STANDING_LABEL5 = "Friendly"
FACTION_STANDING_LABEL6 = "Honored"
function GetText(key) return _G[key] end

-------------------------------------------------------------------------------
-- Items
-------------------------------------------------------------------------------

M.items = {}
M.bags = {}
M.uncached = {}

function M.AddItem(id, name, quality, classID, equipLoc, icon, sell, ilvl, stats)
    local hexes = { [0] = "ff9d9d9d", "ffffffff", "ff1eff00", "ff0070dd", "ffa335ee", "ffff8000" }
    local link = "|c" .. hexes[quality] .. "|Hitem:" .. id .. "::::::::60:::::|h[" .. name .. "]|h|r"
    M.items[id] = { id = id, name = name, quality = quality, classID = classID, equipLoc = equipLoc or "",
        icon = icon, sell = sell, ilvl = ilvl, stats = stats or {}, link = link }
    return link
end

local function FindItem(item)
    if type(item) == "number" then return M.items[item] end
    local id = tonumber(tostring(item):match("item:(%d+)"))
    return id and M.items[id]
end

C_Item = {}
function C_Item.GetItemInfo(item)
    local it = FindItem(item)
    if not it or M.uncached[it.id] then return nil end
    return it.name, it.link, it.quality, it.ilvl, 1, "Type", "Sub", 20, it.equipLoc, it.icon, it.sell, it.classID,
        0, it.bind or 0
end
function C_Item.GetItemInfoInstant(item)
    local it = FindItem(item)
    if not it then return nil end
    return it.id, "Type", "Sub", it.equipLoc, it.icon, it.classID
end
function C_Item.GetItemCount(item)
    local it = FindItem(item)
    return it and M.bags[it.id] or 0
end
function C_Item.GetItemStats(link) local it = FindItem(link); return it and it.stats end
function C_Item.GetDetailedItemLevelInfo(link) local it = FindItem(link); return it and it.ilvl end
function C_Item.GetItemQualityColor(q)
    local c = { [0] = { 0.62, 0.62, 0.62, "ff9d9d9d" }, { 1, 1, 1, "ffffffff" }, { 0.12, 1, 0, "ff1eff00" },
        { 0, 0.44, 0.87, "ff0070dd" }, { 0.64, 0.21, 0.93, "ffa335ee" }, { 1, 0.5, 0, "ffff8000" },
        { 0.9, 0.8, 0.5, "ffe6cc80" }, { 0, 0.8, 1, "ff00ccff" } }
    local v = c[q] or c[1]
    return v[1], v[2], v[3], v[4]
end
function C_Item.RequestLoadItemDataByID(id) M.requested = id end

-------------------------------------------------------------------------------
-- Currency and reputation
-------------------------------------------------------------------------------

M.currencies = {
    [1792] = { name = "Honor", quantity = 100, maxQuantity = 15000, iconFileID = 1455894, quality = 1 },
    [1166] = { name = "Timewarped Badge", quantity = 1960, maxQuantity = 0, iconFileID = 463446, quality = 1 },
}
C_CurrencyInfo = {
    GetCurrencyInfo = function(id) return M.currencies[id] end,
    GetCurrencyListSize = function() return 0 end,
}

M.factions = {
    { name = "Argent Dawn", factionID = 529, reaction = 5, currentStanding = 3080,
      currentReactionThreshold = 3000, nextReactionThreshold = 9000 },
}
C_Reputation = {
    GetNumFactions = function() return #M.factions end,
    GetFactionDataByIndex = function(i) return M.factions[i] end,
}

-------------------------------------------------------------------------------
-- Loot window
-------------------------------------------------------------------------------

LootFrame = NewObject("Frame", "LootFrame")
M.loot = {}        -- { { link = ..., type = 1, locked = false, taken = false } }
M.looted = {}
M.bagsFull = false
function GetNumLootItems() return #M.loot end
function GetLootSlotInfo(i)
    local s = M.loot[i]
    return 134400, "x", 1, nil, 1, s.locked
end
function GetLootSlotType(i) return M.loot[i].type or 1 end
function GetLootSlotLink(i) return M.loot[i].link end
function LootSlotHasItem(i) return not M.loot[i].taken end
function LootSlot(i)
    M.looted[#M.looted + 1] = i
    if not M.bagsFull then M.loot[i].taken = true end
end
function GetCVarBool() return true end
function IsModifiedClick() return false end

-------------------------------------------------------------------------------
-- Units. M.units[token] describes a unit; missing tokens don't exist.
--   { name, class = "DRUID", level, health, maxHealth, power, maxPower,
--     powerType = 0, powerToken = "MANA", player = true, reaction = 5,
--     connected, dead, ghost, tapDenied, classification, creatureType, family,
--     guild, leader, pvp, raidTarget, buffs = { aura... }, debuffs = { aura... } }
-- Aura: { name, icon, applications, duration, expirationTime, dispelName,
--         castable (HELPFUL|RAID), dispellable (HARMFUL|RAID) }
-- With M.secrets = true, health, power, names and aura fields come back as
-- secret values, the way Forever hands them to addons.
-------------------------------------------------------------------------------

M.secrets = false
M.units = {
    player = { class = "DRUID", level = 60, health = 100, maxHealth = 100, power = 50, maxPower = 100,
        powerType = 0, powerToken = "MANA", player = true, reaction = 5 },
}
M.group = { raid = false }
M.bindings = {}
M.comboPoints = 0
M.resting = false
M.inCombat = false

local function Unit(unit) return unit and M.units[unit] end
local function S(v)
    if M.secrets and v ~= nil then return M.MakeSecret(v) end
    return v
end
M.S = S

local CLASS_NAMES = { DRUID = "Druid", HUNTER = "Hunter", MAGE = "Mage", PALADIN = "Paladin", PRIEST = "Priest",
    ROGUE = "Rogue", SHAMAN = "Shaman", WARLOCK = "Warlock", WARRIOR = "Warrior" }

function UnitExists(unit) return Unit(unit) ~= nil end
function UnitName(unit)
    local u = Unit(unit or "player")
    local name = u and u.name or ((unit == nil or unit == "player") and M.playerName or nil)
    if name == nil then return nil end
    return S(name), nil
end
function UnitClass(unit)
    local u = Unit(unit)
    if not u or not u.class then return nil end
    return S(CLASS_NAMES[u.class] or u.class), u.class
end
function UnitLevel(unit) local u = Unit(unit); return u and u.level or 0 end
function UnitHealth(unit) local u = Unit(unit); return u and S(u.health) or 0 end
function UnitHealthMax(unit) local u = Unit(unit); return u and S(u.maxHealth) or 0 end
function UnitHealthMissing(unit) local u = Unit(unit); return u and S(u.maxHealth - u.health) or 0 end
function UnitHealthPercent(unit, _, curve)
    local u = Unit(unit)
    local p = (u and u.maxHealth > 0) and u.health / u.maxHealth or 0
    if curve then
        local v = curve:Evaluate(p)
        if type(v) == "table" then return v end
        return S(v)
    end
    return S(p)
end
-- u.power/u.maxPower are the displayed power; u.powers[type] = { cur, max }
-- holds others (a druid's mana in cat form).
local function Power(u, powerType)
    local p = powerType and u.powers and u.powers[powerType]
    if p then return p[1], p[2] end
    return u.power or 0, u.maxPower or 0
end
function UnitPower(unit, powerType) local u = Unit(unit); return u and S((Power(u, powerType))) or 0 end
function UnitPowerMax(unit, powerType) local u = Unit(unit); return u and S(select(2, Power(u, powerType))) or 0 end
function UnitPowerType(unit) local u = Unit(unit); return u and u.powerType or 0, u and u.powerToken or "MANA" end
function UnitIsPlayer(unit) local u = Unit(unit); return u and u.player or false end
function UnitPlayerControlled(unit) local u = Unit(unit); return u and (u.player or u.pet) or false end
function UnitIsConnected(unit) local u = Unit(unit); return u ~= nil and u.connected ~= false end
function UnitIsDead(unit) local u = Unit(unit); return u and u.dead or false end
function UnitIsGhost(unit) local u = Unit(unit); return u and u.ghost or false end
function UnitIsDeadOrGhost(unit) return UnitIsDead(unit) or UnitIsGhost(unit) end
function UnitReaction(unit) local u = Unit(unit); return u and u.reaction end
function UnitIsTapDenied(unit) local u = Unit(unit); return u and u.tapDenied or false end
function UnitClassification(unit) local u = Unit(unit); return u and u.classification or "normal" end
function UnitCreatureType(unit) local u = Unit(unit); return u and S(u.creatureType) end
function UnitCreatureFamily(unit) local u = Unit(unit); return u and S(u.family) end
function UnitIsFriend(_, unit) local u = Unit(unit); return u ~= nil and (u.reaction or 5) >= 4 end
function UnitCanAttack(_, unit) local u = Unit(unit); return u ~= nil and (u.reaction or 5) <= 4 end
function UnitIsUnit(a, b) return a == b or (Unit(a) ~= nil and Unit(a) == Unit(b)) end
function UnitIsVisible(unit) return Unit(unit) ~= nil end
function UnitGUID(unit) return Unit(unit) and ("Guid-" .. unit) or nil end
function UnitIsGroupLeader(unit) local u = Unit(unit); return u and u.leader or false end
function UnitIsPVP(unit) local u = Unit(unit); return u and u.pvp or false end
function UnitIsPVPFreeForAll() return false end
function UnitFactionGroup(unit) local u = Unit(unit); return u and (u.faction or "Alliance") end
function UnitAffectingCombat(unit) local u = Unit(unit); return u and u.combat or false end
function GetRaidTargetIndex(unit) local u = Unit(unit); return u and u.raidTarget end
function SetRaidTargetIconTexture(tex, index) tex._raidTarget = index end
function GetGuildInfo(unit) local u = Unit(unit); return u and S(u.guild) end
function SetPortraitTexture(tex, unit) tex._portrait = unit end
function IsInRaid() return M.group.raid end
function IsInGroup() return M.group.raid or UnitExists("party1") end
function GetNumGroupMembers() return M.group.members or 0 end
function IsResting() return M.resting end
function InCombatLockdown() return M.inCombat end
function GetComboPoints() return M.comboPoints end
function GetBindingKey(action) return M.bindings[action] end
C_PartyInfo = { GetLootMethod = function() return M.lootMethod or 0, M.masterLooterPartyID end }

RAID_CLASS_COLORS = {
    DRUID = { r = 1, g = 0.49, b = 0.04 }, HUNTER = { r = 0.67, g = 0.83, b = 0.45 },
    MAGE = { r = 0.25, g = 0.78, b = 0.92 }, PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
    PRIEST = { r = 1, g = 1, b = 1 }, ROGUE = { r = 1, g = 0.96, b = 0.41 },
    SHAMAN = { r = 0, g = 0.44, b = 0.87 }, WARLOCK = { r = 0.53, g = 0.53, b = 0.93 },
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
}
FACTION_BAR_COLORS = {
    { r = 0.8, g = 0.3, b = 0.22 }, { r = 0.8, g = 0.3, b = 0.22 }, { r = 0.75, g = 0.27, b = 0 },
    { r = 0.9, g = 0.7, b = 0 }, { r = 0, g = 0.6, b = 0.1 }, { r = 0, g = 0.6, b = 0.1 },
    { r = 0, g = 0.6, b = 0.1 }, { r = 0, g = 0.6, b = 0.1 },
}
DebuffTypeColor = {
    none = { r = 0.8, g = 0, b = 0 }, Magic = { r = 0.2, g = 0.6, b = 1 }, Curse = { r = 0.6, g = 0, b = 1 },
    Disease = { r = 0.6, g = 0.4, b = 0 }, Poison = { r = 0, g = 0.6, b = 0 },
}
function GetCreatureDifficultyColor() return { r = 1, g = 0.82, b = 0 } end
DEAD = "Dead"
PLAYER_OFFLINE = "Offline"
BOSS = "Boss"
ELITE = "Elite"
GROUP = "Group"
function GameTooltip_SetDefaultAnchor(tooltip, owner) tooltip._owner = owner end
function FrameMethods:SetUnit(unit) self._unit = unit end

-------------------------------------------------------------------------------
-- Curves and colours
-------------------------------------------------------------------------------

local ColorMixin = {}
function ColorMixin:GetRGB() return self.r, self.g, self.b end
function ColorMixin:GetRGBA() return self.r, self.g, self.b, self.a end
function CreateColor(r, g, b, a)
    return setmetatable({ r = r, g = g, b = b, a = a or 1 }, { __index = ColorMixin })
end

Enum.LuaCurveType = { Linear = 0, Step = 1, Cosine = 2, Cubic = 3 }
Enum.StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 }

local Curve = {}
Curve.__index = Curve
function Curve:SetType(t) self.type = t end
function Curve:AddPoint(x, y)
    self.points[#self.points + 1] = { x = x, y = y }
    table.sort(self.points, function(a, b) return a.x < b.x end)
end
local function Lerp(a, b, t)
    if type(a) == "table" then
        return CreateColor(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t)
    end
    return a + (b - a) * t
end
-- Step snaps to the last point at or below x; the others interpolate linearly.
function Curve:Evaluate(x)
    local pts = self.points
    if #pts == 0 then return 0 end
    if x <= pts[1].x then return pts[1].y end
    if x >= pts[#pts].x then return pts[#pts].y end
    for i = 2, #pts do
        local a, b = pts[i - 1], pts[i]
        if x < b.x then
            if self.type == Enum.LuaCurveType.Step then return a.y end
            return Lerp(a.y, b.y, (x - a.x) / (b.x - a.x))
        end
    end
    return pts[#pts].y
end
function CreateVector3D(x, y, z) return { x = x, y = y, z = z } end
-- Atlases exist unless listed in M.missingAtlases.
M.missingAtlases = {}
C_Texture = { GetAtlasInfo = function(name) if not M.missingAtlases[name] then return { file = name } end end }

C_CurveUtil = {
    CreateCurve = function() return setmetatable({ points = {}, type = 0 }, Curve) end,
    CreateColorCurve = function() return setmetatable({ points = {}, type = 0 }, Curve) end,
}

-------------------------------------------------------------------------------
-- Auras
-------------------------------------------------------------------------------

local nextAuraID = 0
-- Supports HELPFUL/HARMFUL plus RAID and !RAID (castable buffs, dispellable debuffs).
local function AuraList(unit, filter)
    local u = Unit(unit)
    if not u then return {} end
    filter = filter or "HELPFUL"
    local harmful = filter:find("HARMFUL") ~= nil
    local raid = filter:find("|RAID", 1, true) ~= nil or filter:find("^RAID") ~= nil
    local notRaid = filter:find("!RAID", 1, true) ~= nil
    local list = (harmful and u.debuffs or u.buffs) or {}
    local out = {}
    for _, a in ipairs(list) do
        if not a.auraInstanceID then
            nextAuraID = nextAuraID + 1
            a.auraInstanceID = nextAuraID
        end
        local flag = (harmful and a.dispellable or (not harmful and a.castable)) and true or false
        if (not raid and not notRaid) or (raid and flag) or (notRaid and not flag) then
            out[#out + 1] = a
        end
    end
    return out
end
M.AuraList = AuraList

-- Forever refuses aura reads from addon code while auras are secret.
local function CheckAuraAccess()
    if M.secrets then error("GetAuraDataByIndex(): Auras cannot be accessed when secret while tainted", 3) end
end
local function FindAura(unit, id)
    local u = Unit(unit)
    if not u then return end
    for _, list in ipairs({ u.buffs or {}, u.debuffs or {} }) do
        for _, a in ipairs(list) do
            if a.auraInstanceID == id then return a end
        end
    end
end
C_UnitAuras = {}
function C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
    CheckAuraAccess()
    local a = AuraList(unit, filter)[index]
    if not a then return nil end
    return {
        auraInstanceID = a.auraInstanceID, name = S(a.name or "Aura"), icon = S(a.icon or 136000),
        applications = S(a.applications or 0), duration = S(a.duration or 0),
        expirationTime = S(a.expirationTime or 0), dispelName = S(a.dispelName),
        isHarmful = filter and filter:find("HARMFUL") ~= nil,
    }
end
function C_UnitAuras.GetAuraApplicationDisplayCount(unit, id, minCount)
    CheckAuraAccess()
    local a = FindAura(unit, id)
    local n = a and a.applications or 0
    return S(n >= (minCount or 2) and tostring(n) or "")
end
function C_UnitAuras.GetAuraDuration(unit, id)
    CheckAuraAccess()
    local a = FindAura(unit, id)
    return a and { duration = a.duration, expirationTime = a.expirationTime }
end
function C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, id, filter)
    CheckAuraAccess()
    local a = FindAura(unit, id)
    if not a then return true end
    if filter:find("RAID") then
        if filter:find("HARMFUL") then return not a.dispellable end
        return not a.castable
    end
    return false
end

-------------------------------------------------------------------------------
-- Aura containers (CustomAuraContainerTemplate). The client fills these from
-- secure code; the mock fills them from M.units whether or not auras are
-- secret, and checks the rules addons must follow when styling buttons.
-------------------------------------------------------------------------------

AnchorUtil = {
    FlowLayoutAxis = { Horizontal = 0, Vertical = 1 },
    FlowDirection = { Left = -1, Right = 1, Up = 1, Down = -1 },
}
AuraContainerSortMethod = { Default = 0 }
AuraContainerSortDirection = { Normal = 0, Reverse = 1 }
Enum.CustomAuraButtonDispelTypeTextureStyle = { Border = 0, BorderWithIcon = 1, Icon = 2, PreserveAsset = 3, CustomAsset = 4 }

local VALID_FILTERS = { HELPFUL = true, HARMFUL = true, PLAYER = true, RAID = true, CANCELABLE = true,
    INCLUDE_NAME_PLATE_ONLY = true, CROWD_CONTROL = true, DISPELLABLE = true, IMPORTANT = true }
local function CheckFilter(filter)
    for part in filter:gmatch("[^| ]+") do
        assert(VALID_FILTERS[part:gsub("^!", "")], "Unknown aura filter component: " .. part)
    end
end

local AuraButton = {}
local function Owned(b, obj)
    local p = obj
    while p do
        if p == b then return end
        p = p._parent
    end
    error("bad object in function call (must be a descendant of owner)")
end
function AuraButton:SetIcon(tex) Owned(self, tex); self._iconTex = tex end
function AuraButton:SetApplicationCount(fs) Owned(self, fs); self._countText = fs end
function AuraButton:SetDurationCooldown(cd) Owned(self, cd); self._cooldown = cd end
function AuraButton:AddDispelTypeTexture(tex, options) Owned(self, tex); self._dispel = { tex, options } end
function AuraButton:AddAuraShownAnimation(group) Owned(self, group); self._shownAnim = group end

local AuraContainer = {}
function AuraContainer:GetUnit() return self._unit end
function AuraContainer:SetUnit(unit)
    assert(type(unit) == "string")
    if self._unit ~= unit then
        self._unit = unit
        self:UpdateAllAuras()
    end
end
function AuraContainer:SetFlowLayoutAnchorPoint(point) self._anchorPoint = point end
function AuraContainer:SetFlowLayoutGrowthDirection(h, v) self._growth = { h, v } end
function AuraContainer:SetFlowLayoutMaximumLineSize(size) self._lineSize = size end
function AuraContainer:AddAuraGroup(key, filter, options)
    assert(not self._groups[key], "aura group already exists")
    CheckFilter(filter)
    local g = { key = key, filter = filter, options = options or {}, enabled = true, buttons = {} }
    self._groups[key] = g
    self._order[#self._order + 1] = g
    self:CreateButtons(g)
    self:UpdateAllAuras()
end
function AuraContainer:CreateButtons(g)
    for _ = 1, 10 do
        local b = CreateFrame("Button", nil, self, "CustomAuraButtonTemplate")
        for k, fn in pairs(AuraButton) do b[k] = fn end
        if g.options.initializeFrame then g.options.initializeFrame(b) end
        b._shown = false
        g.buttons[#g.buttons + 1] = b
    end
end
function AuraContainer:GetAuraGroup(key) return self._groups[key] end
function AuraContainer:SetAuraGroupEnabled(key, enabled)
    assert(type(enabled) == "boolean", "enabled must be a boolean.")
    self._groups[key].enabled = enabled
    self:UpdateAllAuras()
end
function AuraContainer:SetAuraGroupFilterString(key, filter)
    CheckFilter(filter)
    self._groups[key].filter = filter
    self:UpdateAllAuras()
end
function AuraContainer:UpdateAllAuras()
    for _, g in ipairs(self._order) do
        local auras = (g.enabled and self._unit) and AuraList(self._unit, g.filter) or {}
        local n = math.min(#auras, g.options.maxFrameCount or math.huge)
        while #g.buttons < n do self:CreateButtons(g) end
        for i, b in ipairs(g.buttons) do
            local a = i <= n and auras[i]
            b._aura = a or nil
            b._shown = a and true or false
            if a then
                if b._iconTex then b._iconTex:SetTexture(a.icon or 136000) end
                if b._countText then
                    b._countText:SetText((a.applications or 0) > 1 and tostring(a.applications) or "")
                end
                if b._dispel then
                    local c = DebuffTypeColor[a.dispelName or "none"] or DebuffTypeColor.none
                    b._dispel[1]:SetVertexColor(c.r, c.g, c.b)
                end
                if b._shownAnim then b._shownAnim:Play() end
            elseif b._shownAnim then
                b._shownAnim:Stop()
            end
        end
    end
end

-- Visible aura buttons of a container, in layout order.
function M.ShownAuras(container)
    local out = {}
    for _, g in ipairs(container._order) do
        for _, b in ipairs(g.buttons) do
            if b._shown then out[#out + 1] = b end
        end
    end
    return out
end

local plainCreateFrame = CreateFrame
function CreateFrame(kind, name, parent, template)
    local f = plainCreateFrame(kind, name, parent, template)
    if template and template:find("CustomAuraContainerTemplate", 1, true) then
        assert(kind == "AuraContainer", "CustomAuraContainerTemplate needs frame type AuraContainer")
        f._groups, f._order = {}, {}
        for k, fn in pairs(AuraContainer) do f[k] = fn end
    end
    return f
end

-------------------------------------------------------------------------------
-- Secure templates and state drivers
-------------------------------------------------------------------------------

function RegisterUnitWatch(frame) frame._unitWatch = true end
function UnregisterUnitWatch(frame) frame._unitWatch = nil end
function RegisterStateDriver(frame, state, values)
    frame._stateDrivers = frame._stateDrivers or {}
    frame._stateDrivers[state] = values
end
function UnregisterStateDriver(frame, state)
    if frame._stateDrivers then frame._stateDrivers[state] = nil end
end
RegisterAttributeDriver = RegisterStateDriver
UnregisterAttributeDriver = UnregisterStateDriver

-- Mimics the unit watch: shows or hides watched frames by their unit.
function M.RunUnitWatch()
    for _, f in ipairs(M.frames) do
        local unit = f._attrs and f._attrs.unit
        if unit and f._unitWatch then
            f._shown = UnitExists(unit)
        end
    end
end

-- Blizzard frames addons commonly replace.
for _, name in ipairs({ "PlayerFrame", "TargetFrame", "TargetFrameToT", "PetFrame", "PartyFrame", "FocusFrame" }) do
    NewObject("Button", name)
end
for i = 1, 4 do PartyFrame["MemberFrame" .. i] = NewObject("Button", nil, PartyFrame) end

-------------------------------------------------------------------------------
-- Hooks and CVars
-------------------------------------------------------------------------------

-- hooksecurefunc([table,] name, fn): fn runs after the original.
function hooksecurefunc(t, name, fn)
    if type(t) == "string" then t, name, fn = _G, t, name end
    local orig = t[name]
    t[name] = function(...)
        local r = { orig(...) }
        fn(...)
        return unpack(r)
    end
end

M.cvars = {}
function SetCVar(name, value) M.cvars[name] = tostring(value) end
function GetCVar(name) return M.cvars[name] end

-------------------------------------------------------------------------------
-- Quest log. M.questLog is the log in order:
--   { isHeader = true, title = "Darkshore", collapsed }
--   { questID, title, level, complete, failed, elite, pushable, hidden,
--     objectives = { { text, finished } }, description, objectivesText }
-- M.watched[questID] = true for tracked quests.
-------------------------------------------------------------------------------

M.questLog = {}
M.watched = {}
M.questCalls = {}

local function QuestEntry(questID)
    for i, e in ipairs(M.questLog) do
        if not e.isHeader and e.questID == questID then return e, i end
    end
end

C_QuestLog = {}
function C_QuestLog.GetNumQuestLogEntries()
    local quests = 0
    for _, e in ipairs(M.questLog) do
        if not e.isHeader then quests = quests + 1 end
    end
    return #M.questLog, quests
end
function C_QuestLog.GetInfo(i)
    local e = M.questLog[i]
    if not e then return nil end
    return {
        title = e.title, questLogIndex = i, questID = e.questID or 0, level = e.level or 0,
        difficultyLevel = e.level or 0, isHeader = e.isHeader or false, isCollapsed = e.collapsed or false,
        isHidden = e.hidden or false, isTask = false, isBounty = false, isScaling = false,
    }
end
function C_QuestLog.IsComplete(id) local e = QuestEntry(id); return e and e.complete or false end
function C_QuestLog.ReadyForTurnIn(id) return C_QuestLog.IsComplete(id) end
function C_QuestLog.IsFailed(id) local e = QuestEntry(id); return e and e.failed or false end
function C_QuestLog.IsEliteQuest(id) local e = QuestEntry(id); return e and e.elite or false end
function C_QuestLog.GetLogIndexForQuestID(id) return select(2, QuestEntry(id)) end
function C_QuestLog.GetTitleForQuestID(id) local e = QuestEntry(id); return e and e.title end
function C_QuestLog.GetQuestObjectives(id) local e = QuestEntry(id); return e and e.objectives or {} end
function C_QuestLog.SetSelectedQuest(id) M.selectedQuest = id end
function C_QuestLog.GetSelectedQuest() return M.selectedQuest end
function C_QuestLog.GetQuestWatchType(id) return M.watched[id] and 0 or nil end
function C_QuestLog.AddQuestWatch(id) M.watched[id] = true end
function C_QuestLog.RemoveQuestWatch(id) M.watched[id] = nil end
function C_QuestLog.CanAbandonQuest(id) return QuestEntry(id) ~= nil end
function C_QuestLog.IsPushableQuest(id) local e = QuestEntry(id); return e and e.pushable or false end
function C_QuestLog.GetMaxNumQuestsCanAccept() return 20 end
function GetQuestLogQuestText(index)
    local e = M.questLog[index or 0]
    return e and e.description, e and e.objectivesText
end
function GetQuestLink(id) return "|cffffff00|Hquest:" .. id .. "|h[" .. (C_QuestLog.GetTitleForQuestID(id) or "") .. "]|h|r" end
function ExpandQuestHeader(i) if M.questLog[i] then M.questLog[i].collapsed = false end end
function CollapseQuestHeader(i) if M.questLog[i] then M.questLog[i].collapsed = true end end
function GetQuestDifficultyColor(level)
    local diff = level - UnitLevel("player")
    if diff >= 5 then return { r = 1, g = 0.1, b = 0.1 } end
    if diff >= 3 then return { r = 1, g = 0.5, b = 0.25 } end
    if diff >= -2 then return { r = 1, g = 1, b = 0 } end
    return { r = 0.25, g = 0.75, b = 0.25 }
end

-- Blizzard's quest option helpers (QuestMapFrame.lua) and quest log entry points.
function QuestMapQuestOptions_TrackQuest(id)
    if M.watched[id] then M.watched[id] = nil else M.watched[id] = true end
end
function QuestMapQuestOptions_AbandonQuest(id) M.questCalls[#M.questCalls + 1] = "abandon " .. id end
function QuestMapQuestOptions_ShareQuest(id) M.questCalls[#M.questCalls + 1] = "share " .. id end
function ToggleQuestLog() M.questCalls[#M.questCalls + 1] = "blizzard toggle" end
function OpenQuestLog() M.questCalls[#M.questCalls + 1] = "blizzard open" end
function QuestMapFrame_OpenToQuestDetails() M.questCalls[#M.questCalls + 1] = "blizzard details" end
QuestFrame = NewObject("Frame", "QuestFrame")
QuestFrame._shown = false

-- QuestInfo_Display records what it was asked to draw and fills in the title.
QuestInfoTitleHeader = NewObject("FontString", "QuestInfoTitleHeader")
QuestInfoSpacerFrame = NewObject("Frame", "QuestInfoSpacerFrame")
function QuestInfo_ShowTitle() end
function QuestInfo_ShowObjectives() end
function QuestInfo_ShowSeal() end
function QuestInfo_ShowRewards() end
QUEST_TEMPLATE_LOG = { questLog = true, contentWidth = 285, canHaveSealMaterial = true,
    elements = { QuestInfo_ShowTitle, 5, -5, QuestInfo_ShowObjectives, 0, -10, QuestInfo_ShowSeal, 0, 0,
        QuestInfo_ShowRewards, 0, -10 } }
M.questInfoCalls = 0
function QuestInfo_Display(template, parent)
    M.questInfoCalls = M.questInfoCalls + 1
    M.questInfo = { template = template, parent = parent, questID = M.selectedQuest }
    QuestInfoTitleHeader:SetText(C_QuestLog.GetTitleForQuestID(M.selectedQuest) or "")
end

-------------------------------------------------------------------------------
-- World map: Blizzard's WorldMapFrame on a map canvas, reduced to what addons
-- restyling it touch. M.maps[uiMapID] = name; the player stands at
-- M.playerPos on M.playerMap; M.cursor is the normalized cursor position,
-- over the canvas when M.cursorOverMap is set.
-------------------------------------------------------------------------------

M.maps = { [1429] = "Elwynn Forest", [1415] = "Eastern Kingdoms" }
M.playerMap = 1429
M.playerPos = { 0.484, 0.393 }
M.cursor = { 0.5, 0.5 }

C_Map = {}
function C_Map.GetMapInfo(id) return M.maps[id] and { mapID = id, name = M.maps[id] } end
function C_Map.GetPlayerMapPosition(id, unit)
    if id ~= M.playerMap or unit ~= "player" then return nil end
    return { GetXY = function() return M.playerPos[1], M.playerPos[2] end }
end
function C_Map.GetBestMapForUnit() return M.playerMap end
MAP_CANVAS_MOUSE_WHEEL_ZOOM_BEHAVIOR_NONE = 3

local function NewWorldMap()
    local map = NewObject("Frame", "WorldMapFrame", UIParent)
    map._shown = false
    map.minimizedWidth, map.minimizedHeight = 702, 534
    map.BorderFrame = NewObject("Frame", nil, map)
    map.NavBar = NewObject("Frame", nil, map)
    map.SidePanelToggle = NewObject("Button", nil, map)
    map.QuestLog = NewObject("Frame", nil, map)
    map.QuestLog._shown = false
    map.WorldMapTrackingOptionsButton = NewObject("DropdownButton", nil, map)
    map.WorldMapTrackingPinButton = NewObject("Button", nil, map)
    map.overlayFrames = { map.WorldMapTrackingOptionsButton, map.WorldMapTrackingPinButton }

    -- A single Blizzard zoom level at scale 1, like many vanilla maps.
    local sc = NewObject("ScrollFrame", nil, map)
    sc.zoomLevels = { { scale = 1, layerIndex = 1 } }
    sc.currentScale, sc.targetScale = 1, 1
    sc.targetScrollX, sc.targetScrollY = 0.5, 0.5
    function sc:GetScaleForMinZoom() return self.zoomLevels[1].scale end
    function sc:GetScaleForMaxZoom() return self.zoomLevels[#self.zoomLevels].scale end
    function sc:GetCanvasScale() return self.currentScale end
    function sc:GetCurrentScrollX() return self.targetScrollX end
    function sc:GetCurrentScrollY() return self.targetScrollY end
    function sc:GetNormalizedCursorPosition() return M.cursor[1], M.cursor[2] end
    function sc:IsMouseOver() return M.cursorOverMap or false end
    -- Like the real one: the scale isn't clamped, the centre is kept in the map.
    function sc:InstantPanAndZoom(scale, x, y)
        self.currentScale, self.targetScale = scale, scale
        local half = 0.5 / scale
        self.targetScrollX = math.max(half, math.min(1 - half, x))
        self.targetScrollY = math.max(half, math.min(1 - half, y))
    end
    function sc:ResetZoom() self:InstantPanAndZoom(self.zoomLevels[1].scale, 0.5, 0.5) end
    map.ScrollContainer = sc

    function map:GetMapID() return self.mapID end
    function map:OnMapChanged() end
    function map:SetMapID(id)
        if self.mapID == id then return end
        self.mapID = id
        sc.mapID = id
        sc:ResetZoom()
        self:OnMapChanged()
    end
    function map:SetMouseWheelZoomMode(mode) sc.mouseWheelZoomMode = mode end
    function map:OnFrameSizeChanged() sc:ResetZoom() end
    -- Like QuestLogOwnerMixin:SetDisplayState: state 1 closes the map, others
    -- show it and then re-anchor it, which resets the zoom after OnShow ran.
    function map:SetDisplayState(state)
        if state == 1 then
            self:Hide()
            return
        end
        self:Show()
        self.SidePanelToggle:Show()
        self:OnFrameSizeChanged()
    end
    function map:SetQuestLogPanelShown(shown) self.QuestLog:SetShown(shown) end
    -- Like WorldMapMixin:OnShow: the player's zone, zoomed out.
    map:SetScript("OnShow", function(self)
        self:SetMapID(M.playerMap)
        sc:ResetZoom()
    end)
    return map
end
WorldMapFrame = NewWorldMap()
-- The M key binding.
function ToggleWorldMap() WorldMapFrame:SetDisplayState(WorldMapFrame:IsShown() and 1 or 2) end

-------------------------------------------------------------------------------
-- Text measuring and geometry. String widths are estimated from the visible
-- characters. With M.geometry = true, GetLeft/GetBottom/... resolve a frame's
-- first anchor (scale ignored), enough for drag-and-drop style tests; off,
-- they return nil like a frame that was never laid out.
-------------------------------------------------------------------------------

function FrameMethods:GetStringWidth()
    local size = self._font and self._font[2] or 12
    local text = tostring(self._text or "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:]*:", ""):gsub("|r", ""):gsub("|T.-|t", "XX")
    return #text * size * 0.55
end
FrameMethods.GetUnboundedStringWidth = FrameMethods.GetStringWidth

local ANCHOR = {
    TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 },
    RIGHT = { 1, 0.5 }, BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}

-- Returns left, bottom, width, height in UIParent coordinates, or nil.
local function Resolve(f, depth)
    if f == UIParent then return 0, 0, UIParent._w, UIParent._h end
    if depth > 20 then return nil end
    local p = f._points[1]
    if not p then return nil end
    local point, rel, relPoint, x, y = p[1], p[2], p[3], p[4], p[5]
    if type(rel) ~= "table" then
        -- SetPoint(point[, x, y]): relative to the parent, same point.
        rel, relPoint, x, y = f._parent, point, rel, relPoint
    end
    x, y = tonumber(x) or 0, tonumber(y) or 0
    local rl, rb, rw, rh = Resolve(rel or UIParent, depth + 1)
    if not rl then return nil end
    local ra, a = ANCHOR[relPoint or point] or ANCHOR.CENTER, ANCHOR[point] or ANCHOR.CENTER
    local w, h = f._w or 0, f._h or 0
    return rl + rw * ra[1] + x - w * a[1], rb + rh * ra[2] + y - h * a[2], w, h
end
M.Resolve = Resolve

function FrameMethods:GetLeft()
    if not M.geometry then return nil end
    return (Resolve(self, 0))
end
function FrameMethods:GetBottom()
    if not M.geometry then return nil end
    local _, b = Resolve(self, 0)
    return b
end
function FrameMethods:GetRight()
    if not M.geometry then return nil end
    local l, _, w = Resolve(self, 0)
    return l and l + w
end
function FrameMethods:GetTop()
    if not M.geometry then return nil end
    local _, b, _, h = Resolve(self, 0)
    return b and b + h
end
function FrameMethods:GetCenter()
    if M.geometry then
        local l, b, w, h = Resolve(self, 0)
        if l then return l + w / 2, b + h / 2 end
    end
    return 500, 400
end

-- M.mouseOver = frame (or a set of frames) the cursor is over.
function FrameMethods:IsMouseOver()
    local over = M.mouseOver
    if over == self then return true end
    return type(over) == "table" and over[self] == true or false
end
function FrameMethods:SetParent(p) self._parent = p end
function FrameMethods:GetFrameStrata() return self._strata or "MEDIUM" end
function FrameMethods:SetFrameStrata(s) self._strata = s end
function FrameMethods:SetFrameLevel(l) self._level = l end
function FrameMethods:EnableMouse(v) self._mouse = v and true or false end
function FrameMethods:IsMouseEnabled() return self._mouse ~= false end
function FrameMethods:SetTexCoord(...) self._texCoord = { ... } end
function FrameMethods:GetObjectType() return self._kind end
function FrameMethods:Enable() self._enabled = true; self:Fire("OnEnable") end
function FrameMethods:Disable() self._enabled = false; self:Fire("OnDisable") end
function FrameMethods:IsEnabled() return self._enabled ~= false end
function FrameMethods:Click(button) self:Fire("OnClick", button or "LeftButton", false) end

M.cursorPos = { 0, 0 }
function GetCursorPosition() return M.cursorPos[1], M.cursorPos[2] end
function GetScreenWidth() return UIParent._w end
function GetScreenHeight() return UIParent._h end

-------------------------------------------------------------------------------
-- MenuUtil (Blizzard_Menu): context menus are recorded as description trees
-- in M.menu. M.FindMenu(root, "Position", "Left") follows entries by text and
-- M.ClickMenu(desc) runs one like a click.
-------------------------------------------------------------------------------

local MenuDesc = {}
MenuDesc.__index = MenuDesc
local function NewDesc(kind, text)
    return setmetatable({ kind = kind, text = text, children = {} }, MenuDesc)
end
local function AddDesc(parent, d)
    parent.children[#parent.children + 1] = d
    return d
end
function MenuDesc:CreateButton(text, callback, data)
    local d = AddDesc(self, NewDesc("button", text))
    d.callback, d.data = callback, data
    return d
end
function MenuDesc:CreateCheckbox(text, isSelected, setSelected, data)
    local d = AddDesc(self, NewDesc("checkbox", text))
    d.isSelected, d.setSelected, d.data = isSelected, setSelected, data
    return d
end
function MenuDesc:CreateRadio(text, isSelected, setSelected, data)
    local d = AddDesc(self, NewDesc("radio", text))
    d.isSelected, d.setSelected, d.data = isSelected, setSelected, data
    return d
end
function MenuDesc:CreateTitle(text) return AddDesc(self, NewDesc("title", text)) end
function MenuDesc:CreateDivider() return AddDesc(self, NewDesc("divider")) end
function MenuDesc:CreateSpacer() return AddDesc(self, NewDesc("spacer")) end
function MenuDesc:CreateColorSwatch(text, callback, info)
    local d = AddDesc(self, NewDesc("color", text))
    d.callback, d.data = callback, info
    return d
end
function MenuDesc:SetTooltip(fn) self.tooltip = fn end
function MenuDesc:SetScrollMode(h) self.scrollMode = h end
function MenuDesc:IsSelected() return self.isSelected and self.isSelected(self.data) or false end

MenuUtil = {
    CreateContextMenu = function(owner, generator, ...)
        local root = NewDesc("root")
        generator(owner, root, ...)
        M.menu, M.menuOwner = root, owner
        return root
    end,
}
function M.FindMenu(root, ...)
    local d = root
    for i = 1, select("#", ...) do
        local text = select(i, ...)
        local found
        for _, c in ipairs(d and d.children or {}) do
            if c.text == text then found = c break end
        end
        d = found
        if not d then return nil end
    end
    return d
end
function M.ClickMenu(d)
    if d.kind == "checkbox" or d.kind == "radio" then
        return d.setSelected(d.data)
    elseif d.callback then
        return d.callback(d.data)
    end
end

-------------------------------------------------------------------------------
-- Time, performance and the game's panels
-------------------------------------------------------------------------------

-- M.fixedTime pins time() and date(); M.gameTime = { hour, minute } is the realm clock.
M.gameTime = { 22, 19 }
function time(t) if t then return os.time(t) end return M.fixedTime or os.time() end
function date(fmt, t) return os.date(fmt, t or M.fixedTime) end
function GetGameTime() return M.gameTime[1], M.gameTime[2] end
M.fps, M.latency = 60, { 40, 110 }
function GetFramerate() return M.fps end
function GetNetStats() return 1.5, 0.8, M.latency[1], M.latency[2] end
M.addons = { { name = "Questie", kb = 30000 }, { name = "Auctionator", kb = 8000 } }
function UpdateAddOnMemoryUsage() M.addonMemoryUpdates = (M.addonMemoryUpdates or 0) + 1 end
function GetAddOnMemoryUsage(i) return M.addons[i] and M.addons[i].kb or 0 end
C_AddOns = C_AddOns or {}
C_AddOns.GetNumAddOns = function() return #M.addons end
C_AddOns.GetAddOnInfo = function(i) return M.addons[i] and M.addons[i].name end
function GetRealmName() return M.realm or "Forever" end

-- Blizzard panel toggles record their calls in M.calls.
M.calls = {}
local function Recorder(name)
    return function(...)
        local args = { ... }
        for i = 1, select("#", ...) do args[i] = tostring(args[i]) end
        M.calls[#M.calls + 1] = name .. (#args > 0 and ("(" .. table.concat(args, ",") .. ")") or "")
    end
end
for _, name in ipairs({ "ToggleCharacter", "ToggleFriendsFrame", "ToggleCalendar", "ToggleAllBags",
    "ToggleHelpFrame", "TogglePVPUI", "ToggleEncounterJournal", "ToggleGameMenu", "ToggleGuildFrame" }) do
    _G[name] = Recorder(name)
end
-- M.chatBox = { Insert = function(self, text) end } is the open chat edit box.
ChatFrameUtil = {
    GetActiveWindow = function() return M.chatBox end,
    -- Like the client: false when no edit box is open.
    InsertLink = function(link)
        if not M.chatBox then return false end
        M.chatBox:Insert(link)
        return true
    end,
}
function M.Calls() local c = M.calls; M.calls = {}; return c end

-------------------------------------------------------------------------------
-- Casting. M.units[unit].cast / .channel = { name, texture, startMs, endMs,
-- notInterruptible, spellID }. With M.secrets = true, casts of units other
-- than the player and pet come back secret (SecretWhenUnitSpellCastRestricted).
-- The *Duration functions return duration objects with the remaining/total
-- getters, secret under the same rule.
-------------------------------------------------------------------------------

local function CastSecret(unit) return M.secrets and unit ~= "player" and unit ~= "pet" end
local function CS(unit, v)
    if v ~= nil and CastSecret(unit) then return M.MakeSecret(v) end
    return v
end
function UnitCastingInfo(unit)
    local u = Unit(unit)
    local c = u and u.cast
    if not c then return end
    return CS(unit, c.name), CS(unit, c.name), CS(unit, c.texture), CS(unit, c.startMs), CS(unit, c.endMs),
        false, CS(unit, "Cast-" .. unit), CS(unit, c.notInterruptible or false), CS(unit, c.spellID or 0)
end
function UnitChannelInfo(unit)
    local u = Unit(unit)
    local c = u and u.channel
    if not c then return end
    return CS(unit, c.name), CS(unit, c.name), CS(unit, c.texture), CS(unit, c.startMs), CS(unit, c.endMs),
        false, CS(unit, c.notInterruptible or false), CS(unit, c.spellID or 0)
end
local DurationObject = {}
DurationObject.__index = DurationObject
function DurationObject:GetRemainingDuration() return CS(self.unit, math.max(0, self.endMs / 1000 - M.now)) end
function DurationObject:GetTotalDuration() return CS(self.unit, (self.endMs - self.startMs) / 1000) end
function DurationObject:HasSecretValues() return CastSecret(self.unit) end
local function Duration(unit, c)
    if not c then return end
    return setmetatable({ unit = unit, startMs = c.startMs, endMs = c.endMs }, DurationObject)
end
function UnitCastingDuration(unit) local u = Unit(unit); return u and Duration(unit, u.cast) end
function UnitChannelDuration(unit) local u = Unit(unit); return u and Duration(unit, u.channel) end

-------------------------------------------------------------------------------
-- Experience and reputation. M.units.player.xp / xpMax; M.rested;
-- M.watchedFaction = C_Reputation.GetWatchedFactionData's table.
-------------------------------------------------------------------------------

function UnitXP(unit) local u = Unit(unit); return u and u.xp or 0 end
function UnitXPMax(unit) local u = Unit(unit); return u and u.xpMax or 0 end
function GetXPExhaustion() return M.rested end
function IsXPUserDisabled() return false end
function GetMaxPlayerLevel() return 60 end
C_Reputation.GetWatchedFactionData = function() return M.watchedFaction end
FACTION_STANDING_LABEL1, FACTION_STANDING_LABEL2, FACTION_STANDING_LABEL3 = "Hated", "Hostile", "Unfriendly"
FACTION_STANDING_LABEL7, FACTION_STANDING_LABEL8 = "Revered", "Exalted"

-------------------------------------------------------------------------------
-- Durability and repairs. M.durability[slotID] = { current, max };
-- M.repairCosts[slotID] = copper (C_TooltipInfo); M.merchant = { canRepair, cost }.
-------------------------------------------------------------------------------

local SLOT_IDS = { HeadSlot = 1, NeckSlot = 2, ShoulderSlot = 3, ChestSlot = 5, WaistSlot = 6, LegsSlot = 7,
    FeetSlot = 8, WristSlot = 9, HandsSlot = 10, MainHandSlot = 16, SecondaryHandSlot = 17, RangedSlot = 18 }
M.durability, M.repairCosts, M.repairs = {}, {}, {}
function GetInventorySlotInfo(name) return SLOT_IDS[name] end
function GetInventoryItemDurability(slot)
    local d = M.durability[slot]
    if d then return d[1], d[2] end
end
C_TooltipInfo = { GetInventoryItem = function(_, slot) return { repairCost = M.repairCosts[slot] } end }
C_Container = {
    GetContainerNumSlots = function() return 0 end,
    GetContainerItemDurability = function() return nil end,
    GetItemCooldown = function(id) local c = M.itemCooldowns and M.itemCooldowns[id]; return c and c[1] or 0, c and c[2] or 0, 1 end,
}
function CanMerchantRepair() return M.merchant ~= nil and M.merchant.canRepair end
function GetRepairAllCost() return M.merchant and M.merchant.cost or 0, M.merchant ~= nil end
function RepairAllItems(guild) M.repairs[#M.repairs + 1] = guild and "guild" or "self" end
function CanGuildBankRepair() return false end

-------------------------------------------------------------------------------
-- Spells and bind location. M.knownSpells[id] = true; M.spellCooldowns[id] =
-- { start, duration }; M.spellCosts[id] = { { type = 0, cost = 50 }, ... }.
-------------------------------------------------------------------------------

M.knownSpells, M.spellCooldowns, M.spellCosts = {}, {}, {}
C_SpellBook = { IsSpellKnown = function(id) return M.knownSpells[id] == true end }
C_Spell = {
    GetSpellName = function(id) return M.spellNames and M.spellNames[id] end,
    GetSpellTexture = function() return 136235 end,
    GetSpellCooldown = function(id)
        local c = M.spellCooldowns[id]
        return { startTime = c and c[1] or 0, duration = c and c[2] or 0, isEnabled = true, modRate = 1 }
    end,
    GetSpellPowerCost = function(id) return M.spellCosts[id] end,
}
C_Item.GetItemNameByID = function(id) return M.items[id] and M.items[id].name end
C_Item.GetItemIconByID = function(id) return M.items[id] and M.items[id].icon end
C_Item.IsEquippedItem = function() return false end
M.bindLocation = "Ironforge"
function GetBindLocation() return M.bindLocation end

-------------------------------------------------------------------------------
-- PvP. M.pvp = { session = { hk, dk }, yesterday = { hk, dk }, lifetime = hk,
-- flagged, winner, faction (0 Horde / 1 Alliance), instance = { inInstance, type, name } }
-------------------------------------------------------------------------------

M.pvp = { session = { 0, 0 }, yesterday = { 0, 0 }, lifetime = 0 }
function GetPVPSessionStats() return M.pvp.session[1], M.pvp.session[2] end
function GetPVPYesterdayStats() return M.pvp.yesterday[1], M.pvp.yesterday[2] end
function GetPVPLifetimeStats() return M.pvp.lifetime, 0 end
function GetPVPTimer() return M.pvp.timer or 301000 end
function IsPVPTimerRunning() return M.pvp.timer ~= nil end
function GetBattlefieldWinner() return M.pvp.winner end
function GetBattlefieldArenaFaction() return M.pvp.faction end
function IsInInstance()
    local i = M.pvp.instance
    if i then return i[1], i[2] end
    return false, "none"
end
function GetInstanceInfo()
    local i = M.pvp.instance
    return i and i[3] or "Elwynn Forest"
end
function GetZoneText() return M.zone or "Elwynn Forest" end

return M
