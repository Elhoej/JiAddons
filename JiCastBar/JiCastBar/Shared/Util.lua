-- Embedded copy of JiAddons/shared/Util.lua. Do not edit here:
-- edit shared/Util.lua and run tools/sync-shared.sh.
local addonName, ns = ...

-- Saved variables, table helpers and chat output.

function ns.DeepCopy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do
        out[k] = ns.DeepCopy(v)
    end
    return out
end

-- Fills missing keys in dst from src, recursing into tables. Existing values win.
function ns.CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then
                dst[k] = {}
            end
            ns.CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

-- Returns the saved-variables table named globalName (as declared in the TOC),
-- creating it and filling in defaults. Call from ADDON_LOADED, never at file
-- scope: saved variables are not loaded yet while files execute.
function ns.LoadSavedVariables(globalName, defaults)
    if type(_G[globalName]) ~= "table" then
        _G[globalName] = {}
    end
    return ns.CopyDefaults(ns.DeepCopy(defaults or {}), _G[globalName])
end

-- Resets a saved-variables table to defaults in place, so existing references
-- stay valid. Keys listed in keep survive the reset.
function ns.ResetSavedVariables(globalName, defaults, keep)
    local db = _G[globalName]
    local kept = {}
    for _, key in ipairs(keep or {}) do kept[key] = db[key] end
    wipe(db)
    ns.CopyDefaults(ns.DeepCopy(defaults or {}), db)
    for key, value in pairs(kept) do db[key] = value end
    return db
end

function ns.Print(...)
    local tag = "|cff33ff99" .. (ns.title or addonName) .. ":|r"
    print(tag, ...)
end
