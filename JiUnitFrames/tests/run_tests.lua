-- Run with: luajit tests/run_tests.lua (from JiUnitFrames/) or luajit JiUnitFrames/tests/run_tests.lua
local here = debug.getinfo(1, "S").source:match("^@(.-)[^/]*$")
package.path = here .. "../../tools/?.lua;" .. package.path
local H = require("harness")

local ns, M = H.LoadAddon(here .. "../JiUnitFrames")
local Fire, test, eq, truthy, plain = H.Fire, H.test, H.eq, H.truthy, H.plain

local function F(key) return _G["JiUnitFrames_" .. key] end

-- Errors inside event handlers and U.Try are swallowed and printed in debug
-- mode; any such print fails the test that caused it.
local function NoErrors()
    for _, line in ipairs(M.printed) do
        if line:find("error", 1, true) or line:find("|cffff6060", 1, true) then
            error("swallowed error: " .. line, 2)
        end
    end
end

local function Reset()
    M.secrets = false
    M.inCombat = false
    M.printed = {}
    M.units = {
        player = { name = "Jiwaah", class = "DRUID", level = 29, health = 888, maxHealth = 888,
            power = 2374, maxPower = 2374, powerType = 0, powerToken = "MANA", player = true, reaction = 5 },
    }
    M.group = { raid = false }
    M.bindings = {}
end

local function Party(i, data)
    local u = { class = "HUNTER", level = 30, health = 777, maxHealth = 1182, power = 1016, maxPower = 1380,
        powerType = 0, powerToken = "MANA", player = true, reaction = 5 }
    for k, v in pairs(data or {}) do u[k] = v end
    M.units["party" .. i] = u
    return u
end

-------------------------------------------------------------------------------

Reset()
Fire("ADDON_LOADED", "JiUnitFrames")
ns.db.debug = true

test("saved variables and slash command", function()
    truthy(JiUnitFramesDB)
    eq(ns.db.locked, true)
    eq(ns.db.scale.party, 1)
    eq(SLASH_JIUNITFRAMES1, "/jiuf")
    truthy(M.settingsCategory)
end)

test("frames are secure unit buttons with click actions", function()
    for _, key in ipairs({ "player", "target", "targettarget", "pet", "party1", "party4", "partypet2" }) do
        local f = F(key)
        truthy(f, key)
        truthy(f._template:find("SecureUnitButtonTemplate", 1, true), key)
        eq(f:GetAttribute("*type1"), "target")
        eq(f:GetAttribute("*type2"), "togglemenu")
    end
    eq(F("party3"):GetAttribute("unit"), "party3")
    eq(F("partypet3"):GetAttribute("unit"), "partypet3")
    -- 100% on the scale sliders is 15% larger than Nurfed's sizes.
    eq(F("player"):GetScale(), 1.15)
    eq(F("party2"):GetScale(), 1.15)
end)

test("visibility is driven by the client", function()
    truthy(F("target")._unitWatch, "target unit watch")
    truthy(F("targettarget")._unitWatch, "tot unit watch")
    truthy(F("pet")._unitWatch, "pet unit watch")
    eq(F("party2")._stateDrivers.visibility, "[@party2,exists] show; hide")
    eq(F("player")._unitWatch, nil)
end)

test("Blizzard frames are disabled and parked", function()
    for _, name in ipairs({ "PlayerFrame", "TargetFrame", "PetFrame", "PartyFrame" }) do
        eq(_G[name]:IsShown(), false, name)
        truthy(_G[name].jiDisabled, name)
    end
    truthy(PartyFrame.MemberFrame1.jiDisabled)
    eq(PartyFrame.MemberFrame1:GetParent(), PartyFrame, "member frames keep their parent")
end)

test("player frame with plain values", function()
    Reset()
    Fire("PLAYER_ENTERING_WORLD")
    local f = F("player")
    eq(f.health.text:GetText(), "888 (888)")
    eq(f.health.missing:GetText(), "")
    eq(f.power.text:GetText(), "2374 (2374)")
    eq(plain(f.name:GetText()), "Jiwaah")
    truthy(f.name:GetText():find("|cffff7d0a", 1, true), "druid orange")
    eq(f.level:GetText(), "29")
    eq(f.health._color[2], 1, "green at full health")
    eq(f.power._color[3], 1, "mana is cyan")
    NoErrors()
end)

