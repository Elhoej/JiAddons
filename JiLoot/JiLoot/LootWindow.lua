local _, ns = ...

-- Keeps Blizzard's loot window out of sight while auto-looting, as long as
-- nothing in the loot needs a decision (bind on pickup, rolls). The window is
-- made transparent rather than hidden: LootFrame:OnHide() calls CloseLoot(),
-- which would abort the looting.

local LootWindow = {}
ns.LootWindow = LootWindow

local BIND_ON_PICKUP = Enum and Enum.ItemBind and Enum.ItemBind.OnAcquire or 1
local SLOT_ITEM = Enum and Enum.LootSlotType and Enum.LootSlotType.Item or 1
local REVEAL_DELAY = 0.5

local hidden = false

local function SetHidden(value)
    local frame = _G.LootFrame
    if not frame then return end
    hidden = value
    frame:SetAlpha(value and 0 or 1)
end

local function AnyItemsLeft()
    for slot = 1, GetNumLootItems() do
        if LootSlotHasItem(slot) then return true end
    end
    return false
end

-- True when every slot can be taken without a prompt: no bind-on-pickup
-- items, nothing locked by a roll, and all item data is known.
function LootWindow:CanTakeAll()
    local count = GetNumLootItems()
    if not count or count == 0 then return false end
    for slot = 1, count do
        local _, _, _, _, _, locked = GetLootSlotInfo(slot)
        if locked then return false end
        if GetLootSlotType(slot) == SLOT_ITEM then
            local link = ns.SafeString(GetLootSlotLink(slot))
            if not link then return false end
            local bindType = select(14, ns.GetItemInfo(link))
            if bindType == nil or bindType == BIND_ON_PICKUP then return false end
        end
    end
    return true
end

function LootWindow:LOOT_READY(autoLoot)
    if not ns.db.hideLootWindow or ns.IsSecret(autoLoot) then return end
    if autoLoot == nil and GetCVarBool then
        autoLoot = GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE")
    end
    if not autoLoot or not self:CanTakeAll() then return end

    SetHidden(true)
    for slot = GetNumLootItems(), 1, -1 do
        LootSlot(slot)
    end
    -- Something could not be taken (e.g. bags are full): show the window.
    C_Timer.After(REVEAL_DELAY, function()
        if hidden and AnyItemsLeft() then SetHidden(false) end
    end)
end

function LootWindow:LOOT_CLOSED()
    if hidden then SetHidden(false) end
end

function LootWindow:Init()
    ns:RegisterEvent("LOOT_READY", function(_, ...) LootWindow:LOOT_READY(...) end)
    ns:RegisterEvent("LOOT_CLOSED", function() LootWindow:LOOT_CLOSED() end)
end
