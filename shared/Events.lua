local addonName, ns = ...

-- One event frame per addon with multiple handlers per event. Handlers run in
-- pcall so one failing handler never blocks the others; errors are printed
-- when ns.db.debug is set.

local eventFrame = CreateFrame("Frame")
local handlers = {}
ns.eventFrame = eventFrame

-- Registers func(event, ...) for event. Returns false if this client does not
-- know the event (RegisterEvent throws on unknown events).
function ns:RegisterEvent(event, func)
    if not handlers[event] then
        local ok = pcall(eventFrame.RegisterEvent, eventFrame, event)
        if not ok then return false end
        handlers[event] = {}
    end
    table.insert(handlers[event], func)
    return true
end

function ns:UnregisterEvent(event, func)
    local list = handlers[event]
    if not list then return end
    -- Build a new list so a dispatch already iterating the old one is unaffected.
    local kept = {}
    for _, f in ipairs(list) do
        if f ~= func then kept[#kept + 1] = f end
    end
    handlers[event] = kept
    if #kept == 0 then
        handlers[event] = nil
        eventFrame:UnregisterEvent(event)
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], event, ...)
        if not ok and ns.db and ns.db.debug then
            ns.Print("error in", event, err)
        end
    end
end)

-- Runs func once this addon's saved variables are available.
function ns:OnLoad(func)
    local function handler(_, loaded)
        if loaded ~= addonName then return end
        ns:UnregisterEvent("ADDON_LOADED", handler)
        func()
    end
    ns:RegisterEvent("ADDON_LOADED", handler)
end
