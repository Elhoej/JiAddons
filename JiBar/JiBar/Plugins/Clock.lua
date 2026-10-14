local _, ns = ...

-- ClockFu: server or local time, optionally both, with a tooltip showing
-- local, server and UTC time and the date. Click opens the calendar.

local floor = math.floor

local P = ns.RegisterPlugin({
    id = "Clock",
    title = "Clock",
    place = { bar = 1, side = "CENTER", order = 3 },
    defaults = {
        twentyFour = false,
        showSeconds = false,
        localTime = false,
        bothTimes = false,
        fontSize = 25,
    },
})

-- The minimap's calendar and clock buttons (see Plugin.lua).
P.clickTargets = {
    { target = "GameTimeFrame" },
    { target = "TimeManagerClockButton", modifier = "shift-" },
}

P.options = {
    { type = "toggle", key = "twentyFour", label = "24-hour format" },
    { type = "toggle", key = "showSeconds", label = "Show seconds" },
    { type = "toggle", key = "localTime", label = "Local time", tip = "Show your computer's time instead of the realm's." },
    { type = "toggle", key = "bothTimes", label = "Show both times" },
}

-- Hours offset of a time from UTC, rounded to half hours.
local function Offset(hour, minute)
    local utc = date("!*t")
    local diff = (hour + minute / 60) - (utc.hour + utc.min / 60)
    diff = floor(diff * 2 + 0.5) / 2
    if diff >= 12 then diff = diff - 24 elseif diff < -12 then diff = diff + 24 end
    return diff
end

function P:Format(hour, minute, second)
    local db = self.db
    if db.twentyFour then
        if db.showSeconds then return string.format("%d:%02d:%02d", hour, minute, second) end
        return string.format("%d:%02d", hour, minute)
    end
    local pm = hour >= 12
    hour = hour % 12
    if hour == 0 then hour = 12 end
    local suffix = pm and "PM" or "AM"
    if db.showSeconds then return string.format("%d:%02d:%02d %s", hour, minute, second, suffix) end
    return string.format("%d:%02d %s", hour, minute, suffix)
end

-- The realm time has no seconds; count them from the moment the minute changed.
function P:ServerTime()
    local hour, minute = GetGameTime()
    if self.lastMinute ~= minute then
        self.lastMinute = minute
        self.minuteStarted = GetTime()
    end
    local second = floor(GetTime() - (self.minuteStarted or GetTime())) % 60
    return hour, minute, second
end

function P:LocalTime()
    local t = date("*t")
    return t.hour, t.min, t.sec
end

function P:UpdateText()
    local server = self:Format(self:ServerTime())
    local loc = self:Format(self:LocalTime())
    if self.db.bothTimes then
        if self.db.localTime then
            self:SetText(ns.Join({ loc, server }))
        else
            self:SetText(ns.Join({ server, loc }))
        end
    else
        self:SetText(self.db.localTime and loc or server)
    end
end

function P:OnTick()
    self:UpdateText()
end

function P:OnTooltip(tip)
    tip:AddTitle("Clock")
    local lh, lm = self:LocalTime()
    local sh, sm = self:ServerTime()
    local function Label(name, offset)
        return string.format("%s (UTC%+d:%02d)", name, offset >= 0 and floor(offset) or -floor(-offset), floor(math.abs(offset) * 60) % 60)
    end
    tip:AddLine(Label("Local time", Offset(lh, lm)), self:Format(self:LocalTime()))
    tip:AddLine(Label("Realm time", Offset(sh, sm)), self:Format(self:ServerTime()))
    local u = date("!*t")
    tip:AddLine("UTC", self:Format(u.hour, u.min, u.sec))
    tip:AddSpacer()
    tip:AddLine(date("%A, %B %d, %Y"), nil, nil, { colors = { { 1, 1, 1 } } })
    tip:SetHint("Click to open the calendar. Shift-click for the stopwatch and alarm.")
end

