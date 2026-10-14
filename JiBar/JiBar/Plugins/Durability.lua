local _, ns = ...

-- DurabilityFu: the durability of your most damaged item (or the average),
-- a tooltip with every equipped item's durability and repair cost, and
-- optional automatic repairs at merchants.

local floor = math.floor

local P = ns.RegisterPlugin({
    id = "Durability",
    title = "Durability",
    icon = ns.MEDIA .. "Icons\\repair",
    place = { bar = 1, side = "CENTER", order = 1 },
    defaults = {
        showAverage = false,
        colorText = false,
        showHealthy = true,
        showInventory = true,
        autoRepair = false,
        useGuildFunds = false,
        hideArmorFigure = false,
    },
})

-- Opens the character window through Blizzard's button (see Plugin.lua).
P.clickTargets = { { target = "CharacterMicroButton" } }

P.options = {
    { type = "toggle", key = "showAverage", label = "Show the average", tip = "Off: the most damaged item." },
    { type = "toggle", key = "colorText", label = "Colour the text by condition" },
    { type = "toggle", key = "showHealthy", label = "List undamaged items" },
    { type = "toggle", key = "showInventory", label = "Include items in your bags" },
    { type = "toggle", key = "autoRepair", label = "Repair automatically at merchants" },
    { type = "toggle", key = "useGuildFunds", label = "Use guild funds for repairs first" },
    { type = "toggle", key = "hideArmorFigure", label = "Hide Blizzard's armour figure" },
}

local SLOTS = {
    { "HeadSlot", INVTYPE_HEAD or "Head" },
    { "ShoulderSlot", INVTYPE_SHOULDER or "Shoulder" },
    { "ChestSlot", INVTYPE_CHEST or "Chest" },
    { "WaistSlot", INVTYPE_WAIST or "Waist" },
    { "LegsSlot", INVTYPE_LEGS or "Legs" },
    { "FeetSlot", INVTYPE_FEET or "Feet" },
    { "WristSlot", INVTYPE_WRIST or "Wrist" },
    { "HandsSlot", INVTYPE_HAND or "Hands" },
    { "MainHandSlot", INVTYPE_WEAPONMAINHAND or "Main Hand" },
    { "SecondaryHandSlot", INVTYPE_WEAPONOFFHAND or "Off Hand" },
    { "RangedSlot", INVTYPE_RANGED or "Ranged" },
}

function P:OnEnable()
    self:RegisterEvent("UPDATE_INVENTORY_DURABILITY", "Update")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "Update")
    self:RegisterEvent("PLAYER_DEAD", "Update")
    self:RegisterEvent("PLAYER_UNGHOST", "Update")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "Update")
    self:RegisterEvent("BAG_UPDATE_DELAYED", "Update")
    self:RegisterEvent("MERCHANT_SHOW", "OnMerchantShow")
    self:RegisterEvent("MERCHANT_CLOSED", "Update")
    self:ApplyArmorFigure()
end

function P:OnSettingChanged(key)
    if key == "hideArmorFigure" then self:ApplyArmorFigure() end
end

-- Blizzard's armour figure (DurabilityFrame) shows when items get damaged.
function P:ApplyArmorFigure()
    local frame = DurabilityFrame
    if type(frame) ~= "table" then return end
    if not self.armorHooked and frame.HookScript then
        self.armorHooked = true
        frame:HookScript("OnShow", function(f)
            if P.db.enabled and P.db.hideArmorFigure then f:Hide() end
        end)
    end
    if self.db.hideArmorFigure and frame.Hide then frame:Hide() end
end

-- Repair cost of an equipped item: from the tooltip data, or the old
-- SetInventoryItem return values, whichever this client offers.
local function RepairCost(slotID)
    if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local data = C_TooltipInfo.GetInventoryItem("player", slotID)
        if type(data) == "table" and type(data.repairCost) == "number" then return data.repairCost end
    end
    return nil
end

