-- Run with: luajit tests/run_tests.lua (from JiCombatFont/) or luajit JiCombatFont/tests/run_tests.lua
local here = debug.getinfo(1, "S").source:match("^@(.-)[^/]*$")
package.path = here .. "../../tools/?.lua;" .. package.path
local H = require("harness")
local M = H.mock

local MEDIA = "Interface\\AddOns\\JiCombatFont\\Media\\"
local GALAXY = MEDIA .. "galaxy.ttf"

-- All exist before addons load: DAMAGE_TEXT_FONT from GameFonts.xml,
-- CombatTextFont (inheriting SystemFont_World) from the client.
DAMAGE_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
local worldFont = M.NewObject("Font", "SystemFont_World")
local combatFont = M.NewObject("Font", "CombatTextFont")
combatFont._fontObject = worldFont
function combatFont:GetFont() return "Fonts\\ARIALN.TTF", 42, "" end

M.cvars.WorldTextScale = "1"

local ns = H.LoadAddon(here .. "../JiCombatFont")
local Fire, test, eq, truthy = H.Fire, H.test, H.eq, H.truthy

test("nothing changes before saved variables load", function()
    eq(DAMAGE_TEXT_FONT, "Fonts\\FRIZQT__.TTF")
    eq(combatFont._fontObject, worldFont)
end)

-- Saved variables from 0.4, whose incoming size and minus fix are gone.
JiCombatFontDB = { incoming = "galaxy", incomingSize = 42, incomingTightMinus = true }
Fire("ADDON_LOADED", "JiCombatFont")

test("every listed font ships with the addon", function()
    for _, font in ipairs(ns.FONTS) do
        if font.key ~= "default" then
            local f = io.open(here .. "../JiCombatFont/Media/" .. font.key .. ".ttf", "rb")
            truthy(f, font.key)
            f:close()
        end
    end
end)

test("every font in Media is listed", function()
    local listed = {}
    for _, font in ipairs(ns.FONTS) do listed[font.key .. ".ttf"] = true end
    local p = io.popen('ls "' .. here .. '../JiCombatFont/Media"')
    for name in p:lines() do
        if name:match("%.ttf$") then truthy(listed[name], name .. " not in ns.FONTS") end
    end
    p:close()
end)

test("every font has a spaced copy for every spacing, and nothing else", function()
    local expected, n = {}, 0
    for _, font in ipairs(ns.FONTS) do
        for _, v in ipairs(ns.SPACINGS) do
            if font.key ~= "default" and v ~= 0 then
                local path = ns.FontPath(font.key, "outgoing", v)
                local file = path:match("^Interface\\AddOns\\JiCombatFont\\Media\\Spaced\\(.+)$")
                truthy(file, path)
                expected[file] = true
                n = n + 1
            end
        end
    end
    local p = io.popen('ls "' .. here .. '../JiCombatFont/Media/Spaced"')
    local found = 0
    for name in p:lines() do
        truthy(expected[name], name .. " in Spaced doesn't match ns.FONTS and ns.SPACINGS")
        found = found + 1
    end
    p:close()
    eq(found, n)
end)

-- The font objects must copy Blizzard's SystemFont_World: without fixedSize,
-- Blizzard's SetTextHeight spreads the letters apart.
test("every font and spacing has a fixed-size XML font object", function()
    for _, font in ipairs(ns.FONTS) do
        for _, v in ipairs(ns.SPACINGS) do
            local name = ns.IncomingFontName(font.key, v)
            if font.key == "default" then
                eq(name, nil)
            else
                local obj = _G[name]
                truthy(type(obj) == "table", name)
                eq(obj._xml.font, ns.FontPath(font.key, "incoming", v))
                eq(obj._xml.fixedSize, "true")
                eq(obj._xml.height, "64")
                eq(obj._xml.filter, "true")
            end
        end
    end
end)

test("defaults to Galaxy for both", function()
    eq(JiCombatFontDB.outgoing, "galaxy")
    eq(JiCombatFontDB.incoming, "galaxy")
    eq(DAMAGE_TEXT_FONT, GALAXY)
    eq(combatFont._fontObject, JiCombatFont_galaxy)
end)

test("incoming never calls SetFont, which would drop fixedSize", function()
    eq(combatFont._font, nil)
end)

test("old incoming size and minus settings are dropped", function()
    eq(JiCombatFontDB.incomingSize, nil)
    eq(JiCombatFontDB.incomingTightMinus, nil)
end)

test("font paths", function()
    eq(ns.FontPath("galaxy", "outgoing", 10), MEDIA .. "Spaced\\galaxy_p10.ttf")
    eq(ns.FontPath("galaxy", "outgoing", -5), MEDIA .. "Spaced\\galaxy_m5.ttf")
    eq(ns.FontPath("galaxy", "outgoing", 0), GALAXY)
    eq(ns.FontPath("galaxy", "outgoing", 7), GALAXY)
    eq(ns.FontPath("default", "outgoing", 10), "Fonts\\FRIZQT__.TTF")
    eq(ns.FontPath("default", "outgoing"), "Fonts\\FRIZQT__.TTF")
    eq(ns.FontPath("default", "incoming"), "Fonts\\ARIALN.TTF")
    eq(ns.FontPath("NoSuchFont", "outgoing"), "Fonts\\FRIZQT__.TTF")
    eq(ns.IncomingFontName("galaxy", 10), "JiCombatFont_galaxy_p10")
    eq(ns.IncomingFontName("galaxy", 7), "JiCombatFont_galaxy")
end)

