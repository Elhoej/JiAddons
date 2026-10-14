local _, ns = ...

-- Right-click menus, built with Blizzard's MenuUtil (Blizzard_Menu). Plugin
-- settings are declared once as a list (plugin.options) and rendered both
-- here and in the options window:
--   { type = "toggle", key, label, tip }
--   { type = "select", key, label, values = { { key, name }, ... } }
--   { type = "range", key, label, min, max, step, fmt, presets = { ... } }
--   { type = "color", key, label }           -- db[key] = { r, g, b }
--   { type = "execute", label, func = function(plugin) end }
--   { type = "header", label }
-- Any entry may give get(plugin)/set(plugin, v) instead of a key, hidden =
-- function(plugin), and menu = false or window = false to skip one place.

local Menu = {}
ns.Menu = Menu

function ns.OptionGet(plugin, opt)
    if opt.get then return opt.get(plugin) end
    return plugin.db[opt.key]
end

function ns.OptionSet(plugin, opt, value)
    if opt.set then
        opt.set(plugin, value)
    else
        plugin.db[opt.key] = value
    end
    if plugin.OnSettingChanged then plugin:OnSettingChanged(opt.key, value) end
    plugin:Refresh()
end

function Menu.Available()
    return MenuUtil ~= nil and MenuUtil.CreateContextMenu ~= nil
end

-- build(root) fills the menu. Without MenuUtil the options window opens instead.
function Menu:Open(owner, build)
    if not Menu.Available() then
        ns.Options:Toggle()
        return
    end
    ns.Tip:Close()
    MenuUtil.CreateContextMenu(owner, function(_, root)
        local ok, err = pcall(build, root)
        if not ok then root:CreateTitle("|cffff5555" .. tostring(err) .. "|r") end
    end)
end

local function RangeValues(opt)
    if opt.presets then return opt.presets end
    local values, step = {}, opt.step or 1
    local count = (opt.max - opt.min) / step
    local stride = math.max(1, math.ceil(count / 10))
    for i = 0, count, stride do values[#values + 1] = opt.min + i * step end
    if values[#values] ~= opt.max then values[#values + 1] = opt.max end
    return values
end

-- Renders a declarative option list into a menu description.
function Menu:AddOptions(root, plugin, options)
    for _, opt in ipairs(options or {}) do
        if opt.menu ~= false and not (opt.hidden and opt.hidden(plugin)) then
            if opt.type == "header" then
                root:CreateTitle(opt.label)
            elseif opt.type == "toggle" then
                root:CreateCheckbox(opt.label,
                    function() return ns.OptionGet(plugin, opt) and true or false end,
                    function() ns.OptionSet(plugin, opt, not ns.OptionGet(plugin, opt)) end)
            elseif opt.type == "select" then
                local sub = root:CreateButton(opt.label)
                for _, v in ipairs(opt.values) do
                    sub:CreateRadio(v.name,
                        function() return ns.OptionGet(plugin, opt) == v.key end,
                        function() ns.OptionSet(plugin, opt, v.key) end, v.key)
                end
            elseif opt.type == "range" then
                local sub = root:CreateButton(opt.label)
                for _, value in ipairs(RangeValues(opt)) do
                    sub:CreateRadio(opt.fmt and opt.fmt(value) or tostring(value),
                        function() return ns.OptionGet(plugin, opt) == value end,
                        function() ns.OptionSet(plugin, opt, value) end, value)
                end
            elseif opt.type == "color" then
                root:CreateButton(opt.label .. "...", function()
                    local color = ns.OptionGet(plugin, opt)
                    ns.Widgets.OpenColorPicker(color, function() ns.OptionSet(plugin, opt, color) end)
                end)
            elseif opt.type == "execute" then
                root:CreateButton(opt.label, function() opt.func(plugin) end)
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Plugin menu
-------------------------------------------------------------------------------

local function AddPositionMenu(root, plugin)
    local pos = root:CreateButton("Position")
    for barIndex = 1, #ns.db.bars do
        local barMenu = #ns.db.bars > 1 and pos:CreateButton("Bar " .. barIndex) or pos
        for _, side in ipairs(ns.SIDES) do
            barMenu:CreateRadio(ns.SIDE_NAMES[side],
                function() return plugin.db.bar == barIndex and plugin.db.side == side end,
                function() ns.Plugins:Move(plugin, barIndex, side) end, side)
        end
    end
end

function Menu:OpenPlugin(plugin)
    self:Open(plugin.frame, function(root)
        root:CreateTitle(plugin.title)
        if plugin.OnMenu then plugin:OnMenu(root) end
        self:AddOptions(root, plugin, plugin.options)
        root:CreateDivider()
        if plugin.hasIcon and plugin.hasText then
            root:CreateCheckbox("Show icon", function() return plugin.db.showIcon end, function()
                plugin.db.showIcon = not plugin.db.showIcon
                if not plugin.db.showIcon then plugin.db.showText = true end
                plugin:Refresh()
            end)
            root:CreateCheckbox("Show text", function() return plugin.db.showText end, function()
                plugin.db.showText = not plugin.db.showText
                if not plugin.db.showText then plugin.db.showIcon = true end
                plugin:Refresh()
            end)
        end
        AddPositionMenu(root, plugin)
        root:CreateButton("Hide " .. plugin.title, function() ns.Plugins:SetEnabled(plugin, false) end)
        root:CreateDivider()
        self:AddBarItems(root, plugin.db.bar)
    end)
end

-------------------------------------------------------------------------------
-- Bar menu
-------------------------------------------------------------------------------

function Menu:AddBarItems(root, barIndex)
    root:CreateCheckbox("Lock bars", function() return ns.db.locked end, function()
        ns.Bars:SetLocked(not ns.db.locked)
    end)
    root:CreateButton("JiBar options...", function() ns.Options:Open(barIndex) end)
end

function Menu:OpenBar(bar)
    local index = bar.index
    local data = bar.data
    self:Open(bar.frame, function(root)
        root:CreateTitle(#ns.db.bars > 1 and ("JiBar " .. index) or "JiBar")
        local attach = root:CreateButton("Attach to")
        for _, a in ipairs({ { "TOP", "Top of screen" }, { "BOTTOM", "Bottom of screen" }, { "FLOAT", "Nothing (floating)" } }) do
            attach:CreateRadio(a[2], function() return data.attach == a[1] end, function()
                ns.Bars:SetAttach(index, a[1])
            end, a[1])
        end
        local skin = root:CreateButton("Background")
        for _, s in ipairs(ns.SKINS) do
            skin:CreateRadio(s.name, function() return data.skin == s.key end, function()
                data.skin = s.key
                ns.Bars:LayoutAll()
            end, s.key)
        end
        root:CreateCheckbox("Auto-hide", function() return data.autoHide end, function()
            data.autoHide = not data.autoHide
            ns.Bars:LayoutAll()
        end)
        local plugins = root:CreateButton("Plugins")
        for _, plugin in ipairs(ns.pluginList) do
            plugins:CreateCheckbox(plugin.title, function() return plugin.db.enabled end, function()
                if plugin.db.enabled then
                    ns.Plugins:SetEnabled(plugin, false)
                else
                    plugin.db.bar = index
                    ns.Plugins:SetEnabled(plugin, true)
                end
            end)
        end
        root:CreateDivider()
        root:CreateButton("Add a bar", function() ns.Bars:AddBar() end)
        if #ns.db.bars > 1 then
            root:CreateButton("Remove this bar", function() ns.Bars:RemoveBar(index) end)
        end
        root:CreateDivider()
        self:AddBarItems(root, index)
    end)
end