function P:Scan()
    local items = {}
    local value, max, lowest, lowestIndex = 0, 0, 1, nil
    for i, slot in ipairs(SLOTS) do
        local id = GetInventorySlotInfo(slot[1])
        local cur, mx = GetInventoryItemDurability(id)
        if cur and mx and mx > 0 then
            local item = { name = slot[2], value = cur, max = mx, percent = cur / mx, cost = RepairCost(id) }
            items[#items + 1] = item
            value, max = value + cur, max + mx
            if item.percent < lowest then lowest, lowestIndex = item.percent, #items end
        end
    end
    local bags = { value = 0, max = 0 }
    if self.db.showInventory and C_Container and C_Container.GetContainerItemDurability then
        for bag = 0, (NUM_BAG_SLOTS or 4) do
            for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
                local cur, mx = C_Container.GetContainerItemDurability(bag, slot)
                if cur and mx and mx > 0 then
                    bags.value, bags.max = bags.value + cur, bags.max + mx
                end
            end
        end
    end
    return {
        items = items, lowest = lowest, lowestIndex = lowestIndex,
        average = max > 0 and value / max or 1, bags = bags,
    }
end

function P:UpdateText()
    local scan = self:Scan()
    self.scan = scan
    local percent = self.db.showAverage and scan.average or scan.lowest
    local text = floor(percent * 100) .. "%"
    if self.db.colorText then text = "|c" .. ns.ThresholdHex(percent) .. text .. "|r" end
    self:SetText(text)
end

function P:OnTooltip(tip)
    local scan = self.scan or self:Scan()
    tip:AddTitle("Durability")
    local total = 0
    local anyCost = false
    for _, item in ipairs(scan.items) do
        if item.cost then
            total = total + item.cost
            anyCost = true
        end
        if self.db.showHealthy or item.percent < 1 then
            tip:AddLine(item.name, floor(item.percent * 100) .. "%",
                (item.cost and item.cost > 0) and ns.FormatCoins(item.cost) or nil,
                { colors = { { 1, 0.82, 0 }, { ns.ThresholdColor(item.percent) }, { 1, 1, 1 } } })
        end
    end
    if #scan.items == 0 then
        tip:AddLine("No items with durability.", nil, nil, { colors = { { 0.7, 0.7, 0.7 } } })
    end
    tip:AddSpacer()
    tip:AddLine("Equipped (average)", floor(scan.average * 100) .. "%", nil,
        { colors = { nil, { ns.ThresholdColor(scan.average) } } })
    if self.db.showInventory and scan.bags.max > 0 then
        local p = scan.bags.value / scan.bags.max
        tip:AddLine("In your bags", floor(p * 100) .. "%", nil, { colors = { nil, { ns.ThresholdColor(p) } } })
    end
    if anyCost then
        tip:AddLine("Repair cost", ns.FormatCoins(total), nil, { colors = { nil, { 1, 1, 1 } } })
    elseif self.lastRepairCost and self.lastRepairCost > 0 then
        tip:AddLine("Repair cost (last merchant)", ns.FormatCoins(self.lastRepairCost))
    end
    tip:SetHint("Click to open your character window.")
end

function P:OnMerchantShow()
    self:Update()
    if not CanMerchantRepair or not CanMerchantRepair() then return end
    local cost, canRepair = GetRepairAllCost()
    self.lastRepairCost = cost
    if not self.db.autoRepair or not canRepair or not cost or cost <= 0 then return end
    local guild = self.db.useGuildFunds and CanGuildBankRepair and CanGuildBankRepair()
        and GetGuildBankWithdrawMoney and (GetGuildBankWithdrawMoney() == -1 or GetGuildBankWithdrawMoney() >= cost)
    if guild then
        RepairAllItems(true)
        ns.Print("Repaired for " .. ns.FormatCoins(cost) .. " (guild funds).")
    elseif GetMoney() >= cost then
        RepairAllItems()
        ns.Print("Repaired for " .. ns.FormatCoins(cost) .. ".")
    else
        ns.Print("Not enough money to repair (" .. ns.FormatCoins(cost) .. ").")
    end
    self.lastRepairCost = 0
end

