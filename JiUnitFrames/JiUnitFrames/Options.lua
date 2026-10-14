local _, ns = ...

-- Options window, built with the shared widget toolkit (Shared/Widgets.lua).

local Options = {}
ns.Options = Options

local W = ns.Widgets
local WIDTH, HEIGHT = 600, 560
local CONTENT_WIDTH = WIDTH - 48

local function db() return ns.db end

local function Opt(key)
    return function() return db()[key] end, function(v) db()[key] = v end
end

local function Sub(group, key)
    return function() return db()[group][key] end, function(v) db()[group][key] = v end
end

local function Pct(v) return math.floor(v * 100 + 0.5) .. "%" end

function Options:BuildContent(content)
    local L = W.NewLayout(content, CONTENT_WIDTH)
    local c = content
    local S = self.set

    L:Header("General")
    self.lockBox = S:Checkbox(c, "Lock frames",
        "Unlock to drag the frames around. Unlocked frames show your own character as sample data. Dragging any party frame moves the whole party.",
        function() return db().locked end, function(v) ns:SetLocked(v) end)
    L:Row(self.lockBox,
        S:Checkbox(c, "3D portraits", "Show a 3D face on the player and target frames. Off, or when a unit is out of visual range, the flat portrait is used.",
            Opt("portrait3D")))
    L:Row(S:Checkbox(c, "Smooth bars", "Health and power bars glide to new values instead of jumping.", Opt("smoothBars")),
        S:Cycle(c, "Font", ns.Elements.FONT_NAMES, "Nurfed's Franklin Gothic, or one of the game's fonts.", Opt("font")))
    L:Row(S:Cycle(c, "Health bar colour", { "By health (green, orange, red)", "Class / reaction", "Always green" }, nil,
        Opt("healthColor")))

    L:Header("Frames")
    L:Row(S:Checkbox(c, "Target of target", "Small frame showing your target's target.", Opt("showToT")),
        S:Checkbox(c, "Pet frame", nil, Opt("showPet")))
    L:Row(S:Checkbox(c, "Party frames", nil, Opt("showParty")),
        S:Checkbox(c, "Hide party frames in raids", nil, Opt("hidePartyInRaid")))
    L:Row(S:Checkbox(c, "Party pets", "Small frames next to each party member for their pet.", Opt("showPartyPets")),
        S:Checkbox(c, "Key bindings on party names", "Prefix party names with the key that targets them, like [F2].",
            Opt("showKeyBindings")))
    L:Row(S:Slider(c, "Party frame spacing", 41, 120, 1, Opt("partySpacing")))

    L:Header("Mana")
    L:Row(S:Checkbox(c, "Five second rule spark",
            "After you spend mana, a spark crosses the player's mana bar during the 5 seconds without spirit regen. Unlocked frames loop it as a preview.",
            Opt("manaSpark")),
        S:Checkbox(c, "Regen tick spark",
            "After the 5 seconds, while mana isn't full, a fainter spark crosses the bar every 2 seconds, timed to the mana ticks.",
            Opt("manaTicks")))
    L:Row(S:Checkbox(c, "Druid mana bar",
        "In cat and bear form, show your mana on a bar under the player frame. The sparks move to it. Unlocked frames show it as a preview.",
        Opt("druidMana")))

    L:Header("Buffs and debuffs")
    L:Row(S:Checkbox(c, "Only buffs I can cast", nil, Sub("auras", "castableOnly")),
        S:Checkbox(c, "Only debuffs I can dispel", nil, Sub("auras", "dispellableOnly")))
    L:Row(S:Checkbox(c, "Target shows all auras", "The two filters above don't apply to the target frame.",
            Sub("auras", "targetShowsAll")),
        S:Checkbox(c, "Duration spirals", "Darken aura icons as they run out. Takes effect after /reload.",
            Sub("auras", "cooldowns")))
    L:Row(S:Checkbox(c, "Flash debuffs I can dispel",
        "Debuffs you can remove are listed first and pulse. Takes effect after /reload.",
        Sub("auras", "flashDispellable")))

    L:Header("Scale")
    -- Sub() isn't the last argument here, so unpack its two returns explicitly.
    local function Scale(label, key)
        local get, set = Sub("scale", key)
        return S:Slider(c, label, 0.5, 2, 0.05, get, set, Pct)
    end
    L:Row(Scale("Player", "player"), Scale("Target", "target"))
    L:Row(Scale("Target of target", "targettarget"), Scale("Pet", "pet"))
    L:Row(Scale("Party", "party"))

    L:Header("Blizzard frames")
    L:Note("Hide the default frames these replace. Showing one again takes effect after /reload.")
    L:Row(S:Checkbox(c, "Hide player frame", nil, Sub("hideBlizzard", "player")),
        S:Checkbox(c, "Hide target frame", nil, Sub("hideBlizzard", "target")))
    L:Row(S:Checkbox(c, "Hide pet frame", nil, Sub("hideBlizzard", "pet")),
        S:Checkbox(c, "Hide party frames", "Also turn off Edit Mode's \"Use Raid-Style Party Frames\" if it's on.",
            Sub("hideBlizzard", "party")))

    content:SetHeight(-L.y + 16)
end

function Options:Build()
    self.set = W.NewSet(function()
        ns.Blizzard:Hide()
        ns:ApplySettings()
    end)
    local content
    self.window, content = W.CreateWindow({
        name = "JiUnitFramesOptionsFrame",
        title = "|cff33ff99JiUnitFrames|r",
        width = WIDTH,
        height = HEIGHT,
        onShow = function() Options.set:Refresh() end,
    })
    self:BuildContent(content)

    local reset = W.Button(self.window, "Reset positions", 130, function() ns:ResetPositions() end)
    reset:SetPoint("BOTTOMLEFT", 14, 12)
    local defaults = W.Button(self.window, "Reset all", 110, function()
        ns:ResetDB()
        Options.set:Refresh()
    end)
    defaults:SetPoint("LEFT", reset, "RIGHT", 8, 0)
end

function Options:Toggle()
    if not self.window then self:Build() end
    self.window:SetShown(not self.window:IsShown())
end

function Options:Refresh()
    if self.set then self.set:Refresh() end
end

function Options:Init()
    W.RegisterSettingsPanel({
        title = ns.title,
        description = "Nurfed-style unit frames. Type /jiuf to open the options, /jiuf unlock to move the frames.",
        icon = 136122,
        open = function() Options:Toggle() end,
    })
end
