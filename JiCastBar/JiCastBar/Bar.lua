local addonName, ns = ...

-- One cast bar (player or target), built the way WeakAuras draws the aurabar
-- in Elva's auras:
--   root     icon on the left, bar to its right, 2px black border drawn
--            inside the edge around both
--   bar      the area right of the icon. Two invisible StatusBars in it
--            follow the cast (see StartDriver); the active one's fill texture
--            marks the progress edge (self.edge), which the client moves
--            even when the cast values are secret.
--   fill     frame from the bar's left edge to the progress edge. It clips a
--            fill texture as wide as the whole bar, so a gradient stays in
--            place while the progress reveals it (WeakAuras' fgMask).
--   above that the spark at the progress edge, the spell models (each in its
--   own clipping frame), the border and the texts.
-- Channels drain: the bar fills in reverse and the fill frame ends at the
-- left edge of the status bar texture instead.

local Bar = {}
Bar.__index = Bar
ns.Bar = Bar

local W = ns.Widgets
local LAYOUT = ns.LAYOUT
local Cast = ns.Cast
local WHITE = W.WHITE
local FONT = "Interface\\AddOns\\" .. addonName .. "\\Media\\FiraSans-Heavy.ttf"
local DEFAULT_SPARK = 130877 -- Interface\CastingBar\UI-CastingBar-Spark
local TEXT_INTERVAL = 0.05
local LATENCY_COLOR = { 1, 0, 0, 0.5 }
local rad = math.rad

local UNIT_EVENTS = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_UPDATE", "UNIT_SPELLCAST_EMPOWER_STOP",
}

-- Casts shown while the bars are unlocked or the options are open.
local SAMPLES = {
    player = { name = "Greater Heal", texture = 135913, seconds = 2.5 },
    target = { name = "Shadow Bolt", texture = 136197, seconds = 3 },
}

local function Debug(...)
    if ns.db and ns.db.debug then ns.Print(...) end
end

-- Fira Sans Heavy is what WeakAuras calls "Fira Sans Black". A FontString
-- without a font errors on SetText, so fall back to the UI font.
local function SetFont(fs)
    if not fs:SetFont(FONT, LAYOUT.fontSize, "OUTLINE") then W.Font(fs, LAYOUT.fontSize, "OUTLINE") end
    fs:SetShadowColor(0, 0, 0, 0)
end

-- Spark textures are file IDs or atlases. bonusobjectives-bar-spark isn't
-- referenced in Forever's UI code, so fall back to the cast bar spark.
local function SetSparkTexture(tex, value)
    if type(value) == "string" then
        local hasAtlas = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(value)
        if hasAtlas then
            tex:SetAtlas(value)
            return
        end
        value = DEFAULT_SPARK
    end
    tex:SetTexture(value)
end

-- WeakAuras' submodel setup. transform uses its Dragonflight conversion,
-- negative scale included.
local function ApplyModel(model, cfg)
    model:SetKeepModelOnHide(true)
    model:SetModel(cfg.file)
    model:ClearTransform()
    if cfg.transform then
        local t = cfg.transform
        if model.MakeCurrentCameraCustom then model:MakeCurrentCameraCustom() end
        model:SetTransform(CreateVector3D(t[1] / 1000, t[2] / 1000, t[3] / 1000),
            CreateVector3D(rad(t[4]), rad(t[5]), rad(t[6])), -t[7] / 1000)
    else
        local p = cfg.position
        model:SetPosition(p[3], p[1], p[2])
        model:SetFacing(rad(cfg.facing or 0))
    end
    if model.SetModelAlpha then model:SetModelAlpha(cfg.alpha) else model:SetAlpha(cfg.alpha) end
end

-------------------------------------------------------------------------------
-- Construction
-------------------------------------------------------------------------------

