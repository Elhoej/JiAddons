local _, ns = ...

-- The unit frames: player, target (+ target of target), pet and party1-4
-- (+ their pets), laid out like Nurfed's "DPS" layout. Frames are secure unit
-- buttons, so left-click targets and right-click opens the unit menu even in
-- combat, and the client shows/hides them as units come and go.

local E, U, W = ns.Elements, ns.Unit, ns.Widgets

local Frames = {}
ns.Frames = Frames

local frames = {}   -- [key] = frame
local order = {}    -- frames in creation order
local byUnit = {}   -- [unit] = { frame, ... }
Frames.frames = frames

local PARTY_SIZE = 4

-------------------------------------------------------------------------------
-- Frame skeleton
-------------------------------------------------------------------------------

local function OnEnter(self)
    local unit = Frames:DisplayUnit(self)
    if GameTooltip_SetDefaultAnchor then
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
    else
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    end
    GameTooltip:SetUnit(unit)
    GameTooltip:Show()
end

local function OnLeave(self)
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end

-- Dragging moves the frame's mover (party frames move as a group, party pets
-- move with their party frame).
local function OnDragStart(self)
    local mover = self.mover
    if ns.db.locked or InCombatLockdown() or not mover then return end
    mover:StartMoving()
end

local function OnDragStop(self)
    local mover = self.mover
    if not mover then return end
    mover:StopMovingOrSizing()
    if mover.SetUserPlaced then mover:SetUserPlaced(false) end
    local point, _, relPoint, x, y = mover:GetPoint(1)
    if point then
        ns.db.positions[mover.positionKey] = { point, relPoint, math.floor(x + 0.5), math.floor(y + 0.5) }
    end
end

