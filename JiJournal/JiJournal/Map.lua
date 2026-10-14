local _, ns = ...

-- Restyles Blizzard's WorldMapFrame after Leatrix Maps: a borderless, movable
-- window without the docked quest log, a bar with coordinates, mouse-wheel
-- zoom on every map, and zoom and pan remembered per map.
--
-- The map itself stays Blizzard's, so pins, quest blobs, flight points and
-- waypoints keep working. It's changed only through hooks, frame attributes,
-- CVars and frame methods; no Blizzard function or table is replaced.

local W = ns.Widgets
local Map = {}
ns.Map = Map

-- The canvas is inset 2px on every side: 1046x697 fits the 3:2 map art exactly.
local WIDTH, HEIGHT, INSET = 1050, 701, 2
local BAR_HEIGHT = 22
local ZOOM_STEP = 1.25
local NO_WHEEL_ZOOM = MAP_CANVAS_MOUSE_WHEEL_ZOOM_BEHAVIOR_NONE or 3

local function db() return ns.db.map end

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-------------------------------------------------------------------------------
-- Zoom and pan
-------------------------------------------------------------------------------

-- Vanilla maps often have a single zoom level, so the wheel zooms past
-- Blizzard's last level up to maxZoom times the fitted size.
function Map:ZoomLimits()
    local sc = self.sc
    local minScale = sc:GetScaleForMinZoom()
    return minScale, math.max(sc:GetScaleForMaxZoom(), minScale * db().maxZoom)
end

-- Zooms by one wheel step, keeping the map point under the cursor in place.
function Map:Zoom(delta)
    local sc = self.sc
    if not (sc.zoomLevels and sc.mapID) then return end
    local minScale, maxScale = self:ZoomLimits()
    local from = sc:GetCanvasScale()
    local to = Clamp(from * (delta > 0 and ZOOM_STEP or 1 / ZOOM_STEP), minScale, maxScale)
    if math.abs(to - from) < 1e-4 then return end
    local cx, cy = sc:GetCurrentScrollX(), sc:GetCurrentScrollY()
    local mx, my = sc:GetNormalizedCursorPosition()
    local keep = from / to
    sc:InstantPanAndZoom(to, mx - (mx - cx) * keep, my - (my - cy) * keep, true)
    self:SaveView()
end

-- Remembers the current map's zoom (relative to the fitted size) and centre.
function Map:SaveView()
    local sc = self.sc
    if not (db().rememberZoom and sc.zoomLevels and sc.mapID) then return end
    local mapID = self.map:GetMapID()
    if not mapID then return end
    local factor = (sc.targetScale or sc:GetCanvasScale()) / sc:GetScaleForMinZoom()
    if factor <= 1.001 then
        db().views[mapID] = nil
    else
        db().views[mapID] = { factor, sc.targetScrollX or sc:GetCurrentScrollX(),
            sc.targetScrollY or sc:GetCurrentScrollY() }
    end
end

function Map:RestoreView()
    local sc = self.sc
    if not (db().rememberZoom and sc.zoomLevels and sc.mapID) then return end
    local view = db().views[self.map:GetMapID()]
    if not view then return end
    local minScale, maxScale = self:ZoomLimits()
    sc:InstantPanAndZoom(Clamp(view[1] * minScale, minScale, maxScale), view[2], view[3], true)
end

-------------------------------------------------------------------------------
-- Coordinates bar (also the drag handle for the window)
-------------------------------------------------------------------------------

local function Coords(x, y)
    return ("%.1f, %.1f"):format(x * 100, y * 100)
end

function Map:UpdateBar()
    local bar, map = self.bar, self.map
    local mapID = map:GetMapID()
    local info = mapID and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    bar.name:SetText(info and info.name or "")

    if not db().coords then
        bar.cursor:SetText("")
        bar.player:SetText("")
        return
    end
    local cursor = ""
    if self.sc:IsMouseOver() then
        local x, y = self.sc:GetNormalizedCursorPosition()
        if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then cursor = Coords(x, y) end
    end
    bar.cursor:SetText("Cursor: " .. cursor)

    local player = ""
    local pos = mapID and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
    if pos then
        local x, y = pos:GetXY()
        if x and (x > 0 or y > 0) then player = Coords(x, y) end
    end
    bar.player:SetText("Player: " .. player)
