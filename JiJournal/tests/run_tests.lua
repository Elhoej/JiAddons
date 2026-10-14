-- Run with: luajit tests/run_tests.lua (from JiJournal/) or luajit JiJournal/tests/run_tests.lua
local here = debug.getinfo(1, "S").source:match("^@(.-)[^/]*$")
package.path = here .. "../../tools/?.lua;" .. package.path
local H = require("harness")

local ns, M = H.LoadAddon(here .. "../JiJournal")
local Fire, test, eq, truthy, plain = H.Fire, H.test, H.eq, H.truthy, H.plain

local function Log()
    M.questLog = {
        { isHeader = true, title = "Darkshore" },
        { questID = 1001, title = "Bashal'Aran", level = 13, pushable = true,
          objectives = { { text = "Seer's Relic: 0/1", finished = false } } },
        { questID = 1002, title = "Buzzbox 323", level = 14, objectivesText = "Collect 6 Moonstalker Fangs.",
          description = "The Buzzbox gives a burst of static." },
        { questID = 1003, title = "As Water Cascades", level = 14, complete = true },
        { questID = 1004, title = "The Absent Minded Prospector", level = 20, elite = true },
        { isHeader = true, title = "Darnassus" },
        { questID = 1010, title = "Grove of the Ancients", level = 11, complete = true },
    }
    M.watched = { [1002] = true }
end

M.units.player.level = 16
Log()
Fire("ADDON_LOADED", "JiJournal")
H.Tick(0.1)

local Q, Map = ns.QuestLog, ns.Map
local frame = JiJournalQuestLogFrame
local map, sc = WorldMapFrame, WorldMapFrame.ScrollContainer

