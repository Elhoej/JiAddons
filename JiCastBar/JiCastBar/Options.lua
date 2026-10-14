local _, ns = ...

-- Options window: one section per bar, plus Unlock and Reset buttons in the
-- footer. While the window is open the bars show a sample cast, so style
-- changes can be seen at once.

local Options = {}
ns.Options = Options

local W = ns.Widgets
local WIDTH, HEIGHT = 560, 600

local STYLE_NAMES = {}
for i, style in ipairs(ns.STYLES) do STYLE_NAMES[i] = style.name end

local function Pct(v) return math.floor(v * 100 + 0.5) .. "%" end

local function BarSection(S, L, content, key)
    local function cfg() return ns.db.bars[key] end
    local function Toggle(label, tip, field)
        return S:Checkbox(content, label, tip,
            function() return cfg()[field] end, function(v) cfg()[field] = v end)
    end

    L:Header(ns.BAR_LABELS[key] .. " cast bar")
    L:Row(Toggle("Enabled", "Show this cast bar.", "enabled"),
        S:Cycle(content, "Style", STYLE_NAMES, "One of Elva's ten cast bar styles.",
            function() return (ns.STYLE_BY_KEY[cfg().style] or ns.STYLES[1]).index end,
            function(i) cfg().style = ns.STYLES[i].key end))
    local limits = ns.SIZE_LIMITS
    L:Row(S:Slider(content, "Width", limits.width[1], limits.width[2], 1,
            function() return cfg().width end, function(v) cfg().width = v end),
        S:Slider(content, "Height", limits.height[1], limits.height[2], 1,
            function() return cfg().height end, function(v) cfg().height = v end))
    L:Row(S:Slider(content, "Scale", 0.5, 2, 0.05,
            function() return cfg().scale end, function(v) cfg().scale = v end, Pct),
        Toggle("Spell effects", "The animated spell models over the bar.", "effects"))
    local hide = Toggle("Hide Blizzard's cast bar", "Turning this off takes effect after a /reload.", "hideBlizzard")
    if key == "player" then
        L:Row(hide, Toggle("Show latency",
            "Mark the end of the cast that falls within your latency, so you know when to queue the next spell.",
            "latency"))
    else
        L:Row(hide)
    end
end

function Options:Build()
    self.set = W.NewSet(function()
        ns.Apply()
        Options:Refresh()
    end)
    local content
    self.window, content = W.CreateWindow({
        name = "JiCastBarOptionsFrame",
        title = "|cff33ff99JiCastBar|r",
        width = WIDTH,
        height = HEIGHT,
        onShow = function()
            ns.optionsOpen = true
            ns.Apply()
            Options:Refresh()
        end,
    })
    self.window:HookScript("OnHide", function()
        ns.optionsOpen = false
        ns.Apply()
    end)

    local L = W.NewLayout(content, self.window.contentWidth)
    for _, key in ipairs(ns.BAR_KEYS) do BarSection(self.set, L, content, key) end
    L:Note("The bars show a sample cast while this window is open. Unlock them to drag them into place. " ..
        "The target bar can't show the latency mark or check its own end: target casts reach addons as secret values.")
    content:SetHeight(-L.y + 16)

    self.lockButton = W.Button(self.window, "Unlock", 110, function()
        ns.SetLocked(not ns.db.locked)
    end)
    self.lockButton:SetPoint("BOTTOMLEFT", 14, 14)
    local reset = W.Button(self.window, "Reset positions", 130, function() ns.ResetPositions() end)
    reset:SetPoint("LEFT", self.lockButton, "RIGHT", 8, 0)

    self.reloadNote = W.Font(self.window:CreateFontString(nil, "OVERLAY"), 12)
    self.reloadNote:SetPoint("LEFT", reset, "RIGHT", 12, 0)
    self.reloadNote:SetTextColor(1, 0.3, 0.3)
    self.reloadNote:SetText("/reload to bring back Blizzard's bar.")
end

function Options:Toggle()
    if not self.window then self:Build() end
    self.window:SetShown(not self.window:IsShown())
end

function Options:Refresh()
    if not self.set then return end
    self.set:Refresh()
    self.lockButton:SetText(ns.db.locked and "Unlock" or "Lock")
    local pending = false
    for _, key in ipairs(ns.BAR_KEYS) do
        pending = pending or ns.BlizzardRestorePending(key)
    end
    self.reloadNote:SetShown(pending)
end

function Options:Init()
    W.RegisterSettingsPanel({
        title = ns.title,
        description = "Elva's cast bars for the player and target. Type /jcb to open the options.",
        icon = 134400,
        open = function() Options:Toggle() end,
    })
end