end

function Map:CreateOverlay()
    local map, sc = self.map, self.sc
    -- HIGH strata keeps the controls above the pins, which climb to high levels.
    local overlay = W.NewFrame("Frame", map, nil, "JiJournalMapOverlay")
    overlay:SetAllPoints()
    overlay:SetFrameStrata("HIGH")
    overlay:SetBackdrop({ edgeFile = W.WHITE, edgeSize = INSET })
    overlay:SetBackdropBorderColor(0.08, 0.08, 0.08, 1)
    self.overlay = overlay

    local bar = CreateFrame("Frame", nil, overlay)
    bar:SetPoint("BOTTOMLEFT", sc, "BOTTOMLEFT")
    bar:SetPoint("BOTTOMRIGHT", sc, "BOTTOMRIGHT")
    bar:SetHeight(BAR_HEIGHT)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() map:StartMoving() end)
    bar:SetScript("OnDragStop", function()
        map:StopMovingOrSizing()
        if map.SetUserPlaced then map:SetUserPlaced(false) end
        Map:SavePosition()
    end)
    W.AttachTooltip(bar, ns.title, "Drag this bar to move the map. Scroll on the map to zoom, drag it to pan, right-click to go up a level.")
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.6)

    local function Label(justify)
        local fs = W.Font(bar:CreateFontString(nil, "OVERLAY"), 13)
        fs:SetTextColor(1, 0.82, 0)
        fs:SetJustifyH(justify)
        return fs
    end
    bar.cursor = Label("LEFT")
    bar.cursor:SetPoint("LEFT", 10, 0)
    bar.player = Label("RIGHT")
    bar.player:SetPoint("RIGHT", -10, 0)
    bar.name = Label("CENTER")
    bar.name:SetPoint("CENTER")
    bar.name:SetTextColor(1, 1, 1)

    local elapsed = 1
    bar:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 0.1 then return end
        elapsed = 0
        Map:UpdateBar()
    end)
    self.bar = bar
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------

function Map:ApplyPosition()
    local map, p = self.map, db().point
    map:ClearAllPoints()
    if p then
        map:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        map:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end
end

function Map:SavePosition()
    local point, _, relPoint, x, y = self.map:GetPoint(1)
    if point then db().point = { point, relPoint, math.floor(x + 0.5), math.floor(y + 0.5) } end
end

function Map:Apply()
    if not self.map then return end
    self.map:SetScale(db().scale)
    self.sc:SetAlpha(db().alpha)
    self:ApplyPosition()
    self:UpdateBar()
end

-- Hides a Blizzard frame for good, even when its own code shows it again.
local function KeepHidden(frame)
    frame:Hide()
    hooksecurefunc(frame, "Show", frame.Hide)
    hooksecurefunc(frame, "SetShown", function(f, shown) if shown then f:Hide() end end)
end

-- Questie (and other addons) add map buttons through Krowi_WorldMapButtons,
-- which lines them up from the top-right corner, 32px apart, and re-anchors
-- them on every map change. The filter button goes to the left of that row.
local BUTTON_SPACING, BUTTON_X, BUTTON_Y = 32, 4, -2

function Map:ArrangeButtons()
    local filters = self.map.WorldMapTrackingOptionsButton
    if type(filters) ~= "table" then return end
    local lib = LibStub and LibStub("Krowi_WorldMapButtons-1.4", true)
    local x = BUTTON_X
    if lib and type(lib.Buttons) == "table" then
        for _, b in ipairs(lib.Buttons) do
            if b == filters then return end -- Krowi places it
            if b:IsShown() then x = x + BUTTON_SPACING end
        end
    end
    filters:ClearAllPoints()
    filters:SetPoint("TOPRIGHT", self.sc, "TOPRIGHT", -x, BUTTON_Y)
