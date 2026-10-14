-- Run with: luajit tests/run_tests.lua (from JiCastBar/) or luajit JiCastBar/tests/run_tests.lua
local here = debug.getinfo(1, "S").source:match("^@(.-)[^/]*$")
package.path = here .. "../../tools/?.lua;" .. package.path
local H = require("harness")
local M = H.mock

-- Blizzard's cast bars exist before addons load.
local blizzPlayer = M.NewObject("StatusBar", "PlayerCastingBarFrame")
local blizzTarget = M.NewObject("StatusBar", "TargetFrameSpellBar")
blizzPlayer:RegisterEvent("UNIT_SPELLCAST_START")
blizzTarget:RegisterEvent("PLAYER_TARGET_CHANGED")

local ns = H.LoadAddon(here .. "../JiCastBar")
local Fire, Tick, test, eq, truthy = H.Fire, H.Tick, H.test, H.eq, H.truthy

Fire("ADDON_LOADED", "JiCastBar")
ns.db.debug = true -- model and other swallowed errors get printed; NoErrors() checks

local player, target = ns.bars.player, ns.bars.target

local function NoErrors()
    for _, line in ipairs(M.printed) do
        if line:find("model") or line:find("rror") then error("swallowed error: " .. line, 2) end
    end
end

local function Close(a, b, msg)
    if math.abs(a - b) > 1e-6 then error((msg or "") .. " expected " .. b .. " got " .. a, 2) end
end

local function StartCast(unit, name, seconds, field)
    local now = M.now * 1000
    M.units[unit] = M.units[unit] or { class = "MAGE", level = 60, health = 100, maxHealth = 100, reaction = 2 }
    M.units[unit][field or "cast"] = { name = name, texture = 135812, startMs = now, endMs = now + seconds * 1000 }
    Fire(field == "channel" and "UNIT_SPELLCAST_CHANNEL_START" or "UNIT_SPELLCAST_START", unit, "guid", 1)
end

local function EndCast(unit, event)
    M.units[unit].cast, M.units[unit].channel = nil, nil
    Fire(event or "UNIT_SPELLCAST_STOP", unit, "guid", 1)
end

-------------------------------------------------------------------------------

test("saved variables initialised with both bars", function()
    truthy(JiCastBarDB)
    eq(ns.db.bars.player.style, "sunset")
    eq(ns.db.bars.target.enabled, true)
    truthy(JiCastBarPlayer)
    truthy(JiCastBarTarget)
    eq(player.root:IsShown(), false)
    eq(target.root:IsShown(), false)
end)

test("Blizzard's cast bars lose their events", function()
    eq(next(blizzPlayer._events), nil)
    eq(next(blizzTarget._events), nil)
    eq(ns.blizzardHidden.player, true)
    eq(ns.BlizzardRestorePending("player"), false)
end)

