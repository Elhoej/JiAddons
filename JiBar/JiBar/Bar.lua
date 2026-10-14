local _, ns = ...

-- Bars (FuBar's panels). Each bar is attached to the top or bottom edge of
-- the screen (several stack inwards) or floats freely, and lays out its
-- plugins in three groups: left-aligned, centred and right-aligned.
--
-- Unlocked (/jibar unlock), plugins can be dragged to any place on any bar,
-- bars can be dragged to another edge or to float, and their edges dragged
-- to resize them.

local W = ns.Widgets
local Bars = { list = {} }
ns.Bars = Bars

local MIN_WIDTH = 120
local SNAP = 0.12 -- drop within this fraction of the screen edge to attach there

local function ScreenSize()
    return UIParent:GetWidth() or 1920, UIParent:GetHeight() or 1080
end

-- Cursor position in UIParent coordinates.
local function Cursor()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale() or 1
    return (x or 0) / scale, (y or 0) / scale
end

-------------------------------------------------------------------------------
-- Construction
-------------------------------------------------------------------------------

local function CreateBarFrame(bar)
    local f = CreateFrame("Frame", "JiBarFrame" .. bar.index, UIParent)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f.bar = bar
    bar.frame = f

    bar.bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    bar.bg:SetAllPoints()
    bar.edge = f:CreateTexture(nil, "BORDER")
    bar.edge:SetHeight(1)

    -- Unlocked-mode decoration.
    local u = CreateFrame("Frame", nil, f)
    u:SetAllPoints()
    u:SetFrameLevel(f:GetFrameLevel() + 30)
    u:Hide()
    local border = u:CreateTexture(nil, "OVERLAY")
    border:SetAllPoints()
    border:SetColorTexture(0.2, 0.6, 1, 0.18)
    u.label = u:CreateFontString(nil, "OVERLAY")
    W.Font(u.label, 10, "OUTLINE")
    u.label:SetTextColor(0.6, 0.85, 1)
    bar.unlock = u

    -- Resize handles, shown while unlocked.
    bar.handles = {}
    for _, side in ipairs({ "LEFT", "RIGHT" }) do
        local h = CreateFrame("Frame", nil, f)
        h:SetWidth(8)
        h:SetPoint("TOP" .. side, f, "TOP" .. side)
        h:SetPoint("BOTTOM" .. side, f, "BOTTOM" .. side)
        h:SetFrameLevel(f:GetFrameLevel() + 40)
        h:EnableMouse(true)
        local tex = h:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints()
        tex:SetColorTexture(1, 0.82, 0, 0.6)
        h:SetScript("OnMouseDown", function(_, button)
            if button == "LeftButton" then Bars:BeginResize(bar, side) end
        end)
        h:SetScript("OnMouseUp", function() Bars:EndResize() end)
        h:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine("Drag to resize the bar")
            GameTooltip:Show()
        end)
        h:SetScript("OnLeave", function() GameTooltip:Hide() end)
        h:Hide()
        bar.handles[side] = h
    end

    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() if not ns.db.locked then Bars:BeginMove(bar) end end)
    f:SetScript("OnDragStop", function() Bars:EndMove() end)
    f:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then ns.Menu:OpenBar(bar) end
    end)
    f:SetScript("OnEnter", function() Bars:OnMouseActivity(bar) end)
    f:SetScript("OnUpdate", function(_, elapsed) Bars:OnBarUpdate(bar, elapsed) end)
end

-- Creates bar objects for db.bars, reusing frames by index.
function Bars:Build()
    local old = self.list
    self.list = {}
    for i, data in ipairs(ns.db.bars) do
        local bar = old[i] or { index = i }
        bar.index, bar.data = i, data
        bar.sides = bar.sides or { LEFT = {}, CENTER = {}, RIGHT = {} }
        if not bar.frame then CreateBarFrame(bar) end
        bar.frame:Show()
        self.list[i] = bar
    end
    for i = #ns.db.bars + 1, #old do
        old[i].frame:Hide()
        for _, side in ipairs(ns.SIDES) do wipe(old[i].sides[side]) end
    end
    self:LayoutAll()
end

-------------------------------------------------------------------------------
-- Position, background and layout
-------------------------------------------------------------------------------