end

-- After Krowi's own OnMapChanged hook, which other addons install later.
function Map:QueueArrange()
    C_Timer.After(0, function() Map:ArrangeButtons() end)
end

-- Blizzard's own coordinates panel; JiJournal's bar replaces it.
local function BlizzardCoordsPanel(map)
    if type(map.overlayFrames) ~= "table" then return end
    for _, f in ipairs(map.overlayFrames) do
        if type(f.PlayerCoords) == "table" and type(f.CursorCoords) == "table" then return f end
    end
end

function Map:Setup()
    local map = WorldMapFrame
    local sc = map.ScrollContainer
    self.map, self.sc = map, sc

    -- Out of Blizzard's panel layout: a frame without an "area" is simply
    -- shown and hidden by ShowUIPanel/HideUIPanel, and stays where it's put.
    map:SetAttribute("UIPanelLayout-defined", true)
    map:SetAttribute("UIPanelLayout-area", nil)
    table.insert(UISpecialFrames, "WorldMapFrame")
    map:SetMovable(true)
    map:SetClampedToScreen(true)

    -- Always the small map without the docked quest log: M toggles it, and
    -- JiJournal's quest log takes over L.
    SetCVar("miniWorldMap", "1")
    SetCVar("questLogOpen", "0")
    map.minimizedWidth, map.minimizedHeight = WIDTH, HEIGHT
    map:SetSize(WIDTH, HEIGHT)

    map.BorderFrame:Hide()
    if type(map.NavBar) == "table" then map.NavBar:Hide() end
    hooksecurefunc(map, "SetDisplayState", function(m)
        if type(m.SidePanelToggle) == "table" then m.SidePanelToggle:Hide() end
        if type(m.QuestLog) == "table" and m.QuestLog:IsShown() then m:SetQuestLogPanelShown(false) end
    end)

    sc:ClearAllPoints()
    sc:SetPoint("TOPLEFT", INSET, -INSET)
    sc:SetPoint("BOTTOMRIGHT", -INSET, INSET)
    -- Camelot parks the filter button next to the (now hidden) navigation
    -- bar and the map pin button in the top-left corner.
    self:ArrangeButtons()
    if type(map.WorldMapTrackingPinButton) == "table" then KeepHidden(map.WorldMapTrackingPinButton) end
    local coords = BlizzardCoordsPanel(map)
    if coords then KeepHidden(coords) end

    self:CreateOverlay()

    map:SetMouseWheelZoomMode(NO_WHEEL_ZOOM)
    sc:HookScript("OnMouseWheel", function(_, delta) Map:Zoom(delta) end)
    sc:HookScript("OnMouseUp", function() Map:SaveView() end)
    -- Blizzard resets the zoom in OnShow, on every map change, and whenever
    -- the frame is re-anchored (OnFrameSizeChanged), which opening the map
    -- with M does after OnShow. Restore after each of them.
    map:HookScript("OnShow", function()
        Map:RestoreView()
        Map:QueueArrange()
    end)
    map:HookScript("OnHide", function() Map:SaveView() end)
    hooksecurefunc(map, "OnMapChanged", function()
        Map:RestoreView()
        Map:QueueArrange()
    end)
    hooksecurefunc(map, "OnFrameSizeChanged", function() Map:RestoreView() end)

    self:Apply()
end

function Map:Init()
    if not db().enabled then return end
    if type(WorldMapFrame) == "table" and type(WorldMapFrame.ScrollContainer) == "table" then
        self:Setup()
        return
    end
    local function handler(_, name)
        if name ~= "Blizzard_WorldMap" then return end
        ns:UnregisterEvent("ADDON_LOADED", handler)
        Map:Setup()
    end
    ns:RegisterEvent("ADDON_LOADED", handler)
end

function Map:ResetZoomMemory()
    wipe(db().views)
end
