local addonName, ns = ...

ns.name = addonName
ns.title = "JiUnitFrames"

-------------------------------------------------------------------------------
-- Defaults
-------------------------------------------------------------------------------

ns.defaults = {
    locked = true,
    font = 1,              -- index into ns.Elements.FONTS
    portrait3D = true,
    smoothBars = true,
    healthColor = 1,       -- 1 = by health %, 2 = class colour, 3 = green

    showPet = true,
    showToT = true,
    showParty = true,
    hidePartyInRaid = false,
    showPartyPets = true,
    showKeyBindings = true,
    manaSpark = true,      -- five second rule spark on the player's mana bar
    manaTicks = true,      -- and the 2 second regen tick spark after it
    druidMana = true,      -- druids' mana under the player frame in cat and bear form
    partySpacing = 62,

    auras = {
        castableOnly = false,   -- buffs: only those I can cast
        dispellableOnly = false, -- debuffs: only those I can dispel
        targetShowsAll = true,  -- the filters above don't apply to the target
        cooldowns = true,
        flashDispellable = true,
    },

    hideBlizzard = { player = true, target = true, pet = true, party = true },

    scale = { player = 1, target = 1, targettarget = 1, pet = 1, party = 1 },

    -- [frame key] = { point, relativePoint, x, y } relative to UIParent.
    -- Defaults match the Nurfed screenshot on a 1080p screen.
    positions = {
        player = { "CENTER", "CENTER", -140, -162 },
        target = { "CENTER", "CENTER", 225, -158 },
        -- Centred in the gap between player and target, level with them.
        targettarget = { "CENTER", "CENTER", 43, -160 },
        pet = { "CENTER", "CENTER", -335, -162 },
        party = { "TOPLEFT", "TOPLEFT", 34, -39 },
    },

    debug = false,
}

-------------------------------------------------------------------------------
-- Combat-safe execution. Secure frames can't be created, moved, scaled or
-- re-driven in combat, so that work waits for PLAYER_REGEN_ENABLED.
-------------------------------------------------------------------------------

local pending = {}

function ns:OutOfCombat(key, fn)
    if InCombatLockdown() then
        pending[key] = fn
        return false
    end
    fn()
    return true
end

ns:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    for key, fn in pairs(pending) do
        pending[key] = nil
        fn()
    end
end)

-------------------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------------------

function ns:InitDB()
    self.db = ns.LoadSavedVariables("JiUnitFramesDB", self.defaults)
end

function ns:ResetDB()
    self.db = ns.ResetSavedVariables("JiUnitFramesDB", self.defaults)
    self:ApplySettings()
end

function ns:ResetPositions()
    self.db.positions = ns.DeepCopy(self.defaults.positions)
    self:ApplySettings()
end

-- Re-applies everything that depends on settings. Safe to call any time:
-- the secure parts wait until combat ends.
function ns:ApplySettings()
    if not (self.Frames and self.Frames.initialized) then return end
    self.Elements.RefreshFonts()
    self:OutOfCombat("layout", function() self.Frames:SetTestMode(not self.db.locked) end)
    self.Frames:UpdateAll()
    self.ManaSpark:Update()
end

function ns:SetLocked(locked)
    self.db.locked = locked and true or false
    self:ApplySettings()
end

ns:OnLoad(function()
    ns:InitDB()
    ns:OutOfCombat("init", function()
        ns.Blizzard:Hide()
        ns.Frames:Init()
        ns:ApplySettings()
    end)
    ns.Options:Init()
end)

-------------------------------------------------------------------------------
-- Slash commands
-------------------------------------------------------------------------------

local function Help()
    ns.Print("commands:")
    print("  /jiuf  - open options")
    print("  /jiuf unlock | lock  - move the frames (unlocked frames show test data)")
    print("  /jiuf reset  - reset frame positions")
    print("  /jiuf debug  - print API errors the frames swallow")
end

SLASH_JIUNITFRAMES1 = "/jiuf"
SLASH_JIUNITFRAMES2 = "/jiunitframes"
SlashCmdList.JIUNITFRAMES = function(msg)
    local cmd = strtrim(msg or ""):lower()
    if cmd == "" or cmd == "options" or cmd == "config" then
        ns.Options:Toggle()
    elseif cmd == "unlock" or cmd == "lock" then
        if InCombatLockdown() then
            ns.Print("can't move frames in combat; will apply after combat.")
        end
        ns:SetLocked(cmd == "lock")
        ns.Options:Refresh()
    elseif cmd == "reset" then
        ns:ResetPositions()
        ns.Print("frame positions reset.")
    elseif cmd == "debug" then
        ns.db.debug = not ns.db.debug
        ns.Print("debug " .. (ns.db.debug and "on" or "off"))
    else
        Help()
    end
end
