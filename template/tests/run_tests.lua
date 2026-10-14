-- Run with: luajit tests/run_tests.lua (from __ADDON__/) or luajit __ADDON__/tests/run_tests.lua
local here = debug.getinfo(1, "S").source:match("^@(.-)[^/]*$")
package.path = here .. "../../tools/?.lua;" .. package.path
local H = require("harness")

local ns, M = H.LoadAddon(here .. "../__ADDON__")
local Fire, test, eq, truthy = H.Fire, H.test, H.eq, H.truthy

Fire("ADDON_LOADED", "__ADDON__")

test("saved variables initialised", function()
    truthy(__ADDON__DB)
    eq(ns.db.enabled, true)
end)

test("slash command toggles the options window", function()
    SlashCmdList.__ADDON_UPPER__("")
    truthy(__ADDON__OptionsFrame:IsShown())
    SlashCmdList.__ADDON_UPPER__("")
    eq(__ADDON__OptionsFrame:IsShown(), false)
end)

H.Finish()
