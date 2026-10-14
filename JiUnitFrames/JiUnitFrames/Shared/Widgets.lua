-- Embedded copy of JiAddons/shared/Widgets.lua. Do not edit here:
-- edit shared/Widgets.lua and run tools/sync-shared.sh.
local _, ns = ...

-- Options UI toolkit. Widgets are built from plain frames and long-standing
-- textures instead of Blizzard templates (UIDropDownMenu, OptionsSliderTemplate,
-- InputBoxTemplate...) that move or disappear between client versions.
-- Only UIPanelButtonTemplate and UIPanelCloseButton are relied on.

local W = {}
ns.Widgets = W

W.WHITE = "Interface\\Buttons\\WHITE8x8"
W.FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local WHITE, FONT = W.WHITE, W.FONT

-- A FontString must have a font before SetText is called.
function W.Font(fs, size, flags)
    fs:SetFont(FONT, size or 12, flags or "")
    return fs
end

-- 1px bordered flat backdrop. The frame must use BackdropTemplate (see NewFrame).
function W.Backdrop(frame, r, g, b, a, edge)
    if not frame.SetBackdrop then return end
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    frame:SetBackdropColor(r, g, b, a)
    local e = edge or 0.25
    frame:SetBackdropBorderColor(e, e, e, 1)
end

-- CreateFrame that always adds BackdropTemplate when the client has it.
function W.NewFrame(kind, parent, template, name)
    local backdrop = BackdropTemplateMixin and "BackdropTemplate" or nil
    if template and backdrop then
        template = template .. "," .. backdrop
    end
    return CreateFrame(kind, name, parent, template or backdrop)
end

function W.AttachTooltip(frame, title, text)
    if not text then return end
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(title, 1, 1, 1)
        GameTooltip:AddLine(text, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
end

function W.Button(parent, label, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 110, 24)
    b:SetText(label)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

-- Opens the colour picker for an { r, g, b } array, editing it in place.
function W.OpenColorPicker(color, onChange)
    local r, g, b = color[1], color[2], color[3]
    local function Set(nr, ng, nb)
        color[1], color[2], color[3] = nr, ng, nb
        onChange()
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b,
            hasOpacity = false,
            swatchFunc = function() Set(ColorPickerFrame:GetColorRGB()) end,
            cancelFunc = function() Set(r, g, b) end,
        })
    else
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = { r, g, b }
        ColorPickerFrame.func = function() Set(ColorPickerFrame:GetColorRGB()) end
        ColorPickerFrame.cancelFunc = function() Set(r, g, b) end
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end
end

-------------------------------------------------------------------------------
-- Widget sets: settings-bound widgets that call onChange() after every edit
-- and can all be refreshed from the saved variables with set:Refresh().
-- Every widget is a holder frame with a fixed height and :Refresh().
-------------------------------------------------------------------------------

local Set = {}
Set.__index = Set

function W.NewSet(onChange)
    return setmetatable({ widgets = {}, onChange = onChange or function() end }, Set)
end

function Set:Add(holder)
    self.widgets[#self.widgets + 1] = holder
    return holder
end

function Set:Refresh()
    for _, w in ipairs(self.widgets) do w:Refresh() end
end

function Set:Checkbox(parent, label, tip, get, set)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(260, 26)
    local cb = CreateFrame("CheckButton", nil, holder)
    cb:SetSize(24, 24)
    cb:SetPoint("LEFT")
    cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    local text = W.Font(holder:CreateFontString(nil, "OVERLAY"), 12)
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(label)
    cb:SetScript("OnClick", function(btn)
        set(btn:GetChecked() and true or false)
        self.onChange()
    end)
    W.AttachTooltip(cb, label, tip)
    holder.check = cb
    function holder:Refresh() cb:SetChecked(get() and true or false) end
    return self:Add(holder)
end

-- fmt(value) optionally formats the displayed value (e.g. percentages).
function Set:Slider(parent, label, minV, maxV, step, get, set, fmt)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(260, 40)
    local title = W.Font(holder:CreateFontString(nil, "OVERLAY"), 12)
    title:SetPoint("TOPLEFT", 2, 0)
    title:SetText(label)
    local value = W.Font(holder:CreateFontString(nil, "OVERLAY"), 12)
    value:SetPoint("TOPRIGHT", -22, 0)
    value:SetTextColor(1, 0.82, 0)

    local s = W.NewFrame("Slider", holder)
    s:SetOrientation("HORIZONTAL")
    s:SetPoint("TOPLEFT", 2, -18)
    s:SetSize(236, 12)
    W.Backdrop(s, 0.05, 0.05, 0.05, 0.9)
    s:SetThumbTexture(WHITE)
    local thumb = s:GetThumbTexture()
    thumb:SetSize(10, 16)
    thumb:SetVertexColor(1, 0.82, 0, 1)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s:EnableMouseWheel(true)

    local function Show(v)
        value:SetText(fmt and fmt(v) or tostring(v))
    end
    local updating = false
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / step + 0.5) * step
        if step < 1 then v = tonumber(string.format("%.2f", v)) end
        Show(v)
        if updating then return end
        if v ~= get() then
            set(v)
            self.onChange()
        end
    end)
    s:SetScript("OnMouseWheel", function(slider, delta)
        slider:SetValue(math.max(minV, math.min(maxV, slider:GetValue() + delta * step)))
    end)
    holder.slider = s
    function holder:Refresh()
        updating = true
        s:SetValue(get())
        Show(get())
        updating = false
    end
    return self:Add(holder)