test("secret health and power still render", function()
    Reset()
    M.secrets = true
    M.units.player.health = 777
    M.units.player.maxHealth = 1182
    Fire("UNIT_HEALTH", "player")
    Fire("UNIT_POWER_FREQUENT", "player", "MANA")
    local f = F("player")
    truthy(f.health.text._secret, "secret went through the widget")
    eq(f.health.text:GetText(), "777 (1182)")
    eq(f.health.missing:GetText(), "-405")
    eq(f.health.missing:GetAlpha(), 1)
    eq(f.health._value, 777)
    eq(f.health._max, 1182)
    eq(f.power.text:GetText(), "2374 (2374)")
    NoErrors()
end)

test("secret full health hides the missing text", function()
    Reset()
    M.secrets = true
    Fire("UNIT_HEALTH", "player")
    local f = F("player")
    eq(f.health.missing:GetText(), "-0")
    eq(f.health.missing:GetAlpha(), 0)
    NoErrors()
end)

test("health colour follows Nurfed's gradient, also when secret", function()
    Reset()
    M.units.player.health = 300 -- 34%
    Fire("UNIT_HEALTH", "player")
    local r1, g1 = F("player").health._color[1], F("player").health._color[2]
    eq(r1, 1)
    truthy(g1 > 0.4 and g1 < 0.7, "orange")
    M.secrets = true
    Fire("UNIT_HEALTH", "player")
    local r2, g2 = F("player").health._color[1], F("player").health._color[2]
    eq(r2, 1)
    truthy(math.abs(g2 - g1) < 0.05, "curve matches gradient: " .. g1 .. " vs " .. g2)
    M.units.player.health = 100 -- 11%
    Fire("UNIT_HEALTH", "player")
    truthy(F("player").health._color[1] < 0.9, "dark red")
    NoErrors()
end)

test("target frame for an elite NPC", function()
    Reset()
    M.units.target = { name = "Dragonmaw Firesworn", level = 30, health = 50, maxHealth = 2000, power = 0,
        maxPower = 0, reaction = 2, classification = "elite", creatureType = "Humanoid" }
    M.RunUnitWatch()
    Fire("PLAYER_TARGET_CHANGED")
    local f = F("target")
    eq(f:IsShown(), true)
    eq(plain(f.name:GetText()), "Dragonmaw Firesworn")
    truthy(f.name:GetText():find("|cffcc4d38", 1, true), "hostile reaction colour")
    eq(plain(f.level:GetText()), "30+ Elite Humanoid")
    eq(f.healthPercent:GetText(), "2%")
    eq(f.power:IsShown(), false, "no power bar without power")
    NoErrors()
end)

test("target frame for a player with a guild, secret name", function()
    Reset()
    M.secrets = true
    M.units.target = { name = "Buchyi", class = "HUNTER", level = 30, health = 777, maxHealth = 1182,
        power = 1016, maxPower = 1380, player = true, reaction = 5, guild = "Nurfed" }
    Fire("PLAYER_TARGET_CHANGED")
    local f = F("target")
    eq(plain(f.name:GetText()), "Buchyi Nurfed")
    eq(plain(f.level:GetText()), "30 Hunter")
    eq(f.healthPercent:GetText(), "65%")
    NoErrors()
end)

test("target of target polls its unit", function()
    Reset()
    M.units.target = { name = "Buchyi", class = "HUNTER", level = 30, health = 10, maxHealth = 10, player = true }
    M.units.targettarget = { name = "Dragonmaw Firesworn", level = 30, health = 40, maxHealth = 2000, reaction = 2 }
    M.RunUnitWatch()
    Fire("PLAYER_TARGET_CHANGED")
    local tot = F("targettarget")
    eq(plain(tot.name:GetText()), "Dragonmaw Firesworn")
    eq(tot.healthPercent:GetText(), "2%")
    M.units.targettarget.health = 1000
    H.Tick(0.3)
    eq(tot.healthPercent:GetText(), "50%")
    eq(tot.healthPercent._color[1], 1, "mini frame percent stays white")
    NoErrors()
end)