test("styles: ten, keyed, each with a fill, background and model", function()
    eq(#ns.STYLES, 10)
    for i, style in ipairs(ns.STYLES) do
        eq(ns.STYLE_BY_KEY[style.key], style)
        eq(style.index, i)
        truthy(ns.SHADE[style.texture], style.key .. " texture")
        eq(#style.color, 3)
        eq(#style.background, 4)
        truthy(#style.models >= 1, style.key .. " models")
        for _, m in ipairs(style.models) do
            truthy(m.transform or m.position, style.key .. " model placement")
        end
    end
end)

test("player cast: name, icon, bar range and time text", function()
    StartCast("player", "Greater Heal", 2.5)
    truthy(player.root:IsShown())
    eq(player.nameText:GetText(), "Greater Heal")
    eq(player.icon._texture, 135812)
    eq(player.info.mode, "relative")
    local min, max = player.valueBar:GetMinMaxValues()
    eq(min, 0)
    eq(max, 2.5)
    eq(player.timeText:GetText(), "2.5 || 2.5")
    eq(player.valueBar._reverseFill, false)
    eq(player.edge, player.valueBar:GetStatusBarTexture())
    truthy(player.spark:IsShown(), "sunset has a spark")
    Tick(1)
    eq(player.timeText:GetText(), "1.5 || 2.5")
    Close(player.valueBar:GetValue(), 1)
    eq(target.root:IsShown(), false, "target bar ignores player events")
end)

test("a failed spell queued behind the cast leaves the bar alone", function()
    Fire("UNIT_SPELLCAST_FAILED", "player", "other-guid", 2)
    truthy(player.root:IsShown())
    eq(player.nameText:GetText(), "Greater Heal")
end)

test("events for other units don't reach the player bar", function()
    M.units.player.cast = nil
    Fire("UNIT_SPELLCAST_STOP", "target", "guid", 1)
    truthy(player.root:IsShown(), "target stop ignored")
    Fire("UNIT_SPELLCAST_STOP", "player", "guid", 1)
    eq(player.root:IsShown(), false)
end)

test("time text: whole seconds from 9 seconds remaining", function()
    StartCast("player", "Hearthstone", 10)
    eq(player.timeText:GetText(), "10 || 10.0")
    Tick(1.2)
    eq(player.timeText:GetText(), "8.8 || 10.0")
    EndCast("player")
end)

test("names are cut at 27 characters without an ellipsis", function()
    StartCast("player", "Summon Infernal Doomguard of Extreme Length", 2)
    eq(player.nameText:GetText(), ("Summon Infernal Doomguard of Extreme Length"):sub(1, 27))
    EndCast("player")
end)

test("channels drain: reverse fill, fill ends at the texture's left edge", function()
    StartCast("player", "Arcane Missiles", 5, "channel")
    truthy(player.root:IsShown())
    eq(player.valueBar._reverseFill, true)
    local p = player.fill._points[2]
    eq(p[1], "BOTTOMRIGHT")
    eq(p[2], player.edge)
    eq(p[3], "BOTTOMLEFT")
    eq(player.timeText:GetText(), "5.0 || 5.0")
    EndCast("player", "UNIT_SPELLCAST_CHANNEL_STOP")
    eq(player.root:IsShown(), false)
    StartCast("player", "Frostbolt", 2)
    eq(player.valueBar._reverseFill, false)
    eq(player.fill._points[2][3], "BOTTOMRIGHT")
    EndCast("player")
end)

test("a missed stop event hides a plain cast shortly after its end", function()
    StartCast("player", "Frostbolt", 1)
    M.units.player.cast = nil -- cast ended, no event
    Tick(1.4)
    truthy(player.root:IsShown(), "still within the grace period")
    Tick(0.3)
    eq(player.root:IsShown(), false)
end)

test("latency mark: player casts only, sized by world latency", function()
    ns.db.bars.player.latency = true
    ns.Apply()
    StartCast("player", "Greater Heal", 2.5)
    truthy(player.latency:IsShown())
    Close(player.latency:GetWidth(), M.latency[2] / 2500 * (280 - 28))
    EndCast("player")
    StartCast("player", "Mind Flay", 3, "channel")
    eq(player.latency:IsShown(), false, "no mark on channels")
    EndCast("player", "UNIT_SPELLCAST_CHANNEL_STOP")
    ns.db.bars.player.latency = false
    ns.Apply()
end)

test("target bar follows target changes", function()
    M.units.target = { class = "MAGE", level = 60, health = 100, maxHealth = 100, reaction = 2 }
    local now = M.now * 1000
    M.units.target.cast = { name = "Fireball", texture = 135812, startMs = now, endMs = now + 3000 }
    Fire("PLAYER_TARGET_CHANGED")
    truthy(target.root:IsShown())
    eq(target.nameText:GetText(), "Fireball")
    eq(player.root:IsShown(), false)
    M.units.target = nil
    Fire("PLAYER_TARGET_CHANGED")
    eq(target.root:IsShown(), false)
end)

test("secret target cast: setters take the secrets, text comes from the duration", function()
    M.secrets = true
    StartCast("target", "Shadow Bolt", 3)
    truthy(target.root:IsShown())
    eq(target.nameText:GetText(), "Shadow Bolt")
    truthy(target.nameText._secret, "name passed through as a secret")
    eq(target.info.mode, "timer")
    eq(target.timerBar._timer[1], target.info.duration)
    eq(target.edge, target.timerBar:GetStatusBarTexture())
    eq(target.fill._points[2][2], target.edge)
    eq(target.timeText:GetText(), "3.0 || 3.0")
    Tick(1)
    eq(target.timeText:GetText(), "2.0 || 3.0")
    eq(target.latency:IsShown(), false)
    EndCast("target")
    eq(target.root:IsShown(), false)
    NoErrors()
end)

test("secret target channel and long secret names pass untouched", function()
    StartCast("target", "Drain Life of a Very Long Spell Name", 5, "channel")
    eq(target.nameText:GetText(), "Drain Life of a Very Long Spell Name")
    eq(target.timerBar._reverseFill, true)
    eq(target.timeText:GetText(), "5.0 || 5.0")
    EndCast("target", "UNIT_SPELLCAST_CHANNEL_STOP")
    M.secrets = false
    M.units.target = nil
    NoErrors()
end)

test("secret cast falls back to absolute times when the timer is refused", function()
    M.secrets, M.refuseTimers = true, true
    StartCast("target", "Shadow Bolt", 3)
    eq(target.info.mode, "absolute")
    truthy(target.valueBar._secret, "range passed through as secrets")
    local min, max = target.valueBar:GetMinMaxValues()
    eq(min, M.now * 1000)
    eq(max, M.now * 1000 + 3000)
    eq(target.edge, target.valueBar:GetStatusBarTexture())
    Tick(1)
    Close(target.valueBar:GetValue(), M.now * 1000)
    EndCast("target")
    M.secrets, M.refuseTimers = false, false
    M.units.target = nil
    NoErrors()
end)

test("player casts stay plain in secret mode", function()
    M.secrets = true
    StartCast("player", "Greater Heal", 2.5)
    eq(player.nameText._secret, nil)
    eq(player.timeText:GetText(), "2.5 || 2.5")
    EndCast("player")
    M.secrets = false
end)

test("every style applies cleanly and sets up its models", function()
    StartCast("player", "Greater Heal", 2.5)
    for _, style in ipairs(ns.STYLES) do
        ns.db.bars.player.style = style.key
        ns.Apply()
        eq(player.style, style)
        local used = 0
        for _, slot in ipairs(player.models) do
            if slot.cfg then
                used = used + 1
                truthy(slot.clip:IsShown())
                local clipTo = slot.clip._points[1][2]
                eq(clipTo, slot.cfg.attach and player.fill or player.bar, style.key .. " clip")
            else
                eq(slot.clip:IsShown(), false, style.key .. " unused slot hidden")
            end
        end
        eq(used, #style.models)
        eq(player.spark:IsShown(), style.spark ~= nil, style.key .. " spark")
        local g = player.fillTexture._gradient
        local shade = ns.SHADE[style.texture]
        Close(g[2].r, style.color[1] * shade, style.key .. " colour")
        Close(g[3].g, (style.color2 or style.color)[2] * shade, style.key .. " colour 2")
    end
    EndCast("player")
    ns.db.bars.player.style = "sunset"
    ns.Apply()
    NoErrors()
end)

test("spark atlases fall back to the cast bar spark when missing", function()
    ns.db.bars.player.style = "nebula"
    M.missingAtlases["bonusobjectives-bar-spark"] = true
    ns.Apply()
    eq(player.spark._texture, 130877)
    M.missingAtlases["bonusobjectives-bar-spark"] = nil
    ns.Apply()
    eq(player.spark._atlas, "bonusobjectives-bar-spark")
    ns.db.bars.player.style = "sunset"
    ns.Apply()
end)

test("spell effects can be turned off", function()
    ns.db.bars.player.effects = false
    ns.Apply()
    eq(player.models[1].clip:IsShown(), false)
    ns.db.bars.player.effects = true
    ns.Apply()
    truthy(player.models[1].clip:IsShown())
end)

test("models are set up when the bar appears", function()
    local model = player.models[1].model
    model.SetModel = function(self, file) self._modelFile = file end
    StartCast("player", "Greater Heal", 2.5)
    eq(model._modelFile, 166594)
    EndCast("player")
    NoErrors()
end)

test("a model hidden at zero width is set up again when it grows", function()
    local slot = player.models[1]
    local model = slot.model
    StartCast("player", "Greater Heal", 2.5)
    slot.clip:Fire("OnSizeChanged", 0, 24)
    eq(model:IsShown(), false)
    model._modelFile = nil
    slot.clip:Fire("OnSizeChanged", 30, 24)
    truthy(model:IsShown())
    eq(model._modelFile, 166594)
    EndCast("player")
    NoErrors()
end)

test("options window shows looping sample casts while open", function()
    SlashCmdList.JICASTBAR("")
    truthy(JiCastBarOptionsFrame:IsShown())
    truthy(player.root:IsShown())
    truthy(target.root:IsShown())
    eq(player.nameText:GetText(), "Greater Heal")
    eq(target.nameText:GetText(), "Shadow Bolt")
    Tick(2.6)
    truthy(player.root:IsShown(), "sample loops")
    eq(player.timeText:GetText():sub(-3), "2.5")
    SlashCmdList.JICASTBAR("")
    eq(JiCastBarOptionsFrame:IsShown(), false)
    eq(player.root:IsShown(), false)
    eq(target.root:IsShown(), false)
end)

test("a real cast replaces the sample", function()
    SlashCmdList.JICASTBAR("")
    StartCast("player", "Frostbolt", 2)
    eq(player.nameText:GetText(), "Frostbolt")
    EndCast("player")
    eq(player.nameText:GetText(), "Greater Heal", "back to the sample")
    SlashCmdList.JICASTBAR("")
end)

test("unlocking shows draggable bars; dragging saves the position", function()
    SlashCmdList.JICASTBAR("unlock")
    eq(ns.db.locked, false)
    truthy(player.root:IsShown())
    truthy(player.moverLabel:IsShown())
    player.root:ClearAllPoints()
    player.root:SetPoint("BOTTOM", UIParent, "BOTTOM", 10, 200)
    player.root:Fire("OnDragStop")
    eq(ns.db.bars.player.point[1], "BOTTOM")
    eq(ns.db.bars.player.point[4], 200)
    SlashCmdList.JICASTBAR("lock")
    eq(ns.db.locked, true)
    eq(player.root:IsShown(), false)
    eq(player.moverLabel:IsShown(), false)
    SlashCmdList.JICASTBAR("reset")
    eq(ns.db.bars.player.point[4], -312)
    eq(player.root._points[1][5], -312)
end)

test("a disabled bar ignores casts and stays hidden", function()
    ns.db.bars.target.enabled = false
    ns.Apply()
    eq(next(target.root._events), nil)
    StartCast("target", "Fireball", 3)
    eq(target.root:IsShown(), false)
    M.units.target = nil
    ns.db.bars.target.enabled = true
    ns.Apply()
    truthy(target.root._events.UNIT_SPELLCAST_START)
end)

test("turning Blizzard hiding off asks for a reload", function()
    ns.db.bars.player.hideBlizzard = false
    eq(ns.BlizzardRestorePending("player"), true)
    SlashCmdList.JICASTBAR("")
    truthy(ns.Options.reloadNote:IsShown())
    ns.db.bars.player.hideBlizzard = true
    ns.Options:Refresh()
    eq(ns.Options.reloadNote:IsShown(), false)
    SlashCmdList.JICASTBAR("")
end)

test("width and height resize the bar; the icon stays square", function()
    eq(player.root:GetWidth(), 280)
    eq(player.root:GetHeight(), 28)
    eq(player.icon:GetWidth(), 28)
    ns.db.bars.player.width = 400
    ns.db.bars.player.height = 40
    ns.Apply()
    eq(player.root:GetWidth(), 400)
    eq(player.root:GetHeight(), 40)
    eq(player.icon:GetWidth(), 40)
    eq(target.root:GetWidth(), 280, "target keeps its own size")
end)

test("spark height and latency mark follow the bar size", function()
    eq(player.spark:GetHeight(), 50 * 40 / 28, "sunset spark scaled to 40px")
    eq(player.spark:GetWidth(), 5)
    ns.db.bars.player.latency = true
    ns.Apply()
    StartCast("player", "Greater Heal", 2.5)
    Close(player.latency:GetWidth(), M.latency[2] / 2500 * (400 - 40))
    EndCast("player")
    ns.db.bars.player.latency = false
    ns.db.bars.player.width, ns.db.bars.player.height = 280, 28
    ns.Apply()
    eq(player.spark:GetHeight(), 50)
end)

test("size sliders in the options change the setting", function()
    SlashCmdList.JICASTBAR("")
    local found = {}
    for _, w in ipairs(ns.Options.set.widgets) do
        if w.slider then
            local minV, maxV = w.slider:GetMinMaxValues()
            found[#found + 1] = { w = w, min = minV, max = maxV }
        end
    end
    -- Per bar: width, height, scale.
    eq(#found, 6)
    eq(found[1].min, 120)
    eq(found[1].max, 600)
    eq(found[2].min, 12)
    found[1].w.slider:SetValue(350)
    eq(ns.db.bars.player.width, 350)
    eq(player.root:GetWidth(), 350)
    found[5].w.slider:SetValue(20)
    eq(ns.db.bars.target.height, 20)
    eq(target.icon:GetWidth(), 20)
    SlashCmdList.JICASTBAR("")
    ns.db.bars.player.width, ns.db.bars.target.height = 280, 28
    ns.Apply()
end)

test("scale applies to the bar", function()
    ns.db.bars.target.scale = 1.5
    ns.Apply()
    eq(target.root:GetScale(), 1.5)
    ns.db.bars.target.scale = 1
    ns.Apply()
    NoErrors()
end)

H.Finish()