end

-- A dropdown replacement: a button that cycles through values (1-based index).
function Set:Cycle(parent, label, values, tip, get, set)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(260, 44)
    local title = W.Font(holder:CreateFontString(nil, "OVERLAY"), 12)
    title:SetPoint("TOPLEFT", 2, 0)
    title:SetText(label)
    local b = W.NewFrame("Button", holder)
    b:SetPoint("TOPLEFT", 2, -16)
    b:SetSize(236, 22)
    W.Backdrop(b, 0.12, 0.12, 0.12, 0.95)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local text = W.Font(b:CreateFontString(nil, "OVERLAY"), 12)
    text:SetPoint("LEFT", 8, 0)
    text:SetPoint("RIGHT", -20, 0)
    text:SetJustifyH("LEFT")
    local arrow = W.Font(b:CreateFontString(nil, "OVERLAY"), 12)
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetText("|cffffd100>|r")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)
    b:SetScript("OnClick", function(_, button)
        local v = get() + (button == "RightButton" and -1 or 1)
        if v > #values then v = 1 elseif v < 1 then v = #values end
        set(v)
        self.onChange()
        holder:Refresh()
    end)
    W.AttachTooltip(b, label, (tip and (tip .. "\n\n") or "") .. "Click for next, right-click for previous.")
    holder.button = b
    function holder:Refresh() text:SetText(values[get()] or "?") end
    return self:Add(holder)
end

-- Text or number input. With numeric, only values >= 0 are accepted.
-- get/set may be nil for a free-standing input (read holder.box yourself).
function Set:Input(parent, label, width, tip, get, set, numeric)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width + 4, 44)
    local title = W.Font(holder:CreateFontString(nil, "OVERLAY"), 12)
    title:SetPoint("TOPLEFT", 2, 0)
    title:SetText(label)
    local box = W.NewFrame("EditBox", holder)
    box:SetPoint("TOPLEFT", 2, -16)
    box:SetSize(width, 22)
    W.Backdrop(box, 0.02, 0.02, 0.02, 0.9)
    box:SetAutoFocus(false)
    box:SetTextInsets(6, 6, 0, 0)
    W.Font(box, 12)
    box:SetTextColor(1, 1, 1)
    local widgetSet = self
    local function Commit(editBox)
        if not set then return end
        local text = editBox:GetText()
        if numeric then
            local v = tonumber(text)
            if v and v >= 0 then
                set(v)
                widgetSet.onChange()
            end
        else
            set(text)
            widgetSet.onChange()
        end
        holder:Refresh()
    end
    box:SetScript("OnEnterPressed", function(editBox)
        Commit(editBox)
        editBox:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", Commit)
    box:SetScript("OnEscapePressed", function(editBox)
        holder:Refresh()
        editBox:ClearFocus()
    end)
    W.AttachTooltip(box, label, tip)
    holder.box = box
    function holder:Refresh()
        if get then box:SetText(tostring(get() or "")) end
        box:SetCursorPosition(0)
    end
    return self:Add(holder)
end

-- getColor returns the { r, g, b } array to edit in place.
function Set:ColorSwatch(parent, label, getColor)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(260, 26)
    local b = W.NewFrame("Button", holder)
    b:SetSize(22, 22)
    b:SetPoint("LEFT", 2, 0)
    W.Backdrop(b, 1, 1, 1, 1, 0.6)
    local text = W.Font(holder:CreateFontString(nil, "OVERLAY"), 12)
    text:SetPoint("LEFT", b, "RIGHT", 8, 0)
    text:SetText(label)
    b:SetScript("OnClick", function()
        W.OpenColorPicker(getColor(), function()
            holder:Refresh()
            self.onChange()
        end)
    end)
    holder.button = b
    function holder:Refresh()
        local c = getColor()
        b:SetBackdropColor(c[1], c[2], c[3], 1)
    end
    return self:Add(holder)
end

-------------------------------------------------------------------------------
-- Layout: stacks headers, notes and rows of up to three widgets downwards.
-------------------------------------------------------------------------------

local Layout = {}
Layout.__index = Layout

function W.NewLayout(content, width)
    return setmetatable({ content = content, width = width or content:GetWidth(), y = -8 }, Layout)
end

function Layout:Header(text)
    self.y = self.y - 10
    local fs = W.Font(self.content:CreateFontString(nil, "OVERLAY"), 14)
    fs:SetPoint("TOPLEFT", 12, self.y)
    fs:SetText(text)
    fs:SetTextColor(1, 0.82, 0)
    local line = self.content:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.25)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 12, self.y - 20)
    line:SetPoint("TOPRIGHT", -12, self.y - 20)
    self.y = self.y - 28
