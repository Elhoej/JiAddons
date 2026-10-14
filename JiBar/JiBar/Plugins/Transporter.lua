local _, ns = ...

-- TransporterFu: your hearthstone's inn (or another way home) and its
-- cooldown. Clicking uses the chosen method. Using items and casting spells
-- are protected actions, so the click goes through a secure overlay (see
-- Plugin:CreateSecureOverlay); the method can't change during combat.

local P = ns.RegisterPlugin({
    id = "Transporter",
    title = "Transporter",
    icon = ns.MEDIA .. "Icons\\transporter",
    place = { bar = 1, side = "RIGHT", order = 1 },
    defaults = {
        method = "item:6948",
        showTag = true,
        showCooldown = true,
        methodIcon = false,
    },
})

P.options = {
    { type = "toggle", key = "showTag", label = "Show the destination" },
    { type = "toggle", key = "showCooldown", label = "Show the cooldown" },
    { type = "toggle", key = "methodIcon", label = "Use the method's icon" },
}

-- home = true: the text shows the hearthstone's inn instead of the name.
local METHODS = {
    { key = "item:6948", item = 6948, home = true },             -- Hearthstone
    { key = "spell:556", spell = 556, home = true },             -- Astral Recall
    { key = "spell:18960", spell = 18960 },                      -- Teleport: Moonglade
    { key = "spell:3561", spell = 3561 }, { key = "spell:3562", spell = 3562 }, { key = "spell:3565", spell = 3565 },
    { key = "spell:3567", spell = 3567 }, { key = "spell:3563", spell = 3563 }, { key = "spell:3566", spell = 3566 },
    { key = "spell:10059", spell = 10059 }, { key = "spell:11416", spell = 11416 }, { key = "spell:11419", spell = 11419 },
    { key = "spell:11417", spell = 11417 }, { key = "spell:11418", spell = 11418 }, { key = "spell:11420", spell = 11420 },
    { key = "spell:13819", spell = 13819 }, { key = "spell:23214", spell = 23214 },  -- paladin mounts
    { key = "spell:5784", spell = 5784 }, { key = "spell:23161", spell = 23161 },    -- warlock mounts
    { key = "item:18986", item = 18986 },                        -- Ultrasafe Transporter: Gadgetzan
    { key = "item:18984", item = 18984 },                        -- Dimensional Ripper - Everlook
}

local FALLBACK_NAMES = {
    [6948] = "Hearthstone", [556] = "Astral Recall", [18960] = "Teleport: Moonglade",
    [3561] = "Teleport: Stormwind", [3562] = "Teleport: Ironforge", [3565] = "Teleport: Darnassus",
    [3567] = "Teleport: Orgrimmar", [3563] = "Teleport: Undercity", [3566] = "Teleport: Thunder Bluff",
    [10059] = "Portal: Stormwind", [11416] = "Portal: Ironforge", [11419] = "Portal: Darnassus",
    [11417] = "Portal: Orgrimmar", [11418] = "Portal: Undercity", [11420] = "Portal: Thunder Bluff",
    [13819] = "Summon Warhorse", [23214] = "Summon Charger", [5784] = "Summon Felsteed",
    [23161] = "Summon Dreadsteed", [18986] = "Ultrasafe Transporter: Gadgetzan",
    [18984] = "Dimensional Ripper - Everlook",
}

local function SpellKnown(id)
    if C_SpellBook and C_SpellBook.IsSpellKnown then return C_SpellBook.IsSpellKnown(id) end
    if IsSpellKnown then return IsSpellKnown(id) end
    return false
end

local function HasItem(id)
    if ns.GetItemCount(id) > 0 then return true end
    local equipped = C_Item and C_Item.IsEquippedItem or IsEquippedItem
    return equipped and equipped(id) or false
end

function P:Name(m)
    if m.spell then
        local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(m.spell)
        return ns.SafeString(name) or FALLBACK_NAMES[m.spell] or ("Spell " .. m.spell)
    end
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(m.item)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(m.item) end
    return ns.SafeString(name) or FALLBACK_NAMES[m.item] or ("Item " .. m.item)
end

function P:Texture(m)
    if m.spell then
        return C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(m.spell)
    end
    return C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(m.item)
end

