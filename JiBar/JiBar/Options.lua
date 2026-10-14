local _, ns = ...

-- The options window: text style, tooltip, one bar at a time, and every
-- plugin with its own settings (rendered from plugin.options, the same list
-- the right-click menus use).

local W = ns.Widgets
local Options = { barIndex = 1 }
ns.Options = Options

local function Percent(v) return math.floor(v * 100 + 0.5) .. "%" end
local function Pixels(v) return v .. " px" end

local function KeyIndex(list, key)
    local _, i = ns.FindByKey(list, key)
    return i or 1
end

local function Names(list)
    local out = {}
    for i, e in ipairs(list) do out[i] = e.name end
    return out
end

function Options:Bar()
    if not ns.db.bars[self.barIndex] then self.barIndex = 1 end
    return ns.db.bars[self.barIndex]
end

-------------------------------------------------------------------------------
-- Building
-------------------------------------------------------------------------------

-- Collects widgets and places them two per row.
local function Rows(L)
    local pending = {}
    local rows = {}
    function rows.Add(widget)
        pending[#pending + 1] = widget
        if #pending == 2 then rows.Flush() end
    end
    function rows.Flush()
        if #pending > 0 then L:Row(unpack(pending)) end
        wipe(pending)
    end
    return rows
end

function Options:BuildGeneral(L, content, set)
    local db = ns.db
    local rows = Rows(L)
    L:Header("General")
    rows.Add(set:Checkbox(content, "Lock bars", "Unlock to drag plugins between places and bars, move bars and resize them.",
        function() return db.locked end, function(v) ns.Bars:SetLocked(v) end))
    rows.Add(set:Checkbox(content, "Text shadow", "Draw a drop shadow behind the bar text.",
        function() return db.shadow end, function(v) db.shadow = v end))
    rows.Add(set:Cycle(content, "Font", Names(ns.FONTS), "Font of the bar text.",
        function() return KeyIndex(ns.FONTS, db.font) end, function(i) db.font = ns.FONTS[i].key end))
    rows.Add(set:Cycle(content, "Outline", Names(ns.OUTLINES), nil,
        function() return KeyIndex(ns.OUTLINES, db.outline) end, function(i) db.outline = ns.OUTLINES[i].key end))
    rows.Add(set:Slider(content, "Font size", 7, 32, 1, function() return db.fontSize end,
        function(v) db.fontSize = v end))
    rows.Add(set:Slider(content, "Icon size", 8, 32, 1, function() return db.iconSize end,
        function(v) db.iconSize = v end))
    rows.Add(set:Slider(content, "Space between icon and text", 0, 16, 0.5, function() return db.iconGap end,
        function(v) db.iconGap = v end, Pixels))
    rows.Add(set:Cycle(content, "Separator", Names(ns.SEPARATORS), "Between the parts of a plugin's text, e.g. 0 HONOR • 8-5.",
        function() return KeyIndex(ns.SEPARATORS, db.separator) end, function(i) db.separator = ns.SEPARATORS[i].key end))
    rows.Add(set:Slider(content, "Text opacity", 0.2, 1, 0.05, function() return db.textAlpha end,
        function(v) db.textAlpha = v end, Percent))
    rows.Flush()
    L:Row(set:ColorSwatch(content, "Text colour", function() return db.textColor end),
        set:ColorSwatch(content, "Hover colour (icons, text-only plugins)", function() return db.hoverColor end))

    L:Header("Tooltip")
    L:Row(set:Slider(content, "Scale", 0.5, 2, 0.05, function() return db.tooltip.scale end,
            function(v) db.tooltip.scale = v end, Percent),
        set:Slider(content, "Background opacity", 0, 1, 0.05, function() return db.tooltip.alpha end,
            function(v) db.tooltip.alpha = v end, Percent),
        set:Slider(content, "Font size", 8, 20, 1, function() return db.tooltip.fontSize end,
            function(v) db.tooltip.fontSize = v end))
end

function Options:BuildBars(L, content)
    local set = W.NewSet(function()
        ns.Bars:LayoutAll()
        ns.Plugins:RefreshAll()
    end)
    self.barSet = set
    local rows = Rows(L)
    L:Header("Bars")
    L:Note("Pick a bar to edit. Right-click a bar for quick settings; unlock to drag bars and plugins.")

    self.barNames = {}
    local selector = set:Cycle(content, "Bar", self.barNames, nil,
        function() return Options.barIndex end, function(i) Options.barIndex = i end)
    local add = W.Button(content, "Add bar", 110, function() ns.Bars:AddBar() end)
    local remove = W.Button(content, "Remove bar", 110, function()
        ns.Bars:RemoveBar(Options.barIndex)
        Options.barIndex = 1
        Options:Refresh()
    end)
    L:Row(selector, add, remove)

    local function B() return Options:Bar() end
    local ATTACH = { { key = "TOP", name = "Top of screen" }, { key = "BOTTOM", name = "Bottom of screen" },
        { key = "FLOAT", name = "Floating" } }
    rows.Add(set:Cycle(content, "Attach to", Names(ATTACH), "Floating bars keep the position they were dragged to.",
        function() return KeyIndex(ATTACH, B().attach) end, function(i) ns.Bars:SetAttach(Options.barIndex, ATTACH[i].key) end))
    rows.Add(set:Cycle(content, "Background", Names(ns.SKINS), "FuBar's skins (FuTextures) or a solid colour.",
        function() return KeyIndex(ns.SKINS, B().skin) end, function(i) B().skin = ns.SKINS[i].key end))
    rows.Add(set:Slider(content, "Height", 12, 60, 1, function() return B().height end,
        function(v) B().height = v end, Pixels))
    rows.Add(set:Slider(content, "Width", 0.1, 1, 0.01, function() return B().width end,
        function(v) B().width = v end, Percent))
    rows.Add(set:Slider(content, "Horizontal position", 0, 1, 0.01, function() return B().x end,
        function(v) B().x = v end, Percent))
    rows.Add(set:Slider(content, "Vertical position (floating)", 0, 1, 0.01, function() return B().y end,
        function(v) B().y = v end, Percent))
    rows.Add(set:Slider(content, "Scale", 0.5, 2, 0.05, function() return B().scale end,
        function(v) B().scale = v end, Percent))
    local STRATA = {}
    for i, s in ipairs(ns.STRATAS) do STRATA[i] = s:sub(1, 1) .. s:sub(2):lower() end
    rows.Add(set:Cycle(content, "Frame strata", STRATA, "Which layer the bar is drawn in.",
        function()
            for i, s in ipairs(ns.STRATAS) do
                if s == B().strata then return i end
            end
            return 3
        end,
        function(i) B().strata = ns.STRATAS[i] end))
    rows.Add(set:Slider(content, "Background opacity", 0, 1, 0.05, function() return B().bgAlpha end,
        function(v) B().bgAlpha = v end, Percent))
    rows.Add(set:ColorSwatch(content, "Background tint", function() return B().bgColor end))
    rows.Add(set:Checkbox(content, "Edge line", "A 1px line along the edge facing the middle of the screen.",
        function() return B().edgeLine end, function(v) B().edgeLine = v end))
    rows.Add(set:ColorSwatch(content, "Edge line colour", function() return B().edgeColor end))
    rows.Add(set:Slider(content, "Padding at the ends", 0, 60, 1, function() return B().padding end,
        function(v) B().padding = v end, Pixels))
    rows.Add(set:Slider(content, "Left spacing", 0, 60, 1, function() return B().spacing.LEFT end,
        function(v) B().spacing.LEFT = v end, Pixels))
    rows.Add(set:Slider(content, "Centre spacing", 0, 60, 1, function() return B().spacing.CENTER end,
        function(v) B().spacing.CENTER = v end, Pixels))
    rows.Add(set:Slider(content, "Right spacing", 0, 60, 1, function() return B().spacing.RIGHT end,
        function(v) B().spacing.RIGHT = v end, Pixels))
    rows.Add(set:Checkbox(content, "Auto-hide", "Fade the bar out until the mouse is over it.",
        function() return B().autoHide end, function(v) B().autoHide = v end))
    rows.Add(set:Slider(content, "Auto-hide opacity", 0, 1, 0.05, function() return B().autoHideAlpha end,
        function(v) B().autoHideAlpha = v end, Percent))
    rows.Add(set:Checkbox(content, "Hide in combat", nil,
        function() return B().hideInCombat end, function(v) B().hideInCombat = v end))
    rows.Flush()
end

-- Position choices for a plugin: every bar and side.
function Options:PositionValues()
    local values, names = {}, {}
    for bar = 1, #ns.db.bars do
        for _, side in ipairs(ns.SIDES) do
            values[#values + 1] = { bar = bar, side = side }
            names[#names + 1] = (#ns.db.bars > 1 and ("Bar " .. bar .. ", ") or "") .. ns.SIDE_NAMES[side]
        end
    end
    return values, names
end

function Options:BuildPlugin(L, content, plugin)
    local set = W.NewSet(function() plugin:Refresh() end)
    self.pluginSets[#self.pluginSets + 1] = set
    local db = plugin.db
    local rows = Rows(L)
    L:Header(plugin.title)
    if plugin.description then L:Note(plugin.description) end

    rows.Add(set:Checkbox(content, "Show on a bar", nil,
        function() return db.enabled end, function(v) ns.Plugins:SetEnabled(plugin, v) end))
    local positions, positionNames = self:PositionValues()
    local cycle = set:Cycle(content, "Position", positionNames, "Or unlock the bars and drag the plugin.",
        function()
            for i, v in ipairs(positions) do
                if v.bar == db.bar and v.side == db.side then return i end
            end
            return 1
        end,
        function(i) ns.Plugins:Move(plugin, positions[i].bar, positions[i].side) end)
    rows.Add(cycle)
    self.positionCycles[#self.positionCycles + 1] = { cycle = cycle, positions = positions, names = positionNames }
    if plugin.hasIcon and plugin.hasText then
        rows.Add(set:Checkbox(content, "Show icon", nil, function() return db.showIcon end, function(v)
            db.showIcon = v
            if not v then db.showText = true end
        end))
        rows.Add(set:Checkbox(content, "Show text", nil, function() return db.showText end, function(v)
            db.showText = v
            if not v then db.showIcon = true end
        end))
    end
    if plugin.hasText then
        rows.Add(set:Slider(content, "Font size (0 = general)", 0, 40, 1, function() return db.fontSize end,
            function(v) db.fontSize = v end))
        rows.Add(set:Checkbox(content, "Own text colour", nil, function() return db.customColor end,
            function(v) db.customColor = v end))
        rows.Add(set:ColorSwatch(content, "Text colour", function() return db.color end))
    end

    for _, opt in ipairs(plugin.options or {}) do
        if opt.window ~= false then
            local function Get() return ns.OptionGet(plugin, opt) end
            local function Set(v)
                if opt.set then opt.set(plugin, v) else db[opt.key] = v end
                if plugin.OnSettingChanged then plugin:OnSettingChanged(opt.key, v) end
            end
            if opt.type == "header" then
                rows.Flush()
                L:Note("|cffffd100" .. opt.label .. "|r")
            elseif opt.type == "toggle" then
                rows.Add(set:Checkbox(content, opt.label, opt.tip, Get, Set))
            elseif opt.type == "select" then
                rows.Add(set:Cycle(content, opt.label, Names(opt.values), opt.tip,
                    function() return KeyIndex(opt.values, Get()) end,
                    function(i) Set(opt.values[i].key) end))
            elseif opt.type == "range" then
                rows.Add(set:Slider(content, opt.label, opt.min, opt.max, opt.step or 1, Get, Set, opt.fmt))
            elseif opt.type == "color" then
                rows.Add(set:ColorSwatch(content, opt.label, Get))
            elseif opt.type == "execute" then
                rows.Add(W.Button(content, opt.label, 200, function()
                    opt.func(plugin)
                    plugin:Refresh()
                end))
            end
        end
    end
    rows.Flush()
    if plugin.BuildExtraOptions then plugin:BuildExtraOptions(L, content, set) end
end

function Options:Build()
    local content
    self.window, content = W.CreateWindow({
        name = "JiBarOptionsFrame",
        title = "|cff33ff99JiBar|r",
        width = 640,
        height = 620,
        onShow = function() Options:Refresh() end,
    })
    local L = W.NewLayout(content, self.window.contentWidth)
    self.set = W.NewSet(function() ns.Plugins:RefreshAll() end)
    self.pluginSets = {}
    self.positionCycles = {}
    self:BuildGeneral(L, content, self.set)
    self:BuildBars(L, content)
    L:Header("Plugins")
    L:Note("Right-click a plugin on the bar for the same settings. Unlock the bars to drag plugins around.")
    for _, plugin in ipairs(ns.pluginList) do
        self:BuildPlugin(L, content, plugin)
    end
    content:SetHeight(-L.y + 16)

    local reset = W.Button(self.window, "Reset all", 110, function()
        ns.ResetSavedVariables("JiBarDB", ns.defaults)
        ns.Print("Settings reset. Type /reload to finish.")
    end)
    reset:SetPoint("BOTTOMLEFT", 12, 12)
    local lock = W.Button(self.window, "Unlock bars", 110, function() ns.Bars:SetLocked(not ns.db.locked) end)
    lock:SetPoint("BOTTOMRIGHT", -12, 12)
    self.lockButton = lock
end

-- Re-reads every widget (after settings changed elsewhere, or bars changed).
function Options:Refresh()
    if not self.window then return end
    wipe(self.barNames)
    for i, bar in ipairs(ns.db.bars) do
        local where = bar.attach == "FLOAT" and "floating" or bar.attach:lower()
        self.barNames[i] = ("Bar %d (%s)"):format(i, where)
    end
    for _, pc in ipairs(self.positionCycles) do
        local values, names = self:PositionValues()
        wipe(pc.positions)
        wipe(pc.names)
        for i, v in ipairs(values) do pc.positions[i], pc.names[i] = v, names[i] end
    end
    self.set:Refresh()
    self.barSet:Refresh()
    for _, s in ipairs(self.pluginSets) do s:Refresh() end
    self.lockButton:SetText(ns.db.locked and "Unlock bars" or "Lock bars")
end

function Options:Toggle()
    if not self.window then self:Build() end
    self.window:SetShown(not self.window:IsShown())
end

function Options:Open(barIndex)
    if not self.window then self:Build() end
    if barIndex then self.barIndex = barIndex end
    self.window:Show()
    self:Refresh()
end
