local _, ns = ...

-- QuestsFu: how many quests are in the log (out of the maximum) and the last
-- quest progress message. The tooltip lists the quests by zone with levels,
-- difficulty colours and objectives; it is clickable:
--   click        open the quest in JiJournal's quest log (else: track it)
--   alt-click    track or untrack the quest
--   shift-click  link the quest in chat
--   ctrl-click   share the quest with your group

local P = ns.RegisterPlugin({
    id = "Quests",
    title = "Quests",
    icon = ns.MEDIA .. "Icons\\quests",
    place = { bar = 1, side = "CENTER", order = 4 },
    defaults = {
        showCompleted = false,
        showCurrent = true,
        showMax = true,
        showMessage = true,
        colorText = false,
        messageSeconds = 30,
        groupByZone = true,
        currentZoneOnly = false,
        showLevels = true,
        difficultyColors = true,
        showImpossible = true,
        showObjectives = true,
        currentZoneObjectivesOnly = false,
        showCompletedObjectives = false,
        colorObjectives = true,
        collapsed = {},
    },
})

-- The quest log through Blizzard's micro button (see Plugin.lua).
P.clickTargets = { { target = "QuestLogMicroButton" } }

P.options = {
    { type = "header", label = "Bar text" },
    { type = "toggle", key = "showCompleted", label = "Completed quests" },
    { type = "toggle", key = "showCurrent", label = "Quests in the log" },
    { type = "toggle", key = "showMax", label = "Maximum quests" },
    { type = "toggle", key = "showMessage", label = "Last quest progress message" },
    { type = "toggle", key = "colorText", label = "Colour the counts", tip = "Green while there is room in the log, red when it is full." },
    { type = "range", key = "messageSeconds", label = "Show the message for (0 = until the next)", min = 0, max = 120,
      step = 5, presets = { 0, 10, 30, 60, 120 }, fmt = function(v) return v == 0 and "always" or (v .. " s") end },
    { type = "header", label = "Tooltip" },
    { type = "toggle", key = "groupByZone", label = "Group by zone" },
    { type = "toggle", key = "currentZoneOnly", label = "Current zone only" },
    { type = "toggle", key = "showLevels", label = "Quest levels" },
    { type = "toggle", key = "difficultyColors", label = "Difficulty colours" },
    { type = "toggle", key = "showImpossible", label = "Quests far above your level" },
    { type = "toggle", key = "showObjectives", label = "Objectives" },
    { type = "toggle", key = "currentZoneObjectivesOnly", label = "Objectives for the current zone only" },
    { type = "toggle", key = "showCompletedObjectives", label = "Completed objectives" },
    { type = "toggle", key = "colorObjectives", label = "Colour objectives by progress" },
}

local PROGRESS_FORMATS

function P:OnEnable()
    PROGRESS_FORMATS = ns.CompileFormats({
        { "ERR_QUEST_ADD_KILL_SII" }, { "ERR_QUEST_ADD_ITEM_SII" }, { "ERR_QUEST_ADD_FOUND_SII" },
        { "ERR_QUEST_ADD_PLAYER_KILL_SII" }, { "ERR_QUEST_OBJECTIVE_COMPLETE_S" }, { "ERR_QUEST_COMPLETE_S" },
        { "ERR_QUEST_UNKNOWN_COMPLETE" },
    })
    self:RegisterEvent("QUEST_LOG_UPDATE", "Update")
    self:RegisterEvent("QUEST_WATCH_LIST_CHANGED", "Update")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "Update")
    self:RegisterEvent("PLAYER_LEVEL_UP", "Update")
    self:RegisterEvent("UI_INFO_MESSAGE", "OnInfoMessage")
end

-- Quest progress arrives as a UI info message ("Kobold Vermin slain: 3/10").
function P:OnInfoMessage(_, _, message)
    message = ns.SafeString(message)
    if not message then return end
    local known = false
    for _, entry in ipairs(PROGRESS_FORMATS or {}) do
        if message:match(entry.pattern or "^$") then known = true break end
    end
    if not known and not message:match("%d+/%d+") then return end
    self.message, self.messageAt = message, GetTime()
    self:Update()
end

function P:OnTick()
    local secs = self.db.messageSeconds or 0
    if self.message and secs > 0 and GetTime() - self.messageAt > secs then
        self.message = nil
        self:UpdateText()
    end
end

-------------------------------------------------------------------------------
-- Quest log
-------------------------------------------------------------------------------

local TAG_DUNGEON, TAG_RAID, TAG_GROUP = 81, 62, 1