end

function Layout:Note(text)
    local fs = W.Font(self.content:CreateFontString(nil, "OVERLAY"), 11)
    fs:SetPoint("TOPLEFT", 16, self.y)
    fs:SetWidth(self.width - 32)
    fs:SetJustifyH("LEFT")
    fs:SetTextColor(0.7, 0.7, 0.7)
    fs:SetText(text)
    self.y = self.y - (fs:GetStringHeight() or 14) - 8
end

-- Places 1-2 widgets in two columns, or 3 widgets in three columns.
function Layout:Row(...)
    local n = select("#", ...)
    local colWidth = (self.width - 24) / (n == 3 and 3 or 2)
    local height = 0
    for i = 1, n do
        local w = select(i, ...)
        if w then
            w:SetPoint("TOPLEFT", self.content, "TOPLEFT", 16 + (i - 1) * colWidth, self.y)
            height = math.max(height, w:GetHeight())
        end
    end
    self.y = self.y - height - 6
end

-------------------------------------------------------------------------------
-- Window: movable, ESC-closable dialog with a scrolling content frame and a
-- 48px footer for buttons.
--   opts.name   global frame name (needed for ESC via UISpecialFrames)
--   opts.title, opts.width, opts.height, opts.onShow
-- Returns window, content. Call window:UpdateScroll() after changing the
-- content height; window.contentWidth is the usable width.
-------------------------------------------------------------------------------

function W.CreateWindow(opts)
    local width, height = opts.width or 640, opts.height or 580
    local window = W.NewFrame("Frame", UIParent, nil, opts.name)
    window:SetSize(width, height)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    W.Backdrop(window, 0.06, 0.06, 0.06, 0.96, 0.35)
    window:Hide()

    if opts.name and UISpecialFrames then
        table.insert(UISpecialFrames, opts.name)
    end

    local title = W.Font(window:CreateFontString(nil, "OVERLAY"), 16, "OUTLINE")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText(opts.title or "")
    window.title = title

    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    window.contentWidth = width - 48
    local scroll = CreateFrame("ScrollFrame", nil, window)
    scroll:SetPoint("TOPLEFT", 8, -40)
    scroll:SetPoint("BOTTOMRIGHT", -28, 48)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(window.contentWidth, 800)
    scroll:SetScrollChild(content)

    local bar = W.NewFrame("Slider", window)
    bar:SetOrientation("VERTICAL")
    bar:SetPoint("TOPRIGHT", -10, -40)
    bar:SetPoint("BOTTOMRIGHT", -10, 48)
    bar:SetWidth(10)
    W.Backdrop(bar, 0.02, 0.02, 0.02, 0.8)
    bar:SetThumbTexture(WHITE)
    bar:GetThumbTexture():SetSize(10, 40)
    bar:GetThumbTexture():SetVertexColor(0.5, 0.5, 0.5, 1)
    bar:SetValueStep(1)
    bar:SetScript("OnValueChanged", function(_, v) scroll:SetVerticalScroll(v) end)

    function window:UpdateScroll()
        local range = math.max(0, content:GetHeight() - scroll:GetHeight())
        bar:SetMinMaxValues(0, range)
        bar:SetShown(range > 0)
        if bar:GetValue() > range then bar:SetValue(range) end
    end

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        local minV, maxV = bar:GetMinMaxValues()
        bar:SetValue(math.max(minV, math.min(maxV, bar:GetValue() - delta * 60)))
    end)
    scroll:SetScript("OnSizeChanged", function() window:UpdateScroll() end)

    window:SetScript("OnShow", function()
        if opts.onShow then opts.onShow() end
        window:UpdateScroll()
    end)
    return window, content
end

-------------------------------------------------------------------------------
-- Entry points: a small page under Options -> AddOns with an "Open options"
-- button, plus the minimap addon compartment.
--   opts.title, opts.description, opts.icon (fileID), opts.open(), opts.toggle()
-------------------------------------------------------------------------------

function W.RegisterSettingsPanel(opts)
    local panel = CreateFrame("Frame")
    panel.name = opts.title
    local title = W.Font(panel:CreateFontString(nil, "OVERLAY"), 16, "OUTLINE")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(opts.title)
    local desc = W.Font(panel:CreateFontString(nil, "OVERLAY"), 12)
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText(opts.description or "")
    local open = W.Button(panel, "Open options", 140, function()
        if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then
            HideUIPanel(SettingsPanel)
        end
        opts.open()
    end)
    open:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)

    pcall(function()
        if Settings and Settings.RegisterCanvasLayoutCategory then
            local category = Settings.RegisterCanvasLayoutCategory(panel, opts.title)
            Settings.RegisterAddOnCategory(category)
        elseif InterfaceOptions_AddCategory then
            InterfaceOptions_AddCategory(panel)
        end
    end)

    if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
        pcall(AddonCompartmentFrame.RegisterAddon, AddonCompartmentFrame, {
            text = opts.title,
            icon = opts.icon,
            notCheckable = true,
            func = opts.toggle or opts.open,
        })
    end
    return panel
end