function Bar.New(key, unit)
    local self = setmetatable({ key = key, unit = unit, models = {} }, Bar)
    local label = ns.BAR_LABELS[key]

    local root = CreateFrame("Frame", "JiCastBar" .. label, UIParent)
    root:SetSize(LAYOUT.width, LAYOUT.height)
    root:SetFrameStrata("MEDIUM")
    root:SetClampedToScreen(true)
    root:SetMovable(true)
    root:RegisterForDrag("LeftButton")
    root:Hide()
    self.root = root
    local level = root:GetFrameLevel()
    self.level = level

    local icon = root:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT")
    icon:SetPoint("BOTTOMLEFT")
    icon:SetWidth(LAYOUT.height) -- square: ApplySettings matches it to the bar height
    local z = LAYOUT.iconZoom
    icon:SetTexCoord(z, 1 - z, z, 1 - z)
    self.icon = icon

    local bar = CreateFrame("Frame", nil, root)
    bar:SetPoint("TOPLEFT", icon, "TOPRIGHT")
    bar:SetPoint("BOTTOMRIGHT")
    bar:SetFrameLevel(level + 1)
    self.bar = bar

    -- Two invisible drivers: valueBar takes values from Lua, timerBar runs a
    -- client-side timer for secret casts. Kept apart so a timer left on one
    -- never fights the values of the other.
    local function Driver()
        local sb = CreateFrame("StatusBar", nil, bar)
        sb:SetAllPoints()
        sb:SetStatusBarTexture(WHITE)
        sb:SetStatusBarColor(0, 0, 0, 0)
        return sb
    end
    self.valueBar = Driver()
    self.timerBar = Driver()

    self.background = bar:CreateTexture(nil, "BACKGROUND")
    self.background:SetAllPoints()

    local fill = CreateFrame("Frame", nil, bar)
    fill:SetFrameLevel(level + 2)
    fill:SetClipsChildren(true)
    self.fill = fill
    self.fillTexture = fill:CreateTexture(nil, "ARTWORK")
    self.fillTexture:SetAllPoints(bar)
    self.fillTexture:SetTexture(WHITE)

    local sparkLayer = CreateFrame("Frame", nil, bar)
    sparkLayer:SetAllPoints()
    sparkLayer:SetFrameLevel(level + 3)
    self.latency = sparkLayer:CreateTexture(nil, "ARTWORK")
    self.latency:SetColorTexture(unpack(LATENCY_COLOR))
    self.latency:SetPoint("TOPRIGHT", bar)
    self.latency:SetPoint("BOTTOMRIGHT", bar)
    self.latency:Hide()
    self.spark = sparkLayer:CreateTexture(nil, "OVERLAY")
    self.spark:SetPoint("CENTER", fill, "RIGHT")
    self.spark:Hide()

    -- Models sit at level + 4 and + 5 (see ModelSlot).

    local border = W.NewFrame("Frame", root)
    border:SetAllPoints()
    border:SetFrameLevel(level + 8)
    if border.SetBackdrop then
        border:SetBackdrop({ edgeFile = WHITE, edgeSize = LAYOUT.border })
        border:SetBackdropBorderColor(0, 0, 0, 1)
    end

    local texts = CreateFrame("Frame", nil, root)
    texts:SetAllPoints()
    texts:SetFrameLevel(level + 9)
    self.nameText = texts:CreateFontString(nil, "OVERLAY")
    SetFont(self.nameText)
    self.nameText:SetJustifyH("LEFT")
    self.nameText:SetWordWrap(false)
    self.nameText:SetTextColor(1, 1, 1)
    self.timeText = texts:CreateFontString(nil, "OVERLAY")
    SetFont(self.timeText)
    self.timeText:SetPoint("RIGHT", bar, "RIGHT", -2, -1) -- INNER_RIGHT adds 2px
    self.timeText:SetTextColor(unpack(LAYOUT.timeColor))

    -- Shown while the bars can be dragged.
    self.moverLabel = W.Font(texts:CreateFontString(nil, "OVERLAY"), 11, "OUTLINE")
    self.moverLabel:SetPoint("BOTTOM", root, "TOP", 0, 3)
    self.moverLabel:SetText(label .. " cast bar")
    self.moverLabel:SetTextColor(1, 0.82, 0)
    self.moverLabel:Hide()

    root:SetScript("OnEvent", function() self:Refresh() end)
    root:SetScript("OnUpdate", function(_, elapsed) self:OnUpdate(elapsed) end)
    -- Models are set up again each time the bar appears, as WeakAuras does:
    -- a model set while hidden may not render.
    root:SetScript("OnShow", function() self:ShowModels() end)
    root:SetScript("OnDragStart", function() root:StartMoving() end)
    root:SetScript("OnDragStop", function()
        root:StopMovingOrSizing()
        self:SavePosition()
    end)

    self:SetDriver(self.valueBar, false)
    return self
end

-- A clipping frame and a model for the style's i-th model.
function Bar:ModelSlot(i)
    local slot = self.models[i]
    if slot then return slot end
    local clip = CreateFrame("Frame", nil, self.bar)
    clip:SetFrameLevel(self.level + 4)
    clip:SetClipsChildren(true)
    local model = CreateFrame("PlayerModel", nil, clip)
    model:SetFrameLevel(self.level + 5)
    slot = { clip = clip, model = model }
    -- WeakAuras hides a model while its clip frame is under a pixel wide
    -- (clipping misbehaves at zero width) and sets it up again when it grows.
    -- Sizes tied to a secret bar value could be secret, so those are left alone.
    clip:SetScript("OnSizeChanged", function(_, width, height)
        if ns.IsSecret(width) or ns.IsSecret(height) then return end
        local big = width >= 1 and height >= 1
        if big and not model:IsShown() then
            model:Show()
            self:SetupModel(slot)
        elseif not big then
            model:Hide()
        end
    end)
    self.models[i] = slot
    return slot
