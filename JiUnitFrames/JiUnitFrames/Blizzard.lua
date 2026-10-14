local _, ns = ...

-- Hides Blizzard's unit frames. Like oUF: stop their events, hide them and
-- park them under a hidden parent so nothing shows them again. Must run out of
-- combat. Turning an option back on needs a /reload to bring the frame back.

local Blizzard = {}
ns.Blizzard = Blizzard

local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()

local CHILD_BARS = { "healthBar", "manaBar", "powerBarAlt", "spellbar", "HealthBar", "ManaBar" }

local function Disable(frame, keepParent)
    if type(frame) ~= "table" or frame.jiDisabled then return end
    frame.jiDisabled = true
    frame:UnregisterAllEvents()
    frame:Hide()
    if not keepParent then frame:SetParent(hiddenParent) end
    for _, key in ipairs(CHILD_BARS) do
        local child = frame[key]
        if type(child) == "table" and child.UnregisterAllEvents then child:UnregisterAllEvents() end
    end
end

function Blizzard:Hide()
    local hide = ns.db.hideBlizzard
    if hide.player then
        Disable(PlayerFrame)
    end
    if hide.target then
        Disable(TargetFrame)
        Disable(TargetFrameToT)
        Disable(ComboFrame)
    end
    if hide.pet then
        Disable(PetFrame)
    end
    if hide.party and PartyFrame then
        -- Member frames come from a pool filled in PartyFrame's OnShow; they stay
        -- parented to PartyFrame, which never shows again once parked.
        local pool = PartyFrame.PartyMemberFramePool
        if type(pool) == "table" and pool.EnumerateActive then
            for member in pool:EnumerateActive() do
                Disable(member, true)
            end
        end
        for i = 1, 4 do
            Disable(PartyFrame["MemberFrame" .. i], true)
        end
        Disable(PartyFrame)
    end
end
