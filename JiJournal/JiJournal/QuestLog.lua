local _, ns = ...

-- A standalone quest log in the style of WideQuestLogPlus: quests grouped by
-- zone on the left, the parchment details on the right, and the classic
-- Abandon / Share / Exit buttons. It takes over L, the micro menu button and
-- the objective tracker's "open quest" clicks, which in Forever otherwise
-- open the quest panel docked to the world map.
--
-- Details are drawn by Blizzard's QuestInfo_Display, the same code its own
-- quest windows use, so rewards, spells, item tooltips and links all work.

local W = ns.Widgets
local QuestLog = {}
ns.QuestLog = QuestLog

local WIDTH, HEIGHT = 690, 500
local TOP, BOTTOM = 60, 26          -- space for the title bar and the button bar
local LIST_WIDTH = 334
local ROW_HEIGHT = 16
local NUM_ROWS = math.floor((HEIGHT - TOP - BOTTOM - 8) / ROW_HEIGHT)
local HEADER_COLOR = { 0.7, 0.7, 0.7 }
local BOOK_ICON = "Interface\\QuestFrame\\UI-QuestLog-BookIcon"
local HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestTitleHighlight"

local function db() return ns.db.questLog end

-- pcall wrapper for Blizzard APIs that may be missing or change shape.
local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if not ok then
        ns.Debug(a)
        return nil
    end
    return a, b, c
end

-------------------------------------------------------------------------------
-- Quest data
-------------------------------------------------------------------------------

local function IsComplete(questID)
    return Try(C_QuestLog.IsComplete, questID) or Try(C_QuestLog.ReadyForTurnIn, questID)
end

local function IsWatched(questID)
    if QuestUtils_IsQuestWatched then return Try(QuestUtils_IsQuestWatched, questID) end
    return Try(C_QuestLog.GetQuestWatchType, questID) ~= nil
end

local function DifficultyColor(info)
    local c = Try(GetQuestDifficultyColor, info.difficultyLevel or info.level, info.isScaling, info.questID)
    if type(c) == "table" and c.r then return c.r, c.g, c.b end
    return 1, 0.82, 0
end

-- "[14+] " like Forever's own quest log, with "+" for elite quests.
local function LevelPrefix(info)
    if not db().showLevels then return "" end
    local elite = Try(C_QuestLog.IsEliteQuest, info.questID) and "+" or ""
    return "[" .. (info.difficultyLevel or info.level or 0) .. elite .. "] "
end

-- Right-hand label: completion state first, then the quest type.
local function StateLabel(questID)
    if Try(C_QuestLog.IsFailed, questID) then return "(" .. (FAILED or "Failed") .. ")" end
    if IsComplete(questID) then return "(" .. (COMPLETE or "Complete") .. ")" end
    if QuestUtilsOverrides and QuestUtilsOverrides.GetQuestTagText then
        return Try(QuestUtilsOverrides.GetQuestTagText, questID) or ""
    end
    return ""
end