local function NewUnitFrame(key, unit, parent, width, height, small)
    local f = W.NewFrame("Button", parent or UIParent, "SecureUnitButtonTemplate", "JiUnitFrames_" .. key)
    f.key, f.unit = key, unit
    f:SetSize(width, height)
    f:SetFrameStrata("LOW")
    f:SetClampedToScreen(true)
    f:SetBackdrop(small and E.BACKDROP_SMALL or E.BACKDROP)
    f:SetBackdropColor(0, 0, 0, 0.75)
    f:SetBackdropBorderColor(0, 0, 0, 1)

    f:SetAttribute("unit", unit)
    f:SetAttribute("*type1", "target")
    f:SetAttribute("*type2", "togglemenu")
    f:RegisterForClicks("AnyUp")
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnEnter", OnEnter)
    f:SetScript("OnLeave", OnLeave)
    f:SetScript("OnDragStart", OnDragStart)
    f:SetScript("OnDragStop", OnDragStop)
    f:HookScript("OnShow", function(self) Frames:Update(self) end)

    frames[key] = f
    order[#order + 1] = f
    byUnit[unit] = byUnit[unit] or {}
    table.insert(byUnit[unit], f)
    return f
end

local function MakeMover(f, positionKey)
    f:SetMovable(true)
    f.mover, f.positionKey = f, positionKey
end

-- Aura rows the client could create (see E.AuraRow).
local function AuraRows(f, ...)
    local rows = {}
    for i = 1, select("#", ...) do
        local row = E.AuraRow(f, (select(i, ...)))
        if row then rows[#rows + 1] = row end
    end
    return rows
end

local function Place(region, ...)
    region:SetPoint(...)
    return region
end

-------------------------------------------------------------------------------
-- Layouts (sizes and offsets from Nurfed_UnitFrames Layout_2.lua)
-------------------------------------------------------------------------------

-- 80x22 frame with a name and a health bar showing the percentage.
local function BuildMini(key, unit, parent)
    local f = NewUnitFrame(key, unit, parent, 80, 22, true)
    f.health = Place(E.Bar(f, 74, 9, { 1, 0, 0, 0.25 }), "BOTTOMLEFT", 3, 3)
    f.healthPercent = E.Text(f.health, 8, nil, "RIGHT")
    f.healthPercent:SetAllPoints()
    f.percentWhite = true -- Nurfed leaves the mini frame percentage white
    f.name = Place(E.Text(f, 8), "TOPLEFT", 3, -2)
    f.name:SetSize(75, 8)
    f.nameStyle = "plain"
    -- No events cover these units' targets changing; poll like Nurfed.
    if unit:find("target", 1, true) then
        local elapsed = 0
        f:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            if elapsed > 0.25 then
                elapsed = 0
                Frames:Update(self)
            end
        end)
    end
    return f
end

local function BuildPlayer()
    local f = NewUnitFrame("player", "player", UIParent, 210, 53)
    MakeMover(f, "player")
    f.health = Place(E.HealthBar(f, 157, 16, true), "BOTTOMRIGHT", -5, 16)
    f.power = Place(E.PowerBar(f, 157, 10), "BOTTOMRIGHT", -5, 5)
    -- Under the frame, its bar right below the power bar.
    f.druidMana = E.DruidManaBar(f)
    f.druidMana.holder:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", -2, 1)
    -- The spark moves to the druid bar while the power bar shows energy or rage.
    f.manaSpark = ns.ManaSpark:Attach(f.power, function()
        return U.Plain(UnitPowerType("player")) == (Enum and Enum.PowerType and Enum.PowerType.Mana or 0)
    end)
    f.druidMana.spark = ns.ManaSpark:Attach(f.druidMana, function() return true end)
    f.portrait = E.Portrait(f, 43)
    f.portrait:SetPoint("BOTTOMLEFT", 5, 4)
    f.name = Place(E.Text(f, 10), "TOPLEFT", 48, -5)
    f.name:SetSize(65, 10)
    f.nameStyle = "plain"
    f.level = Place(E.Text(f, 10, nil, "RIGHT"), "TOP", 10, -5)
    f.level:SetSize(20, 10)
    f.levelStyle = "level"
    f.group = Place(E.Text(f, 8), "TOPLEFT", 48, -14)
    f.group:SetSize(60, 8)
    f.status = Place(E.Icon(f, 20, 20), "TOPRIGHT", -39, -3)
    f.rank = Place(E.Icon(f, 17, 17), "TOPRIGHT", -22, -4)
    f.pvp = E.IconLayouts(E.Icon(f, 28, 28), { 28, 28, "TOPRIGHT", 5, -4 }, { 16, 16, "TOPRIGHT", -5, -5 })
    f.leader = Place(E.Icon(f, 10, 10), "TOP", 28, -4)
    f.master = Place(E.Icon(f, 9, 9), "TOP", 28, -12)
    f.auraRows = AuraRows(f,
        { harmful = true, max = 16, perRow = 8, size = 17, spacing = 2, border = true,
            point = "BOTTOMLEFT", relPoint = "TOPLEFT", x = 4, y = -2, grow = "UP" })
    return f
end

local function BuildTarget()
    local f = NewUnitFrame("target", "target", UIParent, 210, 53)
    MakeMover(f, "target")
    f.health = Place(E.HealthBar(f, 157, 16, true), "BOTTOMLEFT", 5, 16)
    f.power = Place(E.PowerBar(f, 157, 10), "BOTTOMLEFT", 5, 5)
    f.portrait = E.Portrait(f, 43)
    f.portrait:SetPoint("BOTTOMRIGHT", -4, 5)
    f.name = Place(E.Text(f, 10), "TOPLEFT", 5, -4)
    f.name:SetSize(110, 10)
    f.nameStyle = "guild"
    f.level = Place(E.Text(f, 8), "TOPLEFT", 5, -14)
    f.level:SetSize(100, 8)
    f.levelStyle = "class"
    f.healthPercent = Place(E.Text(f, 9, nil, "RIGHT"), "TOPRIGHT", -63, -12)
    f.healthPercent:SetSize(60, 9)
    f.pvp = E.IconLayouts(E.Icon(f, 29, 29), { 29, 29, "TOPRIGHT", -35, -4 }, { 14, 14, "TOPRIGHT", -48, -4 })
    f.rank = Place(E.Icon(f, 20, 20), "TOPRIGHT", f, "TOPLEFT", 3, -4)
    f.raidTarget = Place(E.Icon(f, 15, 15), "TOPLEFT", f, "TOPRIGHT", 0, -5)
    f.combo = Place(E.Text(f, 22, "OUTLINE", "RIGHT"), "BOTTOMRIGHT", f, "BOTTOMLEFT", 2, 3)
    f.combo:Hide()
    f.auraRows = AuraRows(f,
        { harmful = false, max = 32, perRow = 16, size = 17, spacing = 2, border = true,
            point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = 4, y = 2, grow = "DOWN" },
        { harmful = true, max = 16, perRow = 8, size = 17, spacing = 2, border = true,
            point = "BOTTOMLEFT", relPoint = "TOPLEFT", x = 4, y = -2, grow = "UP" })
    return f
end

local function BuildTargetTarget()
    local f = BuildMini("targettarget", "targettarget", UIParent)
    MakeMover(f, "targettarget")
    return f
end

local function BuildPet()
    local f = NewUnitFrame("pet", "pet", UIParent, 160, 43)
    MakeMover(f, "pet")
    f.health = Place(E.HealthBar(f, 150, 12, true), "BOTTOMRIGHT", -5, 14)
    f.power = Place(E.PowerBar(f, 150, 8), "BOTTOMRIGHT", -5, 5)
    f.name = Place(E.Text(f, 10), "TOPLEFT", 5, -4)
    f.name:SetSize(110, 10)
    f.nameStyle = "level"
    f.healthPercent = Place(E.Text(f, 9, "OUTLINE", "RIGHT"), "TOPRIGHT", -5, -5)
    f.happiness = Place(E.Icon(f, 14, 14), "TOPRIGHT", -40, -4)
    f.auraRows = AuraRows(f,
        { harmful = false, max = 16, perRow = 16, size = 16,
            point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = 4, y = 2, grow = "DOWN" },
        { harmful = true, max = 16, perRow = 16, size = 16,
            point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = 4, y = -20, grow = "DOWN" })
    return f
end

local function BuildParty(i)
    local f = NewUnitFrame("party" .. i, "party" .. i, UIParent, 190, 41)
    f.health = Place(E.HealthBar(f, 157, 12, true), "BOTTOMRIGHT", -5, 14)
    f.power = Place(E.PowerBar(f, 157, 8), "BOTTOMRIGHT", -5, 5)
    f.classIcon = Place(E.Icon(f, 23, 23), "TOPLEFT", 5, -4)
    f.highlight = Place(E.Icon(f, 130, 12, "ARTWORK"), "TOPRIGHT", -5, -4)
    f.highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    f.highlight:SetBlendMode("ADD")
    f.leader = Place(E.Icon(f, 12, 13), "TOPLEFT", 5, -25)
    f.master = Place(E.Icon(f, 11, 11), "TOPLEFT", 16, -26)
    f.pvp = E.IconLayouts(E.Icon(f, 20, 20), { 20, 20, "TOPRIGHT", 4, -4 }, { 11, 11, "TOPRIGHT", -4, -5 })
    f.name = Place(E.Text(f, 10), "TOPLEFT", 28, -4)
    f.name:SetSize(120, 10)
    f.nameStyle = "key"
    f.bindingAction = "TARGETPARTYMEMBER" .. i
    f.healthPercent = Place(E.Text(f, 10, "OUTLINE", "RIGHT"), "TOPRIGHT", -15, -5)
    f.auraRows = AuraRows(f,
        { harmful = false, max = 32, perRow = 16, size = 16,
            point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = 4, y = 2, grow = "DOWN" },
        { harmful = true, max = 4, perRow = 4, size = 16, spacing = 1,
            point = "TOPLEFT", relPoint = "TOPRIGHT", x = -3, y = -2, grow = "DOWN" })
    if i == 1 then
        MakeMover(f, "party")
    else
        f.mover = frames.party1
    end

    local pet = BuildMini("partypet" .. i, "partypet" .. i, f)
    pet:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", -4, 2)
    pet.mover = f.mover
    return f
end

-------------------------------------------------------------------------------
-- Updating
-------------------------------------------------------------------------------

-- While unlocked, frames without a unit show the player as sample data.
function Frames:DisplayUnit(f)
    if self.testMode and not UnitExists(f.unit) then return "player" end
    return f.unit
end

local FULL_UPDATE = {
    E.UpdateName, E.UpdateLevel, E.UpdateGroup, E.UpdatePortrait, E.UpdateClassIcon,
    E.UpdateLeader, E.UpdateMasterLooter, E.UpdatePvP, E.UpdateRank, E.UpdateRaidTarget,
    E.UpdateStatus, E.UpdateCombo, E.UpdateHighlight, E.UpdateAuras,
}

local function UpdateHappiness(f, unit)
    local icon = f.happiness
    if not icon then return end
    local happiness = GetPetHappiness and U.Plain(GetPetHappiness())
    if unit == "pet" and happiness and happiness >= 1 and happiness <= 3 then
        icon:SetTexture("Interface\\PetPaperDollFrame\\UI-PetHappiness")
        local left = ({ 0.375, 0.1875, 0 })[happiness]
        icon:SetTexCoord(left, left + 0.1875, 0, 0.359375)
        icon:Show()
    else
        icon:Hide()
    end
end

function Frames:Update(f)
    if not f:IsVisible() then return end
    local unit = self:DisplayUnit(f)
    if not UnitExists(unit) then return end
    E.UpdateHealth(f, unit, true)
    E.UpdatePower(f, unit, true)
    E.UpdateDruidMana(f, unit, true)
    for _, fn in ipairs(FULL_UPDATE) do fn(f, unit) end
    UpdateHappiness(f, unit)
    if self.testMode and f.highlight then f.highlight:Hide() end
end

function Frames:UpdateAll()
    for _, f in ipairs(order) do self:Update(f) end
end

-- Runs fn(frame, unit) on every visible frame.
local function Each(fn)
    for _, f in ipairs(order) do
        if f:IsVisible() then fn(f, Frames:DisplayUnit(f)) end
    end
end

local function Refresh(key)
    local f = frames[key]
    if f then Frames:Update(f) end
end

-- Unit events and the elements they refresh.
local UNIT_EVENTS = {
    UNIT_HEALTH = { E.UpdateHealth },
    UNIT_MAXHEALTH = { E.UpdateHealth },
    UNIT_CONNECTION = { E.UpdateHealth, E.UpdatePower, E.RefreshPortrait },
    UNIT_FLAGS = { E.UpdateHealth, E.UpdatePvP },
    UNIT_POWER_FREQUENT = { E.UpdatePower, E.UpdateDruidMana },
    UNIT_MAXPOWER = { E.UpdatePower, E.UpdateDruidMana },
    UNIT_DISPLAYPOWER = { E.UpdatePower, E.UpdateDruidMana },
    UNIT_NAME_UPDATE = { E.UpdateName, E.UpdateClassIcon },
    UNIT_LEVEL = { E.UpdateLevel, E.UpdateName },
    UNIT_FACTION = { E.UpdatePvP, E.UpdateName, E.UpdateHealth },
    UNIT_PORTRAIT_UPDATE = { E.RefreshPortrait },
    UNIT_MODEL_CHANGED = { E.RefreshPortrait },
    UNIT_CLASSIFICATION_CHANGED = { E.UpdateLevel },
    PLAYER_FLAGS_CHANGED = { E.UpdatePvP },
    UNIT_HAPPINESS = { UpdateHappiness },
}

local function OnUnitEvent(event, unit)
    if ns.IsSecret(unit) then return end
    local list = byUnit[unit]
    if not list then return end
    for _, f in ipairs(list) do
        if f:IsVisible() then
            for _, fn in ipairs(UNIT_EVENTS[event]) do fn(f, unit) end
        end
    end
end

local PET_OF = { player = "pet" }
for i = 1, PARTY_SIZE do PET_OF["party" .. i] = "partypet" .. i end

local function PlayTargetSound()
    if not SOUNDKIT then return end
    if UnitExists("target") then
        if U.Bool(UnitIsEnemy and UnitIsEnemy("target", "player")) then
            PlaySound(SOUNDKIT.IG_CREATURE_AGGRO_SELECT)
        elseif U.Bool(UnitIsFriend("player", "target")) then
            PlaySound(SOUNDKIT.IG_CHARACTER_NPC_SELECT)
        else
            PlaySound(SOUNDKIT.IG_CREATURE_NEUTRAL_SELECT)
        end
    elseif SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT then
        PlaySound(SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT)
    end
end

function Frames:RegisterEvents()
    for event in pairs(UNIT_EVENTS) do
        ns:RegisterEvent(event, OnUnitEvent)
    end
    ns:RegisterEvent("UNIT_POWER_FREQUENT", function(_, unit, powerType)
        if unit == "player" and powerType == "COMBO_POINTS" and frames.target then
            E.UpdateCombo(frames.target)
        end
    end)
    ns:RegisterEvent("PLAYER_ENTERING_WORLD", function() Frames:SyncVisibility(); Frames:UpdateAll() end)
    -- UNIT_DISPLAYPOWER covers cat and bear; this is a fallback for form changes.
    ns:RegisterEvent("UPDATE_SHAPESHIFT_FORM", function()
        if frames.player:IsVisible() then E.UpdateDruidMana(frames.player, "player") end
    end)
    ns:RegisterEvent("PLAYER_TARGET_CHANGED", function()
        Frames:SyncVisibility()
        Refresh("target")
        Refresh("targettarget")
        Each(E.UpdateHighlight)
        PlayTargetSound()
    end)
    ns:RegisterEvent("UNIT_TARGET", function(_, unit)
        if unit == "target" then Refresh("targettarget") end
    end)
    ns:RegisterEvent("UNIT_PET", function(_, owner)
        local key = PET_OF[owner]
        if not key then return end
        Frames:SyncVisibility()
        Refresh(key)
    end)
    ns:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        Frames:SyncVisibility()
        Frames:UpdateAll()
    end)
    ns:RegisterEvent("PARTY_LEADER_CHANGED", function()
        Each(E.UpdateLeader)
        Each(E.UpdateMasterLooter)
    end)
    ns:RegisterEvent("PARTY_LOOT_METHOD_CHANGED", function() Each(E.UpdateMasterLooter) end)
    ns:RegisterEvent("RAID_TARGET_UPDATE", function() Each(E.UpdateRaidTarget) end)
    ns:RegisterEvent("UPDATE_BINDINGS", function() Each(E.UpdateName) end)
    ns:RegisterEvent("PLAYER_UPDATE_RESTING", function()
        if frames.player then E.UpdateStatus(frames.player, "player") end
    end)
    ns:RegisterEvent("PLAYER_REGEN_DISABLED", function()
        frames.player.inCombat = true
        E.UpdateStatus(frames.player, "player")
    end)
    ns:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        frames.player.inCombat = false
        E.UpdateStatus(frames.player, "player")
        Frames:SyncVisibility()
    end)
