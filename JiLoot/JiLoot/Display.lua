local _, ns = ...

-- The loot frame: a stack of timed rows anchored to a movable handle.

local Display = {}
ns.Display = Display

local WHITE = "Interface\\Buttons\\WHITE8x8"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local BG_COLOR = { 0.075, 0.07, 0.047 }
local ICON_CROP = 0.08
local FADE_IN, FADE_OUT = 0.2, 0.4

local entries = {}   -- active entries, in display order after Sort()
local pool = {}      -- released rows
local seq = 0
local anchor

local function db() return ns.db end

-------------------------------------------------------------------------------
-- Rows
-------------------------------------------------------------------------------

local function CreateGlow(row)
    local glow = CreateFrame("Frame", nil, row)
    glow:SetPoint("TOPLEFT", -2, 2)
    glow:SetPoint("BOTTOMRIGHT", 2, -2)
    glow:SetFrameLevel(row:GetFrameLevel() + 3)
    glow.edges = {}
    local function Edge(p1, p2, horizontal)
        local t = glow:CreateTexture(nil, "OVERLAY")
        t:SetTexture(WHITE)
        t:SetPoint(p1)
        t:SetPoint(p2)
        if horizontal then t:SetHeight(2) else t:SetWidth(2) end
        glow.edges[#glow.edges + 1] = t
    end
    Edge("TOPLEFT", "TOPRIGHT", true)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
    Edge("TOPLEFT", "BOTTOMLEFT", false)
    Edge("TOPRIGHT", "BOTTOMRIGHT", false)
    function glow:SetColor(r, g, b)
        for _, t in ipairs(self.edges) do t:SetVertexColor(r, g, b) end
    end
    glow:Hide()
    return glow
end

local function Row_OnEnter(row)
    local e = row.entry
    if not e then return end
    e.hover = true
    if not db().showTooltip then return end
    -- Open the tooltip towards the middle of the screen.
    local x = row:GetCenter()
    local onRight = x and (x * row:GetEffectiveScale()) > (UIParent:GetWidth() * UIParent:GetEffectiveScale() / 2)
    GameTooltip:SetOwner(row, onRight and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
    local ok = false
    if e.link then
        ok = pcall(GameTooltip.SetHyperlink, GameTooltip, e.link)
    elseif e.currencyID and GameTooltip.SetCurrencyByID then
        ok = pcall(GameTooltip.SetCurrencyByID, GameTooltip, e.currencyID)
    end
    if not ok then
        GameTooltip:AddLine(ns.Colorize(e.colorHex, e.name))
        if e.kind == "money" then
            GameTooltip:AddLine(ns.Money(e.value), 1, 1, 1)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Right-click: dismiss", 0.6, 0.6, 0.6)
    if e.kind ~= "money" and e.kind ~= "honor" then
        GameTooltip:AddLine("Alt + Right-click: blacklist", 0.6, 0.6, 0.6)
    end
    if e.link then
        GameTooltip:AddLine("Shift-click: link in chat", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

local function Row_OnLeave(row)
    if row.entry then row.entry.hover = nil end
    if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
end

local function Row_OnClick(row, button)
    local e = row.entry
    if not e then return end
    if button == "RightButton" then
        if IsAltKeyDown() then
            local kind, key
            if e.kind == "item" then
                kind, key = "items", e.itemID
            elseif e.kind == "currency" then
                kind, key = "currencies", e.currencyID
            elseif e.kind == "rep" then
                kind, key = "factions", e.factionName
            end
            if kind and key then
                ns:SetBlacklisted(kind, key, true)
                ns.Print("blacklisted", e.link or ns.Colorize(e.colorHex, e.name),
                    "- undo with /jiloot bl", kind == "items" and "item" or kind == "currencies" and "currency" or "rep",
                    tostring(key))
            end
        end
        Display:Remove(e)
        if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
    elseif e.link and (IsShiftKeyDown() or IsControlKeyDown()) then
        if HandleModifiedItemClick then
            pcall(HandleModifiedItemClick, e.link)
        elseif ChatEdit_InsertLink then
            pcall(ChatEdit_InsertLink, e.link)
        end
    end
end

local function CreateRow()
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local row = CreateFrame("Button", nil, anchor, template)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    if row.SetBackdrop then
        row:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
        row:SetBackdropBorderColor(0, 0, 0, 1)
    end

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)

    row.profQuality = row:CreateTexture(nil, "OVERLAY")
    row.profQuality:SetPoint("TOPLEFT", row.icon, "TOPLEFT", -2, 2)
    row.profQuality:SetSize(20, 20)

    row.right = row:CreateFontString(nil, "OVERLAY")
    row.right:SetJustifyH("RIGHT")
    row.right:SetPoint("RIGHT", row, "RIGHT", -6, 0)

    row.left = row:CreateFontString(nil, "OVERLAY")
    row.left:SetJustifyH("LEFT")
    row.left:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.left:SetPoint("RIGHT", row.right, "LEFT", -6, 0)
    row.left:SetWordWrap(true)
    if row.left.SetMaxLines then row.left:SetMaxLines(3) end

    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetStatusBarTexture(WHITE)
    row.bar:SetMinMaxValues(0, 1)
    row.bar:SetHeight(2)
    row.bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 1)

    row.glow = CreateGlow(row)

    row:SetScript("OnEnter", Row_OnEnter)
    row:SetScript("OnLeave", Row_OnLeave)
    row:SetScript("OnClick", Row_OnClick)
    return row
end

function Display:StyleRow(row)
    local d = db()
    local h = d.height
    row:SetSize(d.width, h)
    if row.SetBackdropColor then
        row:SetBackdropColor(BG_COLOR[1], BG_COLOR[2], BG_COLOR[3], d.bgAlpha)
    end
    row.icon:ClearAllPoints()
    row.icon:SetPoint("LEFT", row, "LEFT", 1, 0)
    row.icon:SetSize(h - 2, h - 2)
    row.bar:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 0, 0)
    row.bar:SetShown(d.showTimerBar)
    row.left:SetFont(FONT, d.fontSize, "OUTLINE")
    row.right:SetFont(FONT, d.fontSize, "OUTLINE")
    row:EnableMouse(not d.clickThrough)