-- Methods this character can use right now.
function P:Available()
    local list = {}
    for _, m in ipairs(METHODS) do
        if (m.spell and SpellKnown(m.spell)) or (m.item and HasItem(m.item)) then list[#list + 1] = m end
    end
    return list
end

function P:Current()
    local available = self:Available()
    for _, m in ipairs(available) do
        if m.key == self.db.method then return m, available end
    end
    return available[1], available
end

-- Seconds left, or 0 when ready. nil when unknown (e.g. secret in combat).
function P:Cooldown(m)
    local start, duration
    if m.spell then
        local info = C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(m.spell)
        if type(info) == "table" then start, duration = info.startTime, info.duration end
    else
        local get = C_Container and C_Container.GetItemCooldown or GetItemCooldown
        if get then start, duration = get(m.item) end
    end
    if ns.IsSecret(start) or ns.IsSecret(duration) or not start or not duration then return nil end
    if start == 0 or duration <= 1.5 then return 0 end
    return math.max(0, start + duration - GetTime())
end

function P:CooldownText(m)
    local cd = self:Cooldown(m)
    if cd == nil then return "|cffaaaaaa?|r" end
    if cd <= 0 then return "|cff33ff33Ready|r" end
    return ns.FormatDuration(cd)
end

function P:OnInit()
    self:CreateSecureOverlay()
end

function P:OnEnable()
    self:RegisterEvent("BAG_UPDATE_DELAYED", "OnMethodsChanged")
    self:RegisterEvent("SPELLS_CHANGED", "OnMethodsChanged")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "OnMethodsChanged")
    self:RegisterEvent("HEARTHSTONE_BOUND", "Update")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Update")
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN", "Update")
    self:RegisterEvent("BAG_UPDATE_COOLDOWN", "Update")
    self:RegisterEvent("GET_ITEM_INFO_RECEIVED", "Update")
    self:OnMethodsChanged()
end

function P:OnMethodsChanged()
    self:ApplyAttributes()
    self:Update()
end

-- Points the secure overlay at the current method (out of combat only).
function P:ApplyAttributes()
    ns.OutOfCombat("transporter", function()
        local b = self.overlay
        local m = self:Current()
        b:SetAttribute("type1", nil)
        b:SetAttribute("spell1", nil)
        b:SetAttribute("item1", nil)
        if m and m.spell then
            b:SetAttribute("type1", "spell")
            b:SetAttribute("spell1", m.spell)
        elseif m and m.item then
            b:SetAttribute("type1", "item")
            b:SetAttribute("item1", "item:" .. m.item)
        end
        self.appliedMethod = m and m.key
    end)
end

function P:SetMethod(key)
    self.db.method = key
    self:ApplyAttributes()
    if InCombatLockdown() then ns.Print("The new method takes effect after combat.") end
    self:Update()
end

function P:UpdateText()
    local db = self.db
    local m = self:Current()
    if not m then
        self:SetText("N/A")
        self:SetIcon(self.icon)
        return
    end
    local parts = {}
    if db.showTag then
        local inn = ns.SafeString(GetBindLocation and GetBindLocation())
        if m.home then
            parts[#parts + 1] = ((inn and inn ~= "") and inn or self:Name(m)):upper()
        else
            parts[#parts + 1] = self:Name(m)
        end
    end
    if db.showCooldown then
        local cd = self:Cooldown(m)
        if cd and cd > 0 then parts[#parts + 1] = ns.FormatDuration(cd) end
    end
    self:SetText(ns.Join(parts))
    if db.methodIcon then
        self:SetIcon(self:Texture(m) or self.icon)
    else
        self:SetIcon(self.icon)
    end
end

function P:OnTick()
    local m = self:Current()
    if m and self.db.showCooldown and (self:Cooldown(m) or 0) > 0 then self:UpdateText() end
end

function P:OnTooltip(tip)
    local current, available = self:Current()
    tip:AddTitle("Transporter")
    if current then
        tip:AddLine("Method", self:Name(current), nil, { colors = { nil, { 1, 1, 1 } } })
    end
    local inn = ns.SafeString(GetBindLocation and GetBindLocation())
    if inn then tip:AddLine("Inn", inn, nil, { colors = { nil, { 1, 1, 1 } } }) end
    if #available > 0 then
        tip:AddHeader("Methods")
        for _, m in ipairs(available) do
            tip:AddLine(self:Name(m), self:CooldownText(m), nil, {
                colors = { { 1, 1, 1 } }, check = m == current,
                onClick = function() self:SetMethod(m.key) end,
            })
        end
        tip:SetHint("Click to use the selected method. Click a method above to select it.")
    else
        tip:AddLine("No hearthstone or teleport found.", nil, nil, { colors = { { 0.7, 0.7, 0.7 } } })
    end
end

function P:OnMenu(root)
    local current, available = self:Current()
    local sub = root:CreateButton("Method")
    for _, m in ipairs(available) do
        sub:CreateRadio(self:Name(m), function() return m == current end, function() self:SetMethod(m.key) end, m.key)
    end
    if #available == 0 then sub:CreateTitle("None available") end
end

function P:OnSecureClick()
    if self.appliedMethod ~= (self:Current() or {}).key then self:ApplyAttributes() end
end
