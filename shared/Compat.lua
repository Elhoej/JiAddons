local _, ns = ...

-- API compatibility. WoW Forever runs the modern (Midnight-era) client, but
-- APIs move between builds: always prefer C_* namespaces, fall back to the old
-- globals, and treat everything as possibly missing.

-- Midnight-era clients can hand addons "secret" values that error on use
-- (arithmetic, comparison, string ops). Check before touching event payloads.
function ns.IsSecret(v)
    return issecretvalue ~= nil and v ~= nil and issecretvalue(v) or false
end

-- Returns v if it is a usable (non-secret) string, otherwise nil.
function ns.SafeString(v)
    if type(v) ~= "string" or ns.IsSecret(v) then return nil end
    return v
end

function ns.IsAddOnLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(name)
    elseif IsAddOnLoaded then
        return IsAddOnLoaded(name)
    end
    return false
end

function ns.GetAddOnMetadata(name, field)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(name, field)
    elseif GetAddOnMetadata then
        return GetAddOnMetadata(name, field)
    end
end

-- Returns nil for items the client has not cached yet; request the data with
-- C_Item.RequestLoadItemDataByID and retry (see JiLoot's Sources:AddItem).
function ns.GetItemInfo(item)
    if C_Item and C_Item.GetItemInfo then
        return C_Item.GetItemInfo(item)
    elseif GetItemInfo then
        return GetItemInfo(item)
    end
end

function ns.GetItemInfoInstant(item)
    if C_Item and C_Item.GetItemInfoInstant then
        return C_Item.GetItemInfoInstant(item)
    elseif GetItemInfoInstant then
        return GetItemInfoInstant(item)
    end
end

function ns.GetItemCount(item)
    local count
    if C_Item and C_Item.GetItemCount then
        count = C_Item.GetItemCount(item)
    elseif GetItemCount then
        count = GetItemCount(item)
    end
    return tonumber(count) or 0
end

function ns.GetItemStats(link)
    if C_Item and C_Item.GetItemStats then
        return C_Item.GetItemStats(link)
    elseif GetItemStats then
        return GetItemStats(link)
    end
end

function ns.GetDetailedItemLevel(link)
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        return C_Item.GetDetailedItemLevelInfo(link)
    elseif GetDetailedItemLevelInfo then
        return GetDetailedItemLevelInfo(link)
    end
end

local FALLBACK_QUALITY_HEX = {
    [0] = "ff9d9d9d", "ffffffff", "ff1eff00", "ff0070dd", "ffa335ee",
    "ffff8000", "ffe6cc80", "ff00ccff", "ff00ccff",
}

-- Returns r, g, b, hex ("ffrrggbb") for an item quality.
function ns.QualityColor(quality)
    quality = tonumber(quality) or 1
    local r, g, b, hex
    if C_Item and C_Item.GetItemQualityColor then
        r, g, b, hex = C_Item.GetItemQualityColor(quality)
    elseif GetItemQualityColor then
        r, g, b, hex = GetItemQualityColor(quality)
    end
    if not r then
        hex = FALLBACK_QUALITY_HEX[quality] or "ffffffff"
        r = tonumber(hex:sub(3, 4), 16) / 255
        g = tonumber(hex:sub(5, 6), 16) / 255
        b = tonumber(hex:sub(7, 8), 16) / 255
    end
    if type(hex) ~= "string" or #hex ~= 8 then
        hex = string.format("ff%02x%02x%02x",
            math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
    end
    return r, g, b, hex
end
