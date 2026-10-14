local _, ns = ...

-- MicroMenuFu: a row of flat icons for the game menu and Blizzard's windows.
--
-- Opening Blizzard's windows from addon code taints them and the shared UI
-- panel manager (see Plugin.lua), so no icon calls ToggleCharacter and the
-- like. Where Blizzard has a micro button for an icon, JiBar "docks" that
-- real button invisibly on top of the icon, so a click is a genuine click on
-- Blizzard's button; that is also the only way to open the game menu, whose
-- button only reacts while the mouse is over it. Other icons get a secure
-- overlay that clicks a Blizzard button elsewhere (the chat frame's social
-- button, the minimap's zone text). Docked buttons show Blizzard's tooltips.

local W = ns.Widgets

local P = ns.RegisterPlugin({
    id = "MicroMenu",
    title = "Micro Menu",
    hasText = false,
    place = { bar = 1, side = "LEFT", order = 1 },
    defaults = {
        buttonSize = 26,
        spacing = 1,
        spacerWidth = 12,
        visible = {},
    },
})
P.custom = true

-- targets: Blizzard buttons that open the window (first that exists).
-- dock: dock it if it's one of the micro menu's buttons; otherwise a secure
-- overlay clicks it (see Plugin.lua). note: shown in the icon's tooltip.
local function ZoneTextButton() return MinimapCluster and MinimapCluster.ZoneTextButton end
local SOCIAL = "Opens the social window."

local BUTTONS = {
    { id = "Menu", icon = "menu", name = MAINMENU_BUTTON or "Game Menu", key = "TOGGLEGAMEMENU",
      targets = { "MainMenuMicroButton" }, dock = true },
    { id = "Spacer1", spacer = true, name = "Gap" },
    { id = "Who", icon = "chat", name = WHO or "Who", key = "TOGGLESOCIAL", note = SOCIAL,
      targets = { "QuickJoinToastButton" } },
    { id = "Guild", icon = "guild", name = GUILD or "Guild", key = "TOGGLEGUILDTAB",
      targets = { "GuildMicroButton" }, dock = true },
    { id = "Friends", icon = "social", name = FRIENDS or "Friends", key = "TOGGLESOCIAL",
      targets = { "QuickJoinToastButton" } },
    { id = "Spacer2", spacer = true, name = "Gap" },
    { id = "Character", icon = "char", name = CHARACTER_BUTTON or "Character", key = "TOGGLECHARACTER0",
      targets = { "CharacterMicroButton" }, dock = true },
    { id = "Spellbook", icon = "spell", name = SPELLBOOK_ABILITIES_BUTTON or "Spellbook", key = "TOGGLESPELLBOOK",
      targets = { "SpellbookMicroButton", "PlayerSpellsMicroButton" }, dock = true },
    { id = "Talents", icon = "talent", name = TALENTS_BUTTON or "Talents", key = "TOGGLETALENTS",
      targets = { "TalentMicroButton", "PlayerSpellsMicroButton" }, dock = true },
    { id = "Reputation", icon = "ach", name = REPUTATION or "Reputation", key = "TOGGLECHARACTER2",
      note = "Opens the character window; pick the reputation tab there.", targets = { "CharacterMicroButton" } },
    { id = "Quests", icon = "quest", name = QUESTLOG_BUTTON or "Quest Log", key = "TOGGLEQUESTLOG",
      targets = { "QuestLogMicroButton" }, dock = true },
    { id = "Raid", icon = "raid", name = RAID or "Raid", key = "TOGGLERAIDTAB", note = SOCIAL,
      targets = { "QuickJoinToastButton" } },
    { id = "Journal", icon = "journal", name = ADVENTURE_JOURNAL or "Dungeon Journal", key = "TOGGLEENCOUNTERJOURNAL",
      targets = { "EJMicroButton" }, dock = true },
    { id = "PvP", icon = "pvp", name = PVP or "Player vs. Player", key = "TOGGLEGROUPFINDER",
      note = "Opens the group finder.", targets = { "LFDMicroButton", "CharacterMicroButton" } },
    { id = "WorldMap", icon = "world", name = WORLDMAP_BUTTON or "World Map", key = "TOGGLEWORLDMAP",
      targets = { ZoneTextButton } },
    { id = "Help", icon = "help", name = HELP_BUTTON or "Help", targets = { "HelpMicroButton" }, dock = true },
    -- Not in MicroMenuFu's default set; off until turned on.
    { id = "GroupFinder", icon = "raid", name = DUNGEONS_BUTTON or "Group Finder", key = "TOGGLEGROUPFINDER",
      hidden = true, targets = { "LFDMicroButton" }, dock = true },
    { id = "Professions", icon = "spell", name = PROFESSIONS_BUTTON or "Professions", key = "TOGGLEPROFESSIONBOOK",
      hidden = true, targets = { "ProfessionMicroButton" }, dock = true },
    { id = "Legacy", icon = "ach", name = "Legacy", hidden = true, targets = { "LegacyMicroButton" }, dock = true },
    { id = "Achievements", icon = "ach", name = ACHIEVEMENT_BUTTON or "Achievements", key = "TOGGLEACHIEVEMENT",
      hidden = true, targets = { "AchievementMicroButton" }, dock = true },
    { id = "Collections", icon = "pet", name = COLLECTIONS or "Collections", key = "TOGGLECOLLECTIONS",
      hidden = true, targets = { "CollectionsMicroButton" }, dock = true },
    { id = "Shop", icon = "shop", name = BLIZZARD_STORE or "Shop", hidden = true,
      targets = { "StoreMicroButton" }, dock = true },
}
P.BUTTONS = BUTTONS

P.options = {
    { type = "range", key = "buttonSize", label = "Button size", min = 12, max = 40, step = 1, presets = { 16, 20, 24, 26, 28, 32 } },
    { type = "range", key = "spacing", label = "Button spacing", min = 0, max = 12, step = 0.5, presets = { 0, 1, 2, 4, 6, 8 } },
    { type = "range", key = "spacerWidth", label = "Gap width", min = 0, max = 40, step = 1, presets = { 0, 6, 12, 20 } },
    { type = "header", label = "Buttons" },
}
for _, b in ipairs(BUTTONS) do
    P.options[#P.options + 1] = {
        type = "toggle", label = b.name .. (b.spacer and (" (" .. b.id:sub(-1) .. ")") or ""),
        get = function(p) return p:IsShowing(b) end,
        set = function(p, v) p.db.visible[b.id] = v end,
    }
end

function P:IsShowing(b)
    local v = self.db.visible[b.id]
    if v == nil then return not b.hidden end
    return v
end

-------------------------------------------------------------------------------
-- Icons
-------------------------------------------------------------------------------

function P:OnInit()
    self.icons = {}
    for _, b in ipairs(BUTTONS) do
        if not b.spacer then
            local btn = CreateFrame("Button", nil, self.frame)
            btn:RegisterForClicks("AnyUp")
            btn.tex = btn:CreateTexture(nil, "ARTWORK")
            btn.tex:SetAllPoints()
            btn.tex:SetTexture(ns.MEDIA .. "Micro\\" .. b.icon)
            btn.entry = b
            -- Left clicks land on the docked button or the overlay above the
            -- icon; the icon itself only gets them when neither exists.
            btn:SetScript("OnClick", function(_, mouse)
                if mouse == "RightButton" then
                    ns.Menu:OpenPlugin(self)
                elseif ns.db.locked then
                    ns.Print(b.name .. " isn't available on this client.")
                end
            end)
            btn:SetScript("OnEnter", function(f) self:IconEnter(f) end)
            btn:SetScript("OnLeave", function(f) self:IconLeave(f) end)
            self.icons[b.id] = btn
        end
    end
end

function P:SetIconHover(btn, hovered)
    local c = hovered and ns.db.hoverColor or { 1, 1, 1 }
    btn.tex:SetVertexColor(c[1], c[2], c[3])
end

function P:IconEnter(btn)
    self:SetIconHover(btn, true)
    ns.Bars:OnMouseActivity(self.bar)
    if not ns.db.locked then
        self:OnEnterFrame()
        return
    end
    local b = btn.entry
    GameTooltip:SetOwner(btn, "ANCHOR_TOP")
    local key = b.key and GetBindingKey and GetBindingKey(b.key)
    GameTooltip:AddLine(b.name .. (key and (" |cffffd100(" .. key .. ")|r") or ""), 1, 1, 1)
    if b.note then GameTooltip:AddLine(b.note, nil, nil, nil, true) end
    GameTooltip:AddLine("Right-click for options.", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

function P:IconLeave(btn)
    self:SetIconHover(btn, false)
    if GameTooltip:IsOwned(btn) then GameTooltip:Hide() end
    if not ns.db.locked then self:OnLeaveFrame() end
end

function P:LayoutContent()
    local db = self.db
    local size, x = db.buttonSize, 0
    local last = false
    for _, b in ipairs(BUTTONS) do
        local btn = self.icons[b.id]
        if self:IsShowing(b) then
            if b.spacer then
                x = x + db.spacerWidth
            else
                btn:ClearAllPoints()
                btn:SetSize(size, size)
                btn:SetPoint("LEFT", self.frame, "LEFT", x, 0)
                btn:Show()
                x = x + size + db.spacing
                last = true
            end
        elseif btn then
            btn:Hide()
        end
    end
    if last then x = x - db.spacing end
    return math.max(x, 1)
end

function P:ApplyContentStyle()
    for _, btn in pairs(self.icons) do self:SetIconHover(btn, false) end
end

-------------------------------------------------------------------------------
-- Docking Blizzard's micro buttons
-------------------------------------------------------------------------------

-- Only buttons the client's micro menu actually added are docked (game
-- rules leave some out), and only while Blizzard shows them.
local function Dockable(btn)
    return btn.jibarDocked or (btn.layoutIndex ~= nil and btn:IsShown())
end

local function ZeroAlpha(btn)
    if btn.jibarDocked then btn:SetAlpha(0) end
end

function P:Dock(b, icon, btn)
    if not btn.jibarHooked then
        btn.jibarHooked = true
        -- Blizzard resets the alpha when buttons are enabled or disabled.
        btn:HookScript("OnEnable", ZeroAlpha)
        btn:HookScript("OnDisable", ZeroAlpha)
        btn:HookScript("OnShow", ZeroAlpha)
        btn:HookScript("OnEnter", function(f)
            if f.jibarDocked and f.jibarIcon then
                self:SetIconHover(f.jibarIcon, true)
                ns.Bars:OnMouseActivity(self.bar)
            end
        end)
        btn:HookScript("OnLeave", function(f)
            if f.jibarDocked and f.jibarIcon then self:SetIconHover(f.jibarIcon, false) end
        end)
    end
    btn.jibarDocked, btn.jibarIcon = true, icon
    btn:SetParent(icon)
    btn:ClearAllPoints()
    btn:SetAllPoints(icon)
    btn:SetFrameLevel(icon:GetFrameLevel() + 2)
    btn:SetAlpha(0)
    btn:EnableMouse(ns.db.locked)
    self.docked[b.id] = btn
end

function P:Undock(id)
    local btn = self.docked[id]
    if not btn then return end
    self.docked[id] = nil
    btn.jibarDocked, btn.jibarIcon = nil, nil
    btn:EnableMouse(true)
    if MicroMenu then btn:SetParent(MicroMenu) end
    btn:SetAlpha((btn.IsEnabled and not btn:IsEnabled()) and 0.5 or 1)
    if MicroMenu and MicroMenu.Layout then pcall(MicroMenu.Layout, MicroMenu) end
    if MicroMenuContainer and MicroMenuContainer.Layout then pcall(MicroMenuContainer.Layout, MicroMenuContainer) end
end

-- The overlay that clicks an icon's Blizzard button when it can't be docked.
function P:IconOverlay(b)
    self.overlaysByIcon = self.overlaysByIcon or {}
    local o = self.overlaysByIcon[b.id]
    if not o then
        local icon = self.icons[b.id]
        o = self:CreateSecureOverlay({
            region = icon,
            onEnter = function() self:IconEnter(icon) end,
            onLeave = function() self:IconLeave(icon) end,
        })
        self.overlaysByIcon[b.id] = o
    end
    return o
end

-- Docks or overlays every shown icon. Changing overlays is protected, so this
-- waits for the end of combat.
function P:UpdateButtons()
    ns.OutOfCombat("micromenu", function()
        self.docked = self.docked or {}
        local claimed = {}
        for _, b in ipairs(BUTTONS) do
            if not b.spacer then
                local showing = self.db.enabled and self:IsShowing(b)
                local target = showing and ns.ResolveFrame(b.targets)
                local dock = target and b.dock and Dockable(target) and not claimed[target]
                if dock then
                    claimed[target] = true
                    if self.docked[b.id] ~= target then
                        self:Undock(b.id)
                        self:Dock(b, self.icons[b.id], target)
                    end
                else
                    self:Undock(b.id)
                end
                if showing and target and not dock then
                    local o = self:IconOverlay(b)
                    o.disabled = false
                    self:SetClickTarget(o, target, 1)
                elseif self.overlaysByIcon and self.overlaysByIcon[b.id] then
                    self.overlaysByIcon[b.id].disabled = true
                end
            end
        end
        ns.Plugins:SyncOverlays()
    end)
end

function P:OnLockChanged(locked)
    for _, btn in pairs(self.icons) do btn:EnableMouse(locked) end
    for _, btn in pairs(self.docked or {}) do btn:EnableMouse(locked) end
end

function P:OnEnable()
    self:UpdateButtons()
    self:OnLockChanged(ns.db.locked)
    -- The micro menu may be built after us; check again once the world is up.
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateButtons")
end

function P:OnDisable()
    self:UpdateButtons()
end

function P:OnSettingChanged()
    self:UpdateButtons()
end