-- Flattens the log into rows: headers, and the quests of expanded headers.
-- Collapsing is JiJournal's own (db().collapsed), so it never fights the
-- collapse state Blizzard keeps for its docked quest log.
function QuestLog:BuildEntries()
    local entries, collapsedByBlizzard = {}, {}
    local numEntries = C_QuestLog.GetNumQuestLogEntries() or 0
    local header
    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHidden then
            if info.isHeader then
                header = { isHeader = true, title = info.title, collapsed = db().collapsed[info.title], count = 0 }
                entries[#entries + 1] = header
                if info.isCollapsed then collapsedByBlizzard[#collapsedByBlizzard + 1] = i end
            elseif not info.isTask and not info.isBounty then
                if header then header.count = header.count + 1 end
                if not (header and header.collapsed) then
                    entries[#entries + 1] = { questID = info.questID, info = info }
                end
            end
        end
    end
    -- Quests under a collapsed Blizzard header may be left out, so expand
    -- those; QUEST_LOG_UPDATE then rebuilds the list.
    for i = #collapsedByBlizzard, 1, -1 do Try(ExpandQuestHeader, collapsedByBlizzard[i]) end

    local out = {}
    for _, e in ipairs(entries) do
        if not e.isHeader or e.count > 0 then out[#out + 1] = e end
    end
    return out
end

-- Quest IDs in log order, collapsed or not; used to pick a selection.
local function AllQuestIDs()
    local ids = {}
    for i = 1, C_QuestLog.GetNumQuestLogEntries() or 0 do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and not info.isHidden and not info.isTask and not info.isBounty then
            ids[#ids + 1] = info.questID
        end
    end
    return ids
end

-------------------------------------------------------------------------------
-- Scroll bars (plain sliders, like the shared options window)
-------------------------------------------------------------------------------

local function NewScrollBar(parent, onChange)
    local bar = W.NewFrame("Slider", parent)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(10)
    W.Backdrop(bar, 0.02, 0.02, 0.02, 0.6)
    bar:SetThumbTexture(W.WHITE)
    bar:GetThumbTexture():SetSize(10, 40)
    bar:GetThumbTexture():SetVertexColor(0.5, 0.5, 0.5, 1)
    bar:SetValueStep(1)
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)
    bar:SetScript("OnValueChanged", function(_, v) onChange(math.floor(v + 0.5)) end)
    function bar:SetRange(range)
        range = math.max(0, range)
        self:SetMinMaxValues(0, range)
        self:SetShown(range > 0)
        if self:GetValue() > range then self:SetValue(range) end
    end
    function bar:Scroll(delta, step)
        local minV, maxV = self:GetMinMaxValues()
        self:SetValue(math.max(minV, math.min(maxV, self:GetValue() - delta * step)))
    end
    return bar
end

-------------------------------------------------------------------------------
-- List
-------------------------------------------------------------------------------

function QuestLog:OnRowClick(row, button)
    local e = row.entry
    if not e then return end
    if e.isHeader then
        db().collapsed[e.title] = (not e.collapsed) or nil
        self:Refresh()
        return
    end
    if IsShiftKeyDown() then
        -- Into the chat box if one is open, otherwise track or untrack.
        local link = Try(GetQuestLink, e.questID)
        local insert = ChatFrameUtil and ChatFrameUtil.InsertLink or ChatEdit_InsertLink
        if not (link and Try(insert, link)) then self:ToggleTracking(e.questID) end
        return
    end
    self:Select(e.questID)
end

function QuestLog:CreateRow(parent, i)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 4, -4 - (i - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.selected = row:CreateTexture(nil, "BACKGROUND")
    row.selected:SetTexture(HIGHLIGHT)
    row.selected:SetBlendMode("ADD")
    row.selected:SetAllPoints()
    row.selected:Hide()
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(HIGHLIGHT)
    hl:SetBlendMode("ADD")
    hl:SetAllPoints()
    row.highlight = hl

    row.expand = row:CreateTexture(nil, "ARTWORK")
    row.expand:SetSize(14, 14)
    row.expand:SetPoint("LEFT", 2, 0)

    row.title = W.Font(row:CreateFontString(nil, "OVERLAY"), 12)
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)
    row.state = W.Font(row:CreateFontString(nil, "OVERLAY"), 12)
    row.state:SetJustifyH("RIGHT")
    row.state:SetPoint("RIGHT", -2, 0)
    row.check = row:CreateTexture(nil, "OVERLAY")
    row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    row.check:SetSize(14, 14)
    row.check:SetPoint("LEFT", row.title, "RIGHT", 1, 0)

    row:SetScript("OnClick", function(r, button) QuestLog:OnRowClick(r, button) end)
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(_, delta) QuestLog.listBar:Scroll(delta, 3) end)
    return row
end

function QuestLog:UpdateRow(row, e)
    row.entry = e
    if not e then
        row:Hide()
        return
    end
    row:Show()
    row.title:ClearAllPoints()
    if e.isHeader then
        row.expand:Show()
        row.expand:SetTexture(e.collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
        row.title:SetPoint("LEFT", 20, 0)
        row.title:SetWidth(LIST_WIDTH - 50)
        row.title:SetText(e.title)
        row.title:SetTextColor(HEADER_COLOR[1], HEADER_COLOR[2], HEADER_COLOR[3])
        row.highlight:SetVertexColor(HEADER_COLOR[1], HEADER_COLOR[2], HEADER_COLOR[3])
        row.state:SetText("")
        row.check:Hide()
        row.selected:Hide()
        return
    end

    local info = e.info
    local r, g, b = DifficultyColor(info)
    row.expand:Hide()
    row.title:SetPoint("LEFT", 20, 0)
    row.title:SetText(LevelPrefix(info) .. (info.title or ""))
    row.title:SetTextColor(r, g, b)
    row.state:SetText(StateLabel(e.questID))
    row.state:SetTextColor(r, g, b)
    -- Size the title to its text so the tracked tick can sit right after it.
    local room = LIST_WIDTH - 60 - (row.state:GetStringWidth() or 0) - 16
    row.title:SetWidth(math.max(40, math.min(row.title:GetStringWidth() or room, room)))
    row.check:SetShown(IsWatched(e.questID) and true or false)
    row.highlight:SetVertexColor(r, g, b)
    row.selected:SetVertexColor(r, g, b)
    row.selected:SetShown(e.questID == self.selected)
end

function QuestLog:UpdateList()
    local entries = self.entries or {}
    self.listBar:SetRange(#entries - NUM_ROWS)
    local offset = self.listOffset or 0
    for i, row in ipairs(self.rows) do
        self:UpdateRow(row, entries[i + offset])
    end
end

-------------------------------------------------------------------------------
-- Details
-------------------------------------------------------------------------------

-- QUEST_TEMPLATE_LOG without the seal material, which expects Blizzard's
-- own detail frame as the grandparent of the content.
local function DetailTemplate()
    if QuestLog.template then return QuestLog.template end
    local base = QUEST_TEMPLATE_LOG
    if type(base) ~= "table" or type(base.elements) ~= "table" then return nil end
    local t = {}
    for k, v in pairs(base) do t[k] = v end
    t.canHaveSealMaterial = nil
    t.elements = {}
    for i = 1, #base.elements, 3 do
        if base.elements[i] ~= QuestInfo_ShowSeal then
            for j = 0, 2 do t.elements[#t.elements + 1] = base.elements[i + j] end
        end
    end
    QuestLog.template = t
    return t
end

-- Blizzard's quest dialog shares the QuestInfo frames; don't take them while
-- it's open (QuestFrame's OnHide redraws the details).
local function QuestInfoBusy()
    for _, name in ipairs({ "QuestFrame", "QuestLogPopupDetailFrame" }) do
        local f = _G[name]
        if type(f) == "table" and f:IsShown() then return true end
    end
    return false
end

-- Plain-text details for clients without QuestInfo_Display.
function QuestLog:ShowSimpleDetails(questID)
    local d = self.detail
    local index = C_QuestLog.GetLogIndexForQuestID(questID)
    local description, objectives = Try(GetQuestLogQuestText, index)
    local lines = { "|cff000000" .. (C_QuestLog.GetTitleForQuestID(questID) or "") .. "|r", "", objectives or "", "" }
    for _, o in ipairs(Try(C_QuestLog.GetQuestObjectives, questID) or {}) do
        lines[#lines + 1] = (o.finished and "|cff606060" or "") .. (o.text or "") .. (o.finished and "|r" or "")
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = description or ""
    d.simple:SetText(table.concat(lines, "\n"))
    d.simple:Show()
end

function QuestLog:ShowDetails()
    local d = self.detail
    local questID = self.selected
    d.simple:Hide()
    d.empty:SetShown(not questID)
    d.child:SetShown(questID ~= nil)
    if not questID or QuestInfoBusy() then return end

    C_QuestLog.SetSelectedQuest(questID)
    local template = DetailTemplate()
    if type(QuestInfo_Display) == "function" and template then
        local ok, err = pcall(QuestInfo_Display, template, d.child)
        if not ok then ns.Debug(err) end
        if db().showIDs and type(QuestInfoTitleHeader) == "table" then
            QuestInfoTitleHeader:SetText((QuestInfoTitleHeader:GetText() or "") .. " [" .. questID .. "]")
        end
    else
        self:ShowSimpleDetails(questID)
    end
    if self.detailQuestID ~= questID then d.bar:SetValue(0) end
    self.detailQuestID = questID
    self:UpdateDetailScroll()
    -- Text heights settle on the next frame.
    C_Timer.After(0, function() QuestLog:UpdateDetailScroll() end)
end

function QuestLog:UpdateDetailScroll()
    local d = self.detail
    local top = d.child:GetTop()
    local last = (d.simple:IsShown() and d.simple) or (type(QuestInfoSpacerFrame) == "table" and QuestInfoSpacerFrame)
    local bottom = last and last:GetBottom()
    local height = (top and bottom) and (top - bottom + 12) or d.scroll:GetHeight()
    d.child:SetHeight(math.max(1, height))
    d.bar:SetRange(height - d.scroll:GetHeight())
end

function QuestLog:UpdateButtons()
    local questID = self.selected
    local count = select(2, C_QuestLog.GetNumQuestLogEntries()) or 0
    local max = Try(C_QuestLog.GetMaxNumQuestsCanAccept) or 20
    self.count:SetFormattedText("%s: |cffffffff%d/%d|r", QUESTS_LABEL or "Quests", count, max)
    self.abandon:SetEnabled(questID ~= nil and Try(C_QuestLog.CanAbandonQuest, questID) and true or false)
    self.share:SetEnabled(questID ~= nil and Try(C_QuestLog.IsPushableQuest, questID) and IsInGroup() and true or false)
    self.track.check:SetChecked(questID ~= nil and IsWatched(questID) and true or false)
    self.track.check:SetEnabled(questID ~= nil)

    local anyExpanded = false
    for _, e in ipairs(self.entries or {}) do
        if e.isHeader and not e.collapsed then anyExpanded = true end
    end
    self.all.icon:SetTexture(anyExpanded and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
end

-------------------------------------------------------------------------------
-- Actions
-------------------------------------------------------------------------------

function QuestLog:Select(questID)
    self.selected = questID
    self:UpdateList()
    self:ShowDetails()
    self:UpdateButtons()
end

function QuestLog:ToggleTracking(questID)
    if not questID then return end
    if QuestMapQuestOptions_TrackQuest then
        Try(QuestMapQuestOptions_TrackQuest, questID)
    elseif IsWatched(questID) then
        Try(C_QuestLog.RemoveQuestWatch, questID)
    else
        Try(C_QuestLog.AddQuestWatch, questID)
    end
    self:Refresh()
end

function QuestLog:ToggleAll()
    local anyExpanded = false
    for _, e in ipairs(self.entries or {}) do
        if e.isHeader and not e.collapsed then anyExpanded = true end
    end
    for _, e in ipairs(self.entries or {}) do
        if e.isHeader then db().collapsed[e.title] = anyExpanded or nil end
    end
    self:Refresh()
end

function QuestLog:Abandon()
    if self.selected and QuestMapQuestOptions_AbandonQuest then
        Try(QuestMapQuestOptions_AbandonQuest, self.selected)
    end
end

function QuestLog:Share()
    if self.selected and QuestMapQuestOptions_ShareQuest then
        Try(QuestMapQuestOptions_ShareQuest, self.selected)
    end
end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------

function QuestLog:Refresh()
    if not (self.frame and self.frame:IsShown()) then
        self.dirty = true
        return
    end
    self.dirty = false
    self.entries = self:BuildEntries()

    local ids = AllQuestIDs()
    if self.selected and not tContains(ids, self.selected) then self.selected = nil end
    if not self.selected then
        for _, e in ipairs(self.entries) do
            if e.questID then
                self.selected = e.questID
                break
            end
        end
        self.selected = self.selected or ids[1]
    end
    self:UpdateList()
    self:ShowDetails()
    self:UpdateButtons()
end

-- QUEST_LOG_UPDATE comes in bursts; refresh once per frame at most.
function QuestLog:QueueRefresh()
    if self.queued then return end
    self.queued = true
    C_Timer.After(0, function()
        QuestLog.queued = false
        QuestLog:Refresh()
    end)
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------

-- Blizzard's portrait window when the template exists, else a flat one.
local function CreateWindowFrame()
    local ok, f = pcall(CreateFrame, "Frame", "JiJournalQuestLogFrame", UIParent, "ButtonFrameTemplate")
    if ok and type(f) == "table" and type(f.TitleContainer) == "table" then
        f:SetTitle(QUEST_LOG or "Quest Log")
        f:SetPortraitToAsset(BOOK_ICON)
        if type(f.Inset) == "table" then f.Inset:Hide() end
        f.CloseButton:SetScript("OnClick", function() f:Hide() end)
        return f
    end
    f = W.NewFrame("Frame", UIParent, nil, "JiJournalQuestLogFrame")
    W.Backdrop(f, 0.06, 0.06, 0.06, 0.96, 0.35)
    local title = W.Font(f:CreateFontString(nil, "OVERLAY"), 14)
    title:SetPoint("TOP", 0, -6)
    title:SetText(QUEST_LOG or "Quest Log")
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(BOOK_ICON)
    icon:SetSize(48, 48)
    icon:SetPoint("TOPLEFT", 6, -4)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() f:Hide() end)
    return f
end

function QuestLog:CreateList(f)
    local list = W.NewFrame("Frame", f)
    list:SetPoint("TOPLEFT", 6, -TOP)
    list:SetPoint("BOTTOMLEFT", 6, BOTTOM + 4)
    list:SetWidth(LIST_WIDTH)
    W.Backdrop(list, 0, 0, 0, 0.55, 0.3)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta) QuestLog.listBar:Scroll(delta, 3) end)

    self.listBar = NewScrollBar(list, function(v)
        QuestLog.listOffset = v
        QuestLog:UpdateList()
    end)
    self.listBar:SetPoint("TOPRIGHT", -3, -3)
    self.listBar:SetPoint("BOTTOMRIGHT", -3, 3)
    self.rows = {}
    for i = 1, NUM_ROWS do self.rows[i] = self:CreateRow(list, i) end
    self.list = list
end

function QuestLog:CreateDetail(f)
    local d = CreateFrame("Frame", nil, f)
    d:SetPoint("TOPLEFT", self.list, "TOPRIGHT", 6, 0)
    d:SetPoint("BOTTOMRIGHT", -8, BOTTOM + 4)
    local bg = d:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("QuestDetailsBackgrounds") then
        bg:SetAtlas("QuestDetailsBackgrounds")
    else
        bg:SetTexture("Interface\\QuestFrame\\QuestBG")
        bg:SetTexCoord(0, 0.586, 0.02, 0.655)
    end

    local scroll = CreateFrame("ScrollFrame", nil, d)
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -18, 8)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(300, 1)
    scroll:SetScrollChild(child)
    d.scroll, d.child = scroll, child

    d.bar = NewScrollBar(d, function(v) scroll:SetVerticalScroll(v) end)
    d.bar:SetPoint("TOPRIGHT", -5, -8)
    d.bar:SetPoint("BOTTOMRIGHT", -5, 8)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) d.bar:Scroll(delta, 40) end)

    d.simple = W.Font(child:CreateFontString(nil, "OVERLAY"), 12)
    d.simple:SetPoint("TOPLEFT", 5, -5)
    d.simple:SetWidth(285)
    d.simple:SetJustifyH("LEFT")
    d.simple:SetTextColor(0.18, 0.12, 0.06)
    d.simple:Hide()
    d.empty = W.Font(d:CreateFontString(nil, "OVERLAY"), 13)
    d.empty:SetPoint("CENTER")
    d.empty:SetTextColor(0.18, 0.12, 0.06)
    d.empty:SetText(QUEST_LOG_NO_QUESTS_TEXT or "No active quests.")
    self.detail = d
end

function QuestLog:CreateControls(f)
    -- Collapse or expand every zone.
    local all = CreateFrame("Button", nil, f)
    all:SetSize(50, 18)
    all:SetPoint("TOPLEFT", 68, -34)
    all.icon = all:CreateTexture(nil, "ARTWORK")
    all.icon:SetSize(14, 14)
    all.icon:SetPoint("LEFT")
    local allText = W.Font(all:CreateFontString(nil, "OVERLAY"), 12)
    allText:SetPoint("LEFT", all.icon, "RIGHT", 4, 0)
    allText:SetText(ALL or "All")
    allText:SetTextColor(1, 0.82, 0)
    all:SetScript("OnClick", function() QuestLog:ToggleAll() end)
    self.all = all

    local set = W.NewSet()
    self.track = set:Checkbox(f, TRACK_QUEST or "Track Quest", "Show this quest in the objective tracker. Shift-click a quest to do the same.",
        function() return QuestLog.selected and IsWatched(QuestLog.selected) end,
        function() QuestLog:ToggleTracking(QuestLog.selected) end)
    self.track:SetPoint("LEFT", all, "RIGHT", 12, 0)
    self.track:SetWidth(140)

    self.count = W.Font(f:CreateFontString(nil, "OVERLAY"), 12)
    self.count:SetPoint("TOPRIGHT", -14, -38)
    self.count:SetTextColor(1, 0.82, 0)

    self.abandon = W.Button(f, ABANDON_QUEST_ABBREV or "Abandon Quest", 120, function() QuestLog:Abandon() end)
    self.abandon:SetPoint("BOTTOMLEFT", 6, 4)
    self.abandon:SetHeight(22)
    local exit = W.Button(f, EXIT or "Exit", 90, function() f:Hide() end)
    exit:SetPoint("BOTTOMRIGHT", -8, 4)
    exit:SetHeight(22)
    self.share = W.Button(f, SHARE_QUEST_ABBREV or "Share Quest", 110, function() QuestLog:Share() end)
    self.share:SetPoint("RIGHT", exit, "LEFT", -4, 0)
    self.share:SetHeight(22)
end

function QuestLog:Create()
    local f = CreateWindowFrame()
    f:SetSize(WIDTH, HEIGHT)
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        if f.SetUserPlaced then f:SetUserPlaced(false) end
        QuestLog:SavePosition()
    end)
    f:Hide()
    table.insert(UISpecialFrames, "JiJournalQuestLogFrame")
    self.frame = f

    self:CreateList(f)
    self:CreateDetail(f)
    self:CreateControls(f)

    f:SetScript("OnShow", function()
        PlaySound(SOUNDKIT.IG_QUEST_LOG_OPEN)
        QuestLog:Refresh()
    end)
    f:SetScript("OnHide", function() PlaySound(SOUNDKIT.IG_QUEST_LOG_CLOSE) end)
    self:Apply()
