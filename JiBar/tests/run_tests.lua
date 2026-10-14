-- Run with: luajit tests/run_tests.lua (from JiBar/) or luajit JiBar/tests/run_tests.lua
local here = debug.getinfo(1, "S").source:match("^@(.-)[^/]*$")
package.path = here .. "../../tools/?.lua;" .. package.path
local H = require("harness")
local M = H.mock

M.geometry = true
M.echo = os.getenv("ECHO") ~= nil
M.fixedTime = os.time({ year = 2026, month = 10, day = 11, hour = 22, min = 19, sec = 5 })
M.money = 1239657
M.units.player.xp, M.units.player.xpMax = 6240, 10000
M.rested = 1500
M.units.player.level = 40
M.durability = { [1] = { 50, 50 }, [5] = { 30, 100 }, [16] = { 90, 100 } }
M.repairCosts = { [5] = 1234, [16] = 56 }
M.knownSpells[556] = false
M.AddItem(6948, "Hearthstone", 1, 15, "", 134414, 0, 1)
M.bags[6948] = 1
M.questLog = {
    { isHeader = true, title = "Elwynn Forest" },
    { questID = 11, title = "Riverpaw Gnoll Bounty", level = 10,
      objectives = { { text = "Painted Gnoll Armband: 3/8", finished = false, numFulfilled = 3, numRequired = 8 } } },
    { questID = 12, title = "Princess Must Die!", level = 12, complete = true },
    { isHeader = true, title = "Westfall" },
    { questID = 21, title = "The Defias Brotherhood", level = 18, elite = true },
}

-- Blizzard's buttons that JiBar clicks or docks.
MicroMenu = CreateFrame("Frame", "MicroMenu", UIParent)
local microLayouts = 0
MicroMenu.Layout = function() microLayouts = microLayouts + 1 end
for i, name in ipairs({ "MainMenuMicroButton", "CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton",
    "QuestLogMicroButton", "GuildMicroButton", "LFDMicroButton", "EJMicroButton", "HelpMicroButton" }) do
    CreateFrame("Button", name, MicroMenu).layoutIndex = i
end
HelpMicroButton:Hide() -- Blizzard hides it while the shop button is shown
CreateFrame("Button", "StoreMicroButton", MicroMenu) -- left out by a game rule: no layoutIndex
CreateFrame("Button", "QuickJoinToastButton", UIParent)
CreateFrame("Frame", "MinimapCluster", UIParent)
MinimapCluster.ZoneTextButton = CreateFrame("Button", nil, MinimapCluster)
CreateFrame("Button", "GameTimeFrame", MinimapCluster)
CreateFrame("Button", "TimeManagerClockButton", MinimapCluster)
CreateFrame("Button", "MainMenuBarBackpackButton", UIParent)

local ns = H.LoadAddon(here .. "../JiBar")
local Fire, test, eq, truthy, plain = H.Fire, H.test, H.eq, H.truthy, H.plain

Fire("ADDON_LOADED", "JiBar")
Fire("PLAYER_LOGIN")
Fire("PLAYER_ENTERING_WORLD")
H.Tick(1.1)

local P = ns.plugins
local bar1 = ns.Bars.list[1]

