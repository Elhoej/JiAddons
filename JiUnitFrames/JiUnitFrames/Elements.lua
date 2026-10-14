local addonName, ns = ...

-- Building blocks of a unit frame (bars, texts, icons, portrait, aura rows)
-- and the functions that fill them from unit data. Every updater takes
-- (frame, unit) and does nothing when the frame lacks that element.

local U = ns.Unit
local IsSecret = ns.IsSecret

local E = {}
ns.Elements = E

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"
E.BAR_TEXTURE = MEDIA .. "statusbar"
E.BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    -- Nurfed's 5 leaves a visible seam inside the border on the modern client
    -- (pixel snapping at our scale). The border draws over the overlap.
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
E.BACKDROP_SMALL = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}
-- The frames' dark edge around aura icons (no background: it sits over the icon).
E.BACKDROP_AURA = {
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 8,
}
E.AURA_BORDER_PAD = 2

E.FONTS = { MEDIA .. "framd.ttf", STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", "Fonts\\ARIALN.TTF" }
E.FONT_NAMES = { "Nurfed (Franklin Gothic)", "Game default", "Arial Narrow" }

-------------------------------------------------------------------------------
-- Fonts
-------------------------------------------------------------------------------

local fontStrings = {}

local function ApplyFont(fs)
    local path = E.FONTS[ns.db and ns.db.font or 1] or E.FONTS[1]
    if fs:SetFont(path, fs.fontSize, fs.fontFlags) == false then
        fs:SetFont(E.FONTS[2], fs.fontSize, fs.fontFlags)
    end
end

function E.RefreshFonts()
    for _, fs in ipairs(fontStrings) do ApplyFont(fs) end
end

-- Nurfed's text style: white, shadowed, or outlined when flags = "OUTLINE".
-- static: skip later font changes (aura buttons are locked after creation).
function E.Text(parent, size, flags, justify, layer, static)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs.fontSize, fs.fontFlags = size, flags or ""
    ApplyFont(fs)
    if not static then fontStrings[#fontStrings + 1] = fs end
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    fs:SetTextColor(1, 1, 1)
    if fs.fontFlags == "" then
        fs:SetShadowColor(0, 0, 0, 0.75)
        fs:SetShadowOffset(-1, -1)
    end
    return fs
end

-------------------------------------------------------------------------------
-- Bars
-------------------------------------------------------------------------------

function E.Bar(parent, width, height, bg)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(width, height)
    bar:SetStatusBarTexture(E.BAR_TEXTURE)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetTexture(E.BAR_TEXTURE)
    bar.bg:SetVertexColor(bg[1], bg[2], bg[3], bg[4])
    return bar
end

-- "cur (max)" on the left, missing health in orange on the right.
function E.HealthBar(parent, width, height, withMissing)
    local bar = E.Bar(parent, width, height, { 1, 0, 0, 0.25 })
    bar.text = E.Text(bar, 10)
    bar.text:SetPoint("LEFT", 1, 0)
    bar.text:SetPoint("RIGHT", -1, 0)
    if withMissing then
        bar.missing = E.Text(bar, 10, "OUTLINE", "RIGHT")
        bar.missing:SetPoint("RIGHT", -1, 0)
        bar.missing:SetTextColor(1, 0.25, 0)
    end
    return bar
end

function E.PowerBar(parent, width, height)
    local bar = E.Bar(parent, width, height, { 0, 1, 1, 0.25 })
    bar.text = E.Text(bar, 10)
    bar.text:SetPoint("LEFT", 1, 0)
    bar.text:SetPoint("RIGHT", -1, 0)
    return bar
end

-- Nurfed glides bars towards new values; the client can do that natively
-- and it works with secret values, unlike a Lua OnUpdate.
local function SetBarValue(bar, value, instant)
    local interp = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
    if interp and not instant and ns.db.smoothBars then
        bar:SetValue(value, interp)
    else
        bar:SetValue(value)
    end
end

-- 1234567 -> "1.23m", 123456 -> "123.5k" (Nurfed's rules); plain values only.
local function Short(v)
    if v >= 1000000 then return string.format("%.2fm", v / 1000000) end
    if v >= 100000 then return string.format("%.1fk", v / 1000) end
    return tostring(v)
end

local function HealthColor(f, unit)
    local mode = ns.db.healthColor
    if mode == 2 then
        if U.Bool(UnitIsPlayer(unit)) then return U.ClassColor(U.UnitClassFile(unit)) end
        return U.NameColor(unit)
    elseif mode == 3 then
        return 0, 1, 0
    end
end

function E.UpdateHealth(f, unit, instant)
    local bar = f.health
    local pct = f.healthPercent
    if not bar and not pct then return end

    local cur, max = UnitHealth(unit), UnitHealthMax(unit)
    local offline = not U.Bool(UnitIsConnected(unit))
    local ghost = U.Bool(UnitIsGhost(unit))
    local dead = ghost or U.Bool(UnitIsDead(unit))
    local plain = not IsSecret(cur) and not IsSecret(max)
    local curves = U.Curves()

    if bar then
        bar:SetMinMaxValues(0, max)
        SetBarValue(bar, (dead or offline) and 0 or cur, instant)
        local text = bar.text
        if not text then
            -- mini frames: the bar only carries the percentage
        elseif offline then
            text:SetText(PLAYER_OFFLINE or "Offline")
        elseif ghost then
            text:SetText("Ghost")
        elseif dead then
            text:SetText(DEAD or "Dead")
        elseif plain then
            text:SetFormattedText("%d (%s)", cur, Short(max))
        else
            text:SetFormattedText("%d (%d)", cur, max)
        end

        if bar.missing then
            if dead or offline then
                bar.missing:SetText("")
            elseif plain then
                bar.missing:SetText(cur < max and ("-" .. Short(max - cur)) or "")
                bar.missing:SetAlpha(1)
            elseif UnitHealthMissing then
                bar.missing:SetFormattedText("-%d", UnitHealthMissing(unit))
                -- "-0" at full health: fade it out with a curve on the secret percentage.
                if not (curves and U.Try("missing alpha", function()
                    bar.missing:SetAlpha(UnitHealthPercent(unit, true, curves.hideFull))
                end)) then
                    bar.missing:SetAlpha(1)
                end
            else
                bar.missing:SetText("")
            end
        end
    end

    if pct then
        if offline then
            pct:SetText("")
        elseif plain then
            pct:SetFormattedText("%d%%", max > 0 and math.floor(cur / max * 100) or 0)
        elseif curves and UnitHealthPercent then
            U.Try("health percent", function()
                pct:SetFormattedText("%d%%", UnitHealthPercent(unit, true, curves.percent))
            end)
        else
            pct:SetText("")
        end
    end

    -- Colour of the bar and the percentage text.
    local r, g, b = HealthColor(f, unit)
    if dead or offline then
        r, g, b = 0.5, 0.5, 0.5
    end
    if f.percentWhite then pct = nil end
    if r then
        if bar then bar:SetStatusBarColor(r, g, b) end
        if pct then pct:SetTextColor(r, g, b) end
    elseif plain then
        r, g, b = U.HealthGradient(max > 0 and cur / max or 0)
        if bar then bar:SetStatusBarColor(r, g, b) end
        if pct then pct:SetTextColor(r, g, b) end
    elseif curves and UnitHealthPercent then
        U.Try("health color", function()
            local c = UnitHealthPercent(unit, true, curves.color)
            if bar then bar:SetStatusBarColor(c:GetRGB()) end
            if pct then pct:SetTextColor(c:GetRGB()) end
        end)
    end
end

function E.UpdatePower(f, unit, instant)
    local bar = f.power
    if not bar then return end
    local cur, max = UnitPower(unit), UnitPowerMax(unit)
    -- Units without power (max 0) hide the bar, like Nurfed.
    if not IsSecret(max) and max == 0 then
        bar:Hide()
        return
    end
    bar:Show()
    local r, g, b = U.PowerColor(unit)
    bar:SetStatusBarColor(r, g, b)
    bar.bg:SetVertexColor(r, g, b, 0.25)
    bar:SetMinMaxValues(0, max)
    local offline = not U.Bool(UnitIsConnected(unit))
    SetBarValue(bar, offline and 0 or cur, instant)
    if offline then
        bar.text:SetText("")
    elseif not IsSecret(cur) and not IsSecret(max) then
        bar.text:SetFormattedText("%d (%s)", cur, Short(max))
    else
        bar.text:SetFormattedText("%d (%d)", cur, max)
    end
end

-- Druids in cat and bear form: their mana on a strip under the player frame,
-- in the frames' small style, coloured like the mana bar.
local MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0

function E.DruidManaBar(parent)
    local holder = ns.Widgets.NewFrame("Frame", parent)
    holder:SetSize(163, 16)
    if holder.SetBackdrop then
        holder:SetBackdrop(E.BACKDROP_SMALL)
        holder:SetBackdropColor(0, 0, 0, 0.75)
        holder:SetBackdropBorderColor(0, 0, 0, 1)
    end
    local bar = E.PowerBar(holder, 157, 10)
    bar:SetPoint("BOTTOMRIGHT", -3, 3)
    local c = U.POWER_COLORS.MANA
    bar:SetStatusBarColor(c[1], c[2], c[3])
    bar.bg:SetVertexColor(c[1], c[2], c[3], 0.25)
    bar.holder = holder
    holder:Hide()
    return bar
end

local function ShowsDruidMana(unit)
    if not ns.db.druidMana or unit ~= "player" or U.UnitClassFile(unit) ~= "DRUID" then return false end
    -- Unlocked frames preview it.
    if ns.Frames and ns.Frames.testMode then return true end
    local powerType = UnitPowerType(unit)
    return not IsSecret(powerType) and powerType ~= MANA
end

function E.UpdateDruidMana(f, unit, instant)
    local bar = f.druidMana
    if not bar then return end
    local show = ShowsDruidMana(unit)
    bar.holder:SetShown(show)
    if not show then return end
    local cur, max = UnitPower(unit, MANA), UnitPowerMax(unit, MANA)
    bar:SetMinMaxValues(0, max)
    SetBarValue(bar, cur, instant)
    if not IsSecret(cur) and not IsSecret(max) then
        bar.text:SetFormattedText("%d (%s)", cur, Short(max))
    else
        bar.text:SetFormattedText("%d (%d)", cur, max)
    end
end

-------------------------------------------------------------------------------
-- Name and level
-------------------------------------------------------------------------------

-- Nurfed colours names only for players (class) and for "...target" units
-- (reaction); pets and the rest stay white.
local function NameHex(unit)
    if U.Bool(UnitIsPlayer(unit)) or unit:find("target", 1, true) then
        return U.Hex(U.NameColor(unit))
    end
    return "ffffffff"
end

local function SameGuild(guild)
    if IsSecret(guild) then return false end
    local own = GetGuildInfo and GetGuildInfo("player")
    return not IsSecret(own) and own == guild
end

-- f.nameStyle: "plain", "key" ("[F2] Name"), "guild" ("Name <Guild>"),
-- "level" ("[60] Name").
function E.UpdateName(f, unit)
    local fs = f.name
    if not fs then return end
    local name = UnitName(unit)
    if not U.Has(name) then
        fs:SetText("")
        return
    end
    local hex = NameHex(unit)
    local style = f.nameStyle
    if style == "key" then
        local label = ns.db.showKeyBindings and f.bindingAction and U.BindingLabel(f.bindingAction)
        fs:SetFormattedText("%s|c%s%s|r", label and ("[" .. label .. "] ") or "", hex, name)
    elseif style == "guild" then
        local guild = GetGuildInfo and GetGuildInfo(unit)
        if U.Has(guild) then
            fs:SetFormattedText("|c%s%s|r |c%s%s|r", hex, name, SameGuild(guild) and "ffff00ff" or "ff00bfff", guild)
        else
            fs:SetFormattedText("|c%s%s|r", hex, name)
        end
    elseif style == "level" then
        fs:SetFormattedText("[%s] |c%s%s|r", (U.LevelText(unit)), hex, name)
    else
        fs:SetFormattedText("|c%s%s|r", hex, name)
    end
end

-- f.levelStyle: "level" ("60") or "class" ("60 Hunter", "30+ Elite Beast").
function E.UpdateLevel(f, unit)
    local fs = f.level
    if not fs then return end
    local text, r, g, b = U.LevelText(unit)
    fs:SetTextColor(r, g, b)
    if f.levelStyle ~= "class" then
        fs:SetText(text)
        return
    end
    local prefix, label, hex = U.ClassLabel(unit)
    if prefix ~= "" then text = text .. " " .. prefix end
    if label == nil then
        fs:SetText(text)
    elseif hex then
        fs:SetFormattedText("%s |c%s%s|r", text, hex, label)
    else
        fs:SetFormattedText("%s %s", text, label)
    end
end

-- "Group: 3" on the player frame while in a raid.
function E.UpdateGroup(f, unit)
    local fs = f.group
    if not fs then return end
    local index = IsInRaid() and UnitInRaid and U.Plain(UnitInRaid(unit))
    local subgroup = index and GetRaidRosterInfo and select(3, GetRaidRosterInfo(index))
    if subgroup and not IsSecret(subgroup) then
        fs:SetFormattedText("%s: |cffffff00%d|r", GROUP or "Group", subgroup)
    else
        fs:SetText("")
    end
end

-------------------------------------------------------------------------------
-- Portrait: 3D face model, or the 2D portrait when the unit is out of
-- visual range (the model would show a question mark) or 3D is off.
-------------------------------------------------------------------------------

function E.Portrait(parent, size)
    local p = {}
    p.model = CreateFrame("PlayerModel", nil, parent)
    p.model:SetSize(size, size)
    p.tex = parent:CreateTexture(nil, "ARTWORK")
    p.tex:SetAllPoints(p.model)
    p.tex:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    p.tex:Hide()
    function p:SetPoint(...) self.model:SetPoint(...) end
    return p
end

-- Reloading the model makes it flicker, so full updates only reload it when
-- the unit or the 3D/2D mode changed; model events pass force.
function E.UpdatePortrait(f, unit, force)
    local p = f.portrait
    if not p then return end
    local use3D = ns.db.portrait3D and U.Bool(UnitIsVisible(unit)) and U.Bool(UnitIsConnected(unit))
    local guid = UnitGUID(unit)
    local same = not force and not IsSecret(guid) and guid == p.guid and use3D == p.use3D
    p.guid, p.use3D = U.Plain(guid), use3D
    if same then return end
    if use3D then
        p.tex:Hide()
        p.model:Show()
        U.Try("portrait", function()
            p.model:ClearModel()
            p.model:SetUnit(unit)
            p.model:SetPortraitZoom(1)
            p.model:SetPosition(0, 0, 0)
        end)
    else
        p.model:Hide()
        p.tex:Show()
        SetPortraitTexture(p.tex, unit)
    end
end

function E.RefreshPortrait(f, unit)
    E.UpdatePortrait(f, unit, true)
end

-------------------------------------------------------------------------------
-- Icons
-------------------------------------------------------------------------------

-- Prefers a modern atlas; falls back to the classic file (+ coords).
-- layout = { width, height, point, x, y } relative to the icon's parent.
local function ApplyIconLayout(tex, layout)
    if not layout or tex.appliedLayout == layout then return end
    tex.appliedLayout = layout
    tex:SetSize(layout[1], layout[2])
    tex:ClearAllPoints()
    tex:SetPoint(layout[3], layout[4], layout[5])
end

-- Icons whose modern atlas fills its box, unlike the padded classic file
-- Nurfed's sizes were made for, get a second, smaller layout for the atlas.
function E.IconLayouts(tex, fileLayout, atlasLayout)
    tex.fileLayout, tex.atlasLayout = fileLayout, atlasLayout
    ApplyIconLayout(tex, fileLayout)
    return tex
end

function E.SetIcon(tex, atlas, file, coords)
    if atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        tex:SetAtlas(atlas)
        tex:SetTexCoord(0, 1, 0, 1)
        ApplyIconLayout(tex, tex.atlasLayout)
    else
        tex:SetTexture(file)
        if coords then tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4]) else tex:SetTexCoord(0, 1, 0, 1) end
        ApplyIconLayout(tex, tex.fileLayout)
    end
end

function E.Icon(parent, width, height, layer)
    local tex = parent:CreateTexture(nil, layer or "OVERLAY")
    tex:SetSize(width, height)
    tex:Hide()
    return tex
end

function E.UpdateClassIcon(f, unit)
    if not f.classIcon then return end
    U.SetClassIcon(f.classIcon, U.Bool(UnitIsPlayer(unit)) and U.UnitClassFile(unit) or nil)
end

function E.UpdateLeader(f, unit)
    local icon = f.leader
    if not icon then return end
    if U.Bool(UnitIsGroupLeader(unit)) then
        E.SetIcon(icon, "UI-HUD-UnitFrame-Player-Group-LeaderIcon", "Interface\\GroupFrame\\UI-Group-LeaderIcon")
        icon:Show()
    else
        icon:Hide()
    end
end

local function GetLootMethod()
    if C_PartyInfo and C_PartyInfo.GetLootMethod then return C_PartyInfo.GetLootMethod() end
    if _G.GetLootMethod then return _G.GetLootMethod() end
end

function E.UpdateMasterLooter(f, unit)
    local icon = f.master
    if not icon then return end
    local _, partyID, raidID = GetLootMethod()
    local isMaster = false
    if raidID and IsInRaid() then
        isMaster = U.Bool(UnitIsUnit("raid" .. raidID, unit))
    elseif partyID then
        isMaster = U.Bool(UnitIsUnit(partyID == 0 and "player" or ("party" .. partyID), unit))
    end
    if isMaster and IsInGroup() then
        icon:SetTexture("Interface\\GroupFrame\\UI-Group-MasterLooter")
        icon:Show()
    else
        icon:Hide()
    end
end

function E.UpdatePvP(f, unit)
    local icon = f.pvp
    if not icon then return end
    local faction = U.Plain(UnitFactionGroup(unit))
    if U.Bool(UnitIsPVPFreeForAll(unit)) then
        E.SetIcon(icon, "UI-HUD-UnitFrame-Player-PVP-FFAIcon", "Interface\\TargetingFrame\\UI-PVP-FFA")
        icon:Show()
    elseif (faction == "Alliance" or faction == "Horde") and U.Bool(UnitIsPVP(unit)) then
        E.SetIcon(icon, "UI-HUD-UnitFrame-SmallCircle-" .. faction, "Interface\\TargetingFrame\\UI-PVP-" .. faction)
        icon:Show()
    else
        icon:Hide()
    end
end

-- Classic honor rank badge, when the client still has PvP ranks.
function E.UpdateRank(f, unit)
    local icon = f.rank
    if not icon then return end
    local rank = UnitPVPRank and GetPVPRankInfo and U.Plain(UnitPVPRank(unit))
    local number = rank and select(2, GetPVPRankInfo(rank, unit))
    if type(number) == "number" and number > 0 then
        icon:SetTexture(string.format("Interface\\PvPRankBadges\\PvPRank%02d", number))
        icon:Show()
    else
        icon:Hide()
    end
end

local RAID_TARGET_COORDS = 0.25

function E.UpdateRaidTarget(f, unit)
    local icon = f.raidTarget
    if not icon then return end
    local index = U.Plain(GetRaidTargetIndex(unit))
    if not index then
        icon:Hide()
        return
    end
    icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    if SetRaidTargetIconTexture then
        SetRaidTargetIconTexture(icon, index)
    else
        local col, row = (index - 1) % 4, math.floor((index - 1) / 4)
        icon:SetTexCoord(col * RAID_TARGET_COORDS, (col + 1) * RAID_TARGET_COORDS,
            row * RAID_TARGET_COORDS, (row + 1) * RAID_TARGET_COORDS)
    end
    icon:Show()
end

-- Resting or in-combat state on the player frame.
function E.UpdateStatus(f, unit)
    local icon = f.status
    if not icon then return end
    if f.inCombat or U.Bool(UnitAffectingCombat(unit)) then
        E.SetIcon(icon, "UI-HUD-UnitFrame-Player-CombatIcon", "Interface\\CharacterFrame\\UI-StateIcon",
            { 0.5, 1, 0, 0.484375 })
        icon:Show()
    elseif IsResting() then
        E.SetIcon(icon, nil, "Interface\\CharacterFrame\\UI-StateIcon", { 0, 0.5, 0, 0.421875 })
        icon:Show()
    else
        icon:Hide()
    end
end

-- Big combo point number left of the target frame: yellow, red at 5.
function E.UpdateCombo(f)
    local fs = f.combo
    if not fs then return end
    local points = GetComboPoints and U.Plain(GetComboPoints("player", "target"), 0) or 0
    if points > 0 then
        fs:SetText(points)
        if points < 5 then fs:SetTextColor(1, 1, 0) else fs:SetTextColor(1, 0, 0) end
        fs:Show()
    else
        fs:Hide()
    end
end

-- Party frames glow while their unit is targeted.
function E.UpdateHighlight(f, unit)
    local tex = f.highlight
    if not tex then return end
    tex:SetShown(UnitExists("target") and U.Bool(UnitIsUnit("target", unit)))
end

-------------------------------------------------------------------------------
-- Auras. Forever won't let addon code read aura data while auras are secret
-- (in combat, or for spells flagged secret): every C_UnitAuras call errors.
-- So each row is Blizzard's CustomAuraContainerTemplate. Its secure code picks
-- the auras and fills the buttons (icon, stacks, duration spiral, dispel
-- border, tooltip), even in combat. We only style buttons as they're created;
-- after that the client locks them against addon access.
--
-- Row cfg: harmful, max, perRow, size, spacing, point, relPoint, x, y,
-- grow ("DOWN" | "UP"), border (the frames' dark edge, drawn outside the
-- icon; give the row spacing so neighbouring borders meet in the gap). Debuff rows hold two groups: debuffs you can dispel
-- (first, flashing like Nurfed) and the rest.
-------------------------------------------------------------------------------

local function StyleAuraButton(b, cfg, flash)
    b:SetSize(cfg.size, cfg.size)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    b:SetIcon(icon)
    if ns.db.auras.cooldowns then
        local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
        cd:SetAllPoints()
        cd:SetReverse(true)
        cd:SetDrawEdge(false)
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
        b:SetDurationCooldown(cd)
    end
    -- Above the cooldown spiral; the stack count goes on it so the edge
    -- doesn't cut through the digits.
    local top = b
    if cfg.border then
        local pad = E.AURA_BORDER_PAD
        top = ns.Widgets.NewFrame("Frame", b)
        top:SetPoint("TOPLEFT", -pad, pad)
        top:SetPoint("BOTTOMRIGHT", pad, -pad)
        top:SetFrameLevel(b:GetFrameLevel() + 2)
        if top.SetBackdrop then
            top:SetBackdrop(E.BACKDROP_AURA)
            top:SetBackdropBorderColor(0, 0, 0, 1)
        end
    end
    local count = E.Text(top, 10, "OUTLINE", "RIGHT", nil, true)
    count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -1)
    b:SetApplicationCount(count)
    if cfg.harmful then
        -- Nurfed's debuff border, tinted by dispel type (red when there's none).
        local border = b:CreateTexture(nil, "OVERLAY")
        border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
        border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
        border:SetAllPoints()
        local styles = Enum.CustomAuraButtonDispelTypeTextureStyle
        b:AddDispelTypeTexture(border, { style = styles and styles.PreserveAsset or 3, showWithoutDispelType = true })
    end
    if flash then
        local pulse = b:CreateAnimationGroup()
        pulse:SetLooping("BOUNCE")
        local fade = pulse:CreateAnimation("Alpha")
        fade:SetFromAlpha(1)
        fade:SetToAlpha(0.3)
        fade:SetDuration(0.3)
        b:AddAuraShownAnimation(pulse)
    end