end

-------------------------------------------------------------------------------
-- Visibility, position and scale (out of combat only)
-------------------------------------------------------------------------------

local function Enabled(f)
    local db = ns.db
    local key = f.key
    if key == "pet" then return db.showPet end
    if key == "targettarget" then return db.showToT end
    if key:find("^partypet") then return db.showParty and db.showPartyPets end
    if key:find("^party") then return db.showParty end
    return true
end

local function PartyCondition(unit)
    return (ns.db.hidePartyInRaid and "[group:raid] hide; " or "") .. "[@" .. unit .. ",exists] show; hide"
end

-- Whether f should be shown right now (same rule the secure drivers use).
local function ShouldShow(f)
    if Frames.testMode then return Enabled(f) end
    if not Enabled(f) then return false end
    if f.key == "player" then return true end
    if f.key:find("^party%d") and ns.db.hidePartyInRaid and IsInRaid() then return false end
    return UnitExists(f.unit)
end

function Frames:ApplyVisibility(f)
    if f.key == "player" then return end
    UnregisterUnitWatch(f)
    UnregisterStateDriver(f, "visibility")
    if not self.testMode and Enabled(f) then
        if f.key:find("^party%d") then
            RegisterStateDriver(f, "visibility", PartyCondition(f.unit))
        else
            RegisterUnitWatch(f)
        end
    end
    f:SetShown(ShouldShow(f))