local function SideIDs(bar, side)
    local out = {}
    for _, p in ipairs(bar.sides[side]) do out[#out + 1] = p.id end
    return table.concat(out, ",")
end

local function Text(id) return plain(P[id].text:GetText()) end

-- Collects the tooltip a plugin would show as plain "left|right|third" lines.
local function TipLines(plugin)
    ns.Tip:Open(plugin)
    local out = {}
    for _, line in ipairs(ns.Tip.lines) do
        if line.kind == "title" then
            out[#out + 1] = "# " .. plain(line.text)
        elseif line.cols then
            local cols = {}
            for c = 1, 3 do
                if line.cols[c] ~= nil then cols[#cols + 1] = plain(tostring(line.cols[c])) end
            end
            out[#out + 1] = table.concat(cols, "|")
        end
    end
    ns.Tip:Close()
    return out
end

local function Has(list, wanted)
    for _, v in ipairs(list) do
        if v:find(wanted, 1, true) then return v end
    end
end

-------------------------------------------------------------------------------
-- Setup and defaults
-------------------------------------------------------------------------------

test("saved variables and slash commands", function()
    truthy(JiBarDB)
    eq(ns.db.locked, true)
    eq(#ns.db.bars, 1)
    eq(SLASH_JIBAR1, "/jibar")
    eq(JiBarDB.plugins.Clock.fontSize, 25, "the clock keeps FuBar's big font")
end)

test("default layout matches the FuBar screenshot", function()
    eq(bar1.data.attach, "BOTTOM")
    eq(SideIDs(bar1, "LEFT"), "MicroMenu")
    eq(SideIDs(bar1, "CENTER"), "Durability,Honor,Clock,Quests,Money")
    eq(SideIDs(bar1, "RIGHT"), "Transporter,Experience,Performance")
    eq(P.CustomMenu.db.enabled, false)
    eq(P.CustomMenu.frame:IsShown(), false)
end)

test("the bar spans the bottom of the screen", function()
    local f = bar1.frame
    eq(f:GetWidth(), 1920)
    eq(f:GetHeight(), 28)
    eq(f:GetLeft(), 0)
    eq(f:GetBottom(), 0)
end)

test("plugins are laid out left, centred and right", function()
    local micro, perf = P.MicroMenu, P.Performance
    eq(micro.layoutX, bar1.data.padding)
    local right = perf.layoutX + perf.width
    eq(math.floor(right + 0.5), 1920 - bar1.data.padding)
    -- The centre group is centred.
    local first, last = bar1.sides.CENTER[1], bar1.sides.CENTER[#bar1.sides.CENTER]
    local left, rightEdge = first.layoutX, last.layoutX + last.width
    truthy(math.abs((left + rightEdge) / 2 - 960) < 1, "centre group centred")
    -- No overlaps on the right side.
    local t, x = P.Transporter, P.Experience
    truthy(t.layoutX + t.width <= x.layoutX, "transporter left of experience")
end)

-------------------------------------------------------------------------------
-- Clock
-------------------------------------------------------------------------------

test("clock shows realm time like ClockFu, with options", function()
    local c = P.Clock
    eq(Text("Clock"), "10:19 PM")
    c.db.twentyFour = true
    c:Refresh()
    eq(Text("Clock"), "22:19")
    c.db.localTime, c.db.bothTimes = true, true
    c:Refresh()
    eq(Text("Clock"), "22:19 • 22:19")
    c.db.twentyFour, c.db.localTime, c.db.bothTimes = false, false, false
    c:Refresh()
    eq(c.text._font[2], 25, "big clock font")
end)

test("clock tooltip, and clicks go to the minimap's calendar and clock", function()
    local lines = TipLines(P.Clock)
    truthy(Has(lines, "Realm time"))
    truthy(Has(lines, "Sunday, October 11, 2026"))
    local o = P.Clock.overlay
    eq(o:GetAttribute("type1"), "click")
    eq(o:GetAttribute("clickbutton1"), GameTimeFrame)
    eq(o:GetAttribute("shift-clickbutton1"), TimeManagerClockButton)
end)

test("window-opening plugins click Blizzard's buttons securely", function()
    eq(P.Durability.overlay:GetAttribute("clickbutton1"), CharacterMicroButton)
    eq(P.Honor.overlay:GetAttribute("clickbutton1"), LFDMicroButton)
    eq(P.Quests.overlay:GetAttribute("clickbutton1"), QuestLogMicroButton)
    eq(P.Money.overlay:GetAttribute("clickbutton1"), MainMenuBarBackpackButton)
    for _, id in ipairs({ "Durability", "Honor", "Quests", "Money", "Clock" }) do
        local o = P[id].overlay
        eq(o:GetParent(), UIParent, id .. " overlay is not a child of the bar")
        truthy(o:IsShown(), id .. " overlay shown")
        eq(o._points[1][4], P[id].layoutX, id .. " overlay covers the plugin")
    end
end)

-------------------------------------------------------------------------------
-- Durability
-------------------------------------------------------------------------------

test("durability shows the most damaged item, or the average", function()
    eq(Text("Durability"), "30%")
    P.Durability.db.showAverage = true
    P.Durability:Refresh()
    eq(Text("Durability"), "68%") -- (50 + 30 + 90) / 250
    P.Durability.db.showAverage = false
    P.Durability:Refresh()
end)

test("durability tooltip lists items with repair costs", function()
    local lines = TipLines(P.Durability)
    eq(Has(lines, "Chest"), "Chest|30%|12s 34c")
    eq(Has(lines, "Repair cost"), "Repair cost|12s 90c")
end)

test("durability repairs automatically at a merchant", function()
    P.Durability.db.autoRepair = true
    M.merchant = { canRepair = true, cost = 1290 }
    Fire("MERCHANT_SHOW")
    eq(M.repairs[1], "self")
    P.Durability.db.autoRepair = false
    M.merchant = nil
end)

-------------------------------------------------------------------------------
-- Money
-------------------------------------------------------------------------------

test("money text styles", function()
    local m = P.Money
    eq(Text("Money"), "123g 96s 57c")
    m.db.style = "GOLD"
    m:Refresh()
    eq(Text("Money"), "123g")
    m.db.style = "SHORT"
    m:Refresh()
    eq(Text("Money"), "124.0g")
    m.db.style = "LETTERS"
    m:Refresh()
end)

test("money tracks gains and spending", function()
    M.money = M.money + 5000
    Fire("PLAYER_MONEY")
    M.money = M.money - 200
    Fire("PLAYER_MONEY")
    eq(P.Money.session.gained, 5000)
    eq(P.Money.session.spent, 200)
    local lines = TipLines(P.Money)
    truthy(Has(lines, "Gained|50s 0c"))
    truthy(Has(lines, "Profit|48s 0c"))
    truthy(Has(lines, "Jiloot|124g 44s 57c"))
end)

-------------------------------------------------------------------------------
-- Quests
-------------------------------------------------------------------------------

test("quests show the count out of the maximum", function()
    eq(Text("Quests"), "3/20")
    P.Quests.db.showCompleted = true
    P.Quests:Refresh()
    eq(Text("Quests"), "1/3/20")
    P.Quests.db.showCompleted = false
    P.Quests:Refresh()
end)

test("quest progress messages appear on the bar", function()
    ERR_QUEST_ADD_ITEM_SII = "%s: %d/%d"
    P.Quests:OnEnable()
    Fire("UI_INFO_MESSAGE", 0, "Painted Gnoll Armband: 4/8")
    eq(Text("Quests"), "3/20 • Painted Gnoll Armband: 4/8")
    H.Tick(31)
    eq(Text("Quests"), "3/20")
end)

test("quest tooltip lists zones, levels and objectives", function()
    local lines = TipLines(P.Quests)
    truthy(Has(lines, "[-] Elwynn Forest"))
    truthy(Has(lines, "[10] Riverpaw Gnoll Bounty"))
    eq(Has(lines, "Painted Gnoll Armband|"), "Painted Gnoll Armband|3/8")
    truthy(Has(lines, "[18+] The Defias Brotherhood"), "elite tag")
    eq(Has(lines, "Princess"), "[12] Princess Must Die!|Done")
end)

test("quest tooltip lines are clickable", function()
    ns.Tip:Open(P.Quests)
    local quest
    for _, line in ipairs(ns.Tip.lines) do
        if line.cols and tostring(line.cols[1]):find("Riverpaw", 1, true) then quest = line end
    end
    truthy(quest and quest.onClick, "quest line has a click handler")
    -- Without JiJournal, a click tracks: Blizzard's quest log can't be opened from addon code.
    local before = #M.questCalls
    quest.onClick("LeftButton")
    eq(#M.questCalls, before, "Blizzard's quest log not opened")
    eq(M.watched[11], true, "click tracks")
    M.modifiers.alt = true
    quest.onClick("LeftButton")
    M.modifiers.alt = false
    eq(M.watched[11], nil, "alt-click untracks")
    -- Clicking a zone header collapses it.
    local header
    for _, line in ipairs(ns.Tip.lines) do
        if line.kind == "header" and tostring(line.cols[1]):find("Elwynn", 1, true) then header = line end
    end
    header.onClick("LeftButton")
    eq(P.Quests.db.collapsed["Elwynn Forest"], true)
    ns.Tip:Close()
    P.Quests.db.collapsed["Elwynn Forest"] = nil
end)

-------------------------------------------------------------------------------
-- Honor
-------------------------------------------------------------------------------

test("honor counts today's honour from the currency", function()
    eq(Text("Honor"), "0 HONOR • 0-0")
    M.currencies[1792].quantity = 160
    Fire("CURRENCY_DISPLAY_UPDATE", 1792, 160, 60)
    eq(Text("Honor"), "60 HONOR • 0-0")
end)

test("honor records battleground wins and losses", function()
    M.pvp.instance = { true, "pvp", "Warsong Gulch" }
    M.pvp.faction, M.pvp.winner = 1, 1
    Fire("UPDATE_BATTLEFIELD_STATUS")
    Fire("UPDATE_BATTLEFIELD_STATUS")
    eq(P.Honor.db.wins, 1, "recorded once")
    Fire("PLAYER_ENTERING_WORLD")
    M.pvp.winner = 0
    Fire("PVP_MATCH_COMPLETE")
    eq(P.Honor.db.losses, 1)
    eq(Text("Honor"), "60 HONOR • 1-1 (50%)")
    eq(P.Honor.db.battlegrounds["Warsong Gulch"].wins, 1)
    M.pvp.instance, M.pvp.winner = nil, nil
end)

-------------------------------------------------------------------------------
-- Experience
-------------------------------------------------------------------------------

test("experience shows XP text instead of FuXP's icon", function()
    eq(P.Experience.hasIcon, false)
    eq(Text("Experience"), "XP 62% +15%")
    P.Experience.db.showValues = true
    P.Experience:Refresh()
    eq(Text("Experience"), "XP 62% +15% • 6240/10.0k")
    P.Experience.db.showValues = false
    P.Experience:Refresh()
end)

test("experience bar runs along the inner edge of the bar", function()
    local b = P.Experience.edgeBar
    truthy(b and b:IsShown())
    eq(b:GetParent(), bar1.frame)
    eq(b._points[1][1], "BOTTOMLEFT")
    eq(b._points[1][3], "TOPLEFT", "above a bottom bar")
    eq(math.floor(b.xp:GetWidth() + 0.5), math.floor(1920 * 0.624 + 0.5))
    eq(math.floor(b.rest:GetWidth() + 0.5), math.floor(1920 * 0.15 + 0.5))
end)

test("experience switches to a watched faction", function()
    M.watchedFaction = { name = "Stormwind", reaction = 5, currentReactionThreshold = 3000,
        nextReactionThreshold = 9000, currentStanding = 4500 }
    Fire("UPDATE_FACTION")
    eq(Text("Experience"), "Rep 25%")
    local lines = TipLines(P.Experience)
    eq(Has(lines, "Standing"), "Standing|Friendly")
    M.watchedFaction = nil
    Fire("UPDATE_FACTION")
end)

test("experience click puts the numbers into chat", function()
    local inserted
    M.chatBox = { Insert = function(_, t) inserted = t end }
    P.Experience.frame:Fire("OnClick", "LeftButton")
    eq(inserted, "Level 40: 6240/10000 XP (62%), 3760 to go")
    M.chatBox = nil
end)

-------------------------------------------------------------------------------
-- Performance
-------------------------------------------------------------------------------

test("performance shows fps, latency, memory and growth", function()
    local t = Text("Performance")
    truthy(t:match("^60fps • 110ms • [%d%.]+ MiB • [%-%d%.]+ KiB/s$"), t)
    P.Performance.db.latency = "HOME"
    P.Performance:Refresh()
    truthy(Text("Performance"):find("40ms", 1, true))
    local lines = TipLines(P.Performance)
    eq(Has(lines, "Questie"), "Questie|29.30 MiB")
end)

-------------------------------------------------------------------------------
-- Transporter (secure overlay)
-------------------------------------------------------------------------------

test("transporter shows the inn and arms its secure button", function()
    local t = P.Transporter
    eq(Text("Transporter"), "IRONFORGE")
    local b = t.overlay
    eq(b._template, "SecureActionButtonTemplate")
    eq(b:GetParent(), UIParent, "not a child of the bar")
    eq(b:GetAttribute("type1"), "item")
    eq(b:GetAttribute("item1"), "item:6948")
    eq(b:GetAttribute("useOnKeyDown"), false, "acts on release, matching the AnyUp registration")
    H.Tick(0.1)
    truthy(b:IsShown(), "overlay shown")
    local p = b._points[1]
    eq(p[2], UIParent)
    eq(p[4], t.layoutX)
end)

test("transporter switches methods, but not in combat", function()
    local t = P.Transporter
    M.knownSpells[556] = true
    Fire("SPELLS_CHANGED")
    M.inCombat = true
    t:SetMethod("spell:556")
    eq(t.overlay:GetAttribute("type1"), "item", "unchanged in combat")
    M.inCombat = false
    Fire("PLAYER_REGEN_ENABLED")
    eq(t.overlay:GetAttribute("type1"), "spell")
    eq(t.overlay:GetAttribute("spell1"), 556)
    M.spellCooldowns[556] = { M.now - 100, 900 }
    t:Update()
    eq(Text("Transporter"), "IRONFORGE • 13m 20s")
    t:SetMethod("item:6948")
    M.knownSpells[556] = nil
    -- No inn known yet: the item's name, never a dangling separator.
    M.bindLocation = ""
    M.itemCooldowns = { [6948] = { M.now - 60, 1800 } }
    t:Update()
    eq(Text("Transporter"), "HEARTHSTONE • 29m 00s")
    M.bindLocation, M.itemCooldowns = "Ironforge", nil
    t:Update()
end)

-------------------------------------------------------------------------------
-- Micro menu
-------------------------------------------------------------------------------

test("micro menu has FuBar's buttons", function()
    local mm = P.MicroMenu
    local shown = 0
    for _, b in ipairs(mm.BUTTONS) do
        if mm.icons[b.id] and mm.icons[b.id]:IsShown() then shown = shown + 1 end
    end
    eq(shown, 14)
end)

test("micro menu docks Blizzard's micro buttons over its icons", function()
    local mm = P.MicroMenu
    for icon, name in pairs({ Menu = "MainMenuMicroButton", Character = "CharacterMicroButton",
        Spellbook = "SpellbookMicroButton", Talents = "TalentMicroButton", Quests = "QuestLogMicroButton",
        Guild = "GuildMicroButton", Journal = "EJMicroButton" }) do
        eq(_G[name]:GetParent(), mm.icons[icon], name .. " docked")
        eq(_G[name]:GetAlpha(), 0, name .. " invisible")
    end
    eq(StoreMicroButton:GetParent(), MicroMenu, "buttons the client left out stay put")
    eq(HelpMicroButton:GetParent(), MicroMenu, "hidden buttons aren't docked")
    -- Blizzard re-enables buttons with SetAlpha(1); the hook hides it again.
    CharacterMicroButton:SetAlpha(1)
    CharacterMicroButton:Fire("OnEnable")
    eq(CharacterMicroButton:GetAlpha(), 0)
end)

test("other micro menu icons click Blizzard buttons through secure overlays", function()
    local mm = P.MicroMenu
    local function Target(id)
        local o = mm.overlaysByIcon[id]
        eq(o:GetAttribute("type1"), "click", id)
        eq(o:GetParent(), UIParent)
        return o:GetAttribute("clickbutton1")
    end
    eq(Target("Who"), QuickJoinToastButton)
    eq(Target("Friends"), QuickJoinToastButton)
    eq(Target("Raid"), QuickJoinToastButton)
    eq(Target("Reputation"), CharacterMicroButton)
    eq(Target("PvP"), LFDMicroButton)
    eq(Target("WorldMap"), MinimapCluster.ZoneTextButton)
    eq(Target("Help"), HelpMicroButton)
    eq(mm.overlaysByIcon.Character, nil, "docked icons need no overlay")
    eq(mm.overlaysByIcon.Friends._points[1][4], P.MicroMenu.layoutX + mm.icons.Friends._points[1][4])
end)

test("hiding a micro menu icon gives Blizzard its button back", function()
    local mm = P.MicroMenu
    mm.db.visible.Character = false
    mm:OnSettingChanged()
    eq(CharacterMicroButton:GetParent(), MicroMenu)
    eq(CharacterMicroButton:GetAlpha(), 1)
    truthy(microLayouts > 0)
    mm.db.visible.Character = nil
    mm:OnSettingChanged()
    eq(CharacterMicroButton:GetParent(), mm.icons.Character)
end)

test("overlay changes wait for the end of combat", function()
    local mm = P.MicroMenu
    M.inCombat = true
    mm.db.visible.Friends = false
    mm:OnSettingChanged()
    eq(mm.overlaysByIcon.Friends.disabled, false, "unchanged in combat")
    M.inCombat = false
    Fire("PLAYER_REGEN_ENABLED")
    eq(mm.overlaysByIcon.Friends.disabled, true)
    mm.db.visible.Friends = nil
    mm:OnSettingChanged()
end)

test("no plugin opens Blizzard windows from addon code", function()
    M.Calls()
    for _, p in ipairs(ns.pluginList) do
        if p.db.enabled and p.id ~= "Experience" and p.id ~= "Performance" then
            p.frame:Fire("OnClick", "LeftButton")
        end
    end
    for _, icon in pairs(P.MicroMenu.icons) do icon:Fire("OnClick", "LeftButton") end
    for _, call in ipairs(M.Calls()) do
        truthy(not call:find("^Toggle"), "called " .. call)
    end
end)

-------------------------------------------------------------------------------
-- Menus
-------------------------------------------------------------------------------

test("right-click menu moves a plugin to another side", function()
    P.Clock.frame:Fire("OnClick", "RightButton")
    local root = M.menu
    eq(root.children[1].text, "Clock")
    truthy(M.FindMenu(root, "24-hour format"), "plugin options in the menu")
    M.ClickMenu(M.FindMenu(root, "Position", "Right"))
    eq(P.Clock.db.side, "RIGHT")
    eq(SideIDs(bar1, "RIGHT"), "Transporter,Experience,Performance,Clock")
    eq(SideIDs(bar1, "CENTER"), "Durability,Honor,Quests,Money")
end)

test("menu checkboxes change plugin settings", function()
    P.Clock.frame:Fire("OnClick", "RightButton")
    local item = M.FindMenu(M.menu, "Show seconds")
    eq(item:IsSelected(), false)
    M.ClickMenu(item)
    eq(P.Clock.db.showSeconds, true)
    truthy(Text("Clock"):match("^10:19:%d%d PM$"), Text("Clock"))
    M.ClickMenu(item)
end)

test("hiding a plugin from its menu and showing it from the bar menu", function()
    P.Honor.frame:Fire("OnClick", "RightButton")
    M.ClickMenu(M.FindMenu(M.menu, "Hide Honor"))
    eq(P.Honor.db.enabled, false)
    eq(P.Honor.frame:IsShown(), false)
    bar1.frame:Fire("OnMouseUp", "RightButton")
    M.ClickMenu(M.FindMenu(M.menu, "Plugins", "Honor"))
    eq(P.Honor.db.enabled, true)
    truthy(P.Honor.frame:IsShown())
end)

-------------------------------------------------------------------------------
-- Unlocked mode: dragging plugins and bars
-------------------------------------------------------------------------------

local function CursorAt(x, y) M.cursorPos[1], M.cursorPos[2] = x, y end

test("unlocking shows drag handles", function()
    SlashCmdList.JIBAR("unlock")
    eq(ns.db.locked, false)
    truthy(bar1.unlock:IsShown())
    truthy(P.Clock.unlockBox:IsShown())
    eq(P.Transporter.overlay:IsShown(), false, "secure overlay out of the way")
end)

test("dragging a plugin drops it at the marker", function()
    -- Drag the clock (now on the right) to the far left of the bar.
    P.Clock.frame:Fire("OnDragStart")
    CursorAt(2, 14)
    H.Tick(0.05)
    truthy(ns.Bars.ghost.marker:IsShown())
    P.Clock.frame:Fire("OnDragStop")
    eq(P.Clock.db.side, "LEFT")
    eq(SideIDs(bar1, "LEFT"), "Clock,MicroMenu")
    -- And between Quests and Money in the centre.
    P.Clock.frame:Fire("OnDragStart")
    CursorAt(P.Money.layoutX - 2, 10)
    P.Clock.frame:Fire("OnDragStop")
    eq(SideIDs(bar1, "CENTER"), "Durability,Honor,Quests,Clock,Money")
    eq(P.Clock.db.order, 4)
end)

test("dragging a bar to the top attaches it there", function()
    bar1.frame:Fire("OnDragStart")
    CursorAt(400, 1070)
    H.Tick(0.05)
    bar1.frame:Fire("OnDragStop")
    eq(bar1.data.attach, "TOP")
    eq(bar1.frame:GetBottom(), 1080 - 28)
    eq(P.Experience.edgeBar._points[1][1], "TOPLEFT", "XP bar now below the bar")
    -- Middle of the screen: floating.
    bar1.frame:Fire("OnDragStart")
    CursorAt(400, 500)
    H.Tick(0.05)
    bar1.frame:Fire("OnDragStop")
    eq(bar1.data.attach, "FLOAT")
    ns.Bars:SetAttach(1, "BOTTOM")
    eq(bar1.frame:GetBottom(), 0)
end)

test("dragging a bar edge resizes it", function()
    ns.Bars:BeginResize(bar1, "RIGHT")
    CursorAt(960, 10)
    H.Tick(0.05)
    ns.Bars:EndResize()
    eq(bar1.data.width, 0.5)
    eq(bar1.frame:GetWidth(), 960)
    local perf = P.Performance
    eq(math.floor(perf.layoutX + perf.width + 0.5), 960 - bar1.data.padding)
    bar1.data.width = 1
    ns.Bars:LayoutAll()
end)

test("locking again", function()
    SlashCmdList.JIBAR("lock")
    eq(ns.db.locked, true)
    eq(bar1.unlock:IsShown(), false)
    H.Tick(0.05)
    truthy(P.Transporter.overlay:IsShown())
end)

-------------------------------------------------------------------------------
-- Several bars
-------------------------------------------------------------------------------

test("a second bar stacks and takes plugins", function()
    local index = ns.Bars:AddBar()
    eq(index, 2)
    local bar2 = ns.Bars.list[2]
    eq(bar2.data.attach, "TOP")
    ns.Plugins:Move(P.Performance, 2, "RIGHT")
    eq(SideIDs(bar2, "RIGHT"), "Performance")
    eq(P.Performance.frame:GetParent(), bar2.frame)
    -- A second bottom bar sits on top of the first.
    ns.Bars:SetAttach(2, "BOTTOM")
    eq(bar2.frame:GetBottom(), 28)
    ns.Bars:RemoveBar(2)
    eq(#ns.db.bars, 1)
    eq(P.Performance.db.bar, 1)
    truthy(P.Performance.frame:IsShown())
end)

-------------------------------------------------------------------------------
-- Visibility
-------------------------------------------------------------------------------

test("auto-hide fades the bar until it is hovered", function()
    bar1.data.autoHide = true
    ns.Bars:LayoutAll()
    H.Tick(0.5)
    eq(bar1.frame:GetAlpha(), 0)
    M.mouseOver = bar1.frame
    H.Tick(0.5)
    eq(bar1.frame:GetAlpha(), 1)
    M.mouseOver = nil
    bar1.data.autoHide = false
    ns.Bars:LayoutAll()
    eq(bar1.frame:GetAlpha(), 1)
end)

test("hide in combat", function()
    bar1.data.hideInCombat = true
    Fire("PLAYER_REGEN_DISABLED")
    eq(bar1.frame:IsShown(), false)
    Fire("PLAYER_REGEN_ENABLED")
    truthy(bar1.frame:IsShown())
    bar1.data.hideInCombat = false
end)

-------------------------------------------------------------------------------
-- Custom menu, options
-------------------------------------------------------------------------------

test("custom menu entries run Lua", function()
    SlashCmdList.JIBAR("custom add Ping ### JIBAR_TEST_RAN = (JIBAR_TEST_RAN or 0) + 1")
    local cm = P.CustomMenu
    eq(#cm.db.entries, 1)
    ns.Plugins:SetEnabled(cm, true)
    cm.frame:Fire("OnClick", "RightButton")
    M.ClickMenu(M.FindMenu(M.menu, "Ping"))
    eq(JIBAR_TEST_RAN, 1)
    SlashCmdList.JIBAR("custom remove Ping")
    eq(#cm.db.entries, 0)
    ns.Plugins:SetEnabled(cm, false)
end)

test("options window builds and follows the settings", function()
    SlashCmdList.JIBAR("")
    truthy(JiBarOptionsFrame:IsShown())
    ns.db.fontSize = 14
    ns.Plugins:RefreshAll()
    eq(P.Quests.text._font[2], 14)
    eq(P.Clock.text._font[2], 25, "own size wins")
    ns.Bars:AddBar()
    eq(ns.Options.barNames[2], "Bar 2 (top)")
    ns.Bars:RemoveBar(2)
    SlashCmdList.JIBAR("")
    eq(JiBarOptionsFrame:IsShown(), false)
end)

test("text colour, opacity and hover tint", function()
    local q = P.Quests
    eq(q.text._color[4], 0.75, "FuBar's text alpha")
    q.frame:Fire("OnEnter")
    local hc = ns.db.hoverColor
    eq(q.iconTexture._color[1], hc[1], "icon tinted on hover")
    truthy(ns.Tip:IsOpenFor(q))
    q.frame:Fire("OnLeave")
    eq(q.iconTexture._color[1], 1)
    -- Text-only plugins tint the text instead.
    P.Clock.frame:Fire("OnEnter")
    eq(P.Clock.text._color[1], hc[1])
    P.Clock.frame:Fire("OnLeave")
    ns.Tip:Close()
end)

test("every icon sits the same distance from its text", function()
    -- Honor's look is the reference: its icon has 3.5 px of transparent margin
    -- on the right, plus the old 3 px offset.
    eq(ns.db.iconGap, 6.5)
    P.Money.db.showIcon = true -- off by default, like FuBar's graphical money
    P.Money:Refresh()
    for _, id in ipairs({ "Durability", "Honor", "Quests", "Money", "Transporter", "Performance" }) do
        local p = P[id]
        local point = p.text._points[1]
        eq(point[2], p.iconTexture, id .. " text follows the icon")
        eq(point[4], 6.5, id .. " gap")
    end
    -- Icons are cropped to their visible pixels.
    eq(P.Honor.iconTexture._texCoord[2], 25 / 32)
    eq(P.Honor.iconTexture:GetWidth(), 12.5)
    eq(P.Quests.iconTexture._texCoord[1], 4 / 16)
    eq(P.Quests.iconTexture:GetWidth(), 11)
    -- The plugin's width includes the gap.
    local q = P.Quests
    eq(q.width, math.ceil(q.text:GetStringWidth()) + 11 + 6.5)
    P.Money.db.showIcon = false
    P.Money:Refresh()
end)

test("the separator is configurable", function()
    ns.db.separator = "|"
    P.Honor:Refresh()
    eq(P.Honor.text:GetText(), "|cffffffff60 HONOR|r || |cffffff001-1 (50%)|r", "a bar is escaped")
    ns.db.separator = ""
    P.Honor:Refresh()
    eq(Text("Honor"), "60 HONOR 1-1 (50%)")
    ns.db.separator = "•"
    P.Honor:Refresh()
end)

test("no errors were printed", function()
    for _, line in ipairs(M.printed) do
        if line:find("error", 1, true) then error(line) end
    end
end)

H.Finish()