end

-------------------------------------------------------------------------------
-- Settings and style
-------------------------------------------------------------------------------

function Bar:ApplySettings(cfg)
    self.cfg = cfg
    local root = self.root
    root:SetScale(cfg.scale)
    root:SetSize(cfg.width, cfg.height)
    self.icon:SetWidth(cfg.height)
    root:ClearAllPoints()
    local p = cfg.point
    root:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    self:ApplyStyle(ns.STYLE_BY_KEY[cfg.style] or ns.STYLES[1])
    self:SetEnabled(cfg.enabled)
end

function Bar:ApplyStyle(style)
    self.style = style
    local shade = ns.SHADE[style.texture] or 1
    local c1 = style.color
    local c2 = style.color2 or c1
    -- A flat style is a gradient between equal colours, which also clears an
    -- earlier style's gradient.
    self.fillTexture:SetGradient("HORIZONTAL",
        CreateColor(c1[1] * shade, c1[2] * shade, c1[3] * shade, 1),
        CreateColor(c2[1] * shade, c2[2] * shade, c2[3] * shade, 1))
    self.background:SetColorTexture(unpack(style.background))

    local spark = style.spark
    if spark then
        SetSparkTexture(self.spark, spark.texture)
        self.spark:SetBlendMode("ADD")
        self.spark:SetVertexColor(spark.color[1], spark.color[2], spark.color[3], 1)
        -- Elva's spark heights suit a 28px bar; taller or shorter bars scale them.
        local height = self.cfg and self.cfg.height or LAYOUT.height
        self.spark:SetSize(spark.width, spark.height * height / LAYOUT.height)
    end
    self.spark:SetShown(spark ~= nil and self.info ~= nil)

    self.nameText:ClearAllPoints()
    self.nameText:SetPoint("LEFT", self.bar, "LEFT", 2 + style.nameX, style.nameY) -- INNER_LEFT adds 2px

    local effects = not self.cfg or self.cfg.effects ~= false
    for i, cfg in ipairs(style.models) do
        local slot = self:ModelSlot(i)
        slot.cfg = cfg
        slot.clip:ClearAllPoints()
        slot.clip:SetAllPoints(cfg.attach and self.fill or self.bar)
        slot.model:ClearAllPoints()
        slot.model:SetAllPoints((cfg.attach and cfg.stretch) and self.fill or self.bar)
        slot.clip:SetShown(effects)
    end
    for i = #style.models + 1, #self.models do
        self.models[i].cfg = nil
        self.models[i].clip:Hide()
    end
    if self.root:IsShown() then self:ShowModels() end
end

function Bar:SetupModel(slot)
    if not (slot.cfg and slot.clip:IsShown()) then return end
    local ok, err = pcall(ApplyModel, slot.model, slot.cfg)
    if not ok then Debug("model " .. tostring(slot.cfg.file) .. ": " .. tostring(err)) end
end

function Bar:ShowModels()
    for _, slot in ipairs(self.models) do self:SetupModel(slot) end
end

function Bar:SetEnabled(enabled)
    local root = self.root
    if enabled and not self.registered then
        for _, event in ipairs(UNIT_EVENTS) do
            -- RegisterUnitEvent spares us comparing the unit argument, which
            -- may be secret. Unknown events throw, hence pcall.
            if not pcall(root.RegisterUnitEvent, root, event, self.unit) then
                pcall(root.RegisterEvent, root, event)
            end
        end
        root:RegisterEvent("PLAYER_ENTERING_WORLD")
        if self.unit == "target" then root:RegisterEvent("PLAYER_TARGET_CHANGED") end
        self.registered = true
    elseif not enabled and self.registered then
        root:UnregisterAllEvents()
        self.registered = false
    end
    self:Refresh()
end

function Bar:SetPreview(on)
    self.preview = on and true or false
    self:Refresh()
end

function Bar:SetMovable(movable)
    self.root:EnableMouse(movable)
    self.moverLabel:SetShown(movable)
end

function Bar:SavePosition()
    local root = self.root
    if root.SetUserPlaced then root:SetUserPlaced(false) end
    local point, _, relPoint, x, y = root:GetPoint(1)
    if point then self.cfg.point = { point, relPoint, x, y } end
end

-------------------------------------------------------------------------------
-- Casting
-------------------------------------------------------------------------------