-- Offset of a top/bottom bar from its screen edge: the heights of the bars
-- before it on the same edge.
local function EdgeOffset(bar)
    local offset = 0
    for i = 1, bar.index - 1 do
        local other = Bars.list[i]
        if other and other.data.attach == bar.data.attach then
            offset = offset + other.data.height * (other.data.scale or 1)
        end
    end
    return offset
end

function Bars:Position(bar)
    local data, f = bar.data, bar.frame
    local scale = data.scale or 1
    local sw, sh = ScreenSize()
    f:SetScale(scale)
    f:SetFrameStrata(data.strata or "MEDIUM")
    data.width = math.max(0.05, math.min(1, data.width or 1))
    data.x = math.max(0, math.min(1 - data.width, data.x or 0))
    local width = data.width * sw / scale
    f:SetSize(width, data.height)
    f:ClearAllPoints()
    local x = data.x * sw / scale
    if data.attach == "TOP" then
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, -EdgeOffset(bar) / scale)
    elseif data.attach == "BOTTOM" then
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, EdgeOffset(bar) / scale)
    else
        data.y = math.max(0, math.min(1, data.y or 0.5))
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, data.y * sh / scale)
    end
    bar.width = width
end

-- Tiles the skin horizontally and crops it vertically. Bordered skins keep
-- their border on the edge facing the middle of the screen.
function Bars:Skin(bar)
    local data, bg = bar.data, bar.bg
    local c = data.bgColor or { 1, 1, 1 }
    local skin = ns.FindByKey(ns.SKINS, data.skin) or ns.SKINS[1]
    if skin.file then
        bg:SetTexture(ns.MEDIA .. "Skins\\" .. skin.file, "REPEAT", "CLAMP")
        local u = (bar.width or 256) / 256
        local v = math.min(1, data.height / 256)
        if data.attach == "TOP" then
            bg:SetTexCoord(0, u, v, 0)
        else
            bg:SetTexCoord(0, u, 0, v)
        end
    else
        bg:SetTexture(W.WHITE)
        bg:SetTexCoord(0, 1, 0, 1)
    end
    bg:SetVertexColor(c[1], c[2], c[3])
    bg:SetAlpha(data.bgAlpha or 1)

    local edge = bar.edge
    edge:ClearAllPoints()
    local side = data.attach == "TOP" and "BOTTOM" or "TOP"
    edge:SetPoint(side .. "LEFT", bar.frame, side .. "LEFT")
    edge:SetPoint(side .. "RIGHT", bar.frame, side .. "RIGHT")
    local e = data.edgeColor or { 0, 0, 0 }
    edge:SetColorTexture(e[1], e[2], e[3], 1)
    edge:SetShown(data.edgeLine and true or false)
end

-- Places the plugins of one bar.
function Bars:Layout(bar)
    if not bar or not bar.data then return end
    local data = bar.data
    local width = bar.width or bar.frame:GetWidth() or 0
    local pad = data.padding or 6
    local spacing = data.spacing or {}

    local function Place(p, x)
        p.layoutX = x
        p.frame:ClearAllPoints()
        p.frame:SetPoint("LEFT", bar.frame, "LEFT", x, 0)
        p.frame:SetHeight(data.height)
    end
    local function W_(p)
        if not p.width then p.width = p:MeasureWidth() end
        return p.width
    end

    local x = pad
    for _, p in ipairs(bar.sides.LEFT) do
        Place(p, x)
        x = x + W_(p) + (spacing.LEFT or 10)
    end

    x = width - pad
    local right = bar.sides.RIGHT
    for i = #right, 1, -1 do
        local p = right[i]
        x = x - W_(p)
        Place(p, x)
        x = x - (spacing.RIGHT or 14)
    end

    local center = bar.sides.CENTER
    local total = 0
    for i, p in ipairs(center) do
        total = total + W_(p) + (i > 1 and (spacing.CENTER or 16) or 0)
    end
    x = (width - total) / 2
    for _, p in ipairs(center) do
        Place(p, x)
        x = x + W_(p) + (spacing.CENTER or 16)
    end

    for _, side in ipairs(ns.SIDES) do
        for _, p in ipairs(bar.sides[side]) do
            if p.OnBarLayout then p:OnBarLayout(bar) end
        end
    end
    self:QueueOverlaySync()
end