test("re-applied when Blizzard_CombatText loads and at login", function()
    combatFont._fontObject = worldFont
    Fire("ADDON_LOADED", "Blizzard_CombatText")
    eq(combatFont._fontObject, JiCombatFont_galaxy)
    combatFont._fontObject = worldFont
    Fire("PLAYER_LOGIN")
    eq(combatFont._fontObject, JiCombatFont_galaxy)
end)

test("missing CombatTextFont is harmless", function()
    local saved = CombatTextFont
    CombatTextFont = nil
    eq(ns.ApplyIncoming(), false)
    CombatTextFont = saved
end)

local function Row(picker, key)
    for _, row in ipairs(picker.rows) do
        if row.key == key then return row end
    end
end

test("options window lists every font in its own face", function()
    SlashCmdList.JICOMBATFONT("")
    truthy(JiCombatFontOptionsFrame:IsShown())
    local O = ns.Options
    eq(#O.outgoing.rows, #ns.FONTS)
    eq(#O.incoming.rows, #ns.FONTS)
    eq(Row(O.outgoing, "Bungee").text._font[1], MEDIA .. "Bungee.ttf")
    eq(Row(O.incoming, "default").text._font[1], "Fonts\\ARIALN.TTF")
    truthy(Row(O.outgoing, "galaxy").selected:IsShown())
    eq(Row(O.outgoing, "Bungee").selected:IsShown(), false)
    eq(O.relogNote:IsShown(), false)
    eq(O.incomingSize, nil)
end)

test("picking an incoming font applies it at once", function()
    local O = ns.Options
    Row(O.incoming, "Roboto"):Fire("OnClick")
    eq(JiCombatFontDB.incoming, "Roboto")
    eq(combatFont._fontObject, JiCombatFont_Roboto)
    truthy(Row(O.incoming, "Roboto").selected:IsShown())
    eq(Row(O.incoming, "galaxy").selected:IsShown(), false)
    eq(JiCombatFontDB.outgoing, "galaxy")
    eq(O.relogNote:IsShown(), false)
end)

test("Blizzard default restores the original font object", function()
    local O = ns.Options
    Row(O.incoming, "default"):Fire("OnClick")
    eq(combatFont._fontObject, worldFont)
    Row(O.incoming, "Roboto"):Fire("OnClick")
    eq(combatFont._fontObject, JiCombatFont_Roboto)
end)

test("picking an outgoing font asks for a relog", function()
    local O = ns.Options
    Row(O.outgoing, "Bungee"):Fire("OnClick")
    eq(JiCombatFontDB.outgoing, "Bungee")
    eq(DAMAGE_TEXT_FONT, MEDIA .. "Bungee.ttf")
    truthy(O.relogNote:IsShown())
    Row(O.outgoing, "galaxy"):Fire("OnClick")
    eq(O.relogNote:IsShown(), false)
end)

local function SetSlider(holder, v) holder.slider:SetValue(v) end

test("incoming spacing applies at once", function()
    local O = ns.Options
    SetSlider(O.incomingSpacing, 5) -- index 5 = +10%
    eq(JiCombatFontDB.incomingSpacing, 10)
    eq(combatFont._fontObject, JiCombatFont_Roboto_p10)
    eq(O.incoming.sample._font[1], MEDIA .. "Spaced\\Roboto_p10.ttf")
    eq(O.relogNote:IsShown(), false)
end)

test("outgoing spacing needs a relog", function()
    local O = ns.Options
    SetSlider(O.outgoingSpacing, 1) -- -10%
    eq(JiCombatFontDB.outgoingSpacing, -10)
    eq(DAMAGE_TEXT_FONT, MEDIA .. "Spaced\\galaxy_m10.ttf")
    truthy(O.relogNote:IsShown())
    SetSlider(O.outgoingSpacing, 3) -- normal
    eq(JiCombatFontDB.outgoingSpacing, 0)
    eq(O.relogNote:IsShown(), false)
end)

test("outgoing size sets the world text scale CVar", function()
    local O = ns.Options
    truthy(O.outgoingSize.slider)
    eq(O.outgoingSize.slider:GetValue(), 1)
    SetSlider(O.outgoingSize, 1.5)
    eq(GetCVar("WorldTextScale"), "1.5")
    eq(JiCombatFontDB.outgoingSize, nil)
end)

test("slash command closes the window again", function()
    SlashCmdList.JICOMBATFONT("")
    eq(JiCombatFontOptionsFrame:IsShown(), false)
end)

H.Finish()
