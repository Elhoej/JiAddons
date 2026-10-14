local _, ns = ...

-- Cast data for a unit. The player's casts arrive as plain values, everyone
-- else's as secrets (SecretWhenUnitSpellCastRestricted: secret unless the
-- unit is the player or their pet, or the spell is flagged otherwise). Secret
-- values may only be passed to widget setters, so the bar is driven with
-- SetMinMaxValues(startMs, endMs) + SetValue(now) for both kinds, and only
-- plain casts get text computed in Lua.

local Cast = {}
ns.Cast = Cast

-- UnitCastingInfo takes UnitTokenPvPRestrictedForAddOns, so some units may
-- be refused outright.
local function Call(fn, ...)
    if not fn then return end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if ok then return a, b, c, d, e end
end

-- Returns { name, texture, startMs, endMs, channel, plain, duration } for the
-- unit's current cast or channel, or nil. type() works on secrets (it reports
-- the underlying type), so it's the presence test; == nil on a secret isn't safe.
function Cast.Query(unit)
    local channel = false
    local name, _, texture, startMs, endMs = Call(UnitCastingInfo, unit)
    if type(name) == "nil" then
        channel = true
        name, _, texture, startMs, endMs = Call(UnitChannelInfo, unit)
        if type(name) == "nil" then return nil end
    end
    local info = {
        name = name, texture = texture, startMs = startMs, endMs = endMs, channel = channel,
        plain = not (ns.IsSecret(name) or ns.IsSecret(startMs) or ns.IsSecret(endMs)),
    }
    if not info.plain then
        -- Secret-safe source for the time text: a duration object (see SetTimeText).
        info.duration = Call(channel and UnitChannelDuration or UnitCastingDuration, unit)
    end
    return info
end

-- WeakAuras' legacy "timed" format as Elva's auras use it: one decimal below
-- the threshold, whole seconds (rounded down) above it.
function Cast.FormatSeconds(seconds, threshold)
    if seconds < 0 then seconds = 0 end
    if seconds < threshold then return ("%.1f"):format(seconds) end
    return tostring(math.floor(seconds))
end

-- The right-hand text, "remaining | total" (|| is an escaped |).
function Cast.TimeText(info, nowMs)
    local remaining = (info.endMs - nowMs) / 1000
    local total = (info.endMs - info.startMs) / 1000
    return Cast.FormatSeconds(remaining, 9) .. " || " .. Cast.FormatSeconds(total, 60)
end

-- WeakAuras cuts the name at 27 characters (ns.Truncate counts UTF-8
-- characters, where the aura's string.sub counted bytes) without an ellipsis.
-- Secrets pass as is.
function Cast.DisplayName(info)
    if not info.plain or type(info.name) ~= "string" then return info.name end
    local cut = ns.Truncate(info.name, 27)
    if cut ~= info.name then cut = cut:sub(1, -4) end
    return cut
end

-- Writes the time text to fs. Secret casts go through their duration
-- object: its getters return secrets, which SetFormattedText accepts.
-- Returns false when that's not possible, so the caller can stop trying.
function Cast.SetTimeText(fs, info, nowMs)
    if info.plain then
        fs:SetText(Cast.TimeText(info, nowMs))
        return true
    end
    local d = info.duration
    if type(d) ~= "userdata" and type(d) ~= "table" then return false end
    local ok = pcall(function()
        fs:SetFormattedText("%.1f || %.1f", d:GetRemainingDuration(), d:GetTotalDuration())
    end)
    return ok
end
