local _, ns = ...

-- PerformanceFu: framerate, latency, addon memory and how fast it grows.
-- The tooltip adds bandwidth and the addons using the most memory.

local floor = math.floor

local P = ns.RegisterPlugin({
    id = "Performance",
    title = "Performance",
    icon = ns.MEDIA .. "Icons\\performance",
    place = { bar = 1, side = "RIGHT", order = 3 },
    defaults = {
        showFramerate = true,
        showLatency = true,
        latency = "WORLD",
        showMemory = true,
        showRate = true,
        topAddons = 10,
    },
})

P.options = {
    { type = "toggle", key = "showFramerate", label = "Show framerate" },
    { type = "toggle", key = "showLatency", label = "Show latency" },
    { type = "select", key = "latency", label = "Latency shown", values = {
        { key = "WORLD", name = "World" }, { key = "HOME", name = "Home" }, { key = "MAX", name = "Highest of both" },
    } },
    { type = "toggle", key = "showMemory", label = "Show memory usage" },
    { type = "toggle", key = "showRate", label = "Show memory growth rate" },
    { type = "range", key = "topAddons", label = "Addons listed in the tooltip", min = 0, max = 30, step = 1,
      presets = { 0, 5, 10, 20, 30 } },
    { type = "execute", label = "Collect garbage now", func = function(p) p:CollectGarbage() end },
}

-- Memory in KiB, sampled once a second; history[1] is the newest.
local history = {}
local initialMemory, startTime

local function Memory()
    return collectgarbage("count")
end

function P:OnEnable()
    initialMemory = Memory()
    startTime = GetTime()
    for i = 1, 11 do history[i] = initialMemory end
end

function P:OnTick()
    table.insert(history, 1, Memory())
    history[12] = nil
    self:UpdateText()
end

-- KiB per second over the last ten seconds.
function P:Rate()
    local newest, oldest = history[1], history[#history]
    if not newest or not oldest or #history < 2 then return 0 end
    return (newest - oldest) / (#history - 1)
end

function P:Latency()
    local _, _, home, world = GetNetStats()
    home, world = home or 0, world or home or 0
    if self.db.latency == "HOME" then return home end
    if self.db.latency == "MAX" then return math.max(home, world) end
    return world
end

function P:UpdateText()
    local parts = {}
    local db = self.db
    if db.showFramerate then
        parts[#parts + 1] = floor(GetFramerate() + 0.5) .. "fps"
    end
    if db.showLatency then
        parts[#parts + 1] = floor(self:Latency()) .. "ms"
    end
    if db.showMemory then
        local mem = history[1] or Memory()
        parts[#parts + 1] = string.format("|c%s%.1f|r MiB", ns.ThresholdHex(mem, 400 * 1024, 300 * 1024, 200 * 1024, 100 * 1024, 50 * 1024), mem / 1024)
    end
    if db.showRate then
        local rate = self:Rate()
        parts[#parts + 1] = string.format("|c%s%.1f|r KiB/s", ns.ThresholdHex(rate, 300, 100, 30, 10, 0), rate)
    end
    self:SetText(ns.Join(parts))
end

function P:CollectGarbage()
    local before = Memory()
    collectgarbage("collect")
    local after = Memory()
    ns.Print(string.format("Freed %.1f MiB of addon memory.", (before - after) / 1024))
    for i = 1, #history do history[i] = after end
    initialMemory, startTime = after, GetTime()
    self:UpdateText()
end

function P:OnTooltip(tip)
    tip:AddTitle("Performance")
    local fps = GetFramerate()
    tip:AddLine("Framerate", string.format("%.1f fps", fps), nil,
        { colors = { nil, { ns.ThresholdColor(fps / 60) } } })

    local inKB, outKB, home, world = GetNetStats()
    tip:AddHeader("Network")
    tip:AddLine("Latency (home)", string.format("%d ms", home or 0), nil,
        { colors = { nil, { ns.ThresholdColor(home or 0, 1000, 500, 250, 100, 0) } } })
    tip:AddLine("Latency (world)", string.format("%d ms", world or 0), nil,
        { colors = { nil, { ns.ThresholdColor(world or 0, 1000, 500, 250, 100, 0) } } })
    tip:AddLine("Bandwidth in", string.format("%.2f KiB/s", inKB or 0))
    tip:AddLine("Bandwidth out", string.format("%.2f KiB/s", outKB or 0))

    local mem = history[1] or Memory()
    local rate = self:Rate()
    local elapsed = math.max(1, GetTime() - (startTime or GetTime()))
    local average = (mem - (initialMemory or mem)) / elapsed
    tip:AddHeader("Addon memory")
    tip:AddLine("Current", string.format("%.1f MiB", mem / 1024))
    tip:AddLine("At login", string.format("%.1f MiB", (initialMemory or mem) / 1024))
    tip:AddLine("Growth (last 10 s)", string.format("%.1f KiB/s", rate), nil,
        { colors = { nil, { ns.ThresholdColor(rate, 300, 100, 30, 10, 0) } } })
    tip:AddLine("Growth (average)", string.format("%.1f KiB/s", average))

    local count = self.db.topAddons or 0
    if count > 0 and UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
        -- UpdateAddOnMemoryUsage is slow with many addons: refresh at most every 10 s.
        if not self.addonMemoryAt or GetTime() - self.addonMemoryAt > 10 then
            self.addonMemoryAt = GetTime()
            UpdateAddOnMemoryUsage()
            local list = {}
            local num = (C_AddOns and C_AddOns.GetNumAddOns or GetNumAddOns)()
            for i = 1, num do
                local name = (C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo)(i)
                local kb = name and GetAddOnMemoryUsage(i) or 0
                if kb > 0 then list[#list + 1] = { name = name, kb = kb } end
            end
            table.sort(list, function(a, b) return a.kb > b.kb end)
            self.addonMemory = list
        end
        tip:AddHeader("Addons using the most memory")
        for i = 1, math.min(count, #self.addonMemory) do
            local a = self.addonMemory[i]
            local text = a.kb >= 1024 and string.format("%.2f MiB", a.kb / 1024) or string.format("%.0f KiB", a.kb)
            tip:AddLine(a.name, text, nil, { colors = { { 1, 1, 1 }, { ns.ThresholdColor(a.kb, 20480, 10240, 5120, 2048, 512) } } })
        end
    end
    tip:SetHint("Click to collect garbage.")
end

function P:OnClick()
    self:CollectGarbage()
end