-- Visible list rows as plain "title|state" strings.
local function Rows()
    local out = {}
    for _, row in ipairs(Q.rows) do
        if row:IsShown() then
            local state = plain(row.state:GetText())
            out[#out + 1] = plain(row.title:GetText()) .. (state ~= "" and ("|" .. state) or "")
        end
    end
    return out
end

local function RowFor(text)
    for _, row in ipairs(Q.rows) do
        if row:IsShown() and plain(row.title:GetText()):find(text, 1, true) then return row end
    end
end

local function Open()
    if not frame:IsShown() then ToggleQuestLog() end
    H.Tick(0.1)
end

-------------------------------------------------------------------------------
-- Setup
-------------------------------------------------------------------------------

test("saved variables initialised", function()
    truthy(JiJournalDB)
    eq(ns.db.map.enabled, true)
    eq(ns.db.questLog.showLevels, true)
    eq(SLASH_JIJOURNAL1, "/jijournal")
end)

test("slash command toggles the options window", function()
    SlashCmdList.JIJOURNAL("")
    truthy(JiJournalOptionsFrame:IsShown())
    SlashCmdList.JIJOURNAL("")
    eq(JiJournalOptionsFrame:IsShown(), false)
end)

-------------------------------------------------------------------------------
-- World map
-------------------------------------------------------------------------------

test("map leaves the panel layout and floats", function()
    eq(map:GetAttribute("UIPanelLayout-defined"), true)
    eq(map:GetAttribute("UIPanelLayout-area"), nil)
    truthy(tContains(UISpecialFrames, "WorldMapFrame"), "ESC closes the map")
    local point, rel, _, _, y = map:GetPoint(1)
    eq(point, "CENTER"); eq(rel, UIParent); eq(y, 40)
end)

test("map is always the small one without the docked quest log", function()
    eq(M.cvars.miniWorldMap, "1")
    eq(M.cvars.questLogOpen, "0")
    eq(map.minimizedWidth, 1050)
    eq(map.minimizedHeight, 701)
    eq(map.BorderFrame:IsShown(), false)
    eq(map.NavBar:IsShown(), false)
    ToggleWorldMap()
    eq(map.SidePanelToggle:IsShown(), false, "side panel toggle")
    map.QuestLog:Show()
    map:SetDisplayState(3)
    eq(map.QuestLog:IsShown(), false, "docked quest log")
    ToggleWorldMap()
end)

test("map pin button stays hidden", function()
    local pin = map.WorldMapTrackingPinButton
    eq(pin:IsShown(), false)
    pin:Show()
    eq(pin:IsShown(), false)
    pin:SetShown(true)
    eq(pin:IsShown(), false)
end)

test("filter button sits left of Questie's Krowi buttons, which keep the corner", function()
    local filters = map.WorldMapTrackingOptionsButton
    local function X()
        local point, rel, _, x, y = filters:GetPoint(1)
        eq(point, "TOPRIGHT"); eq(rel, sc); eq(y, -2)
        return x
    end
    eq(X(), -4, "alone in the corner")
    local questie = M.NewObject("Button", nil, map)
    local hidden = M.NewObject("Button", nil, map)
    hidden._shown = false
    local krowi = { Buttons = { questie, hidden } }
    LibStub = function(name, silent) if name == "Krowi_WorldMapButtons-1.4" then return krowi end end
    ToggleWorldMap()
    H.Tick(0.1)
    eq(X(), -36, "one shown Krowi button to its right")
    map:SetMapID(1415)
    H.Tick(0.1)
    eq(X(), -36, "re-arranged after map changes")
    krowi.Buttons = { filters, questie }
    filters:ClearAllPoints()
    Map:ArrangeButtons()
    eq(filters:GetPoint(1), nil, "left to Krowi when it manages the filter button")
    krowi.Buttons = { questie }
    Map:ArrangeButtons()
    LibStub = nil
    ToggleWorldMap()
end)

test("Blizzard's wheel zoom is off and ours zooms past the last zoom level", function()
    eq(sc.mouseWheelZoomMode, 3)
    ToggleWorldMap()
    M.cursor = { 0.5, 0.5 }
    for _ = 1, 20 do sc:Fire("OnMouseWheel", 1) end
    eq(sc:GetCanvasScale(), 4, "stops at maxZoom")
    for _ = 1, 20 do sc:Fire("OnMouseWheel", -1) end
    eq(sc:GetCanvasScale(), 1, "stops at the fitted size")
    ToggleWorldMap()
end)

test("zooming keeps the point under the cursor in place", function()
    ToggleWorldMap()
    M.cursor = { 0.3, 0.4 }
    sc:Fire("OnMouseWheel", 1)
    sc:Fire("OnMouseWheel", 1)
    local s = sc:GetCanvasScale()
    -- The cursor's offset from the view centre shrinks by the zoom factor.
    local cx, cy = sc:GetCurrentScrollX(), sc:GetCurrentScrollY()
    truthy(math.abs((0.3 - cx) - (0.3 - 0.5) / s) < 1e-6, "x")
    truthy(math.abs((0.4 - cy) - (0.4 - 0.5) / s) < 1e-6, "y")
    ToggleWorldMap()
    Map:ResetZoomMemory()
end)

test("zoom and pan are remembered per map across open and close", function()
    ToggleWorldMap()
    M.cursor = { 0.5, 0.5 }
    sc:Fire("OnMouseWheel", 1)
    sc:InstantPanAndZoom(sc:GetCanvasScale(), 0.45, 0.55)
    sc:Fire("OnMouseUp", "LeftButton")
    local scale = sc:GetCanvasScale()
    ToggleWorldMap()
    ToggleWorldMap()
    eq(sc:GetCanvasScale(), scale, "zoom restored after Blizzard's reset")
    eq(sc:GetCurrentScrollX(), 0.45)
    eq(sc:GetCurrentScrollY(), 0.55)

    map:SetMapID(1415)
    eq(sc:GetCanvasScale(), 1, "other maps keep their own view")
    map:SetMapID(1429)
    eq(sc:GetCanvasScale(), scale, "coming back restores it")

    ns.db.map.rememberZoom = false
    ToggleWorldMap()
    ToggleWorldMap()
    eq(sc:GetCanvasScale(), 1, "off: Blizzard's fitted view")
    ns.db.map.rememberZoom = true
    ToggleWorldMap()
    Map:ResetZoomMemory()
end)

test("coordinates bar shows the map, player and cursor", function()
    ToggleWorldMap()
    M.cursorOverMap = true
    M.cursor = { 0.25, 0.75 }
    Map:UpdateBar()
    eq(Map.bar.name:GetText(), "Elwynn Forest")
    eq(Map.bar.player:GetText(), "Player: 48.4, 39.3")
    eq(Map.bar.cursor:GetText(), "Cursor: 25.0, 75.0")
    M.cursorOverMap = false
    Map:UpdateBar()
    eq(Map.bar.cursor:GetText(), "Cursor: ")
    map:SetMapID(1415)
    Map:UpdateBar()
    eq(Map.bar.player:GetText(), "Player: ", "player isn't on this map")
    ns.db.map.coords = false
    Map:UpdateBar()
    eq(Map.bar.player:GetText(), "")
    ns.db.map.coords = true
    ToggleWorldMap()
end)

test("dragging the bar moves the map and saves the position", function()
    Map.bar:Fire("OnDragStart")
    map:ClearAllPoints()
    map:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100.4, -50.6)
    Map.bar:Fire("OnDragStop")
    local p = ns.db.map.point
    eq(p[1], "TOPLEFT"); eq(p[3], 100); eq(p[4], -51)
    SlashCmdList.JIJOURNAL("reset")
    eq(ns.db.map.point, nil)
    eq((map:GetPoint(1)), "CENTER")
end)

