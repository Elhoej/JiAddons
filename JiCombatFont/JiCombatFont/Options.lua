local _, ns = ...

-- Options window: a font list each for outgoing and incoming damage, with
-- letter-spacing sliders and the outgoing size below. Every entry is drawn
-- in its own font, so the lists double as previews.

local Options = {}
ns.Options = Options

local W = ns.Widgets
local WIDTH, HEIGHT = 600, 690
local PICKER_WIDTH = 250
local ROW_HEIGHT = 22
local LIST_TOP = 112

-- A FontString without a font errors on SetText, so fall back to the UI font
-- if a font file fails to load.
local function SetFontSafe(fs, path, size)
    if not fs:SetFont(path, size, "OUTLINE") then W.Font(fs, size, "OUTLINE") end
end

local function SampleFont(kind)
    return ns.FontPath(ns.db[kind], kind, ns.db[kind .. "Spacing"])
end

-- A font list bound to ns.db[kind]: title, note, a sample in the chosen font
-- and one row per font. Returns a widget-set holder with :Refresh().
local function FontPicker(set, parent, kind, label, note, sample, r, g, b)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(PICKER_WIDTH, LIST_TOP + #ns.FONTS * ROW_HEIGHT)

    local title = W.Font(holder:CreateFontString(nil, "OVERLAY"), 14)
    title:SetPoint("TOPLEFT", 2, 0)
    title:SetTextColor(1, 0.82, 0)
    title:SetText(label)

    local noteText = W.Font(holder:CreateFontString(nil, "OVERLAY"), 11)
    noteText:SetPoint("TOPLEFT", 2, -20)
    noteText:SetWidth(PICKER_WIDTH - 4)
    noteText:SetJustifyH("LEFT")
    noteText:SetTextColor(0.7, 0.7, 0.7)
    noteText:SetText(note)

    local box = W.NewFrame("Frame", holder)
    box:SetPoint("TOPLEFT", 0, -54)
    box:SetSize(PICKER_WIDTH, 50)
    W.Backdrop(box, 0.02, 0.02, 0.02, 0.9)
    local sampleText = box:CreateFontString(nil, "OVERLAY")
    sampleText:SetPoint("CENTER")
    holder.sample = sampleText

    local rows = {}
    for i, font in ipairs(ns.FONTS) do
        local row = CreateFrame("Button", nil, holder)
        row:SetPoint("TOPLEFT", 0, -LIST_TOP - (i - 1) * ROW_HEIGHT)
        row:SetSize(PICKER_WIDTH, ROW_HEIGHT - 2)
        local selected = row:CreateTexture(nil, "BACKGROUND")
        selected:SetAllPoints()
        selected:SetColorTexture(1, 0.82, 0, 0.18)
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        local text = row:CreateFontString(nil, "OVERLAY")
        SetFontSafe(text, ns.FontPath(font.key, kind), 15)
        text:SetPoint("LEFT", 8, 0)
        text:SetText(font.name)
        row:SetScript("OnClick", function()
            ns.db[kind] = font.key
            set.onChange()
        end)
        row.key, row.selected, row.text = font.key, selected, text
        rows[i] = row
    end
    holder.rows = rows

    function holder:Refresh()
        local key = ns.db[kind]
        for _, row in ipairs(rows) do
            local isSelected = row.key == key
            row.selected:SetShown(isSelected)
            if isSelected then row.text:SetTextColor(1, 0.82, 0) else row.text:SetTextColor(1, 1, 1) end
        end
        SetFontSafe(sampleText, SampleFont(kind), 28)
        sampleText:SetTextColor(r, g, b)
        sampleText:SetText(sample)
    end
    return set:Add(holder)
end

-- Spacing slider over the indexes of ns.SPACINGS, so it only stops on
-- spacings that have font files.
local function SpacingSlider(set, parent, kind)
    local key = kind .. "Spacing"
    local function get()
        for i, v in ipairs(ns.SPACINGS) do
            if v == ns.db[key] then return i end
        end
        for i, v in ipairs(ns.SPACINGS) do
            if v == 0 then return i end
        end
    end
    local function fmt(i)
        local v = ns.SPACINGS[i] or 0
        if v == 0 then return "Normal" end
        return (v > 0 and "+" or "") .. v .. "%"
    end
    return set:Slider(parent, "Letter spacing", 1, #ns.SPACINGS, 1, get,
        function(i) ns.db[key] = ns.SPACINGS[i] end, fmt)
end

local function Pct(v) return math.floor(v * 100 + 0.5) .. "%" end

-- Placeholder holder for when the outgoing scale CVar doesn't exist.
local function Unavailable(parent, text)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(260, 40)
    local fs = W.Font(holder:CreateFontString(nil, "OVERLAY"), 11)
    fs:SetPoint("TOPLEFT", 2, 0)
    fs:SetWidth(240)
    fs:SetJustifyH("LEFT")
    fs:SetTextColor(0.7, 0.7, 0.7)
    fs:SetText(text)
    return holder
end

function Options:Build()
    self.set = W.NewSet(function()
        ns.Apply()
        Options:Refresh()
    end)
    local S = self.set
    local content
    self.window, content = W.CreateWindow({
        name = "JiCombatFontOptionsFrame",
        title = "|cff33ff99JiCombatFont|r",
        width = WIDTH,
        height = HEIGHT,
        onShow = function() Options:Refresh() end,
    })
    local L = W.NewLayout(content, self.window.contentWidth)
    self.outgoing = FontPicker(S, content, "outgoing", "Outgoing damage",
        "Numbers above whatever you hit or heal. Font and spacing changes show after you relog.",
        "12,345", 1, 1, 1)
    self.incoming = FontPicker(S, content, "incoming", "Incoming damage",
        "Scrolling combat text around your character. Needs scrolling combat text for self turned on.",
        "-1,234", 1, 0.1, 0.1)
    L:Row(self.outgoing, self.incoming)

    self.outgoingSpacing = SpacingSlider(S, content, "outgoing")
    self.incomingSpacing = SpacingSlider(S, content, "incoming")
    L:Row(self.outgoingSpacing, self.incomingSpacing)

    -- Outgoing size is the client's world text scale, not part of the font.
    -- Incoming has none: Blizzard sets the height of every message itself.
    if ns.GetOutgoingScale() then
        self.outgoingSize = S:Slider(content, "Text size", 0.5, 2.5, 0.1,
            function() return ns.GetOutgoingScale() or 1 end, ns.SetOutgoingScale, Pct)
    else
        self.outgoingSize = Unavailable(content, "This client has no setting for the size of these numbers.")
    end
    L:Row(self.outgoingSize)
    L:Note("Letter spacing doesn't apply to Blizzard's default font. Incoming text has no size setting: Blizzard sets the size of every message itself.")
    content:SetHeight(-L.y + 16)

    local relog = W.Font(self.window:CreateFontString(nil, "OVERLAY"), 12)
    relog:SetPoint("BOTTOMLEFT", 16, 18)
    relog:SetTextColor(1, 0.3, 0.3)
    relog:SetText("Relog to see the new outgoing font.")
    self.relogNote = relog
end

function Options:Toggle()
    if not self.window then self:Build() end
    self.window:SetShown(not self.window:IsShown())
end

function Options:Refresh()
    if not self.set then return end
    self.set:Refresh()
    self.relogNote:SetShown(ns.OutgoingPending())
end

function Options:Init()
    W.RegisterSettingsPanel({
        title = ns.title,
        description = "Choose the fonts for combat text. Type /jcf to open the options.",
        icon = 134400,
        open = function() Options:Toggle() end,
    })
end
