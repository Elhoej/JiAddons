-- Test harness for JiAddons. Loads an addon against the mocked WoW API
-- (mock_wow.lua) the way the client does and offers tiny test helpers.
--
-- Typical <Project>/tests/run_tests.lua:
--
--   local here = debug.getinfo(1, "S").source:match("^@(.-)[^/]*$")
--   package.path = here .. "../../tools/?.lua;" .. package.path
--   local H = require("harness")
--   local ns, M = H.LoadAddon(here .. "../MyAddon")
--   H.Fire("ADDON_LOADED", "MyAddon")
--   H.test("does a thing", function() H.eq(1 + 1, 2) end)
--   H.Finish()

local M = require("mock_wow")

local H = { mock = M, passed = 0, failed = 0 }

local function out(s) io.write(s, "\n") end
H.out = out

-- XML support is limited to <Font> definitions: each named <Font> becomes a
-- mock font object (global, like the client) with _font = { file, height,
-- outline } and _xml = its attributes. Any other element is an error.
local XML_ALLOWED = { Ui = true, Font = true, Shadow = true, Offset = true, AbsDimension = true, Color = true }

local function LoadXML(file)
    local text = assert(io.open(file)):read("*a"):gsub("<!%-%-.-%-%->", "")
    for tag in text:gmatch("<(%a+)") do
        if not XML_ALLOWED[tag] then
            error("harness cannot load <" .. tag .. "> from XML: " .. file)
        end
    end
    for attrs in text:gmatch("<Font%s([^>]*)>") do
        local a = {}
        for k, v in attrs:gmatch('([%w_]+)="([^"]*)"') do a[k] = v end
        if a.name then
            local font = M.NewObject("Font", a.name)
            font._font = { a.font, tonumber(a.height), a.outline or "" }
            font._xml = a
        end
    end
end

-- Loads every file listed in <dir>/<AddonName>.toc, in order: .lua files with
-- the (addonName, ns) varargs the client passes, .xml files via LoadXML.
function H.LoadAddon(dir)
    dir = dir:gsub("/+$", "")
    local name = dir:match("([^/]+)$")
    local ns = {}
    local toc = dir .. "/" .. name .. ".toc"
    for line in io.lines(toc) do
        line = line:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" and not line:match("^#") then
            local path = line:gsub("\\", "/")
            if path:match("%.lua$") then
                local chunk = assert(loadfile(dir .. "/" .. path))
                chunk(name, ns)
            elseif path:match("%.xml$") then
                LoadXML(dir .. "/" .. path)
            end
        end
    end
    H.ns, H.name = ns, name
    return ns, M
end

-- Delivers a game event to every mock frame registered for it. Frames that
-- used RegisterUnitEvent only get it when the first argument is one of their units.
function H.Fire(event, ...)
    for _, f in ipairs(M.frames) do
        local reg = f._events[event]
        if reg == true or (reg and reg[(...)]) then f:Fire("OnEvent", event, ...) end
    end
end

-- Advances time: runs due C_Timer callbacks and every OnUpdate script.
function H.Tick(seconds, step)
    step = step or 0.05
    local t = 0
    while t < seconds do
        M.now = M.now + step
        t = t + step
        local due = {}
        for i = #M.timers, 1, -1 do
            if M.timers[i].at <= M.now then
                due[#due + 1] = table.remove(M.timers, i)
            end
        end
        for i = #due, 1, -1 do due[i].f() end
        for _, f in ipairs(M.frames) do
            local onUpdate = f._shown and f._scripts.OnUpdate
            if onUpdate then onUpdate(f, step) end
        end
    end
end

function H.test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        H.passed = H.passed + 1
        out("PASS  " .. name)
    else
        H.failed = H.failed + 1
        out("FAIL  " .. name .. "\n      " .. tostring(err))
    end
end

function H.eq(a, b, msg)
    if a ~= b then
        error((msg or "") .. " expected [" .. tostring(b) .. "] got [" .. tostring(a) .. "]", 2)
    end
end

function H.truthy(v, msg)
    if not v then error(msg or "expected truthy", 2) end
end

-- Strips colour codes so text can be compared as plain strings.
function H.plain(s)
    return (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:]*:", ""):gsub("|r", ""))
end

function H.Finish()
    out(("\n%d passed, %d failed"):format(H.passed, H.failed))
    os.exit(H.failed == 0 and 0 or 1)
end

return H