end

local function AddGroup(row, key, filter, flash, index)
    local cfg = row.cfg
    local spacing = cfg.spacing or 0
    row:AddAuraGroup(key, filter, {
        maxFrameCount = cfg.max,
        layout = { elementSpacing = spacing, groupSpacing = spacing, layoutIndex = index,
            elementWidth = cfg.size, elementHeight = cfg.size },
        initializeFrame = function(b) U.Try("aura button", StyleAuraButton, b, cfg, flash) end,
    })
end

-- Returns the row, or nil when the client lacks aura containers.
function E.AuraRow(owner, cfg)
    local dir = AnchorUtil and AnchorUtil.FlowDirection
    if not dir then return nil end
    local row
    U.Try("aura container", function()
        row = CreateFrame("AuraContainer", nil, owner, "CustomAuraContainerTemplate")
        row.cfg = cfg
        row:SetPoint(cfg.point, owner, cfg.relPoint, cfg.x, cfg.y)
        row:SetFlowLayoutAnchorPoint(cfg.point)
        row:SetFlowLayoutGrowthDirection(dir.Right, cfg.grow == "UP" and dir.Up or dir.Down)
        row:SetFlowLayoutMaximumLineSize(cfg.perRow * (cfg.size + (cfg.spacing or 0)))
        if cfg.harmful then
            AddGroup(row, "dispellable", "HARMFUL|RAID", ns.db.auras.flashDispellable, 1)
            AddGroup(row, "other", "HARMFUL|!RAID", false, 2)
        else
            AddGroup(row, "buffs", "HELPFUL", false, 1)
        end
        row:SetUnit(owner.unit)
    end)
    return row and row.cfg and row or nil
end

-- Applies the filter options and points the rows at unit. The containers
-- follow UNIT_AURA themselves; this covers unit swaps like target changes.
function E.UpdateAuras(f, unit)
    if not f.auraRows then return end
    local db = ns.db.auras
    local exempt = f.key == "target" and db.targetShowsAll
    for _, row in ipairs(f.auraRows) do
        U.Try("aura row", function()
            if row.cfg.harmful then
                row:SetAuraGroupEnabled("other", (exempt or not db.dispellableOnly) and true or false)
            else
                row:SetAuraGroupFilterString("buffs", (db.castableOnly and not exempt) and "HELPFUL|RAID" or "HELPFUL")
            end
            if row:GetUnit() ~= unit then
                row:SetUnit(unit)
            else
                row:UpdateAllAuras()
            end
        end)
    end
end