end

local function AcquireRow()
    local row = table.remove(pool) or CreateRow()
    Display:StyleRow(row)
    row:SetAlpha(0)
    row:Show()
    return row
end

local function ReleaseRow(row)
    if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
    row.entry = nil
    row.glow:Hide()
    row:Hide()
    row:ClearAllPoints()
    pool[#pool + 1] = row
end

-------------------------------------------------------------------------------
-- Text
-------------------------------------------------------------------------------

function Display:GetAuctionPrice(e)
    local d = db()
    if d.ahMode == 1 or e.kind ~= "item" then return nil end
    if e.isTest then return e.testAH end
    if not e.link or (e.quality == 0 and not d.ahJunk) then return nil end
    local ok, value
    if d.ahSource == 1 then
        local api = Auctionator and Auctionator.API and Auctionator.API.v1
        if api and api.GetAuctionPriceByItemLink then
            ok, value = pcall(api.GetAuctionPriceByItemLink, ns.name, e.link)
        end
    elseif d.ahSource == 2 and TSM_API and TSM_API.GetCustomPriceValue then
        local itemString = TSM_API.ToItemString and TSM_API.ToItemString(e.link)
            or (e.itemID and ("i:" .. e.itemID))
        if itemString then
            ok, value = pcall(TSM_API.GetCustomPriceValue,
                d.tsmSource == 1 and "dbmarket" or "dbminbuyout", itemString)
        end
    end
    return ok and tonumber(value) or nil
end

function Display:PriceText(e)
    local d = db()
    if e.kind == "money" then
        return ns.Money(e.value)
    elseif e.kind ~= "item" then
        return ""
    end
    local lines = {}
    local count = e.count
    local unit = e.unitPrice or 0
    local ah = self:GetAuctionPrice(e)
    e.ahPrice = ah
    if ah and ah > 0 then
        lines[#lines + 1] = ns.Money(d.ahMode == 3 and ah * count or ah, ns.ColorHex(d.ahColor))
    end
    if unit > 0 and (d.stackPriceMode ~= 3 or count == 1) then
        lines[#lines + 1] = ns.Money(unit)
    end
    if unit > 0 and count > 1 and d.stackPriceMode ~= 2 then
        lines[#lines + 1] = ns.Money(unit * count, ns.ColorHex(d.stackColor))
    end
    return table.concat(lines, "\n")
end

local function FormatCount(n)
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(n) end
    return tostring(n)
end

function Display:LeftText(e)
    local d = db()
    local prefix = ""
    if e.kind == "rep" then
        prefix = (e.count >= 0 and ("+" .. FormatCount(e.count)) or ("|cffff0000" .. FormatCount(e.count) .. "|r")) .. " "
    elseif e.kind ~= "money" and e.count > 1 then
        prefix = FormatCount(e.count) .. "x "
    end

    local suffix = e.suffix or ""
    if e.kind == "item" and d.invCount and not e.isGear then
        local have = e.isTest and e.testHave or (e.link and ns.GetItemCount(e.link)) or 0
        if have and have > 1 then
            suffix = " |cffffffff(" .. FormatCount(have) .. ")|r"
        end
    end

    local name = e.name or ""
    if d.maxNameLength and d.maxNameLength > 0 then
        name = ns.Truncate(name, math.max(3, d.maxNameLength - ns.VisibleLength(suffix)))
    end
    local text = prefix .. ns.Colorize(e.colorHex, name) .. suffix

    if e.isGear and (e.ilvl or e.tertiary or e.sockets) then
        local second = {}
        if e.ilvl then second[#second + 1] = "ilvl: " .. math.floor(e.ilvl) end
        if e.tertiary then second[#second + 1] = e.tertiary end
        if e.sockets then second[#second + 1] = e.sockets end
        text = text .. "\n" .. table.concat(second, " ")
    end
    return text
end

function Display:HighlightTier(e)
    local d = db()
    if not d.highlight then return 0 end
    local value
    if e.kind == "money" then
        value = e.value
    elseif e.kind == "item" then
        value = math.max(e.unitPrice or 0, e.ahPrice or 0) * (e.count or 1)
    end
    if not value or value <= 0 then return 0 end
    local mult = 100 ^ ((tonumber(d.highlightUnit) or 3) - 1)
    for tier = 3, 1, -1 do
        local threshold = tonumber(d.thresholds[tier])
        if threshold and threshold > 0 and value >= threshold * mult then
            return tier
        end
    end
    return 0
end

function Display:Refresh(e)
    local row = e.row
    if not row then return end
    local icon = e.icon
    if e.kind == "money" and ns.Sources.MoneyIcon then
        icon = ns.Sources.MoneyIcon(e.value)
    end
    row.icon:SetTexture(icon or 134400)
    if e.profQuality and row.profQuality.SetAtlas then
        row.profQuality:SetAtlas(e.profQuality)
        row.profQuality:Show()
    else
        row.profQuality:Hide()
    end
    row.right:SetText(self:PriceText(e))
    row.left:SetText(self:LeftText(e))

    local r, g, b = ns.QualityColor(e.quality)
    row.bar:SetStatusBarColor(r, g, b, 0.9)

    local tier = self:HighlightTier(e)
    if tier > 0 then
        local c = db().highlightColors[tier] or { 1, 1, 1 }
        row.glow:SetColor(c[1], c[2], c[3])
        row.glow:Show()
        if tier == 3 and db().highlightSound and not e.soundPlayed then
            e.soundPlayed = true
            local kit = SOUNDKIT and (SOUNDKIT.UI_LEGENDARY_LOOT_TOAST or SOUNDKIT.RAID_WARNING)
            PlaySound(kit or 8959, "Master")
        end
    else
        row.glow:Hide()
    end
end

function Display:RefreshAll()
    for _, e in ipairs(entries) do
        if e.row then
            self:StyleRow(e.row)
            self:Refresh(e)
        end
    end
end

-------------------------------------------------------------------------------
-- Ordering and layout
-------------------------------------------------------------------------------

local function Compare(a, b)
    local mode = db().sortMode
    if mode == 1 and a.prio ~= b.prio then
        return (a.prio or 0) > (b.prio or 0)
    end
    if mode == 3 then
        return a.seq < b.seq
    end
    return a.seq > b.seq
end

function Display:Layout()
    table.sort(entries, Compare)
    local d = db()
    local step = d.height + d.spacing
    for i, e in ipairs(entries) do
        e.targetY = (i - 1) * step * (d.growUp and 1 or -1)
        if not e.curY or not d.animations then
            e.curY = e.targetY
        end
        self:Position(e)
    end
end

function Display:Position(e)
    local row = e.row
    if not row then return end
    local up = db().growUp
    row:ClearAllPoints()
    row:SetPoint(up and "BOTTOMLEFT" or "TOPLEFT", anchor, up and "BOTTOMLEFT" or "TOPLEFT", e.curX or 0, e.curY)
end

-------------------------------------------------------------------------------
-- Entry lifecycle
-------------------------------------------------------------------------------

local function Merge(into, new)
    if new.kind == "money" then
        into.value = (into.value or 0) + (new.value or 0)
    else
        into.count = (into.count or 0) + (new.count or 0)
    end
    for _, k in ipairs({ "suffix", "ilvl", "tertiary", "sockets", "icon", "unitPrice", "testAH", "testHave" }) do
        if new[k] ~= nil then into[k] = new[k] end
    end
    into.duration = math.max(new.duration or 0, 0.5)
    into.expires = GetTime() + into.duration
    into.fading = nil
    into.soundPlayed = nil
end

function Display:Push(e)
    if not ns.db or not ns.db.enabled or not anchor then return end
    for _, existing in ipairs(entries) do
        if existing.key == e.key then
            Merge(existing, e)
            self:Refresh(existing)
            self:Layout()
            return existing
        end
    end

    local now = GetTime()
    seq = seq + 1
    e.seq = seq
    e.duration = math.max(e.duration or 5, 0.5)
    e.expires = now + e.duration
    e.alpha = ns.db.animations and 0 or 1
    e.curX = ns.db.animations and -24 or 0
    e.row = AcquireRow()
    e.row.entry = e
    entries[#entries + 1] = e

    -- Enforce the row limit by dropping the oldest entries.
    while #entries > ns.db.maxRows do
        local oldest
        for _, other in ipairs(entries) do
            if other ~= e and (not oldest or other.seq < oldest.seq) then oldest = other end
        end
        if not oldest then break end
        self:Remove(oldest, true)
    end

    self:Refresh(e)
    self:Layout()
    anchor:SetScript("OnUpdate", Display.OnUpdate)
    return e
end

function Display:Remove(e, skipLayout)
    for i, other in ipairs(entries) do
        if other == e then
            table.remove(entries, i)
            break
        end
    end
    if e.row then
        ReleaseRow(e.row)
        e.row = nil
    end
    if not skipLayout then self:Layout() end
end

function Display:Clear()
    for i = #entries, 1, -1 do
        self:Remove(entries[i], true)
    end
end

function Display.OnUpdate(_, elapsed)
    local now = GetTime()
    local d = db()
    local animate = d.animations
    local removed = false
    local pulse = 0.55 + 0.45 * math.sin(now * 6)
    local lerp = math.min(1, elapsed * 12)

    for i = #entries, 1, -1 do
        local e = entries[i]
        local row = e.row
        if e.hover then
            e.expires = e.expires + elapsed
            e.fading = nil
        end
        local remaining = e.expires - now
        if remaining <= 0 then e.fading = true end

        if e.fading then
            if animate then
                e.alpha = e.alpha - elapsed / FADE_OUT
            else
                e.alpha = 0
            end
            if e.alpha <= 0 then
                Display:Remove(e, true)
                removed = true
            end
        elseif e.alpha < 1 then
            e.alpha = animate and math.min(1, e.alpha + elapsed / FADE_IN) or 1
        end

        if e.row then
            row:SetAlpha(e.alpha)
            if d.showTimerBar then
                row.bar:SetValue(math.max(0, math.min(1, remaining / e.duration)))
            end
            local moved = false
            if e.curY ~= e.targetY then
                e.curY = e.curY + (e.targetY - e.curY) * lerp
                if math.abs(e.curY - e.targetY) < 0.5 then e.curY = e.targetY end
                moved = true
            end
            if e.curX and e.curX ~= 0 then
                e.curX = e.curX * (1 - lerp)
                if math.abs(e.curX) < 0.5 then e.curX = 0 end
                moved = true
            end
            if moved then Display:Position(e) end
            if row.glow:IsShown() then row.glow:SetAlpha(pulse) end
        end
    end

    if removed then Display:Layout() end
    if #entries == 0 then anchor:SetScript("OnUpdate", nil) end
end

-------------------------------------------------------------------------------
-- Anchor
-------------------------------------------------------------------------------

local function SavePosition()
    local point, _, relPoint, x, y = anchor:GetPoint(1)
    ns.db.point = { point, relPoint, math.floor(x + 0.5), math.floor(y + 0.5) }
end

function Display:SetLocked(locked)
    ns.db.locked = locked
    anchor:EnableMouse(not locked)
    anchor.overlay:SetShown(not locked)
    if not locked then
        ns.Print("frame unlocked - drag the green bar, right-click it (or /jiloot lock) to lock")
    end
    if ns.Options and ns.Options.Sync then ns.Options:Sync() end
end

function Display:ApplySettings()
    local d = db()
    anchor:SetScale(d.scale)
    anchor:SetSize(d.width, d.height)
    anchor:ClearAllPoints()
    local p = d.point
    anchor:SetPoint(p[1] or "CENTER", UIParent, p[2] or "CENTER", p[3] or 0, p[4] or 0)
    anchor.overlay:SetShown(not d.locked)
    anchor:EnableMouse(not d.locked)
    while #entries > d.maxRows do
        local oldest = entries[1]
        for _, e in ipairs(entries) do
            if e.seq < oldest.seq then oldest = e end
        end
        self:Remove(oldest, true)
    end
    self:RefreshAll()
    self:Layout()
end

function Display:Init()
    anchor = CreateFrame("Frame", "JiLootAnchor", UIParent)
    anchor:SetFrameStrata("MEDIUM")
    anchor:SetClampedToScreen(true)
    anchor:SetMovable(true)
    anchor:RegisterForDrag("LeftButton")
    anchor:SetScript("OnDragStart", function(self) self:StartMoving() end)
    anchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    anchor:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then Display:SetLocked(true) end
    end)

    local overlay = CreateFrame("Frame", nil, anchor)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(anchor:GetFrameLevel() + 20)
    local bg = overlay:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.1, 0.8, 0.4, 0.35)
    local text = overlay:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT, 12, "OUTLINE")
    text:SetPoint("CENTER")
    text:SetText("JiLoot - drag to move, right-click to lock")
    overlay:Hide()
    anchor.overlay = overlay

    self.anchor = anchor
    self:ApplySettings()

    -- Inventory counts lag the loot message; refresh them once bags settle.
    ns:RegisterEvent("BAG_UPDATE_DELAYED", function()
        if not db().invCount then return end
        for _, e in ipairs(entries) do
            if e.kind == "item" and not e.isGear and e.row then
                e.row.left:SetText(Display:LeftText(e))
            end
        end
    end)
end

-------------------------------------------------------------------------------
-- Test mode
-------------------------------------------------------------------------------

function Display:Test()
    if not ns.db.enabled then
        ns.Print("the frame is disabled - enable it with /jiloot toggle")
        return
    end
    local function hex(q) return select(4, ns.QualityColor(q)) end
    local durations = ns.db.durations
    local samples = {
        { kind = "rep", name = "Argent Dawn " .. (REPUTATION_ABBR or "Rep"), icon = 236681, quality = 7, count = 80,
          suffix = " |cffffffff(80 / 3000)|r |cffb0b0b0Friendly|r", prio = 10, duration = durations.rep },
        { kind = "honor", name = HONOR or "Honor", icon = 132486, quality = 6, count = 500,
          suffix = " |cffffffff(|r|cffff000015000 / 15000|r|cffffffff)|r", prio = 9, duration = durations.honor },
        { kind = "currency", name = "Timeworn Badge", icon = 134156, quality = 6, count = 40,
          suffix = " |cffffffff(2000)|r", prio = 9, duration = durations.currency },
        { kind = "item", name = "Some Epic Sword", icon = 135274, quality = 4, count = 1, isGear = true, ilvl = 66,
          tertiary = "|cff00ffffLeech|r", unitPrice = 12345, testAH = 18517, prio = 4, duration = durations.epic },
        { kind = "item", name = "Metal Hat", icon = 133071, quality = 3, count = 2, isGear = true, ilvl = 63,
          tertiary = "|cff00ffffIndestructible|r", unitPrice = 37035, testAH = 55552, prio = 3, duration = durations.rare },
        { kind = "item", name = "Damaged Chest", icon = 132739, quality = 2, count = 1, isGear = true, ilvl = 58,
          sockets = "|T458977:0|t|cffff00ffSocket|r", unitPrice = 24690, testAH = 37035, prio = 2, duration = durations.uncommon },
        { kind = "item", name = "Runecloth", icon = 132903, quality = 1, count = 20, unitPrice = 400, testAH = 1100,
          testHave = 48, prio = 1, duration = durations.common },
        { kind = "money", name = MONEY or "Money", icon = 133784, quality = 1, count = 1, value = 2000000,
          prio = -1, duration = durations.money },
    }
    for i, s in ipairs(samples) do
        s.key = "test:" .. i
        s.isTest = true
        s.colorHex = s.kind == "money" and "ffffffff" or hex(s.quality)
        -- Test rows always show, even for loot kinds set to a 0s duration.
        s.duration = math.max(tonumber(s.duration) or 0, 6)
        self:Push(s)
    end
end