test("party frame: key binding, class icon, leader, highlight", function()
    Reset()
    Party(1, { name = "Buchyi", leader = true })
    Party(2, { name = "Synthetica", class = "PRIEST" })
    M.bindings.TARGETPARTYMEMBER1 = "F2"
    M.bindings.TARGETPARTYMEMBER2 = "SHIFT-F3"
    M.units.target = M.units.party2
    M.RunUnitWatch()
    for i = 1, 4 do F("party" .. i)._shown = M.units["party" .. i] ~= nil end
    Fire("GROUP_ROSTER_UPDATE")
    local p1, p2 = F("party1"), F("party2")
    eq(plain(p1.name:GetText()), "[F2] Buchyi")
    eq(plain(p2.name:GetText()), "[S-F3] Synthetica")
    eq(p1.healthPercent:GetText(), "65%")
    eq(p1.health.missing:GetText(), "-405")
    eq(p1.classIcon:IsShown(), true)
    eq(p1.leader:IsShown(), true)
    eq(p2.leader:IsShown(), false)
    eq(p2.highlight:IsShown(), true, "targeted party member glows")
    eq(p1.highlight:IsShown(), false)
    eq(F("party3"):IsShown(), false)
    NoErrors()
end)

test("dead and offline party members", function()
    Reset()
    Party(1, { name = "Castra", dead = true, health = 0 })
    Party(2, { name = "Edarlin", connected = false })
    for i = 1, 2 do F("party" .. i)._shown = true end
    Fire("GROUP_ROSTER_UPDATE")
    eq(F("party1").health.text:GetText(), "Dead")
    eq(F("party1").health.missing:GetText(), "")
    eq(F("party2").health.text:GetText(), "Offline")
    NoErrors()
end)

test("auras never read aura data directly (Forever errors when secret)", function()
    Reset()
    M.secrets = true
    M.units.target = { name = "Boar", level = 10, health = 5, maxHealth = 10, reaction = 2,
        debuffs = { { name = "Rend", icon = 132155 } } }
    Fire("PLAYER_TARGET_CHANGED")
    Fire("UNIT_AURA", "target")
    NoErrors()
end)