end

function QuestLog:ApplyPosition()
    local f, p = self.frame, db().point
    f:ClearAllPoints()
    if p then
        f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
    end
end

function QuestLog:SavePosition()
    local point, _, relPoint, x, y = self.frame:GetPoint(1)
    if point then db().point = { point, relPoint, math.floor(x + 0.5), math.floor(y + 0.5) } end
end

function QuestLog:Apply()
    if not self.frame then return end
    self.frame:SetScale(db().scale)
    self:ApplyPosition()
    self:Refresh()
end

function QuestLog:Show(questID)
    if not self.frame then return end
    if questID and C_QuestLog.GetLogIndexForQuestID(questID) then self.selected = questID end
    if self.frame:IsShown() then
        self:Refresh()
    else
        self.frame:Show()
    end
end

function QuestLog:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then self.frame:Hide() else self:Show() end
end

-------------------------------------------------------------------------------
-- Taking over L, the micro menu and the objective tracker
-------------------------------------------------------------------------------

-- These globals are what every "open the quest log" path in Forever calls
-- (key binding, micro menu button, objective tracker, quest timers). The
-- world map is never opened along with the log.
function QuestLog:TakeOver()
    ToggleQuestLog = function() QuestLog:Toggle() end
    OpenQuestLog = function() QuestLog:Show() end
    QuestMapFrame_OpenToQuestDetails = function(questID) QuestLog:Show(questID) end