local function LevelTag(q)
    local suffix = ""
    if q.tagID == TAG_DUNGEON then suffix = "D"
    elseif q.tagID == TAG_RAID or q.tagID == 88 or q.tagID == 89 then suffix = "R"
    elseif q.tagID == TAG_GROUP or q.elite then suffix = "+" end
    return "[" .. (q.level or "?") .. suffix .. "] "
end

-- "Kobold Vermin slain: 3/10" -> "Kobold Vermin slain", "3/10"
local function SplitObjective(o)
    local text = o.text or ""
    local name, progress = text:match("^(.-):%s*(%d+%s*/%s*%d+)$")
    if not name then
        progress, name = text:match("^(%d+%s*/%s*%d+)%s+(.+)$")
    end
    if not name then
        name = text
        if o.numRequired and o.numRequired > 0 then
            progress = (o.numFulfilled or 0) .. "/" .. o.numRequired
        end
    end
    if o.finished then progress = "Done" end
    return name, progress or ""
end

-- Reads the log into { zones = { { name, quests = {...} } }, count, completed }.
function P:ReadLog()
    local log = { zones = {}, count = 0, completed = 0 }
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return log end
    local entries, quests = C_QuestLog.GetNumQuestLogEntries()
    log.count = quests or 0
    local zone = { name = "Miscellaneous", quests = {} }
    for i = 1, entries or 0 do
        local info = C_QuestLog.GetInfo(i)
        if info then
            if info.isHeader then
                zone = { name = info.title or "?", quests = {}, collapsed = info.isCollapsed }
                log.zones[#log.zones + 1] = zone
            elseif not info.isHidden and info.questID and info.questID > 0 then
                if #log.zones == 0 then log.zones[1] = zone end
                local id = info.questID
                local q = {
                    id = id, index = i, title = info.title or "?", level = info.level or info.difficultyLevel,
                    zone = zone.name,
                    complete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(id),
                    failed = C_QuestLog.IsFailed and C_QuestLog.IsFailed(id),
                    elite = C_QuestLog.IsEliteQuest and C_QuestLog.IsEliteQuest(id),
                    watched = C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(id) ~= nil,
                    objectives = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(id) or {},
                }
                local tag = C_QuestLog.GetQuestTagInfo and C_QuestLog.GetQuestTagInfo(id)
                if type(tag) == "table" then q.tagID = tag.tagID end
                if q.complete then log.completed = log.completed + 1 end
                zone.quests[#zone.quests + 1] = q
            end
        end
    end
    return log
end

function P:MaxQuests()
    local max = C_QuestLog and C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept()
    return (max and max > 0) and max or 20
end

function P:UpdateText()
    local db = self.db
    local log = self:ReadLog()
    self.log = log
    local max = self:MaxQuests()
    local parts = {}
    local function Colored(value, quality)
        if not db.colorText then return tostring(value) end
        return "|c" .. ns.ThresholdHex(quality) .. value .. "|r"
    end
    if db.showCompleted then
        parts[#parts + 1] = Colored(log.completed, log.count > 0 and log.completed / log.count or 1)
    end
    if db.showCurrent then
        parts[#parts + 1] = Colored(log.count, (max - log.count) / max)
    end
    if db.showMax then parts[#parts + 1] = tostring(max) end
    -- The counts form one part ("6/40"); the message is the next.
    local text = { table.concat(parts, "/") }
    if text[1] == "" then text = {} end
    if db.showMessage and self.message then text[#text + 1] = self.message end
    self:SetText(ns.Join(text))
end

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------

local function MembersOnQuest(id)
    if not (C_QuestLog.IsUnitOnQuest and IsInGroup and IsInGroup()) then return 0 end
    local n = 0
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) and C_QuestLog.IsUnitOnQuest(unit, id) then n = n + 1 end
    end
    return n
end

function P:QuestColor(q)
    if not self.db.difficultyColors or not GetQuestDifficultyColor then return 1, 1, 1 end
    local c = GetQuestDifficultyColor(q.level or UnitLevel("player"))
    return c.r, c.g, c.b
end

local function IsImpossible(q)
    return (q.level or 0) - UnitLevel("player") >= 5
end

-- Blizzard's quest log is a UI panel inside the world map; opening it from
-- addon code would taint the panel manager (see Plugin.lua). JiJournal's
-- quest log is its own window, so quests open there when it is loaded;
-- otherwise a click tracks the quest instead.
local function CanOpenQuest()
    return ns.IsAddOnLoaded("JiJournal") and QuestMapFrame_OpenToQuestDetails ~= nil
end

function P:QuestClick(q, button)
    if IsAltKeyDown() or not (IsShiftKeyDown() or IsControlKeyDown() or CanOpenQuest()) then
        if C_QuestLog.GetQuestWatchType(q.id) ~= nil then
            C_QuestLog.RemoveQuestWatch(q.id)
        else
            C_QuestLog.AddQuestWatch(q.id)
        end
    elseif IsShiftKeyDown() then
        ns.InsertChatLink(GetQuestLink and GetQuestLink(q.id))
    elseif IsControlKeyDown() then
        if QuestMapQuestOptions_ShareQuest then
            QuestMapQuestOptions_ShareQuest(q.id)
        elseif C_QuestLog.SetSelectedQuest and QuestLogPushQuest then
            C_QuestLog.SetSelectedQuest(q.id)
            QuestLogPushQuest()
        end
    else
        QuestMapFrame_OpenToQuestDetails(q.id)
    end
    self:Update()
end

function P:AddQuest(tip, q, withZone)
    local db = self.db
    if IsImpossible(q) and not db.showImpossible then return end
    local r, g, b = self:QuestColor(q)
    local title = (db.showLevels and LevelTag(q) or "") .. q.title
    if withZone then title = title .. " (" .. q.zone .. ")" end
    local members = MembersOnQuest(q.id)
    if members > 0 then title = title .. " |cff00ff00<" .. members .. ">|r" end
    local state, sr, sg, sb
    if q.failed then
        state, sr, sg, sb = "Failed", 1, 0.2, 0.2
    elseif q.complete then
        state, sr, sg, sb = "Done", 0.2, 1, 0.2
    end
    tip:AddLine(title, state, nil, {
        colors = { { r, g, b }, { sr or 1, sg or 1, sb or 1 } }, indent = db.groupByZone and 6 or 0,
        check = q.watched, onClick = function(button) self:QuestClick(q, button) end,
    })

    if not db.showObjectives then return end
    if db.currentZoneObjectivesOnly and q.zone ~= GetZoneText() then return end
    for _, o in ipairs(q.objectives) do
        if not o.finished or db.showCompletedObjectives then
            local name, progress = SplitObjective(o)
            local or_, og, ob = r, g, b
            if db.colorObjectives then
                if o.finished then
                    or_, og, ob = 0.2, 1, 0.2
                elseif o.numRequired and o.numRequired > 0 then
                    or_, og, ob = ns.ThresholdColor((o.numFulfilled or 0) / o.numRequired)
                end
            end
            tip:AddLine(name, progress, nil, {
                colors = { { or_, og, ob }, { or_, og, ob } }, indent = 16, small = true,
                onClick = function(button) self:QuestClick(q, button) end,
            })
        end
    end
end

local function SortQuests(a, b)
    if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) < (b.level or 0) end
    return a.title < b.title
end

function P:OnTooltip(tip)
    local db = self.db
    local log = self.log or self:ReadLog()
    tip:AddTitle(("Quests (%d/%d)"):format(log.count, self:MaxQuests()))
    local currentZone = GetZoneText and GetZoneText()
    if db.groupByZone then
        for _, zone in ipairs(log.zones) do
            if not db.currentZoneOnly or zone.name == currentZone then
                local collapsed = db.collapsed[zone.name]
                local marker = collapsed and "|cffaaaaaa[+]|r " or "|cffaaaaaa[-]|r "
                tip:AddHeader(marker .. zone.name, 0.75, 1, 0.75, function()
                    db.collapsed[zone.name] = not db.collapsed[zone.name] or nil
                end)
                if not collapsed then
                    if zone.collapsed and #zone.quests == 0 then
                        tip:AddLine("(collapsed in the quest log)", nil, nil, { colors = { { 0.6, 0.6, 0.6 } }, indent = 6, small = true })
                    end
                    for _, q in ipairs(zone.quests) do self:AddQuest(tip, q, false) end
                end
            end
        end
    else
        local all = {}
        for _, zone in ipairs(log.zones) do
            for _, q in ipairs(zone.quests) do
                if not db.currentZoneOnly or zone.name == currentZone then all[#all + 1] = q end
            end
        end
        table.sort(all, SortQuests)
        for _, q in ipairs(all) do self:AddQuest(tip, q, true) end
    end
    if log.count == 0 then tip:AddLine("Your quest log is empty.", nil, nil, { colors = { { 0.7, 0.7, 0.7 } } }) end
    if CanOpenQuest() then
        tip:SetHint("Click a quest to open it, alt-click to track it, shift-click to link it, ctrl-click to share it. Click the plugin for the quest log.")
    else
        tip:SetHint("Click a quest to track it, shift-click to link it, ctrl-click to share it. Click the plugin for the quest log.")
    end
end

