local _, ns = ...

-- The plugin tooltip, modelled on FuBar's Tablet: a title, categories of one
-- to three column lines, optional click handlers per line, and a green hint.
-- Plugins fill it in plugin:OnTooltip(tip); it is rebuilt every second while
-- shown so values stay live. Tooltips with clickable lines stay open while
-- the mouse moves from the plugin into them.

local W = ns.Widgets
local Tip = { lines = {}, rows = {} }
ns.Tip = Tip

local PAD, GAP = 10, 14
local HIDE_DELAY = 0.15

-------------------------------------------------------------------------------
-- Builder API (used by plugins)
-------------------------------------------------------------------------------

local function Add(line)
    Tip.lines[#Tip.lines + 1] = line
    if line.onClick then Tip.clickable = true end
    return line
end

function Tip:AddTitle(text, r, g, b)
    return Add({ kind = "title", text = text, color = { r or 1, g or 0.82, b or 0 } })
end

-- A category header. onClick makes it clickable (e.g. to collapse it).
function Tip:AddHeader(text, r, g, b, onClick)
    if #self.lines > 0 then self:AddSpacer() end
    return Add({ kind = "header", cols = { text }, colors = { { r or 1, g or 0.82, b or 0 } }, onClick = onClick })
end

-- opts: colors = { {r,g,b}, ... } per column (default yellow, white, white),
-- onClick(button), indent (px), small, wrap, check (shows a tick).
function Tip:AddLine(left, right, third, opts)
    opts = opts or {}
    local line = {
        kind = "line", cols = { left, right, third }, colors = opts.colors or {},
        onClick = opts.onClick, indent = opts.indent or 0, small = opts.small, wrap = opts.wrap,
        check = opts.check,
    }
    return Add(line)
end

function Tip:AddSpacer()
    return Add({ kind = "spacer" })
end

function Tip:SetHint(text)
    self.hint = text
end

-------------------------------------------------------------------------------
-- Frame
-------------------------------------------------------------------------------

local function CreateRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.cols = {}
    for i = 1, 3 do
        local fs = row:CreateFontString(nil, "OVERLAY")
        W.Font(fs, 12)
        fs:SetJustifyH(i == 1 and "LEFT" or "RIGHT")
        fs:SetWordWrap(false)
        row.cols[i] = fs
    end
    row.check = row:CreateTexture(nil, "OVERLAY")
    row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    row.check:SetSize(14, 14)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.12)
    row.highlight = hl
    row:SetScript("OnClick", function(self, button)
        if self.line and self.line.onClick then
            self.line.onClick(button)
            Tip:Refresh()
        end
    end)
    row:SetScript("OnEnter", function() Tip:CancelHide() end)
    row:SetScript("OnLeave", function() Tip:ScheduleHide() end)
    return row
end

function Tip:GetFrame()
    if self.frame then return self.frame end
    local f = W.NewFrame("Frame", UIParent, nil, "JiBarTooltip")
    f:SetFrameStrata("TOOLTIP")
    f:SetClampedToScreen(true)
    f:Hide()
    W.Backdrop(f, 0.03, 0.03, 0.05, 0.92, 0.3)
    f.hint = f:CreateFontString(nil, "OVERLAY")
    W.Font(f.hint, 11)
    f.hint:SetJustifyH("LEFT")
    f.hint:SetTextColor(0.2, 1, 0.2)
    f:SetScript("OnEnter", function() Tip:CancelHide() end)
    f:SetScript("OnLeave", function() Tip:ScheduleHide() end)
    f:SetScript("OnUpdate", function(_, elapsed) Tip:OnUpdate(elapsed) end)
    self.frame = f
    return f
end

function Tip:OnUpdate(elapsed)
    if self.hideIn then
        self.hideIn = self.hideIn - elapsed
        if self.hideIn <= 0 then
            self.hideIn = nil
            if not (self.owner and self.owner.frame:IsMouseOver()) and not self.frame:IsMouseOver() then
                self:Close()
                return
            end
        end
    end
    self.sinceRefresh = (self.sinceRefresh or 0) + elapsed
    if self.sinceRefresh >= 1 then
        self:Refresh()
    end
end

-------------------------------------------------------------------------------
-- Showing
-------------------------------------------------------------------------------

function Tip:Open(plugin)
    if not plugin.OnTooltip then return end
    self.owner = plugin
    self.hideIn = nil
    local f = self:GetFrame()
    self:Refresh()
    self:Anchor()
    f:Show()
end

function Tip:IsOpenFor(plugin)
    return self.frame and self.frame:IsShown() and self.owner == plugin
end

function Tip:Close()
    self.hideIn = nil
    self.owner = nil
    if self.frame then self.frame:Hide() end
end

-- Leaving the plugin: clickable tooltips wait a moment so the mouse can enter them.
function Tip:ScheduleHide()
    if not self.frame or not self.frame:IsShown() then return end
    if self.clickable then
        self.hideIn = HIDE_DELAY
    else
        self:Close()
    end
end

function Tip:CancelHide()
    self.hideIn = nil
end

