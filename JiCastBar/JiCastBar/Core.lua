local addonName, ns = ...

ns.name = addonName
ns.title = "JiCastBar"

-- Where each bar sits by default: the player's where Elva's auras put it,
-- the target's just above it. width includes the icon, which is as wide as
-- the bar is tall.
local WIDTH, HEIGHT = ns.LAYOUT.width, ns.LAYOUT.height
ns.defaults = {
    locked = true,
    bars = {
        player = { enabled = true, style = "sunset", scale = 1, width = WIDTH, height = HEIGHT, effects = true,
            hideBlizzard = true, latency = false, point = { "CENTER", "CENTER", 0, -312 } },
        target = { enabled = true, style = "sunset", scale = 1, width = WIDTH, height = HEIGHT, effects = true,
            hideBlizzard = true, point = { "CENTER", "CENTER", 0, -262 } },
    },
}

-- Option ranges. The narrowest bar still leaves room for the texts beside a
-- square icon at the tallest height.
ns.SIZE_LIMITS = { width = { 120, 600 }, height = { 12, 60 } }

ns.BAR_KEYS = { "player", "target" }
ns.BAR_LABELS = { player = "Player", target = "Target" }
ns.bars = {}

-------------------------------------------------------------------------------
-- Blizzard's cast bars
-------------------------------------------------------------------------------

-- Without events the Blizzard bars never start a cast, so they never show.
-- Hide(), SetAlpha(0) and changing their fields are worse: the player bar is
-- a bottom-managed frame (hiding it relayouts the container that holds the
-- extra action button under our taint), and edit mode and every cast start
-- reset its alpha. Unregistering can't be undone safely, so turning the
-- option off needs a /reload.
local BLIZZARD_BARS = { player = "PlayerCastingBarFrame", target = "TargetFrameSpellBar" }
ns.blizzardHidden = {}

function ns.HideBlizzardBars()
    for key, frameName in pairs(BLIZZARD_BARS) do
        local cfg = ns.db.bars[key]
        local frame = _G[frameName]
        if cfg.enabled and cfg.hideBlizzard and not ns.blizzardHidden[key]
            and type(frame) == "table" and frame.UnregisterAllEvents then
            ns.blizzardHidden[key] = pcall(frame.UnregisterAllEvents, frame)
        end
    end
end

-- True when Blizzard's bar for key is hidden but the settings no longer want it.
function ns.BlizzardRestorePending(key)
    local cfg = ns.db.bars[key]
    return ns.blizzardHidden[key] and not (cfg.enabled and cfg.hideBlizzard) or false
end

-------------------------------------------------------------------------------
-- Applying settings
-------------------------------------------------------------------------------

-- Bars show a sample cast while unlocked or while the options are open.
ns.optionsOpen = false

function ns.Apply()
    ns.HideBlizzardBars()
    local preview = not ns.db.locked or ns.optionsOpen
    for _, key in ipairs(ns.BAR_KEYS) do
        local bar = ns.bars[key]
        bar:ApplySettings(ns.db.bars[key])
        bar:SetMovable(not ns.db.locked)
        bar:SetPreview(preview)
    end
end

function ns.SetLocked(locked)
    ns.db.locked = locked and true or false
    ns.Apply()
    if ns.Options then ns.Options:Refresh() end
end

function ns.ResetPositions()
    for _, key in ipairs(ns.BAR_KEYS) do
        ns.db.bars[key].point = ns.DeepCopy(ns.defaults.bars[key].point)
    end
    ns.Apply()
end

-------------------------------------------------------------------------------
-- Startup
-------------------------------------------------------------------------------

ns:OnLoad(function()
    ns.db = ns.LoadSavedVariables("JiCastBarDB", ns.defaults)
    ns.bars.player = ns.Bar.New("player", "player")
    ns.bars.target = ns.Bar.New("target", "target")
    ns.Apply()
    ns.Options:Init()
end)

-- Blizzard's frames exist by our ADDON_LOADED; this catches any that don't.
ns:RegisterEvent("PLAYER_LOGIN", function()
    if ns.db then ns.HideBlizzardBars() end
end)

SLASH_JICASTBAR1 = "/jicastbar"
SLASH_JICASTBAR2 = "/jcb"
SlashCmdList.JICASTBAR = function(msg)
    local cmd = strtrim(msg or ""):lower()
    if cmd == "unlock" or cmd == "move" then
        ns.SetLocked(false)
        ns.Print("Bars unlocked. Drag them, then type /jcb lock.")
    elseif cmd == "lock" then
        ns.SetLocked(true)
    elseif cmd == "reset" then
        ns.ResetPositions()
        ns.Print("Bar positions reset.")
    elseif cmd == "debug" then
        -- Prints how each cast is driven (plain/secret, relative/timer/absolute) and model errors.
        ns.db.debug = not ns.db.debug
        ns.Print("Debug output " .. (ns.db.debug and "on." or "off."))
    else
        ns.Options:Toggle()
    end
end