-- Secure overlays follow the layout one frame later, after anchors resolve.
function Bars:QueueOverlaySync()
    if self.syncQueued then return end
    self.syncQueued = true
    C_Timer.After(0, function()
        Bars.syncQueued = false
        ns.Plugins:SyncOverlays()
    end)
end

function Bars:LayoutAll()
    for _, bar in ipairs(self.list) do
        self:Position(bar)
        self:Skin(bar)
        self:UpdateVisibility(bar)
        self:UpdateUnlock(bar)
        for _, side in ipairs(ns.SIDES) do
            for _, p in ipairs(bar.sides[side]) do
                p.frame:SetHeight(bar.data.height)
            end
        end
        self:Layout(bar)
    end
end

-------------------------------------------------------------------------------
-- Visibility: auto-hide (fade out until hovered) and hide in combat
-------------------------------------------------------------------------------

function Bars:UpdateVisibility(bar)
    local data = bar.data
    local inCombat = InCombatLockdown() or UnitAffectingCombat("player")
    bar.frame:SetShown(not (data.hideInCombat and inCombat))
    if not data.autoHide or not ns.db.locked then
        bar.alpha = 1
        bar.frame:SetAlpha(1)
    end
end

function Bars:OnMouseActivity(bar)
    if bar then bar.holdUntil = GetTime() + 0.6 end
end

local function BarHovered(bar)
    if bar.frame:IsMouseOver() then return true end
    if bar.holdUntil and GetTime() < bar.holdUntil then return true end
    local owner = ns.Tip.owner
    return owner ~= nil and owner.bar == bar
end

function Bars:OnBarUpdate(bar, elapsed)
    local data = bar.data
    if not data or not data.autoHide or not ns.db.locked then return end
    local target = BarHovered(bar) and 1 or (data.autoHideAlpha or 0)
    local alpha = bar.alpha or 1
    if alpha ~= target then
        local step = elapsed * 4
        alpha = alpha < target and math.min(target, alpha + step) or math.max(target, alpha - step)
        bar.alpha = alpha
        bar.frame:SetAlpha(alpha)
    end
end

ns:RegisterEvent("PLAYER_REGEN_DISABLED", function()
    for _, bar in ipairs(Bars.list) do
        if bar.data.hideInCombat then bar.frame:Hide() end
    end
end)

ns:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    for _, bar in ipairs(Bars.list) do
        if bar.data.hideInCombat then bar.frame:Show() end
    end
end)

-------------------------------------------------------------------------------
-- Bars: adding, removing, attaching
-------------------------------------------------------------------------------