end

-- Belt and braces for the secure drivers: re-checks visibility out of combat.
function Frames:SyncVisibility()
    if InCombatLockdown() then return end
    for _, f in ipairs(order) do
        local show = ShouldShow(f)
        if f:IsShown() ~= show then f:SetShown(show) end
    end
end

-- Nurfed's sizes were made for 2005-era screens, so every frame is drawn 15%
-- larger; the scale sliders multiply on top of this (100% = BASE_SCALE).
-- Children (texts, auras, party pets) and position offsets scale along.
Frames.BASE_SCALE = 1.15

local SCALE_GROUP = { player = "player", target = "target", targettarget = "targettarget", pet = "pet" }
for i = 1, PARTY_SIZE do SCALE_GROUP["party" .. i] = "party" end

function Frames:ApplyLayout()
    local db = ns.db
    for _, f in ipairs(order) do
        local group = SCALE_GROUP[f.key]
        if group then f:SetScale(Frames.BASE_SCALE * (db.scale[group] or 1)) end
        if f.positionKey then
            local pos = db.positions[f.positionKey] or ns.defaults.positions[f.positionKey]
            f:ClearAllPoints()
            f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
        end
        self:ApplyVisibility(f)
        -- Unlocked frames get a green border.
        if self.testMode then
            f:SetBackdropBorderColor(0.2, 1, 0.2, 1)
        else
            f:SetBackdropBorderColor(0, 0, 0, 1)
        end
    end
    for i = 2, PARTY_SIZE do
        local f = frames["party" .. i]
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", frames.party1, "TOPLEFT", 0, -(i - 1) * db.partySpacing)
    end
end

function Frames:SetTestMode(on)
    self.testMode = on and true or false
    self:ApplyLayout()
    self:UpdateAll()
end

-------------------------------------------------------------------------------

function Frames:Init()
    if self.initialized then return end
    self.initialized = true
    BuildPlayer()
    BuildTarget()
    BuildTargetTarget()
    BuildPet()
    for i = 1, PARTY_SIZE do BuildParty(i) end
    self:ApplyLayout()
    self:RegisterEvents()
    self:UpdateAll()
end