test("map scale and opacity apply", function()
    ns.db.map.scale, ns.db.map.alpha = 1.3, 0.8
    ns:ApplySettings()
    eq(map:GetScale(), 1.3)
    eq(sc:GetAlpha(), 0.8)
    ns.db.map.scale, ns.db.map.alpha = 1, 1
    ns:ApplySettings()
end)

-------------------------------------------------------------------------------
-- Quest log
-------------------------------------------------------------------------------

test("L, OpenQuestLog and tracker clicks open JiJournal's log, not Blizzard's", function()
    M.questCalls = {}
    ToggleQuestLog()
    truthy(frame:IsShown())
    ToggleQuestLog()
    eq(frame:IsShown(), false)
    OpenQuestLog()
    truthy(frame:IsShown())
    QuestMapFrame_OpenToQuestDetails(1003)
    eq(Q.selected, 1003)
    eq(#M.questCalls, 0, "Blizzard's versions never ran")
    eq(map:IsShown(), false, "the map stays closed")
    frame:Hide()
end)

test("the quest log takes the globals back when Blizzard's map loads after it", function()
    -- Blizzard_WorldMap.lua redefines these when it loads.
    ToggleQuestLog = function() M.questCalls[#M.questCalls + 1] = "blizzard toggle" end
    OpenQuestLog = function() M.questCalls[#M.questCalls + 1] = "blizzard open" end
    Fire("ADDON_LOADED", "Blizzard_WorldMap")
    M.questCalls = {}
    ToggleQuestLog()
    truthy(frame:IsShown())
    frame:Hide()
    OpenQuestLog()
    truthy(frame:IsShown())
    eq(#M.questCalls, 0)
    frame:Hide()
    ToggleQuestLog = function() end
    Fire("PLAYER_LOGIN")
    ToggleQuestLog()
    truthy(frame:IsShown(), "and again at login")
    frame:Hide()
end)

test("list groups quests by zone with levels and states", function()
    Q.selected = nil
    Open()
    local rows = Rows()
    eq(rows[1], "Darkshore")
    eq(rows[2], "[13] Bashal'Aran")
    eq(rows[3], "[14] Buzzbox 323")
    eq(rows[4], "[14] As Water Cascades|(Complete)")
    eq(rows[5], "[20+] The Absent Minded Prospector")
    eq(rows[6], "Darnassus")
    eq(rows[7], "[11] Grove of the Ancients|(Complete)")
    eq(plain(Q.count:GetText()), "Quests: 5/20")
    ns.db.questLog.showLevels = false
    Q:Refresh()
    eq(Rows()[2], "Bashal'Aran")
    ns.db.questLog.showLevels = true
    Q:Refresh()
end)

test("rows are coloured by difficulty and tracked quests get a tick", function()
    Open()
    eq(RowFor("Absent").title._color[2], 0.5, "orange: 3-4 levels above")
    eq(RowFor("Grove").title._color[1], 0.25, "green: low level")
    eq(RowFor("Buzzbox").title._color[2], 1, "yellow: around your level")
    truthy(RowFor("Buzzbox").check:IsShown(), "tracked")
    eq(RowFor("Bashal").check:IsShown(), false)
end)

test("the first quest is selected and its details drawn by QuestInfo", function()
    Open()
    Q.selected = nil
    Q:Refresh()
    eq(Q.selected, 1001)
    eq(M.selectedQuest, 1001)
    eq(M.questInfo.questID, 1001)
    eq(M.questInfo.parent, Q.detail.child)
    eq(QuestInfoTitleHeader:GetText(), "Bashal'Aran [1001]", "quest ID after the title")
    local t = M.questInfo.template
    eq(t.canHaveSealMaterial, nil, "no seal material")
    for i = 1, #t.elements, 3 do truthy(t.elements[i] ~= QuestInfo_ShowSeal, "no seal element") end
    eq(#t.elements, 9)
    truthy(RowFor("Bashal").selected:IsShown())
end)

test("clicking a quest selects it", function()
    Open()
    RowFor("Buzzbox"):Fire("OnClick", "LeftButton")
    eq(Q.selected, 1002)
    eq(QuestInfoTitleHeader:GetText(), "Buzzbox 323 [1002]")
    eq(RowFor("Bashal").selected:IsShown(), false)
    ns.db.questLog.showIDs = false
    Q:ShowDetails()
    eq(QuestInfoTitleHeader:GetText(), "Buzzbox 323")
    ns.db.questLog.showIDs = true
end)

test("headers collapse and expand, one at a time or all", function()
    Open()
    RowFor("Darkshore"):Fire("OnClick", "LeftButton")
    eq(#Rows(), 3)
    eq(Rows()[2], "Darnassus")
    eq(ns.db.questLog.collapsed.Darkshore, true)
    RowFor("Darkshore"):Fire("OnClick", "LeftButton")
    eq(#Rows(), 7)
    Q.all:Fire("OnClick")
    eq(#Rows(), 2, "all collapsed")
    Q.all:Fire("OnClick")
    eq(#Rows(), 7, "all expanded")
end)

test("headers Blizzard collapsed are expanded again", function()
    M.questLog[6].collapsed = true
    Q:Refresh()
    eq(M.questLog[6].collapsed, false)
end)

test("track checkbox and shift-click toggle tracking", function()
    Open()
    Q:Select(1001)
    eq(Q.track.check:GetChecked(), false)
    Q.track.check:SetChecked(true)
    Q.track.check:Fire("OnClick")
    eq(M.watched[1001], true)
    H.Tick(0.1)
    truthy(RowFor("Bashal").check:IsShown())
    M.modifiers.shift = true
    RowFor("Bashal"):Fire("OnClick", "LeftButton")
    M.modifiers.shift = false
    eq(M.watched[1001], nil, "shift-click untracks with chat closed")
    eq(Q.selected, 1001, "shift-click doesn't change the selection")
end)

test("abandon and share go through Blizzard's quest options", function()
    Open()
    M.questCalls = {}
    Q:Select(1001)
    M.units.party1 = { name = "Friend", level = 15 }
    Q:UpdateButtons()
    Q.share:Fire("OnClick")
    Q.abandon:Fire("OnClick")
    eq(M.questCalls[1], "share 1001")
    eq(M.questCalls[2], "abandon 1001")
    M.units.party1 = nil
end)

test("abandoned quests drop out and the selection moves on", function()
    Open()
    Q:Select(1002)
    table.remove(M.questLog, 3)
    Fire("QUEST_LOG_UPDATE")
    H.Tick(0.1)
    eq(Q.selected, 1001)
    eq(RowFor("Buzzbox"), nil)
    Log()
    Fire("QUEST_LOG_UPDATE")
    H.Tick(0.1)
end)

test("details wait while Blizzard's quest dialog uses QuestInfo", function()
    Open()
    QuestFrame:Show()
    local calls = M.questInfoCalls
    Q:Select(1003)
    eq(M.questInfoCalls, calls, "not drawn while the dialog is open")
    QuestFrame:Hide()
    eq(M.questInfoCalls, calls + 1, "drawn when it closes")
    eq(M.questInfo.questID, 1003)
end)

test("quest log updates are batched while open and skipped while closed", function()
    Open()
    local calls = M.questInfoCalls
    for _ = 1, 5 do Fire("QUEST_LOG_UPDATE") end
    H.Tick(0.1)
    eq(M.questInfoCalls, calls + 1, "one redraw for a burst")
    frame:Hide()
    Fire("QUEST_LOG_UPDATE")
    H.Tick(0.1)
    eq(M.questInfoCalls, calls + 1, "nothing while closed")
end)

test("hidden quests are left out and empty headers dropped", function()
    M.questLog[7].hidden = true
    Open()
    Q:Refresh()
    eq(RowFor("Darnassus"), nil)
    Log()
    Q:Refresh()
end)

test("escape closes the quest log, and position and scale are saved", function()
    truthy(tContains(UISpecialFrames, "JiJournalQuestLogFrame"))
    frame:Fire("OnDragStart")
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -80)
    frame:Fire("OnDragStop")
    eq(ns.db.questLog.point[3], 40)
    ns.db.questLog.scale = 1.2
    ns:ApplySettings()
    eq(frame:GetScale(), 1.2)
end)

test("options sliders change the map scale", function()
    SlashCmdList.JIJOURNAL("")
    local slider
    for _, f in ipairs(M.frames) do
        if f._kind == "Slider" and f._min == 0.5 and f._max == 2 and not slider then slider = f end
    end
    truthy(slider, "found the map scale slider")
    slider:SetValue(1.5)
    eq(ns.db.map.scale, 1.5)
    eq(map:GetScale(), 1.5)
    SlashCmdList.JIJOURNAL("")
end)

H.Finish()