function Bars:AddBar()
    local data = ns.DeepCopy(ns.BAR_TEMPLATE)
    -- New bars go to the top unless the top is taken and the bottom is free.
    local top, bottom = false, false
    for _, b in ipairs(ns.db.bars) do
        if b.attach == "TOP" then top = true elseif b.attach == "BOTTOM" then bottom = true end
    end
    data.attach = (top and not bottom) and "BOTTOM" or "TOP"
    table.insert(ns.db.bars, data)
    self:Build()
    ns.Plugins:PlaceAll()
    ns.Print("Added bar " .. #ns.db.bars .. ". Unlock the bars to drag plugins onto it.")
    if ns.Options.Refresh then ns.Options:Refresh() end
    return #ns.db.bars
end

-- Plugins on a removed bar move to the first bar.
function Bars:RemoveBar(index)
    if #ns.db.bars <= 1 or not ns.db.bars[index] then return end
    for _, p in ipairs(ns.pluginList) do
        if p.db.bar == index then
            p.db.bar, p.db.order = 1, 99
        elseif p.db.bar > index then
            p.db.bar = p.db.bar - 1
        end
    end
    table.remove(ns.db.bars, index)
    self:Build()
    ns.Plugins:PlaceAll()
    if ns.Options.Refresh then ns.Options:Refresh() end
end

function Bars:SetAttach(index, attach)
    local data = ns.db.bars[index]
    if not data then return end
    if attach == "FLOAT" and data.attach ~= "FLOAT" then
        local bar = self.list[index]
        local _, sh = ScreenSize()
        local bottom = bar and bar.frame:GetBottom()
        data.y = bottom and (bottom * (data.scale or 1) / sh) or 0.5
        if data.attach == "TOP" then data.y = math.min(data.y, 0.85) else data.y = math.max(data.y, 0.15) end
    end
    data.attach = attach
    self:LayoutAll()
    ns.Plugins:UpdateAll()
end

-------------------------------------------------------------------------------
-- Locking
-------------------------------------------------------------------------------

function Bars:SetLocked(locked)
    ns.db.locked = locked and true or false
    ns.Tip:Close()
    for _, p in ipairs(ns.pluginList) do
        p.unlockBox:SetShown(not ns.db.locked and p.db.enabled)
        if p.OnLockChanged then p:OnLockChanged(ns.db.locked) end
    end
    self:LayoutAll()
    ns.Plugins:SyncOverlays()
    if not ns.db.locked then
        ns.Print("Bars unlocked: drag plugins to move them, drag a bar to another screen edge, drag its yellow edges to resize. /jibar lock when done.")
    end
    if ns.Options.Refresh then ns.Options:Refresh() end
end

function Bars:UpdateUnlock(bar)
    local unlocked = not ns.db.locked
    bar.unlock:SetShown(unlocked)
    for _, h in pairs(bar.handles) do h:SetShown(unlocked) end
    if unlocked then
        local where = bar.data.attach == "FLOAT" and "floating" or (bar.data.attach == "TOP" and "top" or "bottom")
        bar.unlock.label:SetText(("JiBar %d (%s)"):format(bar.index, where))
        bar.unlock.label:ClearAllPoints()
        if bar.data.attach == "TOP" then
            bar.unlock.label:SetPoint("TOP", bar.frame, "BOTTOM", 0, -2)
        else
            bar.unlock.label:SetPoint("BOTTOM", bar.frame, "TOP", 0, 2)
        end
    end
end

-------------------------------------------------------------------------------
-- Dragging bars (move between edges / float) and resizing them
-------------------------------------------------------------------------------

function Bars:BeginMove(bar)
    local cx, cy = Cursor()
    local scale = bar.data.scale or 1
    local left, bottom = bar.frame:GetLeft(), bar.frame:GetBottom()
    self.moving = { bar = bar, dx = cx - (left or 0) * scale, dy = cy - (bottom or 0) * scale }
    bar.frame:SetScript("OnUpdate", function() Bars:UpdateMove() end)
end

function Bars:UpdateMove()
    local m = self.moving
    if not m then return end
    local cx, cy = Cursor()
    local data = m.bar.data
    local sw, sh = ScreenSize()
    local scale = data.scale or 1
    local f = m.bar.frame
    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (cx - m.dx) / scale, (cy - m.dy) / scale)
    m.x = (cx - m.dx) / sw
    m.y = (cy - m.dy) / sh
    m.cy = cy / sh
end

function Bars:EndMove()
    local m = self.moving
    if not m then return end
    self.moving = nil
    local bar = m.bar
    bar.frame:SetScript("OnUpdate", function(_, elapsed) Bars:OnBarUpdate(bar, elapsed) end)
    local data = bar.data
    if m.cy then
        if m.cy >= 1 - SNAP then
            data.attach = "TOP"
        elseif m.cy <= SNAP then
            data.attach = "BOTTOM"
        else
            data.attach = "FLOAT"
            data.y = m.y
        end
        data.x = m.x
    end
    self:LayoutAll()
    ns.Plugins:UpdateAll()
end

function Bars:BeginResize(bar, side)
    self.resizing = { bar = bar, side = side }
    bar.frame:SetScript("OnUpdate", function() Bars:UpdateResize() end)
end

function Bars:UpdateResize()
    local r = self.resizing
    if not r then return end
    local data = r.bar.data
    local sw = ScreenSize()
    local cx = math.max(0, math.min(sw, (Cursor())))
    local left, right = data.x * sw, (data.x + data.width) * sw
    if r.side == "LEFT" then
        left = math.min(cx, right - MIN_WIDTH)
    else
        right = math.max(cx, left + MIN_WIDTH)
    end
    data.x, data.width = left / sw, (right - left) / sw
    self:Position(r.bar)
    self:Skin(r.bar)
    self:Layout(r.bar)
end

function Bars:EndResize()
    local r = self.resizing
    if not r then return end
    self.resizing = nil
    local bar = r.bar
    bar.frame:SetScript("OnUpdate", function(_, elapsed) Bars:OnBarUpdate(bar, elapsed) end)
    self:LayoutAll()
end

-------------------------------------------------------------------------------
-- Dragging plugins
-------------------------------------------------------------------------------