function Tip:Anchor()
    local f, plugin = self.frame, self.owner
    local anchor = plugin.frame
    f:ClearAllPoints()
    local _, y = anchor:GetCenter()
    local below = y and y > (UIParent:GetHeight() or 768) / 2
    if below then
        f:SetPoint("TOP", anchor, "BOTTOM", 0, -4)
    else
        f:SetPoint("BOTTOM", anchor, "TOP", 0, 4)
    end
end

-- Rebuilds the content from the owning plugin.
function Tip:Refresh()
    local plugin = self.owner
    if not plugin or not self.frame then return end
    self.sinceRefresh = 0
    wipe(self.lines)
    self.hint, self.clickable = nil, false
    local ok, err = pcall(plugin.OnTooltip, plugin, self)
    if not ok then
        wipe(self.lines)
        self:AddLine("|cffff5555Error: " .. tostring(err) .. "|r", nil, nil, { wrap = true })
    end
    self:Render()
end

function Tip:Render()
    local f = self.frame
    local db = ns.db.tooltip
    local size = db.fontSize or 12
    local font = ns.FontPath("Friz")
    f:SetScale(db.scale or 1)
    f:SetBackdropColor(0.03, 0.03, 0.05, db.alpha or 0.92)
    f:EnableMouse(self.clickable)

    -- First pass: set texts and measure the columns.
    local widths = { 0, 0, 0 }
    local fullWidth = 0
    local used = 0
    for i, line in ipairs(self.lines) do
        local row = self.rows[i] or CreateRow(f)
        self.rows[i] = row
        row.line = line
        used = i
        local fsize = (line.kind == "title" and size + 2) or (line.small and size - 2) or size
        row.height = line.kind == "spacer" and 6 or fsize + 4
        local ncols = 0
        for c = 1, 3 do
            local fs = row.cols[c]
            fs:SetFont(font, fsize, "")
            local text = (line.kind == "title" and c == 1) and line.text or (line.cols and line.cols[c])
            if text ~= nil and text ~= "" then
                fs:SetText(tostring(text))
                local color = line.kind == "title" and line.color or (line.colors and line.colors[c])
                if not color then color = c == 1 and { 1, 0.82, 0 } or { 1, 1, 1 } end
                fs:SetTextColor(color[1], color[2], color[3])
                fs:Show()
                ncols = c
            else
                fs:SetText("")
                fs:Hide()
            end
        end
        row.ncols = ncols
        local indent = (line.indent or 0) + (line.check and 16 or 0)
        if ncols <= 1 and (line.kind ~= "line" or line.wrap) then
            -- Titles, headers and wrapped text span every column.
            if not line.wrap then
                fullWidth = math.max(fullWidth, (row.cols[1]:GetStringWidth() or 0) + indent)
            end
        else
            for c = 1, ncols do
                local w = row.cols[c]:GetStringWidth() or 0
                if c == 1 then w = w + indent end
                widths[c] = math.max(widths[c], w)
            end
        end
    end
    for i = used + 1, #self.rows do self.rows[i]:Hide() end

    local colsWidth = widths[1] + (widths[2] > 0 and GAP + widths[2] or 0) + (widths[3] > 0 and GAP + widths[3] or 0)
    local width = math.max(colsWidth, fullWidth, 120)
    local hintHeight = 0
    if self.hint then
        f.hint:SetFont(font, size - 1, "")
        f.hint:SetWidth(0)
        f.hint:SetText(self.hint)
        width = math.max(width, math.min(f.hint:GetStringWidth() or 0, 320))
        f.hint:SetWidth(width)
        hintHeight = (f.hint:GetStringHeight() or size) + 8
        f.hint:Show()
    else
        f.hint:Hide()
    end

    -- Second pass: place the rows.
    local y = -PAD
    for i = 1, used do
        local row, line = self.rows[i], self.lines[i]
        local indent = line.indent or 0
        local x = PAD + indent
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", f, "TOPLEFT", PAD - 2, y)
        row:SetWidth(width + 4)
        row:EnableMouse(line.onClick ~= nil)
        row.highlight:SetShown(line.onClick ~= nil)
        row.check:SetShown(line.check and true or false)
        if line.check then
            row.check:ClearAllPoints()
            row.check:SetPoint("LEFT", row, "LEFT", indent + 2, 0)
            x = x + 16
        end
        local c1 = row.cols[1]
        c1:ClearAllPoints()
        c1:SetPoint("TOPLEFT", f, "TOPLEFT", x, y - 2)
        if row.ncols <= 1 and line.wrap then
            c1:SetWordWrap(true)
            c1:SetWidth(width - (x - PAD))
            row.height = math.max(row.height, (c1:GetStringHeight() or 0) + 4)
        else
            c1:SetWordWrap(false)
            c1:SetWidth(0)
        end
        if row.ncols > 1 then
            local right = PAD + width
            for c = row.ncols, 2, -1 do
                local fs = row.cols[c]
                fs:ClearAllPoints()
                fs:SetPoint("TOPRIGHT", f, "TOPLEFT", right, y - 2)
                right = right - widths[c] - GAP
            end
        end
        row:SetHeight(row.height)
        row:Show()
        y = y - row.height
    end
    if self.hint then
        f.hint:ClearAllPoints()
        f.hint:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y - 6)
        y = y - hintHeight
    end
    f:SetSize(width + PAD * 2, -y + PAD)
end
