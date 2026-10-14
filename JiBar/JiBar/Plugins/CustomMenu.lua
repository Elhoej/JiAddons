local _, ns = ...

-- CustomMenuFu: a menu of your own Lua snippets. Add entries with
--   /jibar custom add <name> ### <lua>
-- (a script of "---" adds a separator) or in the options window. Snippets
-- run as addon code, so they can't do protected things like casting.

local W = ns.Widgets

local P = ns.RegisterPlugin({
    id = "CustomMenu",
    title = "Custom Menu",
    icon = "Interface\\Icons\\INV_Scroll_08",
    hasText = false,
    enabledByDefault = false,
    place = { bar = 1, side = "LEFT", order = 2 },
    defaults = {
        entries = {}, -- { { name, script } }
    },
})

local function Find(entries, name)
    for i, e in ipairs(entries) do
        if e.name == name then return i end
    end
end

function P:Add(name, script)
    name, script = strtrim(name or ""), strtrim(script or "")
    if name == "" or script == "" then return false end
    local entries = self.db.entries
    local i = Find(entries, name)
    if i then
        entries[i].script = script
        ns.Print("Updated " .. name .. ".")
    else
        entries[#entries + 1] = { name = name, script = script }
        ns.Print("Added " .. name .. ".")
    end
    return true
end

function P:Remove(name)
    local i = Find(self.db.entries, name)
    if not i then return false end
    table.remove(self.db.entries, i)
    ns.Print("Removed " .. name .. ".")
    return true
end

function P:Run(entry)
    local fn, err = (loadstring or load)(entry.script, "JiBar: " .. entry.name)
    if not fn then
        ns.Print("|cffff5555" .. tostring(err) .. "|r")
        return
    end
    local ok, runErr = pcall(fn)
    if not ok then ns.Print("|cffff5555" .. tostring(runErr) .. "|r") end
end

-- /jibar custom add <name> ### <lua> | remove <name> | list
function P:Command(msg)
    local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "add" then
        local name, script = rest:match("^(.-)%s+###%s+(.+)$")
        if not (name and self:Add(name, script)) then
            ns.Print("Usage: /jibar custom add <name> ### <lua>")
        end
    elseif cmd == "remove" then
        if not self:Remove(strtrim(rest)) then ns.Print("No entry named " .. rest .. ".") end
    else
        if #self.db.entries == 0 then ns.Print("The custom menu is empty.") end
        for _, e in ipairs(self.db.entries) do ns.Print(e.name .. " ### " .. e.script) end
    end
end

function P:OnMenu(root)
    for _, e in ipairs(self.db.entries) do
        if e.script == "---" then
            root:CreateDivider()
        else
            root:CreateButton(e.name, function() self:Run(e) end)
        end
    end
    if #self.db.entries == 0 then root:CreateTitle("Add entries with /jibar custom add") end
    if #self.db.entries > 0 then
        local remove = root:CreateButton("Remove")
        for _, e in ipairs(self.db.entries) do
            remove:CreateButton(e.name, function() self:Remove(e.name) end)
        end
    end
    root:CreateDivider()
end

function P:OnTooltip(tip)
    tip:AddTitle("Custom Menu")
    for _, e in ipairs(self.db.entries) do
        if e.script == "---" then
            tip:AddSpacer()
        else
            tip:AddLine(e.name, nil, nil, { colors = { { 1, 1, 1 } }, onClick = function() self:Run(e) end })
        end
    end
    if #self.db.entries == 0 then
        tip:AddLine("Empty. Add entries with /jibar custom add <name> ### <lua>.", nil, nil,
            { colors = { { 0.7, 0.7, 0.7 } }, wrap = true })
    end
    tip:SetHint("Click an entry to run it. Right-click for the menu.")
end

function P:OnClick()
    ns.Menu:OpenPlugin(self)
end

function P:BuildExtraOptions(L, content, set)
    local name = set:Input(content, "New entry: name", 180, nil)
    local script = set:Input(content, "Lua (or --- for a separator)", 260, nil)
    local add = W.Button(content, "Add", 80, function()
        if self:Add(name.box:GetText(), script.box:GetText()) then
            name.box:SetText("")
            script.box:SetText("")
        end
    end)
    L:Row(name, script, add)
    L:Note("Remove entries from the plugin's right-click menu, or with /jibar custom remove <name>.")
end