function Bar:SampleCast()
    local sample = SAMPLES[self.key]
    local now = GetTime() * 1000
    return { name = sample.name, texture = sample.texture, startMs = now,
        endMs = now + sample.seconds * 1000, channel = false, plain = true, sample = true }
end

-- Every event just asks the client again: event payloads (cast GUIDs) can be
-- secret, and a FAILED for a spell queued behind the current cast then
-- leaves the current one alone.
function Bar:Refresh()
    local info
    if self.cfg and self.cfg.enabled then
        info = Cast.Query(self.unit)
        if not info and self.preview then info = self:SampleCast() end
    end
    if info then self:Start(info) else self:Stop() end
end

-- Points the fill frame at the driver's progress edge.
function Bar:SetDriver(driver, channel)
    if self.driver == driver and self.channel == channel then return end
    self.driver, self.channel = driver, channel
    driver:SetReverseFill(channel)
    self.edge = driver:GetStatusBarTexture()
    self.fill:ClearAllPoints()
    self.fill:SetPoint("TOPLEFT", self.bar)
    self.fill:SetPoint("BOTTOMRIGHT", self.edge, channel and "BOTTOMLEFT" or "BOTTOMRIGHT")
end

-- Plain casts run from 0 to their length. Secret casts can't be offset, so
-- they hand the cast's duration object to the client's timer; if that's
-- refused they fall back to the absolute times (startMs..endMs against
-- GetTime), which works with secrets but may move in coarser steps.
function Bar:StartDriver(info)
    if info.plain then
        info.mode = "relative"
        self.valueBar:SetMinMaxValues(0, (info.endMs - info.startMs) / 1000)
        self:SetDriver(self.valueBar, info.channel)
    else
        local timer = self.timerBar
        local direction = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime or 0
        local interpolation = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or 0
        if info.duration and timer.SetTimerDuration
            and pcall(timer.SetTimerDuration, timer, info.duration, interpolation, direction) then
            info.mode = "timer"
            self:SetDriver(timer, info.channel)
        else
            info.mode = "absolute"
            self.valueBar:SetMinMaxValues(info.startMs, info.endMs)
            self:SetDriver(self.valueBar, info.channel)
        end
    end
    if not info.sample then
        Debug(("%s cast: %s values, %s"):format(self.unit, info.plain and "plain" or "secret", info.mode))
    end
    self:UpdateValue(GetTime())
end

function Bar:UpdateValue(now)
    local info = self.info
    if info.mode == "relative" then
        self.valueBar:SetValue(now - info.startMs / 1000)
    elseif info.mode == "absolute" then
        self.valueBar:SetValue(now * 1000)
    end
end

function Bar:Start(info)
    self.info = info
    self:StartDriver(info)
    self.icon:SetTexture(info.texture)
    self.nameText:SetText(Cast.DisplayName(info))
    self.spark:SetShown(self.style.spark ~= nil)
    self:UpdateLatency()
    self.timeOK = true
    self.textElapsed = 0
    self:UpdateTime()
    self.root:Show()
end

function Bar:Stop()
    self.info = nil
    self.root:Hide()
end

-- Time between sending a cast and the server starting it, as a red block at
-- the end of the bar. Player casts only: it needs plain values.
function Bar:UpdateLatency()
    local info = self.info
    local total = info.plain and (info.endMs - info.startMs) or 0
    local _, _, _, latencyWorld = GetNetStats()
    local show = self.cfg.latency and self.unit == "player" and not info.channel
        and total > 0 and (latencyWorld or 0) > 0
    if show then
        local barWidth = self.cfg.width - self.cfg.height
        self.latency:SetWidth(math.max(1, math.min(1, latencyWorld / total) * barWidth))
    end
    self.latency:SetShown(show and true or false)
end

function Bar:UpdateTime(nowMs)
    if not self.timeOK then return end
    self.timeOK = Cast.SetTimeText(self.timeText, self.info, nowMs or GetTime() * 1000)
    if not self.timeOK then self.timeText:SetText("") end
end

function Bar:OnUpdate(elapsed)
    local info = self.info
    if not info then return end
    local now = GetTime() * 1000
    if info.sample and now >= info.endMs then
        self:Start(self:SampleCast())
        return
    end
    self:UpdateValue(now / 1000)
    -- A missed stop event (unit out of range, say) would leave a plain cast
    -- full forever; secret casts can't be checked and rely on the events.
    if info.plain and not info.sample and now > info.endMs + 500 then
        self:Refresh()
        return
    end
    self.textElapsed = self.textElapsed + elapsed
    if self.textElapsed >= TEXT_INTERVAL then
        self.textElapsed = 0
        self:UpdateTime(now)
    end
end
