-- Run with: luajit tests/run_tests.lua (from JiLoot/) or luajit JiLoot/tests/run_tests.lua
local here = debug.getinfo(1, "S").source:match("^@(.-)[^/]*$")
package.path = here .. "../../tools/?.lua;" .. package.path
local H = require("harness")

local ns, M = H.LoadAddon(here .. "../JiLoot")
local Fire, Tick, test, eq, truthy = H.Fire, H.Tick, H.test, H.eq, H.truthy

-- Visible rows sorted by vertical position (top first when growing down).
local function Rows()
    local out = {}
    for _, f in ipairs(M.frames) do
        if f.entry and f._shown then out[#out + 1] = f end
    end
    table.sort(out, function(a, b) return (a.entry.targetY or 0) > (b.entry.targetY or 0) end)
    return out
end

local function FindRow(pattern)
    for _, r in ipairs(Rows()) do
        if r.left:GetText():find(pattern, 1, true) then return r end
    end
end

-------------------------------------------------------------------------------

Fire("ADDON_LOADED", "SomeOtherAddon")
test("does not initialise for other addons", function()
    eq(ns.db, nil)
end)

Fire("ADDON_LOADED", "JiLoot")
M.money = 10000
Fire("PLAYER_ENTERING_WORLD")

test("saved variables initialised with defaults", function()
    truthy(JiLootDB)
    eq(ns.db.maxRows, 10)
    eq(ns.db.durations.epic, 20)
    eq(type(ns.db.blacklist.items), "table")
end)

test("settings category and slash command registered", function()
    truthy(M.settingsCategory, "settings category")
    eq(SLASH_JILOOT1, "/jiloot")
    truthy(SlashCmdList.JILOOT)
end)

test("FormatToPattern handles reordered and literal specifiers", function()
    local pat, pos, types = ns.FormatToPattern("%2$s gets %1$d%% of it.")
    local args = ns.MatchFormat({ pattern = pat, positions = pos, types = types }, "Bob gets 50% of it.")
    eq(args[1], 50)
    eq(args[2], "Bob")
end)

test("money formatting", function()
    local plain = ns.FormatMoney(1234567):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    eq(plain, "123g 45s 67c")
    local small = ns.FormatMoney(305):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    eq(small, "3s 5c")
    eq(ns.FormatMoney(0), "")
end)

test("utf8 truncation never splits characters", function()
    eq(ns.Truncate("Thunderfury", 5), "Thund...")
    eq(ns.Truncate("Ëëëëë", 3), "Ëëë...")
    eq(ns.Truncate("Short", 10), "Short")
end)

local sword = M.AddItem(19019, "Thunderfury, Blessed Blade of the Windseeker", 5, 2, "INVTYPE_WEAPONMAINHAND",
    135349, 255355, 80, { ITEM_MOD_CR_LIFESTEAL_SHORT = 1, EMPTY_SOCKET_RED = 1 })
local cloth = M.AddItem(14047, "Runecloth", 1, 7, "", 132903, 400, 50)
local quest = M.AddItem(18422, "Head of Onyxia", 4, 12, "", 134153, 0, 60)
local junk = M.AddItem(4865, "Ruined Pelt", 0, 15, "", 134359, 5, 1)

test("looting a single item creates a row", function()
    Fire("CHAT_MSG_LOOT", "You receive loot: " .. sword .. ".", "", "", "", "Jiloot")
    local row = FindRow("Thunderfury")
    truthy(row, "row for sword")
    local text = row.left:GetText()
    truthy(text:find("ilvl: 80", 1, true), "ilvl line: " .. text)
    truthy(text:find("Leech", 1, true), "tertiary: " .. text)
    truthy(text:find("Socket", 1, true), "socket: " .. text)
    truthy(text:find("|cffff8000", 1, true), "legendary colour")
    truthy(row.right:GetText():find("25", 1, true), "vendor price: " .. row.right:GetText())
    eq(row.entry.duration, ns.db.durations.legendary)
end)

test("stacked loot shows count, unit and stack price", function()
    M.bags[14047] = 25
    Fire("CHAT_MSG_LOOT", "You receive loot: " .. cloth .. "x5.", "", "", "", "Jiloot")
    local row = FindRow("Runecloth")
    truthy(row, "runecloth row")
    local text = row.left:GetText()
    truthy(text:find("^5x "), "count prefix: " .. text)
    truthy(text:find("(25)", 1, true), "bag count: " .. text)
    local right = row.right:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    eq(right, "4s 0c\n20s 0c")
end)

test("repeated loot merges into the same row", function()
    local before = #Rows()
    Fire("CHAT_MSG_LOOT", "You receive loot: " .. cloth .. "x3.", "", "", "", "Jiloot")
    eq(#Rows(), before)
    eq(FindRow("Runecloth").entry.count, 8)
end)

test("modern |cnIQ quality colour links parse", function()
    local link = "|cnIQ3:|Hitem:14047::::::::60:::::|h[Runecloth]|h|r"
    local parsed, count = ns.Sources:ParseLootMessage("You receive loot: " .. link .. "x2.")
    eq(parsed, link)
    eq(count, 2)
end)

test("other players' loot is ignored", function()
    local before = #Rows()
    Fire("CHAT_MSG_LOOT", "Bob receives loot: " .. junk .. ".", "", "", "", "Bob")
    eq(#Rows(), before)
end)

test("quest items use the quest duration and colour", function()
    Fire("CHAT_MSG_LOOT", "You receive item: " .. quest .. ".", "", "", "", "Jiloot")
    local row = FindRow("Head of Onyxia")
    truthy(row)
    eq(row.entry.duration, ns.db.durations.quest)
    truthy(row.left:GetText():find("|cff00ccff", 1, true), "quest colour")
end)

test("secret chat payloads are ignored without errors", function()
    local before = #Rows()
    Fire("CHAT_MSG_LOOT", M.MakeSecret("x"), "", "", "", "Jiloot")
    eq(#Rows(), before)
end)

test("encounter loot is de-duplicated against the chat message", function()
    local before = FindRow("Thunderfury").entry.count
    Fire("ENCOUNTER_LOOT_RECEIVED", 1084, 19019, sword, 1, "Jiloot-Realm", "WARRIOR")
    eq(FindRow("Thunderfury").entry.count, before)
end)

test("uncached items are retried until data arrives", function()
    local ring = M.AddItem(18821, "Quick Strike Ring", 4, 4, "INVTYPE_FINGER", 133357, 20000, 67)
    M.uncached[18821] = true
    Fire("CHAT_MSG_LOOT", "You receive loot: " .. ring .. ".", "", "", "", "Jiloot")
    eq(FindRow("Quick Strike Ring"), nil)
    eq(M.requested, 18821)
    M.uncached[18821] = nil
    Tick(0.3)
    truthy(FindRow("Quick Strike Ring"), "row after cache")
end)

test("money gains show and merge", function()
    M.money = 10000 + 12345
    Fire("PLAYER_MONEY")
    local row = FindRow("Money")
    truthy(row)
    M.money = M.money + 10000
    Fire("PLAYER_MONEY")
    eq(row.entry.value, 22345)
    M.money = M.money - 5000 -- spending never shows
    Fire("PLAYER_MONEY")
    eq(row.entry.value, 22345)
end)

test("currency gains show quantity and cap", function()
    M.currencies[1166].quantity = 2000
    Fire("CURRENCY_DISPLAY_UPDATE", 1166, 2000, 40, 0, 0)
    local row = FindRow("Timewarped Badge")
    truthy(row)
    local text = row.left:GetText()
    truthy(text:find("^40x "), text)
    truthy(text:find("2000", 1, true), text)
end)

test("honor currency and honor chat merge into one row", function()
    M.currencies[1792].quantity = 15000
    Fire("CURRENCY_DISPLAY_UPDATE", 1792, 15000, 100, 0, 0)
    local row = FindRow("Honor")
    truthy(row, "honor row")
    truthy(row.left:GetText():find("|cffff0000", 1, true), "capped honor shown in red")
    Fire("CHAT_MSG_COMBAT_HONOR_GAIN", "You have been awarded 100 honor points.")
    eq(row.entry.count, 100, "duplicate honor from chat ignored")
    Tick(3.5)
    Fire("CHAT_MSG_COMBAT_HONOR_GAIN", "Bob dies, honorable kill Rank: Knight (Estimated Honor Points: 25)")
    local r2 = FindRow("Honor")
    truthy(r2)
    eq(r2.entry.count, 125)
end)

test("reputation gains show standing", function()
    M.factions[1].currentStanding = 3160
    Fire("CHAT_MSG_COMBAT_FACTION_CHANGE", "Reputation with Argent Dawn increased by 80.")
    local row = FindRow("Argent Dawn")
    truthy(row)
    local text = row.left:GetText()
    truthy(text:find("^%+80 "), text)
    truthy(text:find("160 / 6000", 1, true), text)
    truthy(text:find("Friendly", 1, true), text)
    Fire("CHAT_MSG_COMBAT_FACTION_CHANGE", "Reputation with Argent Dawn decreased by 100.")
    eq(row.entry.count, -20)
    truthy(row.left:GetText():find("|cffff0000-20|r", 1, true), row.left:GetText())
end)

test("reputation bonus variant parses", function()
    ns.Display:Clear()
    Fire("CHAT_MSG_COMBAT_FACTION_CHANGE", "Reputation with Argent Dawn increased by 55. (+5.5 bonus)")
    eq(FindRow("Argent Dawn").entry.count, 55)
end)

test("rows expire and are removed", function()
    ns.Display:Clear()
    Fire("CHAT_MSG_LOOT", "You receive loot: " .. cloth .. ".", "", "", "", "Jiloot")
    truthy(FindRow("Runecloth"))
    Tick(ns.db.durations.common + 1)
    eq(FindRow("Runecloth"), nil)
end)

test("hovering pauses the timer", function()
    Fire("CHAT_MSG_LOOT", "You receive loot: " .. cloth .. ".", "", "", "", "Jiloot")
    local row = FindRow("Runecloth")
    row:Fire("OnEnter")
    truthy(GameTooltip._lines[1]:find("HYPERLINK", 1, true), "item tooltip")
    Tick(ns.db.durations.common + 2)
    truthy(FindRow("Runecloth"), "still shown while hovered")
    row:Fire("OnLeave")
    Tick(ns.db.durations.common + 1)
    eq(FindRow("Runecloth"), nil)
end)

test("durations of 0 hide that quality", function()
    ns.db.durations.poor = 0
    Fire("CHAT_MSG_LOOT", "You receive loot: " .. junk .. ".", "", "", "", "Jiloot")
    eq(FindRow("Ruined Pelt"), nil)
    ns.db.durations.poor = 3
end)

test("alt+right-click blacklists and blacklist blocks loot", function()
    Fire("CHAT_MSG_LOOT", "You receive loot: " .. junk .. ".", "", "", "", "Jiloot")
    local row = FindRow("Ruined Pelt")
    truthy(row)
    M.modifiers.alt = true
    row:Fire("OnClick", "RightButton")
    M.modifiers.alt = nil
    eq(FindRow("Ruined Pelt"), nil)
    truthy(ns.db.blacklist.items[4865])
    Fire("CHAT_MSG_LOOT", "You receive loot: " .. junk .. ".", "", "", "", "Jiloot")
    eq(FindRow("Ruined Pelt"), nil)
    SlashCmdList.JILOOT("bl item 4865")
    eq(ns.db.blacklist.items[4865], nil)
end)

test("shift-click links the item", function()
    Fire("CHAT_MSG_LOOT", "You receive loot: " .. sword .. ".", "", "", "", "Jiloot")
    M.modifiers.shift = true
    FindRow("Thunderfury"):Fire("OnClick", "LeftButton")
    M.modifiers.shift = nil
    eq(M.linked, sword)
end)

test("row limit evicts the oldest rows", function()
    ns.Display:Clear()
    ns.db.maxRows = 3
    for i = 1, 5 do
        local link = M.AddItem(30000 + i, "Item " .. i, 2, 7, "", 134400, 100, 10)
        Fire("CHAT_MSG_LOOT", "You receive loot: " .. link .. ".", "", "", "", "Jiloot")
    end
    eq(#Rows(), 3)
    eq(FindRow("Item 1"), nil)
    truthy(FindRow("Item 5"))
    ns.db.maxRows = 10
end)

test("sorting by type puts reputation first and money last", function()
    ns.Display:Clear()
    M.money = M.money + 500
    Fire("PLAYER_MONEY")
    Fire("CHAT_MSG_LOOT", "You receive loot: " .. sword .. ".", "", "", "", "Jiloot")
    Fire("CHAT_MSG_COMBAT_FACTION_CHANGE", "Reputation with Argent Dawn increased by 5.")
    local rows = Rows()
    truthy(rows[1].left:GetText():find("Argent Dawn", 1, true), rows[1].left:GetText())
    truthy(rows[#rows].left:GetText():find("Money", 1, true), rows[#rows].left:GetText())
end)

test("highlight tiers and sound", function()
    ns.Display:Clear()
    ns.db.highlightSound = true
    Fire("CHAT_MSG_LOOT", "You receive loot: " .. sword .. ".", "", "", "", "Jiloot") -- 25g vendor
    local row = FindRow("Thunderfury")
    truthy(row.glow:IsShown(), "tier 1 glow at 25g")
    eq(ns.Display:HighlightTier(row.entry), 1)
    ns.db.thresholds[3] = 20
    ns.Display:Refresh(row.entry)
    eq(ns.Display:HighlightTier(row.entry), 3)
    eq(#M.sounds, 1)
    ns.db.thresholds[3] = 1000
    ns.db.highlightSound = false
end)

test("auction prices from Auctionator", function()
    Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function(_, link)
        return link:find("14047") and 1500 or nil
    end } } }
    ns.Display:Clear()
    Fire("CHAT_MSG_LOOT", "You receive loot: " .. cloth .. "x2.", "", "", "", "Jiloot")
    local right = FindRow("Runecloth").right:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    eq(right, "15s 0c\n4s 0c\n8s 0c")
    Auctionator = nil
end)

test("test mode shows sample rows", function()
    ns.Display:Clear()
    SlashCmdList.JILOOT("test")
    eq(#Rows(), 8)
    truthy(FindRow("Some Epic Sword"))
    ns.Display:Clear()
end)

test("options window builds and widgets refresh", function()
    SlashCmdList.JILOOT("")
    truthy(JiLootOptionsFrame and JiLootOptionsFrame:IsShown())
    JiLootOptionsFrame:Fire("OnShow")
    SlashCmdList.JILOOT("")
    eq(JiLootOptionsFrame:IsShown(), false)
end)

test("unlock and lock the anchor", function()
    SlashCmdList.JILOOT("unlock")
    eq(ns.db.locked, false)
    truthy(ns.Display.anchor.overlay:IsShown())
    SlashCmdList.JILOOT("lock")
    eq(ns.db.locked, true)
end)

test("grow up anchors rows at the bottom", function()
    ns.db.growUp = true
    ns.Display:ApplySettings()
    Fire("CHAT_MSG_LOOT", "You receive loot: " .. cloth .. ".", "", "", "", "Jiloot")
    local row = FindRow("Runecloth")
    eq(row._points[1][1], "BOTTOMLEFT")
    ns.db.growUp = false
    ns.Display:ApplySettings()
    eq(row._points[1][1], "TOPLEFT")
end)

test("disabled addon shows nothing", function()
    ns.Display:Clear()
    SlashCmdList.JILOOT("toggle")
    Fire("CHAT_MSG_LOOT", "You receive loot: " .. cloth .. ".", "", "", "", "Jiloot")
    eq(#Rows(), 0)
    SlashCmdList.JILOOT("toggle")
end)

test("missing events do not break loading", function()
    M.unknownEvents = { SOME_EVENT = true }
    eq(ns:RegisterEvent("SOME_EVENT", function() end), false)
    M.unknownEvents = nil
end)

test("reset keeps the blacklist", function()
    ns.db.blacklist.factions["Syndicate"] = true
    ns.db.width = 555
    ns:ResetDB()
    eq(ns.db.width, 400)
    truthy(ns.db.blacklist.factions["Syndicate"])
    eq(JiLootDB, ns.db)
end)

-------------------------------------------------------------------------------
-- Blizzard loot window
-------------------------------------------------------------------------------

local boe = M.AddItem(40001, "Green Boots", 2, 4, "INVTYPE_FEET", 132535, 500, 20)
M.items[40001].bind = 2
local bop = M.AddItem(40002, "Bound Helm", 3, 4, "INVTYPE_HEAD", 133071, 900, 25)
M.items[40002].bind = 1

local function OpenLoot(slots, autoLoot)
    M.loot, M.looted = slots, {}
    LootFrame:SetAlpha(1)
    Fire("LOOT_READY", autoLoot)
end

test("auto-loot without BoP takes everything and hides the loot window", function()
    OpenLoot({ { link = boe }, { link = cloth }, { type = 2 } }, true)
    eq(LootFrame:GetAlpha(), 0)
    eq(#M.looted, 3)
    Tick(1)
    eq(LootFrame:GetAlpha(), 0, "stays hidden while nothing is left")
    Fire("LOOT_CLOSED")
    eq(LootFrame:GetAlpha(), 1)
end)

test("bind-on-pickup loot leaves the loot window alone", function()
    OpenLoot({ { link = boe }, { link = bop } }, true)
    eq(LootFrame:GetAlpha(), 1)
    eq(#M.looted, 0)
end)

test("manual looting leaves the loot window alone", function()
    OpenLoot({ { link = boe } }, false)
    eq(LootFrame:GetAlpha(), 1)
    eq(#M.looted, 0)
end)

test("locked slots (rolls) and uncached items leave the window alone", function()
    OpenLoot({ { link = boe, locked = true } }, true)
    eq(LootFrame:GetAlpha(), 1)
    M.uncached[40001] = true
    OpenLoot({ { link = boe } }, true)
    eq(LootFrame:GetAlpha(), 1)
    M.uncached[40001] = nil
end)

test("loot window reappears when items cannot be taken", function()
    M.bagsFull = true
    OpenLoot({ { link = boe } }, true)
    eq(LootFrame:GetAlpha(), 0)
    Tick(0.6)
    eq(LootFrame:GetAlpha(), 1)
    M.bagsFull = false
    Fire("LOOT_CLOSED")
end)

test("option off leaves the loot window alone", function()
    ns.db.hideLootWindow = false
    OpenLoot({ { link = boe } }, true)
    eq(LootFrame:GetAlpha(), 1)
    ns.db.hideLootWindow = true
end)

H.Finish()
