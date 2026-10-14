local _, ns = ...

-- Plugins are the pieces shown on a bar (FuBar's plugins). Each is created
-- with ns.RegisterPlugin(def) at file scope and gets a frame with an icon and
-- a text when JiBar loads. A plugin implements any of:
--   :OnEnable()           at PLAYER_LOGIN (register events here)
--   :UpdateText()         sets the bar text with :SetText()
--   :OnTooltip(tip)       fills the tooltip (see Tip.lua)
--   :OnClick(button)      left/middle click (right click opens the menu)
--   :OnMenu(root)         extra menu entries before the declared options
--   :OnTick()             every second while enabled
--   :LayoutContent()      custom content (plugin.custom = true): returns width
--   :OnPlaced()           after the plugin moved to another bar
-- plugin.db is its saved settings: the common ones below plus def.defaults.

local W = ns.Widgets
local Plugin = {}
Plugin.__index = Plugin

ns.plugins = {}
ns.pluginList = {}

local COMMON_DEFAULTS = {
    enabled = true,
    bar = 1,
    side = "LEFT",
    order = 99,
    showIcon = true,
    showText = true,
    fontSize = 0,        -- 0 = the global size
    customColor = false,
    color = { 1, 1, 1 },
}

function ns.RegisterPlugin(def)
    local p = setmetatable(def, Plugin)
    p.title = p.title or p.id
    p.hasText = p.hasText ~= false
    p.hasIcon = p.icon ~= nil
    p.events = {}
    ns.plugins[p.id] = p
    ns.pluginList[#ns.pluginList + 1] = p
    return p
end

-- Merges every plugin's defaults into the saved variables and builds frames.
function ns.InitPlugins()
    for _, p in ipairs(ns.pluginList) do
        -- Plugin defaults win over the common ones (e.g. the clock's big font).
        local defaults = ns.DeepCopy(p.defaults or {})
        ns.CopyDefaults(p.place or {}, defaults)
        if p.enabledByDefault == false then defaults.enabled = false end
        ns.CopyDefaults(COMMON_DEFAULTS, defaults)
        ns.db.plugins[p.id] = ns.CopyDefaults(defaults, ns.db.plugins[p.id] or {})
        p.db = ns.db.plugins[p.id]
        p:CreateFrame()
        if p.clickTargets then p:CreateSecureOverlay() end
        if p.OnInit then p:OnInit() end
    end
end

-------------------------------------------------------------------------------
-- Frame
-------------------------------------------------------------------------------

function Plugin:CreateFrame()
    local f = CreateFrame("Button", "JiBarPlugin" .. self.id, UIParent)
    f:RegisterForClicks("AnyUp")
    f:RegisterForDrag("LeftButton")
    f.plugin = self
    self.frame = f

    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("LEFT", f, "LEFT", 0, 0)
    self.iconTexture = icon

    local text = f:CreateFontString(nil, "OVERLAY")
    W.Font(text, 12)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    self.text = text
    self.textValue = ""
    if self.icon then self:SetIcon(self.icon) end

    -- Shown while the bars are unlocked, so plugins can be told apart and dragged.
    local box = f:CreateTexture(nil, "BACKGROUND")
    box:SetAllPoints()
    box:SetColorTexture(0.2, 0.6, 1, 0.25)
    box:Hide()
    self.unlockBox = box

    f:SetScript("OnEnter", function() self:OnEnterFrame() end)
    f:SetScript("OnLeave", function() self:OnLeaveFrame() end)
    f:SetScript("OnClick", function(_, button) self:OnClickFrame(button) end)
    f:SetScript("OnDragStart", function() ns.Bars:BeginPluginDrag(self) end)
    f:SetScript("OnDragStop", function() ns.Bars:EndPluginDrag() end)
end

function Plugin:OnEnterFrame()
    self.hovered = true
    self:ApplyHover()
    if ns.db.locked then
        ns.Tip:Open(self)
    else
        GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
        GameTooltip:AddLine(self.title, 1, 1, 1)
        GameTooltip:AddLine("Drag to move it to another place or bar.", nil, nil, nil, true)
        GameTooltip:AddLine("Right-click for its options.", nil, nil, nil, true)
        GameTooltip:Show()
    end
    ns.Bars:OnMouseActivity(self.bar)
end

function Plugin:OnLeaveFrame()
    self.hovered = false
    self:ApplyHover()
    ns.Tip:ScheduleHide()
    if GameTooltip:IsOwned(self.frame) then GameTooltip:Hide() end
end

function Plugin:OnClickFrame(button)
    if button == "RightButton" then
        ns.Menu:OpenPlugin(self)
    elseif ns.db.locked and self.OnClick then
        self:OnClick(button)
        self:Update()
    end
end

-------------------------------------------------------------------------------
-- Text and icon
-------------------------------------------------------------------------------

function Plugin:SetText(text)
    text = text or ""
    if text == self.textValue then return end
    self.textValue = text
    self.text:SetText(text)
    self:CheckWidth()
end

-- JiBar's own icons are cropped to their visible columns (ns.ICON_BOUNDS).
function Plugin:SetIcon(texture, l, r, t, b)
    texture = texture or self.icon
    self.iconTexture:SetTexture(texture)
    if not l then
        local bounds = ns.IconBounds(texture)
        l, r, t, b = bounds and bounds[1] or 0, bounds and bounds[2] or 1, 0, 1
    end
    self.iconTexture:SetTexCoord(l, r, t, b)
    self.iconCrop = r - l
    self:ApplyIconSize()
end

function Plugin:ApplyIconSize()
    local size = self.iconSize or ns.db.iconSize
    local width = size * (self.iconCrop or 1)
    if width ~= self.iconWidth then
        self.iconWidth = width
        self.iconTexture:SetSize(width, size)
        self:CheckWidth()
    end
end

function Plugin:TextColor()
    local c = self.db.customColor and self.db.color or ns.db.textColor
    return c[1], c[2], c[3], ns.db.textAlpha
end

function Plugin:FontSize()
    local size = self.db.fontSize
    return (size and size > 0) and size or ns.db.fontSize
end

-- Applies fonts, colours and sizes from the settings.
function Plugin:ApplyStyle()
    local flags = ns.db.outline or ""
    self.text:SetFont(ns.FontPath(ns.db.font), self:FontSize(), flags)
    if ns.db.shadow then
        self.text:SetShadowColor(0, 0, 0, 1)
        self.text:SetShadowOffset(1, -1)
    else
        self.text:SetShadowOffset(0, 0)
    end
    self.iconWidth = nil
    self:ApplyIconSize()
    self:ApplyHover()
    if self.ApplyContentStyle then self:ApplyContentStyle() end
end

-- FuBar tints the icon (or the text, for text-only plugins) while hovered.
function Plugin:ApplyHover()
    local hc = ns.db.hoverColor
    local r, g, b, a = self:TextColor()
    local showIcon = self:ShowsIcon()
    if self.hovered and showIcon then
        self.iconTexture:SetVertexColor(hc[1], hc[2], hc[3])
    else
        self.iconTexture:SetVertexColor(1, 1, 1)
    end
    if self.hovered and not showIcon then
        self.text:SetTextColor(hc[1], hc[2], hc[3], a)
    else
        self.text:SetTextColor(r, g, b, a)
    end
end

function Plugin:ShowsIcon()
    return self.hasIcon and (self.db.showIcon or not self.hasText)
end

function Plugin:ShowsText()
    return self.hasText and (self.db.showText or not self:ShowsIcon())
end

-- Width of the plugin's frame for the current content.
function Plugin:MeasureWidth()
    if self.custom then return self:LayoutContent() or 0 end
    local width = 0
    local icon = self:ShowsIcon()
    if icon then width = self.iconWidth or ns.db.iconSize end
    if self:ShowsText() and self.textValue ~= "" then
        if icon then width = width + ns.db.iconGap end
        width = width + math.ceil(self.text:GetStringWidth() or 0)
    end
    return math.max(width, 1)
end

-- Repositions icon and text and resizes the frame. Relayouts the bar if the
-- width changed.
function Plugin:CheckWidth()
    local icon, text = self:ShowsIcon(), self:ShowsText()
    self.iconTexture:SetShown(icon and true or false)
    self.text:SetShown(text and true or false)
    self.text:ClearAllPoints()
    if icon then
        self.text:SetPoint("LEFT", self.iconTexture, "RIGHT", ns.db.iconGap, 0)
    else
        self.text:SetPoint("LEFT", self.frame, "LEFT", 0, 0)
    end
    local width = self:MeasureWidth()
    if width ~= self.width then
        self.width = width
        self.frame:SetWidth(width)
        if self.bar then ns.Bars:Layout(self.bar) end
    end
end

-- Re-reads settings and data: call after any setting change.
function Plugin:Refresh()
    self:ApplyStyle()
    self:Update()
    self.width = nil
    self:CheckWidth()
end

function Plugin:Update()
    if not self.db.enabled then return end
    if self.UpdateText then
        local ok, err = pcall(self.UpdateText, self)
        if not ok then ns.Debug(self.id, err) end
    end
    if self.custom then self:CheckWidth() end
    if ns.Tip:IsOpenFor(self) then ns.Tip:Refresh() end
end

function Plugin:IsEnabled()
    return self.db.enabled
end

-- Events only reach enabled plugins. handler is a function(plugin, event, ...)
-- or the name of a method.
function Plugin:RegisterEvent(event, handler)
    handler = handler or event
    return ns:RegisterEvent(event, function(...)
        if not self.db.enabled then return end
        local fn = type(handler) == "string" and self[handler] or handler
        fn(self, ...)
    end)
end

-------------------------------------------------------------------------------
-- Secure overlays: invisible SecureActionButtons laid over a plugin (or one
-- of its regions, like a micro menu icon) for clicks that must run as
-- Blizzard code: using the hearthstone, casting, and opening Blizzard's
-- windows. Opening a UI panel from addon code taints the shared panel
-- manager, and from then on every window it opens runs tainted (the
-- character sheet then errors on secret health values). So plugins never
-- call ToggleCharacter and friends; they "click" a Blizzard button through
-- an overlay instead (type "click", see Plugin:SetClickTarget).
--
-- Overlays are parented to UIParent and placed by absolute coordinates, so
-- the bar and plugin frames never become protected. They can only be moved
-- out of combat; Plugins:SyncOverlays() runs after every layout.
-------------------------------------------------------------------------------

-- opts.region: the region to cover (default the plugin frame);
-- opts.onEnter/onLeave(overlay): hover handlers (default the plugin's).
function Plugin:CreateSecureOverlay(opts)
    opts = opts or {}
    local b = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    b.region = opts.region or self.frame
    -- Addon secure buttons act on key down when the ActionButtonUseKeyDown CVar
    -- is on (the default; SecureActionButton_OnClick only exempts Blizzard's
    -- own mouse clicks), so a button registered for "AnyUp" alone never fires.
    -- Act on release, like every other button.
    b:RegisterForClicks("AnyUp")
    b:SetAttribute("useOnKeyDown", false)
    b:SetScript("OnEnter", opts.onEnter or function() self:OnEnterFrame() end)
    b:SetScript("OnLeave", opts.onLeave or function() self:OnLeaveFrame() end)
    b:SetScript("PostClick", function(_, button)
        if button == "RightButton" then
            ns.Menu:OpenPlugin(self)
        elseif self.OnSecureClick then
            self:OnSecureClick(button)
        end
        self:Update()
    end)
    b:SetAttribute("type2", "")
    b:Hide()
    self.overlays = self.overlays or {}
    self.overlays[#self.overlays + 1] = b
    if b.region == self.frame then self.overlay = b end
    return b
end

-- Makes a mouse button (1 = left) with an optional modifier ("shift-") click
-- a Blizzard button. target is a frame, a global name, or a function
-- returning one. Returns false if the target doesn't exist on this client.
function Plugin:SetClickTarget(overlay, target, button, modifier)
    target = ns.ResolveFrame(target)
    local ok = type(target) == "table" and target.Click ~= nil
    local prefix, suffix = modifier or "", tostring(button or 1)
    ns.OutOfCombat(tostring(overlay) .. prefix .. suffix, function()
        overlay:SetAttribute(prefix .. "type" .. suffix, ok and "click" or nil)
        overlay:SetAttribute(prefix .. "clickbutton" .. suffix, ok and target or nil)
    end)
    return ok
end

-- Plugins declaring clickTargets open Blizzard windows through an overlay:
--   clickTargets = { { target = { "LFDMicroButton", "CharacterMicroButton" } },
--                    { target = "TimeManagerClockButton", modifier = "shift-" } }
-- (a list of names means the first that exists). Applied at login and again
-- whenever a Blizzard addon loads, since some targets are load-on-demand.
function Plugin:ApplyClickTargets()
    if not self.clickTargets then return end
    local b = self.overlay or self:CreateSecureOverlay()
    for _, t in ipairs(self.clickTargets) do
        self:SetClickTarget(b, t.target, t.button or 1, t.modifier)
    end
end

function Plugin:SyncOverlay()
    if InCombatLockdown() then return end
    for _, b in ipairs(self.overlays or {}) do
        local f = b.region
        local show = self.db.enabled and ns.db.locked and not b.disabled and f:IsVisible()
            and self.bar and self.bar.frame:IsShown()
        local left, bottom = f:GetLeft(), f:GetBottom()
        if not show or not left or not bottom then
            if UnregisterStateDriver then UnregisterStateDriver(b, "visibility") end
            b:Hide()
        else
            local ratio = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
            b:ClearAllPoints()
            b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * ratio, bottom * ratio)
            b:SetSize((f:GetWidth() or 1) * ratio, (f:GetHeight() or 1) * ratio)
            b:SetFrameStrata(self.bar.frame:GetFrameStrata() or "MEDIUM")
            b:SetFrameLevel((self.bar.frame:GetFrameLevel() or 1) + 20)
            if self.bar.data.hideInCombat and RegisterStateDriver then
                RegisterStateDriver(b, "visibility", "[combat] hide; show")
            else
                if UnregisterStateDriver then UnregisterStateDriver(b, "visibility") end
                b:Show()
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Registry: placement on bars, enabling, the one-second tick
-------------------------------------------------------------------------------

-- A frame from a frame, a global name, a function, or a list of names (the
-- first that exists).
function ns.ResolveFrame(target)
    if type(target) == "function" then target = target() end
    if type(target) == "string" then target = _G[target] end
    if type(target) == "table" and not target.GetObjectType then
        for _, name in ipairs(target) do
            local f = ns.ResolveFrame(name)
            if f then return f end
        end
        return nil
    end
    return target
end

local Plugins = {}
ns.Plugins = Plugins

-- Puts every enabled plugin on its bar, in saved order, and lays out the bars.
function Plugins:PlaceAll()
    for _, bar in ipairs(ns.Bars.list) do
        for _, side in ipairs(ns.SIDES) do wipe(bar.sides[side]) end
    end
    for _, p in ipairs(ns.pluginList) do
        if p.db.enabled then
            self:Attach(p)
        else
            p.frame:Hide()
            p.bar = nil
        end
    end
    for _, bar in ipairs(ns.Bars.list) do self:SortBar(bar) end
    for _, p in ipairs(ns.pluginList) do
        if p.db.enabled then p:Refresh() end
    end
    ns.Bars:LayoutAll()
end

function Plugins:Attach(p)
    local bar = ns.Bars.list[p.db.bar]
    if not bar then
        p.db.bar = 1
        bar = ns.Bars.list[1]
    end
    if not bar.sides[p.db.side] then p.db.side = "LEFT" end
    local previous = p.bar
    p.bar = bar
    p.frame:SetParent(bar.frame)
    p.frame:SetHeight(bar.data.height)
    p.frame:Show()
    table.insert(bar.sides[p.db.side], p)
    if p.OnPlaced and previous ~= bar then p:OnPlaced() end
end

function Plugins:SortBar(bar)
    for _, side in ipairs(ns.SIDES) do
        local list = bar.sides[side]
        table.sort(list, function(a, b)
            if a.db.order ~= b.db.order then return a.db.order < b.db.order end
            return a.id < b.id
        end)
        for i, p in ipairs(list) do p.db.order = i end
    end
end

local function Remove(p)
    if not p.bar then return end
    local list = p.bar.sides[p.db.side]
    for i = #list, 1, -1 do
        if list[i] == p then table.remove(list, i) end
    end
    for i, other in ipairs(list) do other.db.order = i end
end

-- Moves a plugin to a bar and side, before position index (default: last).
function Plugins:Move(p, barIndex, side, index)
    local oldBar = p.bar
    Remove(p)
    local bar = ns.Bars.list[barIndex] or ns.Bars.list[1]
    p.db.bar, p.db.side = bar.index, side
    local list = bar.sides[side]
    index = math.max(1, math.min(index or (#list + 1), #list + 1))
    for i = index, #list do list[i].db.order = i + 1 end
    p.db.order = index
    p.frame:SetParent(bar.frame)
    p.frame:SetHeight(bar.data.height)
    p.bar = bar
    table.insert(list, index, p)
    for i, other in ipairs(list) do other.db.order = i end
    if p.OnPlaced and oldBar ~= bar then p:OnPlaced() end
    p:Refresh()
    if oldBar and oldBar ~= bar then ns.Bars:Layout(oldBar) end
    ns.Bars:Layout(bar)
end

function Plugins:SetEnabled(p, enabled)
    if p.db.enabled == enabled then return end
    p.db.enabled = enabled
    if enabled then
        -- The old order is kept, so the plugin comes back where it was.
        self:Attach(p)
        self:SortBar(p.bar)
        if not p.enabledOnce and self.loggedIn then
            p.enabledOnce = true
            if p.OnEnable then p:OnEnable() end
        end
        p:Refresh()
        ns.Bars:Layout(p.bar)
    else
        local bar = p.bar
        Remove(p)
        p.bar = nil
        p.frame:Hide()
        if p.OnDisable then p:OnDisable() end
        if ns.Tip:IsOpenFor(p) then ns.Tip:Close() end
        if bar then ns.Bars:Layout(bar) end
        self:SyncOverlays()
    end
    if ns.Options.Refresh then ns.Options:Refresh() end
end

-- OnEnable runs once per plugin, for enabled plugins at login and for others
-- when they are first enabled.
function Plugins:EnableAll()
    self.loggedIn = true
    self:ApplyClickTargets()
    for _, p in ipairs(ns.pluginList) do
        if p.db.enabled and not p.enabledOnce then
            p.enabledOnce = true
            local ok, err = pcall(p.OnEnable or function() end, p)
            if not ok then ns.Print("error enabling", p.id, err) end
        end
    end
    self:UpdateAll()
end

function Plugins:ApplyClickTargets()
    for _, p in ipairs(ns.pluginList) do p:ApplyClickTargets() end
end

function Plugins:UpdateAll()
    for _, p in ipairs(ns.pluginList) do
        if p.db.enabled then p:Update() end
    end
end

function Plugins:RefreshAll()
    for _, p in ipairs(ns.pluginList) do
        if p.db.enabled then p:Refresh() end
    end
    ns.Bars:LayoutAll()
end

function Plugins:SyncOverlays()
    if InCombatLockdown() then
        ns.OutOfCombat("overlays", function() Plugins:SyncOverlays() end)
        return
    end
    for _, p in ipairs(ns.pluginList) do
        if p.overlays then p:SyncOverlay() end
    end
end

-- The one-second heartbeat for clocks, cooldowns and performance numbers.
local ticker = CreateFrame("Frame")
local elapsedTotal = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    elapsedTotal = elapsedTotal + elapsed
    if elapsedTotal < 1 then return end
    elapsedTotal = 0
    if not Plugins.loggedIn then return end
    for _, p in ipairs(ns.pluginList) do
        if p.db.enabled and p.OnTick then
            local ok, err = pcall(p.OnTick, p)
            if not ok then ns.Debug(p.id, err) end
        end
    end
end)

ns:RegisterEvent("ADDON_LOADED", function(_, name)
    if Plugins.loggedIn and type(name) == "string" and name:find("^Blizzard_") then
        Plugins:ApplyClickTargets()
    end
end)
