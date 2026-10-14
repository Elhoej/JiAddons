local addonName, ns = ...

ns.name = addonName
ns.title = "JiJournal"

-------------------------------------------------------------------------------
-- Defaults
-------------------------------------------------------------------------------

ns.defaults = {
    map = {
        enabled = true,        -- restyle Blizzard's world map (needs /reload)
        scale = 1,
        alpha = 1,             -- map art opacity; the border and bar stay solid
        coords = true,         -- bottom bar with cursor and player coordinates
        rememberZoom = true,
        maxZoom = 4,           -- deepest zoom, as a multiple of the fitted map
        point = nil,           -- { point, relativePoint, x, y } relative to UIParent
        views = {},            -- [uiMapID] = { zoom factor, centre x, centre y }
    },
    questLog = {
        enabled = true,        -- replace the quest log (needs /reload)
        scale = 1,
        showLevels = true,     -- "[14] Title"
        showIDs = true,        -- quest ID after the title in the details
        point = nil,
        collapsed = {},        -- [header title] = true
    },
    debug = false,
}

-------------------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------------------

function ns:InitDB()
    self.db = ns.LoadSavedVariables("JiJournalDB", self.defaults)
end

-- Debug output for API calls that fail inside pcall.
function ns.Debug(...)
    if ns.db and ns.db.debug then ns.Print(...) end
end

function ns:ApplySettings()
    self.Map:Apply()
    self.QuestLog:Apply()
end

function ns:ResetPositions()
    self.db.map.point = nil
    self.db.questLog.point = nil
    self:ApplySettings()
end

-- Each part starts on its own, so a failure in one leaves the others working.
local function Start(label, part)
    local ok, err = pcall(part.Init, part)
    if not ok then ns.Print(label .. " failed to start: " .. tostring(err)) end
end

ns:OnLoad(function()
    ns:InitDB()
    Start("map", ns.Map)
    Start("quest log", ns.QuestLog)
    Start("options", ns.Options)
end)

-------------------------------------------------------------------------------
-- Slash commands
-------------------------------------------------------------------------------

local function Help()
    ns.Print("commands:")
    print("  /jij  - open options")
    print("  /jij quests  - toggle the quest log")
    print("  /jij reset  - reset window positions")
    print("  /jij debug  - print API errors the addon swallows")
end

SLASH_JIJOURNAL1 = "/jijournal"
SLASH_JIJOURNAL2 = "/jij"
SlashCmdList.JIJOURNAL = function(msg)
    local cmd = strtrim(msg or ""):lower()
    if cmd == "" or cmd == "options" or cmd == "config" then
        ns.Options:Toggle()
    elseif cmd == "quests" or cmd == "log" then
        ns.QuestLog:Toggle()
    elseif cmd == "reset" then
        ns:ResetPositions()
        ns.Print("window positions reset.")
    elseif cmd == "debug" then
        ns.db.debug = not ns.db.debug
        ns.Print("debug " .. (ns.db.debug and "on" or "off"))
    else
        Help()
    end
end
