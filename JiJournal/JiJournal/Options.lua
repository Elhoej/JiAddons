local _, ns = ...

-- Options window, built with the shared widget toolkit (Shared/Widgets.lua).

local Options = {}
ns.Options = Options

local W = ns.Widgets
local WIDTH, HEIGHT = 600, 470
local CONTENT_WIDTH = WIDTH - 48

local function Sub(group, key)
    return function() return ns.db[group][key] end, function(v) ns.db[group][key] = v end
end

local function Pct(v) return math.floor(v * 100 + 0.5) .. "%" end
local function Times(v) return v .. "x" end

function Options:BuildContent(content)
    local L = W.NewLayout(content, CONTENT_WIDTH)
    local c = content
    local S = self.set
    -- Sub() isn't the last argument in these calls, so unpack its returns first.
    local function Slider(label, group, key, minV, maxV, step, fmt)
        local get, set = Sub(group, key)
        return S:Slider(c, label, minV, maxV, step, get, set, fmt)
    end

    L:Header("World map")
    L:Note("Press M to open the map. Scroll to zoom, drag to pan, right-click to go up a level. Drag the bar along the bottom to move it.")
    L:Row(S:Checkbox(c, "Replace the world map", "Turn off to get Blizzard's map back. Takes effect after /reload.",
            Sub("map", "enabled")),
        S:Checkbox(c, "Show coordinates", "Cursor and player coordinates in the bar along the bottom of the map.",
            Sub("map", "coords")))
    L:Row(S:Checkbox(c, "Remember zoom and position", "Each map reopens at the zoom and position you left it at.",
        Sub("map", "rememberZoom")))
    L:Row(Slider("Map scale", "map", "scale", 0.5, 2, 0.05, Pct), Slider("Map opacity", "map", "alpha", 0.2, 1, 0.05, Pct))
    L:Row(Slider("Maximum zoom", "map", "maxZoom", 2, 8, 0.5, Times))

    L:Header("Quest log")
    L:Note("Press L to open the quest log. Shift-click a quest to link it in chat, or to track it when chat is closed.")
    L:Row(S:Checkbox(c, "Replace the quest log", "Turn off to get Blizzard's quest log back. Takes effect after /reload.",
            Sub("questLog", "enabled")),
        S:Checkbox(c, "Show quest levels", "Prefix quests with their level, like [14], and + for elite quests.",
            Sub("questLog", "showLevels")))
    L:Row(S:Checkbox(c, "Show quest IDs", "Show the quest ID after the title in the quest details.",
        Sub("questLog", "showIDs")))
    L:Row(Slider("Quest log scale", "questLog", "scale", 0.5, 2, 0.05, Pct))
    content:SetHeight(-L.y + 16)
end

function Options:Build()
    self.set = W.NewSet(function() ns:ApplySettings() end)
    local content
    self.window, content = W.CreateWindow({
        name = "JiJournalOptionsFrame",
        title = "|cff33ff99JiJournal|r",
        width = WIDTH,
        height = HEIGHT,
        onShow = function() Options.set:Refresh() end,
    })
    self:BuildContent(content)

    local reset = W.Button(self.window, "Reset positions", 130, function() ns:ResetPositions() end)
    reset:SetPoint("BOTTOMLEFT", 14, 12)
    local zoom = W.Button(self.window, "Forget map zoom", 140, function() ns.Map:ResetZoomMemory() end)
    zoom:SetPoint("LEFT", reset, "RIGHT", 8, 0)
end

function Options:Toggle()
    if not self.window then self:Build() end
    self.window:SetShown(not self.window:IsShown())
end

function Options:Init()
    W.RegisterSettingsPanel({
        title = ns.title,
        description = "A movable, zoomable world map and a WideQuestLog-style quest log. Type /jij to open the options.",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
        open = function() Options:Toggle() end,
    })
end