local function DragGhost()
    if Bars.ghost then return Bars.ghost end
    local g = W.NewFrame("Frame", UIParent)
    g:SetFrameStrata("TOOLTIP")
    g:SetSize(80, 20)
    W.Backdrop(g, 0.1, 0.3, 0.6, 0.85, 0.8)
    g.text = g:CreateFontString(nil, "OVERLAY")
    W.Font(g.text, 11)
    g.text:SetPoint("CENTER")
    g:Hide()
    local marker = UIParent:CreateTexture(nil, "OVERLAY")
    marker:SetColorTexture(1, 0.82, 0, 1)
    marker:SetWidth(3)
    marker:Hide()
    g.marker = marker
    Bars.ghost = g
    return g
end

-- Finds where the cursor would drop a plugin: bar, side and index in that
-- side's list (the dragged plugin left out), plus the marker's x in the bar.
function Bars:FindDropTarget(dragged, cx, cy)
    local best
    for _, bar in ipairs(self.list) do
        local f = bar.frame
        local scale = f:GetEffectiveScale() / (UIParent:GetEffectiveScale() or 1)
        local left, bottom, top = f:GetLeft(), f:GetBottom(), f:GetTop()
        if f:IsShown() and left and bottom and top then
            local x = cx / scale - left
            local y = cy / scale
            if y >= bottom - 12 and y <= top + 12 and x >= -20 and x <= (bar.width or 0) + 20 then
                local data = bar.data
                local pad = data.padding or 6
                for _, side in ipairs(ns.SIDES) do
                    local list = {}
                    for _, p in ipairs(bar.sides[side]) do
                        if p ~= dragged then list[#list + 1] = p end
                    end
                    local gap = (data.spacing and data.spacing[side] or 10) / 2
                    local slots = {}
                    if #list == 0 then
                        local sx = side == "LEFT" and pad or (side == "RIGHT" and (bar.width - pad) or bar.width / 2)
                        slots[1] = { index = 1, x = sx }
                    else
                        for i, p in ipairs(list) do
                            slots[#slots + 1] = { index = i, x = (p.layoutX or 0) - gap }
                        end
                        local last = list[#list]
                        slots[#slots + 1] = { index = #list + 1, x = (last.layoutX or 0) + (last.width or 0) + gap }
                    end
                    for _, slot in ipairs(slots) do
                        local d = math.abs(x - slot.x)
                        if not best or d < best.distance then
                            best = { bar = bar, side = side, index = slot.index, x = slot.x, distance = d }
                        end
                    end
                end
            end
        end
    end
    return best
end

function Bars:BeginPluginDrag(p)
    if ns.db.locked or not p.bar then return end
    ns.Tip:Close()
    GameTooltip:Hide()
    local g = DragGhost()
    g.text:SetText(p.title)
    g:SetWidth((g.text:GetStringWidth() or 60) + 16)
    g:Show()
    p.frame:SetAlpha(0.35)
    self.dragging = p
    g:SetScript("OnUpdate", function() Bars:UpdatePluginDrag() end)
end

function Bars:UpdatePluginDrag()
    local p, g = self.dragging, self.ghost
    if not p then return end
    local cx, cy = Cursor()
    g:ClearAllPoints()
    g:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", cx + 12, cy + 8)
    local target = self:FindDropTarget(p, cx, cy)
    self.dropTarget = target
    local marker = g.marker
    if target then
        local f = target.bar.frame
        marker:SetParent(f)
        marker:ClearAllPoints()
        marker:SetPoint("TOP", f, "TOPLEFT", target.x, 2)
        marker:SetPoint("BOTTOM", f, "BOTTOMLEFT", target.x, -2)
        marker:SetDrawLayer("OVERLAY", 7)
        marker:Show()
    else
        marker:Hide()
    end
end

function Bars:EndPluginDrag()
    local p = self.dragging
    if not p then return end
    self:UpdatePluginDrag()
    self.dragging = nil
    local g = self.ghost
    g:SetScript("OnUpdate", nil)
    g:Hide()
    g.marker:Hide()
    p.frame:SetAlpha(1)
    local target = self.dropTarget
    self.dropTarget = nil
    if target then
        ns.Plugins:Move(p, target.bar.index, target.side, target.index)
    else
        self:Layout(p.bar)
    end
end
