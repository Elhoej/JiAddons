local addonName, ns = ...

ns.name = addonName
ns.title = "__ADDON__"

ns.defaults = {
    enabled = true,
}

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------

local W = ns.Widgets
local Options = {}
ns.Options = Options

function Options:Toggle()
    if not self.window then
        self.set = W.NewSet(function() --[[ apply settings here ]] end)
        local content
        self.window, content = W.CreateWindow({
            name = "__ADDON__OptionsFrame",
            title = "|cff33ff99__ADDON__|r",
            width = 520,
            height = 360,
            onShow = function() Options.set:Refresh() end,
        })
        local L = W.NewLayout(content, self.window.contentWidth)
        L:Header("General")
        L:Row(self.set:Checkbox(content, "Enabled", "Turn __ADDON__ on or off.",
            function() return ns.db.enabled end, function(v) ns.db.enabled = v end))
        content:SetHeight(-L.y + 16)
    end
    self.window:SetShown(not self.window:IsShown())
end

-------------------------------------------------------------------------------
-- Startup
-------------------------------------------------------------------------------

ns:OnLoad(function()
    ns.db = ns.LoadSavedVariables("__ADDON__DB", ns.defaults)
    W.RegisterSettingsPanel({
        title = ns.title,
        description = "Type /__ADDON_LOWER__ to open the options.",
        icon = 134400,
        open = function() Options:Toggle() end,
    })
end)

SLASH___ADDON_UPPER__1 = "/__ADDON_LOWER__"
SlashCmdList.__ADDON_UPPER__ = function()
    Options:Toggle()
end