test("auras: containers show buffs and debuffs, also when secret", function()
    Reset()
    M.secrets = true
    local buffs = {}
    for i = 1, 20 do buffs[i] = { name = "Buff" .. i, icon = 1000 + i } end
    buffs[1].applications = 3
    M.units.target = { name = "Boss", level = -1, health = 5, maxHealth = 10, reaction = 2,
        classification = "worldboss", buffs = buffs,
        debuffs = { { name = "Moonfire", icon = 136096, dispelName = "Magic" } } }
    Fire("PLAYER_TARGET_CHANGED")
    local f = F("target")
    local buffRow, debuffRow = f.auraRows[1], f.auraRows[2]
    eq(buffRow:GetUnit(), "target")
    local shown = M.ShownAuras(buffRow)
    eq(#shown, 20)
    eq(shown[1]._countText:GetText(), "3")
    eq(shown[2]._countText:GetText(), "")
    eq(shown[5]._iconTex._texture, 1005)
    eq(shown[1]:GetWidth(), 17)
    truthy(shown[1]._cooldown, "duration spiral attached")
    eq(buffRow._lineSize, 16 * (17 + 2), "16 per row")
    local edge = shown[1]._countText:GetParent()
    eq(edge._backdrop, ns.Elements.BACKDROP_AURA, "dark border on target buffs")
    eq(edge:GetParent(), shown[1])
    truthy(M.ShownAuras(debuffRow)[1]._countText:GetParent()._backdrop, "and on target debuffs")
    eq(buffRow._anchorPoint, "TOPLEFT")
    eq(debuffRow._anchorPoint, "BOTTOMLEFT")
    eq(debuffRow._growth[2], AnchorUtil.FlowDirection.Up, "debuffs stack upwards above the target")
    local debuffs = M.ShownAuras(debuffRow)
    eq(#debuffs, 1)
    eq(debuffs[1]._dispel[1]._color[3], 1, "magic border is blue")
    eq(debuffs[1]._shownAnim, nil, "only dispellable debuffs flash")
    eq(plain(f.level:GetText()), "Boss")
    NoErrors()
end)

test("auras: dispellable debuffs come first and flash", function()
    Reset()
    Party(1, { name = "Buchyi", debuffs = {
        { name = "Rend", icon = 132155 },
        { name = "Curse of Agony", icon = 136139, dispelName = "Curse", dispellable = true },
    } })
    F("party1")._shown = true
    Fire("GROUP_ROSTER_UPDATE")
    local row = F("party1").auraRows[2]
    local shown = M.ShownAuras(row)
    eq(#shown, 2)
    eq(shown[1]._aura.name, "Curse of Agony")
    eq(shown[1]._shownAnim:IsPlaying(), true, "dispellable debuff flashes")
    eq(shown[2]._aura.name, "Rend")
    eq(row._lineSize, 4 * 17, "four debuffs beside the party frame")
    ns.db.auras.dispellableOnly = true
    ns:ApplySettings()
    shown = M.ShownAuras(row)
    eq(#shown, 1)
    eq(shown[1]._aura.name, "Curse of Agony")
    ns.db.auras.dispellableOnly = false
    ns:ApplySettings()
    NoErrors()
end)

test("auras: castable-only filter, with the target exempt", function()
    Reset()
    Party(1, { name = "Buchyi", buffs = { { name = "Mark of the Wild", castable = true }, { name = "Aspect" } } })
    M.units.target = M.units.party1
    F("party1")._shown = true
    ns.db.auras.castableOnly = true
    ns:ApplySettings()
    eq(#M.ShownAuras(F("party1").auraRows[1]), 1)
    eq(#M.ShownAuras(F("target").auraRows[1]), 2, "target shows all")
    ns.db.auras.castableOnly = false
    ns:ApplySettings()
    eq(#M.ShownAuras(F("party1").auraRows[1]), 2)
    NoErrors()
end)

test("PvP badge fits inside the frame when the modern atlas is used", function()
    Reset()
    M.units.player.pvp = true
    local savedTexture = C_Texture
    C_Texture = { GetAtlasInfo = function(atlas) return atlas:find("SmallCircle", 1, true) and {} or nil end }
    Fire("UNIT_FACTION", "player")
    local pvp = F("player").pvp
    eq(pvp:IsShown(), true)
    eq(pvp._atlas, "UI-HUD-UnitFrame-SmallCircle-Alliance")
    eq(pvp:GetWidth(), 16)
    local point, x = pvp:GetPoint(1)
    eq(point, "TOPRIGHT")
    truthy(x < 0, "inside the right edge")
    C_Texture = nil
    Fire("UNIT_FACTION", "player")
    eq(pvp:GetWidth(), 28, "classic padded texture keeps Nurfed's size")
    C_Texture = savedTexture
    NoErrors()
end)

test("combo points on the target", function()
    Reset()
    M.units.target = { name = "Boar", level = 10, health = 5, maxHealth = 10, reaction = 2 }
    M.comboPoints = 3
    Fire("PLAYER_TARGET_CHANGED")
    local combo = F("target").combo
    eq(combo:GetText(), "3")
    eq(combo._color[3], 0, "yellow")
    M.comboPoints = 5
    Fire("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
    eq(combo._color[2], 0, "red at five")
    M.comboPoints = 0
    Fire("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
    eq(combo:IsShown(), false)
end)

test("unlocking shows every frame with sample data", function()
    Reset()
    SlashCmdList.JIUNITFRAMES("unlock")
    eq(ns.db.locked, false)
    local p3 = F("party3")
    eq(p3:IsShown(), true)
    eq(p3._unitWatch, nil)
    eq(p3._stateDrivers.visibility, nil)
    eq(plain(p3.name:GetText()), "Jiwaah")
    eq(p3.auraRows[1]:GetUnit(), "player", "auras show the sample unit too")
    SlashCmdList.JIUNITFRAMES("lock")
    eq(ns.db.locked, true)
    eq(p3:IsShown(), false)
    eq(p3._stateDrivers.visibility, "[@party3,exists] show; hide")
    NoErrors()
end)

test("layout changes wait for the end of combat", function()
    Reset()
    M.inCombat = true
    SlashCmdList.JIUNITFRAMES("unlock")
    eq(F("party3"):IsShown(), false, "not while in combat")
    M.inCombat = false
    Fire("PLAYER_REGEN_ENABLED")
    eq(F("party3"):IsShown(), true)
    SlashCmdList.JIUNITFRAMES("lock")
end)

test("dragging saves the position", function()
    Reset()
    ns.db.locked = false
    local p2 = F("party2")
    p2:Fire("OnDragStart")
    local party1 = F("party1")
    party1:ClearAllPoints()
    party1:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100.4, -200.6)
    p2:Fire("OnDragStop")
    local pos = ns.db.positions.party
    eq(pos[1], "TOPLEFT")
    eq(pos[3], 100)
    eq(pos[4], -201)
    ns.db.locked = true
    SlashCmdList.JIUNITFRAMES("reset")
    eq(ns.db.positions.party[3], 34)
end)

test("target of target is a separate, movable frame", function()
    Reset()
    local tot = F("targettarget")
    eq(tot:GetParent(), UIParent)
    eq(tot.mover, tot)
    local point, rel, relPoint, x, y = tot:GetPoint(1)
    eq(point, "CENTER"); eq(rel, UIParent); eq(x, 43); eq(y, -160)
    ns.db.locked = false
    tot:Fire("OnDragStart")
    tot:ClearAllPoints()
    tot:SetPoint("CENTER", UIParent, "CENTER", 10, 20)
    tot:Fire("OnDragStop")
    eq(ns.db.positions.targettarget[3], 10)
    eq(ns.db.positions.target[3], 225, "target stays put")
    ns.db.scale.targettarget = 1.5
    ns:ApplySettings()
    eq(tot:GetScale(), ns.Frames.BASE_SCALE * 1.5)
    ns.db.scale.targettarget = 1
    ns.db.locked = true
    SlashCmdList.JIUNITFRAMES("reset")
    eq(ns.db.positions.targettarget[3], 43)
end)

test("party frames hide in raids when asked", function()
    Reset()
    ns.db.hidePartyInRaid = true
    ns:ApplySettings()
    eq(F("party1")._stateDrivers.visibility, "[group:raid] hide; [@party1,exists] show; hide")
    ns.db.hidePartyInRaid = false
    ns:ApplySettings()
end)

-- The spark's x offset from the bar's left edge, or nil when hidden.
local function SparkX(spark)
    spark = spark or F("player").manaSpark
    if not spark:IsShown() then return nil end
    local p = spark._points[#spark._points]
    eq(p[1], "CENTER")
    eq(p[3], "LEFT")
    return p[4]
end

local function SetMana(v)
    M.units.player.power = v
    Fire("UNIT_POWER_FREQUENT", "player", "MANA")
end

test("mana spark: spending mana runs the 5 second rule, then regen ticks", function()
    Reset()
    ns.ManaSpark.state.tickAt, ns.ManaSpark.state.ruleStart = nil, nil
    Fire("PLAYER_ENTERING_WORLD")
    eq(SparkX(), nil, "hidden at full mana")
    local width = F("player").power:GetWidth()

    SetMana(2000)
    Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 123)
    eq(SparkX(), 0, "starts at the left edge")
    eq(F("player").manaSpark._color[4], 1, "rule spark is the bright one")
    H.Tick(2.5, 0.1)
    truthy(math.abs(SparkX() - width / 2) < 2, "halfway after 2.5s")

    -- A regen tick during the rule (mp5) sets the tick cadence.
    H.Tick(1, 0.1)
    SetMana(2010)
    local tickAt = M.now
    H.Tick(1.3, 0.1)
    truthy(SparkX() > width * 0.9, "rule spark near the right edge")
    H.Tick(0.8, 0.1)

    -- Rule over: the tick spark follows the 2 second cadence.
    local x = SparkX()
    truthy(x, "tick spark shown")
    eq(F("player").manaSpark._color[4], ns.ManaSpark.TICK_COLOR[4])
    local expected = ((M.now - tickAt) % 2) / 2 * width
    truthy(math.abs(x - expected) < 0.01, "on the tick cadence")

    -- The next tick re-anchors the cadence; gains right after it don't.
    SetMana(2020)
    tickAt = M.now
    H.Tick(0.5, 0.1)
    SetMana(2030)
    eq(ns.ManaSpark.state.tickAt, tickAt)

    SetMana(2374)
    H.Tick(0.1)
    eq(SparkX(), nil, "hidden again at full mana")
    NoErrors()
end)

test("mana spark: casts that don't spend mana and mana lost otherwise are ignored", function()
    Reset()
    ns.ManaSpark.state.tickAt, ns.ManaSpark.state.ruleStart = nil, nil
    Fire("PLAYER_ENTERING_WORLD")
    Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 123)
    eq(SparkX(), nil, "free cast")
    H.Tick(1)
    SetMana(2000)
    eq(SparkX(), nil, "mana burned without a cast")
    Fire("UNIT_SPELLCAST_SUCCEEDED", "target", "guid", 123)
    eq(SparkX(), nil, "someone else's cast")
    NoErrors()
end)

test("mana spark: the power event may come after the cast", function()
    Reset()
    ns.ManaSpark.state.tickAt, ns.ManaSpark.state.ruleStart = nil, nil
    Fire("PLAYER_ENTERING_WORLD")
    H.Tick(1)
    Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 123)
    H.Tick(0.1)
    SetMana(2000)
    eq(SparkX(), 0)
    NoErrors()
end)

test("mana spark: secret mana goes by the spell's mana cost", function()
    Reset()
    ns.ManaSpark.state.tickAt, ns.ManaSpark.state.ruleStart = nil, nil
    M.secrets = true
    Fire("PLAYER_ENTERING_WORLD")
    M.spellCosts[200] = { { type = 3, cost = 40 } }
    M.spellCosts[201] = { { type = 0, cost = 0, requiredAuraID = 0 }, { type = 0, cost = 80, requiredAuraID = 99, hasRequiredAura = false } }
    M.spellCosts[202] = { { type = 0, cost = 80, requiredAuraID = 0 } }
    Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 200)
    Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 201)
    eq(SparkX(), nil, "no mana cost")
    SetMana(2000)
    Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 202)
    eq(SparkX(), 0, "mana spell")
    H.Tick(5.1, 0.1)
    eq(SparkX(), nil, "no tick spark without plain mana")
    NoErrors()
end)

test("mana spark: only on a mana bar, and only when enabled", function()
    Reset()
    ns.ManaSpark.state.tickAt, ns.ManaSpark.state.ruleStart = nil, nil
    Fire("PLAYER_ENTERING_WORLD")
    SetMana(2000)
    Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 123)
    truthy(SparkX(), "shown")
    -- A warrior's rage bar never gets it.
    M.units.player.class = "WARRIOR"
    M.units.player.powerType, M.units.player.powerToken = 1, "RAGE"
    Fire("UNIT_DISPLAYPOWER", "player")
    eq(SparkX(), nil, "rage bar")
    eq(SparkX(F("player").druidMana.spark), nil, "no druid bar")
    M.units.player.class = "DRUID"
    M.units.player.powerType, M.units.player.powerToken = 0, "MANA"
    Fire("UNIT_DISPLAYPOWER", "player")
    truthy(SparkX(), "back on mana")
    ns.db.manaSpark = false
    ns:ApplySettings()
    eq(SparkX(), nil, "turned off")
    ns.db.manaSpark = true
    ns.db.locked = false
    ns:ApplySettings()
    ns.ManaSpark.state.ruleStart = nil
    H.Tick(0.1)
    truthy(SparkX(), "unlocked frames preview it")
    ns.db.locked = true
    ns:ApplySettings()
    NoErrors()
end)

test("druid mana bar: under the player frame in cat and bear form", function()
    Reset()
    ns.ManaSpark.state.tickAt, ns.ManaSpark.state.ruleStart = nil, nil
    Fire("PLAYER_ENTERING_WORLD")
    local f = F("player")
    local bar = f.druidMana
    eq(bar.holder:IsShown(), false, "hidden in caster form")
    local p = bar.holder._points[1]
    eq(p[1], "TOPRIGHT")
    eq(p[2], f)
    eq(p[3], "BOTTOMRIGHT")
    eq(bar:GetWidth(), f.power:GetWidth(), "as wide as the power bar")
    eq(bar._color[3], 1, "mana cyan")
    eq(bar._color[1], f.power._color[1], "same colour as the mana bar")

    -- Cat form: the power bar shows energy, the druid bar mana.
    local u = M.units.player
    u.powerType, u.powerToken, u.power, u.maxPower = 3, "ENERGY", 100, 100
    u.powers = { [0] = { 1800, 2374 } }
    Fire("UNIT_DISPLAYPOWER", "player")
    eq(bar.holder:IsShown(), true, "cat form")
    eq(bar.text:GetText(), "1800 (2374)")
    eq(bar._value, 1800)
    eq(f.power.text:GetText(), "100 (100)")

    u.powers[0][1] = 1700
    Fire("UNIT_POWER_FREQUENT", "player", "MANA")
    eq(bar.text:GetText(), "1700 (2374)")

    -- The five second rule spark moves to the druid bar.
    Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 768)
    eq(SparkX(bar.spark), 0, "spark on the druid bar")
    eq(SparkX(), nil, "not on the energy bar")

    -- Bear form, then back to caster.
    u.powerType, u.powerToken, u.power = 1, "RAGE", 0
    Fire("UNIT_DISPLAYPOWER", "player")
    eq(bar.holder:IsShown(), true, "bear form")
    u.powerType, u.powerToken, u.power, u.maxPower = 0, "MANA", 1700, 2374
    u.powers = nil
    Fire("UNIT_DISPLAYPOWER", "player")
    eq(bar.holder:IsShown(), false, "caster form")
    truthy(SparkX(), "spark back on the power bar")
    eq(SparkX(bar.spark), nil)

    ns.db.druidMana = false
    u.powerType = 3
    Fire("UNIT_DISPLAYPOWER", "player")
    eq(bar.holder:IsShown(), false, "turned off")
    ns.db.druidMana = true
    NoErrors()
end)

test("druid mana bar: secret mana, and other classes", function()
    Reset()
    M.secrets = true
    local u = M.units.player
    u.powerType, u.powerToken, u.power, u.maxPower = 3, "ENERGY", 100, 100
    u.powers = { [0] = { 1800, 2374 } }
    Fire("UNIT_DISPLAYPOWER", "player")
    local bar = F("player").druidMana
    eq(bar.holder:IsShown(), true)
    eq(bar.text:GetText(), "1800 (2374)")
    eq(bar._max, 2374)
    NoErrors()

    Reset()
    M.units.player.class = "ROGUE"
    M.units.player.powerType, M.units.player.powerToken = 3, "ENERGY"
    Fire("UNIT_DISPLAYPOWER", "player")
    eq(bar.holder:IsShown(), false, "rogue")
    NoErrors()
end)

test("mana spark: with secret mana, the cost is read when the cast is sent", function()
    Reset()
    ns.ManaSpark.state.tickAt, ns.ManaSpark.state.ruleStart = nil, nil
    M.secrets = true
    Fire("PLAYER_ENTERING_WORLD")
    -- Cat Form: a percentage cost that only applies in caster form.
    M.spellCosts[768] = { { type = 0, name = "MANA", cost = 0, costPercent = 35, requiredAuraID = 0 } }
    Fire("UNIT_SPELLCAST_SENT", "player", "", "cast-1", 768)
    M.spellCosts[768] = nil -- shifted: the cost no longer applies
    Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 768)
    eq(SparkX(), 0, "percentage cost counted, read at send")

    -- A failed cast leaves nothing behind.
    ns.ManaSpark.state.ruleStart = nil
    M.spellCosts[202] = { { type = 0, cost = 80 } }
    Fire("UNIT_SPELLCAST_SENT", "player", "", "cast-2", 202)
    Fire("UNIT_SPELLCAST_FAILED", "player", "cast-2", 202)
    M.spellCosts[202] = nil
    Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 202)
    H.Tick(0.1)
    eq(SparkX(), nil)
    NoErrors()
end)

test("options window: scale sliders store their value", function()
    SlashCmdList.JIUNITFRAMES("")
    truthy(JiUnitFramesOptionsFrame:IsShown())
    local slider
    for _, f in ipairs(M.frames) do
        if f._kind == "Slider" and f._min == 0.5 and f._max == 2 and not slider then slider = f end
    end
    truthy(slider, "found the player scale slider")
    slider:SetValue(1.25)
    eq(ns.db.scale.player, 1.25)
    eq(F("player"):GetScale(), ns.Frames.BASE_SCALE * 1.25)
    SlashCmdList.JIUNITFRAMES("")
    eq(JiUnitFramesOptionsFrame:IsShown(), false)
    NoErrors()
end)

H.Finish()