end

function QuestLog:Hook()
    self:TakeOver()
    -- Blizzard_WorldMap and Blizzard_UIPanels_Game define these globals too,
    -- and in Forever the map loads after addons, so its definitions win
    -- unless they're taken back once each Blizzard addon has loaded.
    ns:RegisterEvent("ADDON_LOADED", function(_, name)
        if type(name) == "string" and name:find("^Blizzard_") then QuestLog:TakeOver() end
    end)
    ns:RegisterEvent("PLAYER_LOGIN", function() QuestLog:TakeOver() end)

    if type(QuestFrame) == "table" then
        QuestFrame:HookScript("OnHide", function()
            if QuestLog.frame:IsShown() then QuestLog:ShowDetails() end
        end)
    end
end

function QuestLog:Init()
    if not db().enabled then return end
    self:Create()
    self:Hook()
    local function Changed() QuestLog:QueueRefresh() end
    ns:RegisterEvent("QUEST_LOG_UPDATE", Changed)
    ns:RegisterEvent("QUEST_WATCH_LIST_CHANGED", Changed)
    ns:RegisterEvent("QUEST_REMOVED", Changed)
    ns:RegisterEvent("GROUP_ROSTER_UPDATE", function() if QuestLog.frame:IsShown() then QuestLog:UpdateButtons() end end)
end
