--[[
╔══════════════════════════════════════════════════════════════════════╗
                              LouisHub
                Master UI Suite: LouisHub Engine V4.0
         PART 1A: POLYFILLS, SERVICES, CAPABILITIES & STATE
╚══════════════════════════════════════════════════════════════════════╝
]]

-- ══════════════════════════════════════════════════════════════
--  SECTION 1: POLYFILLS & LOW-LEVEL RUNTIME COMPATIBILITY
-- ══════════════════════════════════════════════════════════════
if type(task) ~= "table" then task = {} end
if type(task.wait) ~= "function" then
    task.wait = function(t)
        if type(wait) == "function" then return wait(t) end
        return t or 0
    end
end
if type(task.spawn) ~= "function" then
    task.spawn = function(f, ...)
        if type(spawn) == "function" then
            return spawn(function(...) f(...) end, ...)
        end
        local co = coroutine.create(f)
        local ok, err = coroutine.resume(co, ...)
        if not ok then warn("[LouisHub] Polyfill task.spawn error:", err) end
        return co
    end
end
if type(task.delay) ~= "function" then
    task.delay = function(t, f, ...)
        local args = {...}
        if type(delay) == "function" then
            delay(t, function() f(table.unpack(args)) end)
        else
            coroutine.wrap(function()
                if type(wait) == "function" then wait(t) end
                f(table.unpack(args))
            end)()
        end
    end
end
if type(task.defer) ~= "function" then task.defer = task.spawn end
if type(task.cancel) ~= "function" then
    task.cancel = function(thread)
        if type(thread) == "thread" then
            pcall(function()
                if coroutine.status(thread) ~= "dead" and coroutine.close then
                    coroutine.close(thread)
                end
            end)
        end
    end
end

local function cloneTable(t)
    if type(t) ~= "table" then return {} end
    if type(table.clone) == "function" then return table.clone(t) end
    local copy = {}
    for key, value in pairs(t) do copy[key] = value end
    return copy
end

local function copyDefault(v)
    if type(v) == "table" then return cloneTable(v) end
    return v
end

local function normalizeArgSet(...)
    if select('#', ...) >= 2 then
        return (select(2, ...))
    end
    return (select(1, ...))
end

local function Kwargify(defaults, passed)
    passed = passed or {}
    for i, v in pairs(defaults) do
        if passed[i] == nil then
            passed[i] = v
        end
    end
    return passed
end

local function PackColor(Color)
    return {R = Color.R * 255, G = Color.G * 255, B = Color.B * 255}
end

local function UnpackColor(Color)
    return Color3.fromRGB(Color.R, Color.G, Color.B)
end

-- ══════════════════════════════════════════════════════════════
--  SECTION 2: SERVICES & ENVIRONMENT INITIALIZATION
-- ══════════════════════════════════════════════════════════════
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")
local RunService       = game:GetService("RunService")
local Localization     = game:GetService("LocalizationService")
local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")
local Lighting         = game:GetService("Lighting")
local CoreGui          = game:GetService("CoreGui")
local TextService      = game:GetService("TextService")
local LocalPlayer      = Players.LocalPlayer
if not LocalPlayer then
    pcall(function()
        LocalPlayer = Players.PlayerAdded:Wait()
    end)
end

local isStudio = RunService:IsStudio()
local request = (syn and syn.request) or (http and http.request) or http_request or nil

local function isFilesystemAvailable()
    return type(writefile) == "function" and type(readfile) == "function"
end

local function getGuiParent()
    local ok, hui = pcall(function() return gethui() end)
    if ok and hui then return hui end
    if LocalPlayer then
        local okPgui, pgui = pcall(function() return LocalPlayer:WaitForChild("PlayerGui", 5) end)
        if okPgui and pgui then return pgui end
    end
    local okCore, cgui = pcall(function() return CoreGui end)
    if okCore and cgui then return cgui end
    return nil
end

local function protectGui(gui)
    pcall(function()
        if syn and syn.protect_gui then
            syn.protect_gui(gui)
        elseif protectgui then
            protectgui(gui)
        end
    end)
end

-- ══════════════════════════════════════════════════════════════
--  SECTION 3: LOUISHUB NAMESPACE & AUTO-CLEANUP REGISTRY
-- ══════════════════════════════════════════════════════════════
local LouisHub = {}
LouisHub.Version = "4.0.0"
LouisHub.DebugMode = false
LouisHub.ShowUIErrors = true
LouisHub.Folder = "LouisHub/Config"

_G.LouisHub = LouisHub

local function cleanupPreviousInstance()
    local previous = _G.LouisHub_Instance
    if type(previous) ~= "table" then return end

    for _, connection in ipairs(previous.Connections or {}) do
        pcall(function()
            if connection and connection.Connected then connection:Disconnect() end
        end)
    end

    for _, thread in ipairs(previous.Threads or {}) do
        pcall(function()
            if thread and coroutine.status(thread) ~= "dead" then task.cancel(thread) end
        end)
    end

    for _, drawingObj in ipairs(previous.Drawings or {}) do
        pcall(function() if drawingObj then drawingObj:Remove() end end)
    end

    for _, inst in ipairs(previous.Instances or {}) do
        pcall(function() if inst and inst.Parent then inst:Destroy() end end)
    end

    pcall(function()
        local parent = getGuiParent()
        if parent then
            for _, guiName in ipairs({
                "LouisHub_ScreenGui", "LouisHub_NotifGui", "LouisHub_TooltipOverlay", "LouisHub_PopupGui"
            }) do
                local old = parent:FindFirstChild(guiName)
                if old then old:Destroy() end
            end
        end
    end)
end

cleanupPreviousInstance()

_G.LouisHub_Instance = {
    Connections = {},
    Threads     = {},
    Drawings    = {},
    Instances   = {},
    Window      = nil,
    Title       = "LouisHub",
}

function LouisHub:RegisterConnection(connection)
    if _G.LouisHub_Instance and connection then
        table.insert(_G.LouisHub_Instance.Connections, connection)
    end
    return connection
end

function LouisHub:DisconnectAndClean(connection)
    if not connection then return end
    pcall(function() connection:Disconnect() end)
    if _G.LouisHub_Instance then
        local list = _G.LouisHub_Instance.Connections
        local idx = table.find(list, connection)
        if idx then table.remove(list, idx) end
    end
end

function LouisHub:RegisterThread(thread)
    if _G.LouisHub_Instance and thread then
        table.insert(_G.LouisHub_Instance.Threads, thread)
    end
    return thread
end

function LouisHub:RegisterDrawing(drawingObj)
    if _G.LouisHub_Instance and drawingObj then
        table.insert(_G.LouisHub_Instance.Drawings, drawingObj)
    end
    return drawingObj
end

function LouisHub:RegisterInstance(instance)
    if _G.LouisHub_Instance and instance then
        table.insert(_G.LouisHub_Instance.Instances, instance)
    end
    return instance
end

-- ══════════════════════════════════════════════════════════════
--  SECTION 4: HARDWARE CAPABILITIES & ENVIRONMENT DIAGNOSTICS
-- ══════════════════════════════════════════════════════════════
local function detectExecutor()
    if type(getexecutorname) == "function" then
        local ok, name = pcall(getexecutorname)
        if ok and name and name ~= "" then return name end
    end
    local list = {
        {function() return syn ~= nil end, "Synapse X"},
        {function() return krnl ~= nil end, "Krnl"},
        {function() return fluxus ~= nil end, "Fluxus"},
        {function() return sirhurt ~= nil end, "SirHurt"},
        {function() return PROTOSMASHER_LOADED ~= nil end, "ProtoSmasher"},
        {function() return is_sirhurt_closure ~= nil end, "SirHurt (alt)"},
        {function() return identifyexecutor ~= nil end, (identifyexecutor and identifyexecutor()) or "Identified Executor"},
    }
    for _, entry in ipairs(list) do
        local ok2, matches = pcall(entry[1])
        if ok2 and matches then return entry[2] end
    end
    return "Unknown"
end

local VALID_ENV_TYPES = {
    PC = true, Mobile = true, Tablet = true,
    Console = true, Studio = true, Unknown = true,
}

LouisHub.Capabilities = {
    Filesystem   = isFilesystemAvailable(),
    Drawing      = type(Drawing) == "table" and type(Drawing.new) == "function",
    ProtectGUI   = (type(syn) == "table" and type(syn.protect_gui) == "function") or type(protectgui) == "function",
    GetHUI       = type(gethui) == "function",
    Keyboard     = UserInputService.KeyboardEnabled,
    Gamepad      = UserInputService.GamepadEnabled,
    IsStudio     = RunService:IsStudio(),
    TouchEnabled = UserInputService.TouchEnabled,
    MouseEnabled = UserInputService.MouseEnabled,
    Platform     = (function()
        local ok, p = pcall(function() return UserInputService:GetPlatform() end)
        return (ok and p) or nil
    end)(),
    ViewportSize = (function()
        local c = Workspace.CurrentCamera
        return c and c.ViewportSize or Vector2.new(0, 0)
    end)(),
    Type         = "Unknown",
    IsTouch      = false,
    IsDesktop    = false,
    IsTouchOnly  = false,
}

function LouisHub.Capabilities:PlatformName()
    local p = self.Platform
    if not p then return "Unknown" end
    return p.Name or tostring(p)
end

function LouisHub:RecalculateEnvironmentDerivatives()
    local C = self.Capabilities
    local CONSOLE_PLATFORMS = {
        XboxOne = true, XboxSeriesX = true, XboxSeriesS = true,
        PS4 = true, PS5 = true, UWP = true,
    }
    local platformName = C.Platform and C.Platform.Name
    local detectedType

    if _G.LouisHub_ForcedType and VALID_ENV_TYPES[_G.LouisHub_ForcedType] then
        detectedType = _G.LouisHub_ForcedType
    elseif C.IsStudio then
        detectedType = "Studio"
    elseif platformName and CONSOLE_PLATFORMS[platformName] then
        detectedType = "Console"
    elseif C.MouseEnabled and C.Keyboard then
        detectedType = "PC"
    elseif C.TouchEnabled then
        if C.ViewportSize.Y < 500 or C.ViewportSize.X < 600 then
            detectedType = "Mobile"
        else
            detectedType = "Tablet"
        end
    elseif C.Keyboard then
        detectedType = "PC"
    else
        detectedType = "Unknown"
    end

    C.Type        = detectedType
    C.IsTouch     = (detectedType == "Mobile" or detectedType == "Tablet")
    C.IsDesktop   = (detectedType == "PC" or detectedType == "Console")
    C.IsTouchOnly = C.TouchEnabled and not C.MouseEnabled and not C.Keyboard

    if self.Events and self.Events.TypeChanged then
        self.Events.TypeChanged:Fire(detectedType)
    end
    return detectedType
end

LouisHub:RecalculateEnvironmentDerivatives()

if type(_G.LouisHub_CapabilitiesConnections) == "table" then
    for _, c in ipairs(_G.LouisHub_CapabilitiesConnections) do
        pcall(function() if c and c.Connected then c:Disconnect() end end)
    end
end
_G.LouisHub_CapabilitiesConnections = {}

local function hookViewportCapabilities(cam)
    if not cam then return end
    local conn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        LouisHub.Capabilities.ViewportSize = cam.ViewportSize
        LouisHub:RecalculateEnvironmentDerivatives()
    end)
    table.insert(_G.LouisHub_CapabilitiesConnections, conn)
end

hookViewportCapabilities(Workspace.CurrentCamera)
table.insert(_G.LouisHub_CapabilitiesConnections,
    Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        local cam = Workspace.CurrentCamera
        if not cam then return end
        LouisHub.Capabilities.ViewportSize = cam.ViewportSize
        LouisHub:RecalculateEnvironmentDerivatives()
        hookViewportCapabilities(cam)
    end)
)

LouisHub.Features = {
    { name = "GUI",          capKey = nil,             test = function() return true end, level = "required" },
    { name = "Filesystem",   capKey = "Filesystem",    level = "recommended", message = "Configurations will not save to disk." },
    { name = "Drawing",      capKey = "Drawing",       level = "recommended", message = "Visual ESP components will not function." },
    { name = "ProtectGUI",   capKey = "ProtectGUI",    level = "recommended", message = "GUI might be detected by client checks." },
    { name = "GetHUI",       capKey = "GetHUI",        level = "recommended", message = "GUI might render behind CoreGui elements." },
    { name = "Keyboard",     capKey = "Keyboard",      level = "optional",    message = "Keybinds will default to touch-cancel mode." },
    { name = "Gamepad",      capKey = "Gamepad",       level = "optional",    message = "Gamepad shortcuts will be unavailable." },
    { name = "Loadstring",   test = function() return type(loadstring) == "function" end, level = "optional", message = "External scripts cannot be evaluated." },
    { name = "SetClipboard", test = function() return type(setclipboard) == "function" end, level = "optional", message = "Cannot copy text to system clipboard." },
}

local _featuresIndex = {}
for _, f in ipairs(LouisHub.Features) do
    _featuresIndex[f.name] = f
end

function LouisHub:VerifySupport(featureName)
    local f = _featuresIndex[featureName]
    if not f then
        return { ok = false, level = "unknown", name = featureName, message = "Feature not recognized by LouisHub." }
    end
    local ok = false
    if f.capKey then
        ok = self.Capabilities[f.capKey] == true
    elseif f.test then
        local okTest, res = pcall(f.test)
        ok = okTest and res == true
    end
    return { ok = ok, level = f.level, name = f.name, message = ok and nil or f.message }
end

function LouisHub:ForceType(envType)
    if envType and not VALID_ENV_TYPES[envType] then
        return false, "Invalid environment type. Valid: PC, Mobile, Tablet, Console, Studio, Unknown."
    end
    _G.LouisHub_ForcedType = envType
    self:RecalculateEnvironmentDerivatives()
    return true
end

function LouisHub:ReleaseForcedType()
    return self:ForceType(nil)
end

function LouisHub:FullDiagnostics()
    local C = self.Capabilities
    local supportedCount, totalCount, warnings = 0, 0, {}
    for _, f in ipairs(self.Features) do
        totalCount = totalCount + 1
        local r = self:VerifySupport(f.name)
        if r.ok then
            supportedCount = supportedCount + 1
        elseif f.level ~= "required" then
            table.insert(warnings, {
                name    = f.name,
                level   = f.level,
                message = r.message,
            })
        end
    end
    return {
        Type          = C.Type,
        Platform      = C:PlatformName(),
        IsStudio      = C.IsStudio,
        Executor      = detectExecutor(),
        Viewport      = C.ViewportSize,
        ForcedType    = _G.LouisHub_ForcedType,
        FeaturesOk    = supportedCount,
        FeaturesTotal = totalCount,
        Warnings      = warnings,
        Capabilities  = C,
    }
end

-- ══════════════════════════════════════════════════════════════
--  SECTION 5: ERROR HANDLING & LOGGING ENGINE
-- ══════════════════════════════════════════════════════════════
local MAX_ERROR_LOGS = 50
LouisHub._Logs = {}

function LouisHub:_LogError(context, message)
    table.insert(self._Logs, {
        Time    = os.time(),
        Context = tostring(context or "?"),
        Message = tostring(message or ""),
    })
    if #self._Logs > MAX_ERROR_LOGS then
        table.remove(self._Logs, 1)
    end
    warn("[LouisHub] Error in '" .. tostring(context or "?") .. "': " .. tostring(message or ""))
end

function LouisHub:GetErrors()
    local copy = {}
    for i, entry in ipairs(self._Logs) do copy[i] = cloneTable(entry) end
    return copy
end

local function silentTry(description, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and LouisHub.DebugMode then
        warn("[LouisHub] (DebugMode) '" .. description .. "' failed: " .. tostring(err))
    end
    return ok, err
end

local function warnDev(ctrlType, name, message)
    warn(("[LouisHub] %s \"%s\": %s"):format(ctrlType, tostring(name or "?"), message))
end

local function executeWithFallback(callback, context, ...)
    if not callback then return end
    local args = {...}
    local ok, err = pcall(function() return callback(table.unpack(args)) end)
    if not ok then
        LouisHub:_LogError(context, err)
        local fullMsg = tostring(err)
        local displayMsg = fullMsg:sub(1, 120)
        if #fullMsg > 120 then
            displayMsg = displayMsg .. "… (inspect LouisHub:GetErrors())"
        end
        if LouisHub.ShowUIErrors ~= false and LouisHub.Notify then
            pcall(function()
                LouisHub:Notify({
                    Title    = "⚠️ Error in " .. (context or "control"),
                    Content  = displayMsg,
                    Duration = 6,
                    Icon     = "warning"
                })
            end)
        end
        warn("[LouisHub] Callback error (" .. (context or "?") .. "):", err)
    end
    return ok
end

local function validateCallback(ctrlType, cfg)
    if cfg.Callback ~= nil and type(cfg.Callback) ~= "function" then
        warnDev(ctrlType, cfg.Text or cfg.Name, "'Callback' provided but is not a function (got " .. typeof(cfg.Callback) .. "). Ignored.")
        cfg.Callback = nil
    end
end

-- ══════════════════════════════════════════════════════════════
--  SECTION 6: SIGNALS, GLOBAL FLAGS & STATE REGISTRY
-- ══════════════════════════════════════════════════════════════
local function createSignal()
    local connected = {}
    local sig = {}
    function sig:Connect(callback)
        if type(callback) ~= "function" then
            return {Disconnect = function() end}
        end
        local entry = {active = true, callback = callback}
        table.insert(connected, entry)
        return {
            Disconnect = function() entry.active = false end,
        }
    end
    function sig:Fire(...)
        local snapshot = table.move(connected, 1, #connected, 1, {})
        for _, entry in ipairs(snapshot) do
            if entry.active then
                local ok, err = pcall(entry.callback, ...)
                if not ok then LouisHub:_LogError("Events", err) end
            end
        end
    end
    return sig
end

LouisHub.Events = {
    FlagChanged         = createSignal(),
    TabChanged          = createSignal(),
    ThemeChanged        = createSignal(),
    ControlRegistered   = createSignal(),
    TypeChanged         = createSignal(),
    HistoryChanged      = createSignal(),
    CategoryChanged     = createSignal(),
    SubTabChanged       = createSignal(),
}

local function newElementTable()
    return setmetatable({}, {
        __newindex = function(t, flag, elem)
            rawset(t, flag, elem)
            if type(elem) == "table" and type(elem.Get) == "function" then
                local ok, val = pcall(function() return elem:Get() end)
                if ok and val ~= nil then elem._default = copyDefault(val) end
            end
        end,
    })
end

LouisHub.Elements = newElementTable()
LouisHub.Options  = {}

local activeSaveWindow = nil
local hasPendingUnsavedChanges = false
local isAutosaveLoopActive = false
local _isLoadingFromFile = false

local function markPendingChange()
    if _isLoadingFromFile then return end
    hasPendingUnsavedChanges = true
end

local function startAutosaveLoop()
    if isAutosaveLoopActive then return end
    isAutosaveLoopActive = true
    LouisHub:RegisterThread(task.spawn(function()
        while isAutosaveLoopActive do
            task.wait(10)
            if hasPendingUnsavedChanges and activeSaveWindow and activeSaveWindow.ConfigName and LouisHub.SaveManager then
                hasPendingUnsavedChanges = false
                pcall(function()
                    LouisHub.SaveManager:SaveSilent(activeSaveWindow.ConfigName)
                end)
            end
        end
    end))
end

local _realFlags = {}
local _nonPersistentFlags = {}
local _uiFlags = {}
local _registeredKeybinds = {}

local function _decomposeKey(v)
    if typeof(v) == "table" then
        return v.KeyCode, v.Ctrl or false, v.Shift or false, v.Alt or false
    end
    return v, false, false, false
end

local function _formatKey(keyCode, ctrl, shift, alt)
    if not keyCode or keyCode == Enum.KeyCode.Unknown then return "None" end
    local parts = {}
    if ctrl then table.insert(parts, "Ctrl") end
    if shift then table.insert(parts, "Shift") end
    if alt then table.insert(parts, "Alt") end
    table.insert(parts, keyCode.Name)
    return table.concat(parts, "+")
end

local function _keysInConflict(a, b)
    local kA, cA, sA, aA = _decomposeKey(a)
    local kB, cB, sB, aB = _decomposeKey(b)
    if not kA or not kB then return false end
    if kA == Enum.KeyCode.Unknown or kB == Enum.KeyCode.Unknown then return false end
    return kA == kB and cA == cB and sA == sB and aA == aB
end

local function _checkKeybindConflict(ownEntry, newVal)
    local conflicts = {}
    for _, entry in ipairs(_registeredKeybinds) do
        if entry ~= ownEntry then
            local okVal, otherVal = pcall(function() return entry:GetValue() end)
            if okVal and _keysInConflict(newVal, otherVal) then
                table.insert(conflicts, entry.text or "Keybind")
            end
        end
    end
    if #conflicts > 0 then
        local k, c, s, a = _decomposeKey(newVal)
        pcall(function()
            LouisHub:Notify({
                Title    = "⚠️ Keybind in Use",
                Content  = "'" .. _formatKey(k, c, s, a) .. "' is already assigned to: " .. table.concat(conflicts, ", "),
                Duration = 4,
                Icon     = "warning"
            })
        end)
    end
end

LouisHub.Flags = setmetatable({}, {
    __index = _realFlags,
    __newindex = function(_, key, val)
        if type(val) ~= "table" and _realFlags[key] == val then
            return
        end
        _realFlags[key] = val
        markPendingChange()
        if LouisHub.Events and LouisHub.Events.FlagChanged then
            LouisHub.Events.FlagChanged:Fire(key, val)
        end
    end,
})

function LouisHub:GetFlag(flag)
    return LouisHub.Flags[flag]
end

function LouisHub:GetElement(flag)
    return LouisHub.Elements[flag]
end

function LouisHub:UpdateLabel(flag, text)
    local elem = self.Elements[flag]
    if not elem then return false end
    return pcall(function() elem:Set(text) end)
end

function LouisHub:MarkAsUI(flagOrTable)
    if type(flagOrTable) == "table" then
        for _, f in ipairs(flagOrTable) do _uiFlags[f] = true end
    else
        _uiFlags[flagOrTable] = true
    end
end

function LouisHub:Try(flag, fallback)
    local elem = self.Elements[flag]
    if not elem then return fallback end
    local ok, val = pcall(function() return elem:Get() end)
    if not ok or val == nil then return fallback end
    return val
end

--[[
╔══════════════════════════════════════════════════════════════════════╗
                              LouisHub
                Master UI Suite: LouisHub Engine V4.0
             PART 1B: COMPLETE ICON MODULE (300+ ICONS)
╚══════════════════════════════════════════════════════════════════════╝
]]

-- ══════════════════════════════════════════════════════════════
--  SECTION 7: COMPLETE ICON MODULE (MATERIAL & LUCIDE MAPPINGS)
-- ══════════════════════════════════════════════════════════════
local IconModule = {
    Lucide = nil,
    Material = {
        ["perm_media"] = "http://www.roblox.com/asset/?id=6031215982",
        ["sticky_note_2"] = "http://www.roblox.com/asset/?id=6031265972",
        ["gavel"] = "http://www.roblox.com/asset/?id=6023565902",
        ["table_view"] = "http://www.roblox.com/asset/?id=6031233835",
        ["home"] = "http://www.roblox.com/asset/?id=6026568195",
        ["list"] = "http://www.roblox.com/asset/?id=6026568229",
        ["alarm_add"] = "http://www.roblox.com/asset/?id=6023426898",
        ["speaker_notes"] = "http://www.roblox.com/asset/?id=6031266001",
        ["check_circle_outline"] = "http://www.roblox.com/asset/?id=6023426909",
        ["extension"] = "http://www.roblox.com/asset/?id=6023565892",
        ["pending"] = "http://www.roblox.com/asset/?id=6031084745",
        ["pageview"] = "http://www.roblox.com/asset/?id=6031216007",
        ["group_work"] = "http://www.roblox.com/asset/?id=6023565910",
        ["zoom_in"] = "http://www.roblox.com/asset/?id=6031075573",
        ["aspect_ratio"] = "http://www.roblox.com/asset/?id=6022668895",
        ["code"] = "http://www.roblox.com/asset/?id=6022668955",
        ["3d_rotation"] = "http://www.roblox.com/asset/?id=6022668893",
        ["translate"] = "http://www.roblox.com/asset/?id=6031225812",
        ["star_rate"] = "http://www.roblox.com/asset/?id=6031265978",
        ["system_update_alt"] = "http://www.roblox.com/asset/?id=6031251515",
        ["open_with"] = "http://www.roblox.com/asset/?id=6026568265",
        ["build_circle"] = "http://www.roblox.com/asset/?id=6023426952",
        ["toc"] = "http://www.roblox.com/asset/?id=6031229341",
        ["settings_phone"] = "http://www.roblox.com/asset/?id=6031289445",
        ["open_in_full"] = "http://www.roblox.com/asset/?id=6026568245",
        ["history"] = "http://www.roblox.com/asset/?id=6026568197",
        ["accessibility_new"] = "http://www.roblox.com/asset/?id=6022668945",
        ["hourglass_disabled"] = "http://www.roblox.com/asset/?id=6026568193",
        ["line_style"] = "http://www.roblox.com/asset/?id=6026568276",
        ["account_circle"] = "http://www.roblox.com/asset/?id=6022668898",
        ["settings_cell"] = "http://www.roblox.com/asset/?id=6031280890",
        ["search_off"] = "http://www.roblox.com/asset/?id=6031260783",
        ["shop"] = "http://www.roblox.com/asset/?id=6031265983",
        ["anchor"] = "http://www.roblox.com/asset/?id=6023426906",
        ["language"] = "http://www.roblox.com/asset/?id=6026568213",
        ["settings_brightness"] = "http://www.roblox.com/asset/?id=6031280902",
        ["restore_page"] = "http://www.roblox.com/asset/?id=6031154877",
        ["chrome_reader_mode"] = "http://www.roblox.com/asset/?id=6023426912",
        ["sync_alt"] = "http://www.roblox.com/asset/?id=6031233840",
        ["book"] = "http://www.roblox.com/asset/?id=6022860343",
        ["smart_button"] = "http://www.roblox.com/asset/?id=6031265962",
        ["request_page"] = "http://www.roblox.com/asset/?id=6031154873",
        ["lock_clock"] = "http://www.roblox.com/asset/?id=6026568260",
        ["android"] = "http://www.roblox.com/asset/?id=6022668966",
        ["outgoing_mail"] = "http://www.roblox.com/asset/?id=6026568242",
        ["dynamic_form"] = "http://www.roblox.com/asset/?id=6023426970",
        ["track_changes"] = "http://www.roblox.com/asset/?id=6031225814",
        ["source"] = "http://www.roblox.com/asset/?id=6031289451",
        ["thumb_down"] = "http://www.roblox.com/asset/?id=6031229336",
        ["integration_instructions"] = "http://www.roblox.com/asset/?id=6026568214",
        ["opacity"] = "http://www.roblox.com/asset/?id=6026568295",
        ["perm_identity"] = "http://www.roblox.com/asset/?id=6031215978",
        ["view_module"] = "http://www.roblox.com/asset/?id=6031079152",
        ["perm_data_setting"] = "http://www.roblox.com/asset/?id=6031215991",
        ["assignment_turned_in"] = "http://www.roblox.com/asset/?id=6023426904",
        ["change_history"] = "http://www.roblox.com/asset/?id=6023426914",
        ["thumb_down_off_alt"] = "http://www.roblox.com/asset/?id=6031229354",
        ["text_rotation_angledown"] = "http://www.roblox.com/asset/?id=6031251513",
        ["bookmark"] = "http://www.roblox.com/asset/?id=6022852108",
        ["view_stream"] = "http://www.roblox.com/asset/?id=6031079164",
        ["remove_done"] = "http://www.roblox.com/asset/?id=6031086169",
        ["markunread_mailbox"] = "http://www.roblox.com/asset/?id=6031082531",
        ["store"] = "http://www.roblox.com/asset/?id=6031265968",
        ["text_rotation_angleup"] = "http://www.roblox.com/asset/?id=6031229337",
        ["eco"] = "http://www.roblox.com/asset/?id=6023426988",
        ["find_in_page"] = "http://www.roblox.com/asset/?id=6023426986",
        ["api"] = "http://www.roblox.com/asset/?id=6022668911",
        ["launch"] = "http://www.roblox.com/asset/?id=6026568211",
        ["text_rotation_down"] = "http://www.roblox.com/asset/?id=6031229334",
        ["flip_to_back"] = "http://www.roblox.com/asset/?id=6023565896",
        ["contact_page"] = "http://www.roblox.com/asset/?id=6022668881",
        ["preview"] = "http://www.roblox.com/asset/?id=6031260793",
        ["restore"] = "http://www.roblox.com/asset/?id=6031260800",
        ["favorite_border"] = "http://www.roblox.com/asset/?id=6023565882",
        ["assignment_late"] = "http://www.roblox.com/asset/?id=6022668880",
        ["youtube_searched_for"] = "http://www.roblox.com/asset/?id=6031075934",
        ["hourglass_full"] = "http://www.roblox.com/asset/?id=6026568190",
        ["timeline"] = "http://www.roblox.com/asset/?id=6031229350",
        ["turned_in"] = "http://www.roblox.com/asset/?id=6031225808",
        ["info"] = "http://www.roblox.com/asset/?id=6026568227",
        ["restore_from_trash"] = "http://www.roblox.com/asset/?id=6031154869",
        ["arrow_circle_down"] = "http://www.roblox.com/asset/?id=6022668877",
        ["flaky"] = "http://www.roblox.com/asset/?id=6031082523",
        ["alarm_on"] = "http://www.roblox.com/asset/?id=6023426920",
        ["swap_vertical_circle"] = "http://www.roblox.com/asset/?id=6031233839",
        ["open_in_new"] = "http://www.roblox.com/asset/?id=6026568256",
        ["watch_later"] = "http://www.roblox.com/asset/?id=6031075924",
        ["alarm_off"] = "http://www.roblox.com/asset/?id=6023426901",
        ["maximize"] = "http://www.roblox.com/asset/?id=6026568267",
        ["lock_outline"] = "http://www.roblox.com/asset/?id=6031082533",
        ["outbond"] = "http://www.roblox.com/asset/?id=6026568244",
        ["view_carousel"] = "http://www.roblox.com/asset/?id=6031251507",
        ["published_with_changes"] = "http://www.roblox.com/asset/?id=6031243328",
        ["verified_user"] = "http://www.roblox.com/asset/?id=6031225819",
        ["drag_indicator"] = "http://www.roblox.com/asset/?id=6023426962",
        ["lightbulb_outline"] = "http://www.roblox.com/asset/?id=6026568254",
        ["segment"] = "http://www.roblox.com/asset/?id=6031260773",
        ["assignment"] = "http://www.roblox.com/asset/?id=6022668882",
        ["work_outline"] = "http://www.roblox.com/asset/?id=6031075930",
        ["line_weight"] = "http://www.roblox.com/asset/?id=6026568226",
        ["dangerous"] = "http://www.roblox.com/asset/?id=6022668916",
        ["assessment"] = "http://www.roblox.com/asset/?id=6022668897",
        ["view_day"] = "http://www.roblox.com/asset/?id=6031079153",
        ["help_center"] = "http://www.roblox.com/asset/?id=6026568192",
        ["logout"] = "http://www.roblox.com/asset/?id=6031082522",
        ["event"] = "http://www.roblox.com/asset/?id=6023426959",
        ["get_app"] = "http://www.roblox.com/asset/?id=6023565889",
        ["tab"] = "http://www.roblox.com/asset/?id=6031233851",
        ["label"] = "http://www.roblox.com/asset/?id=6031082525",
        ["g_translate"] = "http://www.roblox.com/asset/?id=6031082526",
        ["view_week"] = "http://www.roblox.com/asset/?id=6031079154",
        ["view_in_ar"] = "http://www.roblox.com/asset/?id=6031079158",
        ["card_travel"] = "http://www.roblox.com/asset/?id=6023426925",
        ["lock_open"] = "http://www.roblox.com/asset/?id=6026568220",
        ["voice_over_off"] = "http://www.roblox.com/asset/?id=6031075927",
        ["app_blocking"] = "http://www.roblox.com/asset/?id=6022668952",
        ["settings_ethernet"] = "http://www.roblox.com/asset/?id=6031280883",
        ["supervised_user_circle"] = "http://www.roblox.com/asset/?id=6031289449",
        ["done_all"] = "http://www.roblox.com/asset/?id=6023426929",
        ["lightbulb"] = "http://www.roblox.com/asset/?id=6026568247",
        ["find_replace"] = "http://www.roblox.com/asset/?id=6023426979",
        ["bookmarks"] = "http://www.roblox.com/asset/?id=6023426924",
        ["today"] = "http://www.roblox.com/asset/?id=6031229352",
        ["class"] = "http://www.roblox.com/asset/?id=6022668949",
        ["supervisor_account"] = "http://www.roblox.com/asset/?id=6031251516",
        ["support"] = "http://www.roblox.com/asset/?id=6031251532",
        ["done_outline"] = "http://www.roblox.com/asset/?id=6023426936",
        ["reorder"] = "http://www.roblox.com/asset/?id=6031154868",
        ["fact_check"] = "http://www.roblox.com/asset/?id=6023426951",
        ["thumb_up"] = "http://www.roblox.com/asset/?id=6031229347",
        ["assignment_returned"] = "http://www.roblox.com/asset/?id=6023426899",
        ["card_giftcard"] = "http://www.roblox.com/asset/?id=6023426978",
        ["trending_down"] = "http://www.roblox.com/asset/?id=6031225811",
        ["settings_backup_restore"] = "http://www.roblox.com/asset/?id=6031280886",
        ["settings_voice"] = "http://www.roblox.com/asset/?id=6031265966",
        ["dns"] = "http://www.roblox.com/asset/?id=6023426958",
        ["perm_scan_wifi"] = "http://www.roblox.com/asset/?id=6031215985",
        ["plagiarism"] = "http://www.roblox.com/asset/?id=6031243320",
        ["commute"] = "http://www.roblox.com/asset/?id=6022668901",
        ["gif"] = "http://www.roblox.com/asset/?id=6031082540",
        ["work"] = "http://www.roblox.com/asset/?id=6031075939",
        ["picture_in_picture_alt"] = "http://www.roblox.com/asset/?id=6031215979",
        ["query_builder"] = "http://www.roblox.com/asset/?id=6031086183",
        ["label_off"] = "http://www.roblox.com/asset/?id=6026568209",
        ["all_out"] = "http://www.roblox.com/asset/?id=6022668876",
        ["article"] = "http://www.roblox.com/asset/?id=6022668907",
        ["shopping_basket"] = "http://www.roblox.com/asset/?id=6031265997",
        ["mark_as_unread"] = "http://www.roblox.com/asset/?id=6026568223",
        ["work_off"] = "http://www.roblox.com/asset/?id=6031075937",
        ["delete_outline"] = "http://www.roblox.com/asset/?id=6022668962",
        ["account_box"] = "http://www.roblox.com/asset/?id=6023426915",
        ["home_filled"] = "rbxassetid://9080449299",
        ["lock"] = "http://www.roblox.com/asset/?id=6026568224",
        ["perm_device_information"] = "http://www.roblox.com/asset/?id=6031215996",
        ["add_task"] = "http://www.roblox.com/asset/?id=6022668912",
        ["text_rotate_up"] = "http://www.roblox.com/asset/?id=6031251526",
        ["swipe"] = "http://www.roblox.com/asset/?id=6031233863",
        ["eject"] = "http://www.roblox.com/asset/?id=6023426930",
        ["mediation"] = "http://www.roblox.com/asset/?id=6026568249",
        ["label_important_outline"] = "http://www.roblox.com/asset/?id=6026568199",
        ["settings_remote"] = "http://www.roblox.com/asset/?id=6031289442",
        ["history_toggle_off"] = "http://www.roblox.com/asset/?id=6026568196",
        ["invert_colors"] = "http://www.roblox.com/asset/?id=6026568253",
        ["visibility_off"] = "http://www.roblox.com/asset/?id=6031075929",
        ["addchart"] = "http://www.roblox.com/asset/?id=6023426905",
        ["cancel_schedule_send"] = "http://www.roblox.com/asset/?id=6022668963",
        ["loyalty"] = "http://www.roblox.com/asset/?id=6026568237",
        ["speaker_notes_off"] = "http://www.roblox.com/asset/?id=6031265965",
        ["online_prediction"] = "http://www.roblox.com/asset/?id=6026568239",
        ["remove_shopping_cart"] = "http://www.roblox.com/asset/?id=6031260778",
        ["text_rotate_vertical"] = "http://www.roblox.com/asset/?id=6031251518",
        ["visibility"] = "http://www.roblox.com/asset/?id=6031075931",
        ["add_to_drive"] = "http://www.roblox.com/asset/?id=6022860335",
        ["accessible"] = "http://www.roblox.com/asset/?id=6022668902",
        ["bookmark_border"] = "http://www.roblox.com/asset/?id=6022860339",
        ["tour"] = "http://www.roblox.com/asset/?id=6031229362",
        ["compare_arrows"] = "http://www.roblox.com/asset/?id=6022668951",
        ["view_sidebar"] = "http://www.roblox.com/asset/?id=6031079160",
        ["face"] = "http://www.roblox.com/asset/?id=6023426944",
        ["wysiwyg"] = "http://www.roblox.com/asset/?id=6031075938",
        ["camera_enhance"] = "http://www.roblox.com/asset/?id=6023426935",
        ["perm_camera_mic"] = "http://www.roblox.com/asset/?id=6031215983",
        ["model_training"] = "http://www.roblox.com/asset/?id=6026568222",
        ["arrow_circle_up"] = "http://www.roblox.com/asset/?id=6022668934",
        ["euro_symbol"] = "http://www.roblox.com/asset/?id=6023426954",
        ["pending_actions"] = "http://www.roblox.com/asset/?id=6031260777",
        ["not_accessible"] = "http://www.roblox.com/asset/?id=6026568269",
        ["explore_off"] = "http://www.roblox.com/asset/?id=6023426953",
        ["build"] = "http://www.roblox.com/asset/?id=6023426938",
        ["backup"] = "http://www.roblox.com/asset/?id=6023426911",
        ["settings_input_antenna"] = "http://www.roblox.com/asset/?id=6031280891",
        ["disabled_by_default"] = "http://www.roblox.com/asset/?id=6023426939",
        ["upgrade"] = "http://www.roblox.com/asset/?id=6031225815",
        ["contactless"] = "http://www.roblox.com/asset/?id=6022668886",
        ["trending_flat"] = "http://www.roblox.com/asset/?id=6031225818",
        ["schedule"] = "http://www.roblox.com/asset/?id=6031260808",
        ["offline_pin"] = "http://www.roblox.com/asset/?id=6031084770",
        ["date_range"] = "http://www.roblox.com/asset/?id=6022668894",
        ["flight_land"] = "http://www.roblox.com/asset/?id=6023565897",
        ["view_headline"] = "http://www.roblox.com/asset/?id=6031079151",
        ["cached"] = "http://www.roblox.com/asset/?id=6023426921",
        ["unpublished"] = "http://www.roblox.com/asset/?id=6031225817",
        ["outlet"] = "http://www.roblox.com/asset/?id=6031084748",
        ["favorite"] = "http://www.roblox.com/asset/?id=6023426974",
        ["vertical_split"] = "http://www.roblox.com/asset/?id=6031225820",
        ["report_problem"] = "http://www.roblox.com/asset/?id=6031086176",
        ["fingerprint"] = "http://www.roblox.com/asset/?id=6023565895",
        ["important_devices"] = "http://www.roblox.com/asset/?id=6026568202",
        ["outbox"] = "http://www.roblox.com/asset/?id=6026568263",
        ["all_inbox"] = "http://www.roblox.com/asset/?id=6022668909",
        ["label_important"] = "http://www.roblox.com/asset/?id=6026568215",
        ["print"] = "http://www.roblox.com/asset/?id=6031243324",
        ["settings_bluetooth"] = "http://www.roblox.com/asset/?id=6031280905",
        ["power_settings_new"] = "http://www.roblox.com/asset/?id=6031260781",
        ["zoom_out"] = "http://www.roblox.com/asset/?id=6031075577",
        ["stars"] = "http://www.roblox.com/asset/?id=6031265971",
        ["offline_bolt"] = "http://www.roblox.com/asset/?id=6031084742",
        ["feedback"] = "http://www.roblox.com/asset/?id=6023426957",
        ["accessibility"] = "http://www.roblox.com/asset/?id=6022668887",
        ["announcement"] = "http://www.roblox.com/asset/?id=6022668946",
        ["settings_input_hdmi"] = "http://www.roblox.com/asset/?id=6031280970",
        ["leaderboard"] = "http://www.roblox.com/asset/?id=6026568216",
        ["view_quilt"] = "http://www.roblox.com/asset/?id=6031079155",
        ["note_add"] = "http://www.roblox.com/asset/?id=6031084749",
        ["theaters"] = "http://www.roblox.com/asset/?id=6031229335",
        ["alarm"] = "http://www.roblox.com/asset/?id=6023426910",
        ["settings_input_composite"] = "http://www.roblox.com/asset/?id=6031280896",
        ["grade"] = "http://www.roblox.com/asset/?id=6026568189",
        ["tab_unselected"] = "http://www.roblox.com/asset/?id=6031251505",
        ["swap_vert"] = "http://www.roblox.com/asset/?id=6031233847",
        ["assignment_return"] = "http://www.roblox.com/asset/?id=6023426931",
        ["highlight_alt"] = "http://www.roblox.com/asset/?id=6023565913",
        ["shopping_bag"] = "http://www.roblox.com/asset/?id=6031265970",
        ["contact_support"] = "http://www.roblox.com/asset/?id=6022668879",
        ["flip_to_front"] = "http://www.roblox.com/asset/?id=6023565894",
        ["touch_app"] = "http://www.roblox.com/asset/?id=6031229361",
        ["room"] = "http://www.roblox.com/asset/?id=6031154875",
        ["send_and_archive"] = "http://www.roblox.com/asset/?id=6031280889",
        ["view_array"] = "http://www.roblox.com/asset/?id=6031225842",
        ["settings_power"] = "http://www.roblox.com/asset/?id=6031289446",
        ["admin_panel_settings"] = "http://www.roblox.com/asset/?id=6022668961",
        ["open_in_browser"] = "http://www.roblox.com/asset/?id=6026568266",
        ["card_membership"] = "http://www.roblox.com/asset/?id=6023426942",
        ["rule"] = "http://www.roblox.com/asset/?id=6031154859",
        ["schedule_send"] = "http://www.roblox.com/asset/?id=6031154866",
        ["calendar_today"] = "http://www.roblox.com/asset/?id=6022668917",
        ["info_outline"] = "http://www.roblox.com/asset/?id=6026568210",
        ["description"] = "http://www.roblox.com/asset/?id=6022668888",
        ["dashboard_customize"] = "http://www.roblox.com/asset/?id=6022668899",
        ["rowing"] = "http://www.roblox.com/asset/?id=6031154857",
        ["swap_horizontal_circle"] = "http://www.roblox.com/asset/?id=6031233833",
        ["account_balance_wallet"] = "http://www.roblox.com/asset/?id=6022668892",
        ["view_agenda"] = "http://www.roblox.com/asset/?id=6031225831",
        ["shop_two"] = "http://www.roblox.com/asset/?id=6031289461",
        ["done"] = "http://www.roblox.com/asset/?id=6023426926",
        ["circle_notifications"] = "http://www.roblox.com/asset/?id=6023426923",
        ["compress"] = "http://www.roblox.com/asset/?id=6022668878",
        ["calendar_view_day"] = "http://www.roblox.com/asset/?id=6023426946",
        ["thumbs_up_down"] = "http://www.roblox.com/asset/?id=6031229373",
        ["account_balance"] = "http://www.roblox.com/asset/?id=6022668900",
        ["play_for_work"] = "http://www.roblox.com/asset/?id=6031260776",
        ["pets"] = "http://www.roblox.com/asset/?id=6031260782",
        ["view_column"] = "http://www.roblox.com/asset/?id=6031079172",
        ["search"] = "http://www.roblox.com/asset/?id=6031154871",
        ["autorenew"] = "http://www.roblox.com/asset/?id=6023565901",
        ["copyright"] = "http://www.roblox.com/asset/?id=6023565898",
        ["privacy_tip"] = "http://www.roblox.com/asset/?id=6031260784",
        ["arrow_right_alt"] = "http://www.roblox.com/asset/?id=6022668890",
        ["delete"] = "http://www.roblox.com/asset/?id=6022668885",
        ["nightlight_round"] = "http://www.roblox.com/asset/?id=6031084743",
        ["batch_prediction"] = "http://www.roblox.com/asset/?id=6022860334",
        ["shopping_cart"] = "http://www.roblox.com/asset/?id=6031265976",
        ["login"] = "http://www.roblox.com/asset/?id=6031082527",
        ["settings_input_svideo"] = "http://www.roblox.com/asset/?id=6031289444",
        ["payment"] = "http://www.roblox.com/asset/?id=6031084751",
        ["update"] = "http://www.roblox.com/asset/?id=6031225810",
        ["text_rotation_none"] = "http://www.roblox.com/asset/?id=6031229344",
        ["perm_contact_calendar"] = "http://www.roblox.com/asset/?id=6031215990",
        ["explore"] = "http://www.roblox.com/asset/?id=6023426941",
        ["delete_forever"] = "http://www.roblox.com/asset/?id=6022668939",
        ["rounded_corner"] = "http://www.roblox.com/asset/?id=6031154861",
        ["book_online"] = "http://www.roblox.com/asset/?id=6022860332",
        ["quickreply"] = "http://www.roblox.com/asset/?id=6031243319",
        ["bug_report"] = "http://www.roblox.com/asset/?id=6022852107",
        ["subtitles_off"] = "http://www.roblox.com/asset/?id=6031289466",
        ["close_fullscreen"] = "http://www.roblox.com/asset/?id=6023426928",
        ["horizontal_split"] = "http://www.roblox.com/asset/?id=6026568194",
        ["minimize"] = "http://www.roblox.com/asset/?id=6026568240",
        ["filter_list_alt"] = "http://www.roblox.com/asset/?id=6023426955",
        ["add_shopping_cart"] = "http://www.roblox.com/asset/?id=6022668875",
        ["next_plan"] = "http://www.roblox.com/asset/?id=6026568231",
        ["view_list"] = "http://www.roblox.com/asset/?id=6031079156",
        ["receipt"] = "http://www.roblox.com/asset/?id=6031086173",
        ["polymer"] = "http://www.roblox.com/asset/?id=6031260785",
        ["spellcheck"] = "http://www.roblox.com/asset/?id=6031289450",
        ["wifi_protected_setup"] = "http://www.roblox.com/asset/?id=6031075926",
        ["label_outline"] = "http://www.roblox.com/asset/?id=6026568207",
        ["highlight_off"] = "http://www.roblox.com/asset/?id=6023565916",
        ["turned_in_not"] = "http://www.roblox.com/asset/?id=6031225806",
        ["edit_off"] = "http://www.roblox.com/asset/?id=6023426983",
        ["question_answer"] = "http://www.roblox.com/asset/?id=6031086172",
        ["settings_overscan"] = "http://www.roblox.com/asset/?id=6031289459",
        ["trending_up"] = "http://www.roblox.com/asset/?id=6031225816",
        ["verified"] = "http://www.roblox.com/asset/?id=6031225809",
        ["flight_takeoff"] = "http://www.roblox.com/asset/?id=6023565891",
        ["grading"] = "http://www.roblox.com/asset/?id=6026568191",
        ["dashboard"] = "http://www.roblox.com/asset/?id=6022668883",
        ["expand"] = "http://www.roblox.com/asset/?id=6022668891",
        ["backup_table"] = "http://www.roblox.com/asset/?id=6022860338",
        ["analytics"] = "http://www.roblox.com/asset/?id=6022668884",
        ["picture_in_picture"] = "http://www.roblox.com/asset/?id=6031215994",
        ["settings"] = "http://www.roblox.com/asset/?id=6031280882",
        ["accessible_forward"] = "http://www.roblox.com/asset/?id=6022668906",
        ["pan_tool"] = "http://www.roblox.com/asset/?id=6031084771",
        ["https"] = "http://www.roblox.com/asset/?id=6026568200",
        ["filter_alt"] = "http://www.roblox.com/asset/?id=6023426984",
        ["thumb_up_off_alt"] = "http://www.roblox.com/asset/?id=6031229342",
        ["record_voice_over"] = "http://www.roblox.com/asset/?id=6031243318",
        ["help_outline"] = "http://www.roblox.com/asset/?id=6026568201",
        ["check_circle"] = "http://www.roblox.com/asset/?id=6023426945",
        ["comment_bank"] = "http://www.roblox.com/asset/?id=6023426937",
        ["perm_phone_msg"] = "http://www.roblox.com/asset/?id=6031215986",
        ["settings_applications"] = "http://www.roblox.com/asset/?id=6031280894",
        ["exit_to_app"] = "http://www.roblox.com/asset/?id=6023426922",
        ["saved_search"] = "http://www.roblox.com/asset/?id=6031154867",
        ["toll"] = "http://www.roblox.com/asset/?id=6031229343",
        ["not_started"] = "http://www.roblox.com/asset/?id=6026568232",
        ["subject"] = "http://www.roblox.com/asset/?id=6031289452",
        ["redeem"] = "http://www.roblox.com/asset/?id=6031086170",
        ["input"] = "http://www.roblox.com/asset/?id=6026568225",
        ["settings_input_component"] = "http://www.roblox.com/asset/?id=6031280884",
        ["assignment_ind"] = "http://www.roblox.com/asset/?id=6022668935",
        ["swap_horiz"] = "http://www.roblox.com/asset/?id=6031233841",
        ["fullscreen"] = "http://www.roblox.com/asset/?id=6031094681",
        ["cancel"] = "http://www.roblox.com/asset/?id=6031094677",
        ["subdirectory_arrow_left"] = "http://www.roblox.com/asset/?id=6031104654",
        ["close"] = "http://www.roblox.com/asset/?id=6031094678",
        ["arrow_back_ios"] = "http://www.roblox.com/asset/?id=6031091003",
        ["east"] = "http://www.roblox.com/asset/?id=6031094675",
        ["unfold_more"] = "http://www.roblox.com/asset/?id=6031104644",
        ["south"] = "http://www.roblox.com/asset/?id=6031104646",
        ["arrow_drop_up"] = "http://www.roblox.com/asset/?id=6031090990",
        ["arrow_back"] = "http://www.roblox.com/asset/?id=6031091000",
        ["arrow_downward"] = "http://www.roblox.com/asset/?id=6031090991",
        ["west"] = "http://www.roblox.com/asset/?id=6031104677",
        ["legend_toggle"] = "http://www.roblox.com/asset/?id=6031097233",
        ["fullscreen_exit"] = "http://www.roblox.com/asset/?id=6031094691",
        ["last_page"] = "http://www.roblox.com/asset/?id=6031094686",
        ["switch_right"] = "http://www.roblox.com/asset/?id=6031104649",
        ["check"] = "http://www.roblox.com/asset/?id=6031094667",
        ["home_work"] = "http://www.roblox.com/asset/?id=6031094683",
        ["north_east"] = "http://www.roblox.com/asset/?id=6031097228",
        ["double_arrow"] = "http://www.roblox.com/asset/?id=6031094674",
        ["more_vert"] = "http://www.roblox.com/asset/?id=6031104648",
        ["chevron_left"] = "http://www.roblox.com/asset/?id=6031094670",
        ["more_horiz"] = "http://www.roblox.com/asset/?id=6031104650",
        ["unfold_less"] = "http://www.roblox.com/asset/?id=6031104681",
        ["first_page"] = "http://www.roblox.com/asset/?id=6031094682",
        ["payments"] = "http://www.roblox.com/asset/?id=6031097227",
        ["arrow_right"] = "http://www.roblox.com/asset/?id=6031090994",
        ["offline_share"] = "http://www.roblox.com/asset/?id=6031097267",
        ["south_west"] = "http://www.roblox.com/asset/?id=6031104652",
        ["expand_less"] = "http://www.roblox.com/asset/?id=6031094679",
        ["south_east"] = "http://www.roblox.com/asset/?id=6031104642",
        ["assistant_navigation"] = "http://www.roblox.com/asset/?id=6031091006",
        ["apps"] = "http://www.roblox.com/asset/?id=6031090999",
        ["arrow_upward"] = "http://www.roblox.com/asset/?id=6031090997",
        ["app_settings_alt"] = "http://www.roblox.com/asset/?id=6031090998",
        ["subdirectory_arrow_right"] = "http://www.roblox.com/asset/?id=6031104647",
        ["north_west"] = "http://www.roblox.com/asset/?id=6031104630",
        ["switch_left"] = "http://www.roblox.com/asset/?id=6031104651",
        ["chevron_right"] = "http://www.roblox.com/asset/?id=6031094680",
        ["arrow_forward"] = "http://www.roblox.com/asset/?id=6031090995",
        ["arrow_forward_ios"] = "http://www.roblox.com/asset/?id=6031091008",
        ["arrow_drop_down"] = "http://www.roblox.com/asset/?id=6031091004",
        ["refresh"] = "http://www.roblox.com/asset/?id=6031097226",
        ["pivot_table_chart"] = "http://www.roblox.com/asset/?id=6031097234",
        ["expand_more"] = "http://www.roblox.com/asset/?id=6031094687",
        ["campaign"] = "http://www.roblox.com/asset/?id=6031094666",
        ["arrow_left"] = "http://www.roblox.com/asset/?id=6031091002",
        ["arrow_drop_down_circle"] = "http://www.roblox.com/asset/?id=6031091001",
        ["menu_open"] = "http://www.roblox.com/asset/?id=6031097229",
        ["waterfall_chart"] = "http://www.roblox.com/asset/?id=6031104632",
        ["assistant_direction"] = "http://www.roblox.com/asset/?id=6031091005",
        ["menu"] = "http://www.roblox.com/asset/?id=6031097225",
        ["personal_video"] = "http://www.roblox.com/asset/?id=6034457070",
        ["power_off"] = "http://www.roblox.com/asset/?id=6034457087",
        ["wifi_off"] = "http://www.roblox.com/asset/?id=6034461625",
        ["adb"] = "http://www.roblox.com/asset/?id=6034418515",
        ["airline_seat_recline_normal"] = "http://www.roblox.com/asset/?id=6034418512",
        ["sync_problem"] = "http://www.roblox.com/asset/?id=6034452653",
        ["network_check"] = "http://www.roblox.com/asset/?id=6034461631",
        ["event_busy"] = "http://www.roblox.com/asset/?id=6034439634",
        ["airline_seat_flat"] = "http://www.roblox.com/asset/?id=6034418511",
        ["disc_full"] = "http://www.roblox.com/asset/?id=6034418518",
        ["sd_card"] = "http://www.roblox.com/asset/?id=6034457089",
        ["time_to_leave"] = "http://www.roblox.com/asset/?id=6034452660",
        ["phone_bluetooth_speaker"] = "http://www.roblox.com/asset/?id=6034457057",
        ["phone_paused"] = "http://www.roblox.com/asset/?id=6034457066",
        ["phone_locked"] = "http://www.roblox.com/asset/?id=6034457058",
        ["more"] = "http://www.roblox.com/asset/?id=6034461627",
        ["add_call"] = "http://www.roblox.com/asset/?id=6034418524",
        ["account_tree"] = "http://www.roblox.com/asset/?id=6034418507",
        ["do_not_disturb_on"] = "http://www.roblox.com/asset/?id=6034439649",
        ["event_note"] = "http://www.roblox.com/asset/?id=6034439637",
        ["sync_disabled"] = "http://www.roblox.com/asset/?id=6034452649",
        ["mms"] = "http://www.roblox.com/asset/?id=6034461621",
        ["airline_seat_flat_angled"] = "http://www.roblox.com/asset/?id=6034418513",
        ["bluetooth_audio"] = "http://www.roblox.com/asset/?id=6034418522",
        ["vibration"] = "http://www.roblox.com/asset/?id=6034452651",
        ["system_update"] = "http://www.roblox.com/asset/?id=6034452663",
        ["enhanced_encryption"] = "http://www.roblox.com/asset/?id=6034439652",
        ["wc"] = "http://www.roblox.com/asset/?id=6034452643",
        ["live_tv"] = "http://www.roblox.com/asset/?id=6034439648",
        ["folder_special"] = "http://www.roblox.com/asset/?id=6034439639",
        ["phone_missed"] = "http://www.roblox.com/asset/?id=6034457056",
        ["airline_seat_recline_extra"] = "http://www.roblox.com/asset/?id=6034418528",
        ["sms"] = "http://www.roblox.com/asset/?id=6034452645",
        ["tap_and_play"] = "http://www.roblox.com/asset/?id=6034452650",
        ["confirmation_number"] = "http://www.roblox.com/asset/?id=6034418519",
        ["event_available"] = "http://www.roblox.com/asset/?id=6034439643",
        ["sms_failed"] = "http://www.roblox.com/asset/?id=6034452676",
        ["do_not_disturb_alt"] = "http://www.roblox.com/asset/?id=6034461619",
        ["do_not_disturb"] = "http://www.roblox.com/asset/?id=6034439645",
        ["ondemand_video"] = "http://www.roblox.com/asset/?id=6034457065",
        ["no_encryption"] = "http://www.roblox.com/asset/?id=6034457059",
        ["airline_seat_legroom_extra"] = "http://www.roblox.com/asset/?id=6034418508",
        ["tv_off"] = "http://www.roblox.com/asset/?id=6034452646",
        ["sim_card_alert"] = "http://www.roblox.com/asset/?id=6034452641",
        ["airline_seat_legroom_normal"] = "http://www.roblox.com/asset/?id=6034418532",
        ["wifi"] = "http://www.roblox.com/asset/?id=6034461626",
        ["do_not_disturb_off"] = "http://www.roblox.com/asset/?id=6034439642",
        ["imagesearch_roller"] = "http://www.roblox.com/asset/?id=6034439635",
        ["power"] = "http://www.roblox.com/asset/?id=6034457105",
        ["airline_seat_legroom_reduced"] = "http://www.roblox.com/asset/?id=6034418520",
        ["phone_in_talk"] = "http://www.roblox.com/asset/?id=6034457067",
        ["airline_seat_individual_suite"] = "http://www.roblox.com/asset/?id=6034418514",
        ["priority_high"] = "http://www.roblox.com/asset/?id=6034457092",
        ["phone_callback"] = "http://www.roblox.com/asset/?id=6034457104",
        ["phone_forwarded"] = "http://www.roblox.com/asset/?id=6034457106",
        ["sync"] = "http://www.roblox.com/asset/?id=6034452662",
        ["vpn_lock"] = "http://www.roblox.com/asset/?id=6034452648",
        ["support_agent"] = "http://www.roblox.com/asset/?id=6034452656",
        ["network_locked"] = "http://www.roblox.com/asset/?id=6034457064",
        ["directions_off"] = "http://www.roblox.com/asset/?id=6034418517",
        ["drive_eta"] = "http://www.roblox.com/asset/?id=6034464371",
        ["sensor_window"] = "http://www.roblox.com/asset/?id=6031067242",
        ["sensor_door"] = "http://www.roblox.com/asset/?id=6031067241",
        ["keyboard_return"] = "http://www.roblox.com/asset/?id=6034818370",
        ["monitor"] = "http://www.roblox.com/asset/?id=6034837803",
        ["device_hub"] = "http://www.roblox.com/asset/?id=6034789877",
        ["keyboard"] = "http://www.roblox.com/asset/?id=6034818398",
        ["keyboard_voice"] = "http://www.roblox.com/asset/?id=6034818360",
        ["cast"] = "http://www.roblox.com/asset/?id=6034789876",
        ["developer_board"] = "http://www.roblox.com/asset/?id=6034789883",
        ["tablet"] = "http://www.roblox.com/asset/?id=6034848733",
        ["keyboard_hide"] = "http://www.roblox.com/asset/?id=6034818386",
        ["dock"] = "http://www.roblox.com/asset/?id=6034789888",
        ["phonelink"] = "http://www.roblox.com/asset/?id=6034837801",
        ["device_unknown"] = "http://www.roblox.com/asset/?id=6034789884",
        ["speaker_group"] = "http://www.roblox.com/asset/?id=6034848732",
        ["desktop_mac"] = "http://www.roblox.com/asset/?id=6034789898",
        ["point_of_sale"] = "http://www.roblox.com/asset/?id=6034837798",
        ["memory"] = "http://www.roblox.com/asset/?id=6034837807",
        ["keyboard_tab"] = "http://www.roblox.com/asset/?id=6034818363",
        ["router"] = "http://www.roblox.com/asset/?id=6034837806",
        ["sim_card"] = "http://www.roblox.com/asset/?id=6034837800",
        ["headset"] = "http://www.roblox.com/asset/?id=6034789880",
        ["gamepad"] = "http://www.roblox.com/asset/?id=6034789879",
        ["speaker"] = "http://www.roblox.com/asset/?id=6034848746",
        ["devices_other"] = "http://www.roblox.com/asset/?id=6034789873",
        ["laptop"] = "http://www.roblox.com/asset/?id=6034818367",
        ["scanner"] = "http://www.roblox.com/asset/?id=6034837799",
        ["tv"] = "http://www.roblox.com/asset/?id=6034848740",
        ["headset_mic"] = "http://www.roblox.com/asset/?id=6034818383",
        ["browser_not_supported"] = "http://www.roblox.com/asset/?id=6034789875",
        ["computer"] = "http://www.roblox.com/asset/?id=6034789874",
        ["connected_tv"] = "http://www.roblox.com/asset/?id=6034789870",
        ["phonelink_off"] = "http://www.roblox.com/asset/?id=6034837804",
        ["headset_off"] = "http://www.roblox.com/asset/?id=6034818402",
        ["cast_connected"] = "http://www.roblox.com/asset/?id=6034789895",
        ["watch"] = "http://www.roblox.com/asset/?id=6034848747",
        ["keyboard_arrow_up"] = "http://www.roblox.com/asset/?id=6034818379",
        ["keyboard_backspace"] = "http://www.roblox.com/asset/?id=6034818381",
        ["laptop_chromebook"] = "http://www.roblox.com/asset/?id=6034818364",
        ["phone_iphone"] = "http://www.roblox.com/asset/?id=6034837811",
        ["smartphone"] = "http://www.roblox.com/asset/?id=6034848731",
        ["power_input"] = "http://www.roblox.com/asset/?id=6034837794",
        ["videogame_asset"] = "http://www.roblox.com/asset/?id=6034848748",
        ["desktop_windows"] = "http://www.roblox.com/asset/?id=6034789893",
        ["keyboard_arrow_down"] = "http://www.roblox.com/asset/?id=6034818372",
        ["laptop_mac"] = "http://www.roblox.com/asset/?id=6034837808",
        ["laptop_windows"] = "http://www.roblox.com/asset/?id=6034837796",
        ["keyboard_arrow_right"] = "http://www.roblox.com/asset/?id=6034818365",
        ["cast_for_education"] = "http://www.roblox.com/asset/?id=6034789872",
        ["keyboard_capslock"] = "http://www.roblox.com/asset/?id=6034818403",
        ["toys"] = "http://www.roblox.com/asset/?id=6034848752",
        ["tablet_android"] = "http://www.roblox.com/asset/?id=6034848734",
        ["mouse"] = "http://www.roblox.com/asset/?id=6034837797",
        ["phone_android"] = "http://www.roblox.com/asset/?id=6034837793",
        ["keyboard_arrow_left"] = "http://www.roblox.com/asset/?id=6034818375",
        ["security"] = "http://www.roblox.com/asset/?id=6034837802",
        ["dry_cleaning"] = "http://www.roblox.com/asset/?id=6034754456",
        ["bakery_dining"] = "http://www.roblox.com/asset/?id=6034767610",
        ["place"] = "http://www.roblox.com/asset/?id=6034503372",
        ["run_circle"] = "http://www.roblox.com/asset/?id=6034503367",
        ["local_post_office"] = "http://www.roblox.com/asset/?id=6034513883",
        ["takeout_dining"] = "http://www.roblox.com/asset/?id=6034467808",
        ["nightlife"] = "http://www.roblox.com/asset/?id=6034510003",
        ["design_services"] = "http://www.roblox.com/asset/?id=6034754453",
        ["celebration"] = "http://www.roblox.com/asset/?id=6034767613",
        ["near_me_disabled"] = "http://www.roblox.com/asset/?id=6034509988",
        ["add_location_alt"] = "http://www.roblox.com/asset/?id=6034483678",
        ["directions_run"] = "http://www.roblox.com/asset/?id=6034754445",
        ["local_fire_department"] = "http://www.roblox.com/asset/?id=6034684949",
        ["add_road"] = "http://www.roblox.com/asset/?id=6034483677",
        ["my_location"] = "http://www.roblox.com/asset/?id=6034509987",
        ["dinner_dining"] = "http://www.roblox.com/asset/?id=6034754457",
        ["local_airport"] = "http://www.roblox.com/asset/?id=6034687951",
        ["zoom_out_map"] = "http://www.roblox.com/asset/?id=6035229856",
        ["pin_drop"] = "http://www.roblox.com/asset/?id=6034470807",
        ["subway"] = "http://www.roblox.com/asset/?id=6034467790",
        ["electric_moped"] = "http://www.roblox.com/asset/?id=6034744027",
        ["restaurant_menu"] = "http://www.roblox.com/asset/?id=6034503378",
        ["local_gas_station"] = "http://www.roblox.com/asset/?id=6034684935",
        ["local_cafe"] = "http://www.roblox.com/asset/?id=6034687954",
        ["theater_comedy"] = "http://www.roblox.com/asset/?id=6034467796",
        ["directions_bus"] = "http://www.roblox.com/asset/?id=6034754434",
        ["hail"] = "http://www.roblox.com/asset/?id=6034744033",
        ["satellite"] = "http://www.roblox.com/asset/?id=6034503370",
        ["local_phone"] = "http://www.roblox.com/asset/?id=6034513884",
        ["electric_bike"] = "http://www.roblox.com/asset/?id=6034744032",
        ["local_see"] = "http://www.roblox.com/asset/?id=6034513887",
        ["transit_enterexit"] = "http://www.roblox.com/asset/?id=6034467805",
        ["local_convenience_store"] = "http://www.roblox.com/asset/?id=6034687956",
        ["local_offer"] = "http://www.roblox.com/asset/?id=6034513891",
        ["electric_car"] = "http://www.roblox.com/asset/?id=6034744029",
        ["beenhere"] = "http://www.roblox.com/asset/?id=6034483675",
        ["miscellaneous_services"] = "http://www.roblox.com/asset/?id=6034509993",
        ["maps_ugc"] = "http://www.roblox.com/asset/?id=6034509992",
        ["moped"] = "http://www.roblox.com/asset/?id=6034509999",
        ["medical_services"] = "http://www.roblox.com/asset/?id=6034510001",
        ["money"] = "http://www.roblox.com/asset/?id=6034509997",
        ["transfer_within_a_station"] = "http://www.roblox.com/asset/?id=6034467809",
        ["electrical_services"] = "http://www.roblox.com/asset/?id=6034744038",
        ["museum"] = "http://www.roblox.com/asset/?id=6034510005",
        ["add_location"] = "http://www.roblox.com/asset/?id=6034483672",
        ["layers"] = "http://www.roblox.com/asset/?id=6034687957",
        ["handyman"] = "http://www.roblox.com/asset/?id=6034744057",
        ["local_pharmacy"] = "http://www.roblox.com/asset/?id=6034513903",
        ["electric_rickshaw"] = "http://www.roblox.com/asset/?id=6034744043",
        ["alt_route"] = "http://www.roblox.com/asset/?id=6034483670",
        ["no_transfer"] = "http://www.roblox.com/asset/?id=6034503363",
        ["pedal_bike"] = "http://www.roblox.com/asset/?id=6034503374",
        ["directions_transit"] = "http://www.roblox.com/asset/?id=6034754436",
        ["railway_alert"] = "http://www.roblox.com/asset/?id=6034470823",
        ["local_police"] = "http://www.roblox.com/asset/?id=6034513895",
        ["directions_car"] = "http://www.roblox.com/asset/?id=6034754441",
        ["category"] = "http://www.roblox.com/asset/?id=6034767621",
        ["attractions"] = "http://www.roblox.com/asset/?id=6034767620",
        ["person_pin_circle"] = "http://www.roblox.com/asset/?id=6034503375",
        ["cleaning_services"] = "http://www.roblox.com/asset/?id=6034767619",
        ["terrain"] = "http://www.roblox.com/asset/?id=6034467794",
        ["no_meals"] = "http://www.roblox.com/asset/?id=6034510024",
        ["train"] = "http://www.roblox.com/asset/?id=6034467803",
        ["delivery_dining"] = "http://www.roblox.com/asset/?id=6034767644",
        ["pest_control"] = "http://www.roblox.com/asset/?id=6034470809",
        ["directions"] = "http://www.roblox.com/asset/?id=6034754449",
        ["atm"] = "http://www.roblox.com/asset/?id=6034767614",
        ["rate_review"] = "http://www.roblox.com/asset/?id=6034503385",
        ["local_bar"] = "http://www.roblox.com/asset/?id=6034687950",
        ["local_drink"] = "http://www.roblox.com/asset/?id=6034687965",
        ["directions_railway"] = "http://www.roblox.com/asset/?id=6034754433",
        ["person_pin"] = "http://www.roblox.com/asset/?id=6034503364",
        ["ev_station"] = "http://www.roblox.com/asset/?id=6034744037",
        ["home_repair_service"] = "http://www.roblox.com/asset/?id=6034744064",
        ["bus_alert"] = "http://www.roblox.com/asset/?id=6034767618",
        ["agriculture"] = "http://www.roblox.com/asset/?id=6034483674",
        ["volunteer_activism"] = "http://www.roblox.com/asset/?id=6034467799",
        ["breakfast_dining"] = "http://www.roblox.com/asset/?id=6034483671",
        ["layers_clear"] = "http://www.roblox.com/asset/?id=6034687975",
        ["plumbing"] = "http://www.roblox.com/asset/?id=6034470800",
        ["taxi_alert"] = "http://www.roblox.com/asset/?id=6034467792",
        ["add_business"] = "http://www.roblox.com/asset/?id=6034483666",
        ["badge"] = "http://www.roblox.com/asset/?id=6034767607",
        ["edit_attributes"] = "http://www.roblox.com/asset/?id=6034754443",
        ["directions_walk"] = "http://www.roblox.com/asset/?id=6034754448",
        ["local_play"] = "http://www.roblox.com/asset/?id=6034513889",
        ["bike_scooter"] = "http://www.roblox.com/asset/?id=6034483669",
        ["two_wheeler"] = "http://www.roblox.com/asset/?id=6034467795",
        ["local_florist"] = "http://www.roblox.com/asset/?id=6034684940",
        ["local_hotel"] = "http://www.roblox.com/asset/?id=6034684939",
        ["no_meals_ouline"] = "http://www.roblox.com/asset/?id=6034510025",
        ["festival"] = "http://www.roblox.com/asset/?id=6034744031",
        ["local_shipping"] = "http://www.roblox.com/asset/?id=6034684926",
        ["directions_boat"] = "http://www.roblox.com/asset/?id=6034754442",
        ["wrong_location"] = "http://www.roblox.com/asset/?id=6034467801",
        ["restaurant"] = "http://www.roblox.com/asset/?id=6034503366",
        ["directions_subway"] = "http://www.roblox.com/asset/?id=6034754440",
        ["not_listed_location"] = "http://www.roblox.com/asset/?id=6034503380",
        ["electric_scooter"] = "http://www.roblox.com/asset/?id=6034744041",
        ["ramen_dining"] = "http://www.roblox.com/asset/?id=6034503377",
        ["edit_road"] = "http://www.roblox.com/asset/?id=6034744035",
        ["local_printshop"] = "http://www.roblox.com/asset/?id=6034513897",
        ["map"] = "http://www.roblox.com/asset/?id=6034684930",
        ["car_rental"] = "http://www.roblox.com/asset/?id=6034767641",
        ["multiple_stop"] = "http://www.roblox.com/asset/?id=6034510026",
        ["brunch_dining"] = "http://www.roblox.com/asset/?id=6034767611",
        ["local_laundry_service"] = "http://www.roblox.com/asset/?id=6034684943",
        ["set_meal"] = "http://www.roblox.com/asset/?id=6034503368",
        ["local_car_wash"] = "http://www.roblox.com/asset/?id=6034687976",
        ["pest_control_rodent"] = "http://www.roblox.com/asset/?id=6034470803",
        ["local_pizza"] = "http://www.roblox.com/asset/?id=6034513885",
        ["local_grocery_store"] = "http://www.roblox.com/asset/?id=6034684933",
        ["traffic"] = "http://www.roblox.com/asset/?id=6034467797",
        ["departure_board"] = "http://www.roblox.com/asset/?id=6034767615",
        ["icecream"] = "http://www.roblox.com/asset/?id=6034687967",
        ["navigation"] = "http://www.roblox.com/asset/?id=6034509984",
        ["near_me"] = "http://www.roblox.com/asset/?id=6034509996",
        ["fastfood"] = "http://www.roblox.com/asset/?id=6034744034",
        ["local_library"] = "http://www.roblox.com/asset/?id=6034684931",
        ["local_activity"] = "http://www.roblox.com/asset/?id=6034687955",
        ["local_hospital"] = "http://www.roblox.com/asset/?id=6034684956",
        ["menu_book"] = "http://www.roblox.com/asset/?id=6034509994",
        ["directions_bike"] = "http://www.roblox.com/asset/?id=6034754459",
        ["store_mall_directory"] = "http://www.roblox.com/asset/?id=6034470811",
        ["trip_origin"] = "http://www.roblox.com/asset/?id=6034467804",
        ["tram"] = "http://www.roblox.com/asset/?id=6034467806",
        ["edit_location"] = "http://www.roblox.com/asset/?id=6034754439",
        ["streetview"] = "http://www.roblox.com/asset/?id=6034470805",
        ["hvac"] = "http://www.roblox.com/asset/?id=6034687960",
        ["lunch_dining"] = "http://www.roblox.com/asset/?id=6034684928",
        ["car_repair"] = "http://www.roblox.com/asset/?id=6034767617",
        ["compass_calibration"] = "http://www.roblox.com/asset/?id=6034767623",
        ["360"] = "http://www.roblox.com/asset/?id=6034767608",
        ["flight"] = "http://www.roblox.com/asset/?id=6034744030",
        ["local_mall"] = "http://www.roblox.com/asset/?id=6034684934",
        ["hotel"] = "http://www.roblox.com/asset/?id=6034687977",
        ["local_parking"] = "http://www.roblox.com/asset/?id=6034513893",
        ["hardware"] = "http://www.roblox.com/asset/?id=6034744036",
        ["local_dining"] = "http://www.roblox.com/asset/?id=6034687963",
        ["park"] = "http://www.roblox.com/asset/?id=6034503369",
        ["location_pin"] = "http://www.roblox.com/asset/?id=6034684937",
        ["local_movies"] = "http://www.roblox.com/asset/?id=6034684936",
        ["local_atm"] = "http://www.roblox.com/asset/?id=6034687953",
        ["local_taxi"] = "http://www.roblox.com/asset/?id=6034684927",
        ["brightness_low"] = "http://www.roblox.com/asset/?id=6034989542",
        ["screen_lock_landscape"] = "http://www.roblox.com/asset/?id=6034996700",
        ["graphic_eq"] = "http://www.roblox.com/asset/?id=6034989551",
        ["screen_lock_rotation"] = "http://www.roblox.com/asset/?id=6034996710",
        ["signal_cellular_4_bar"] = "http://www.roblox.com/asset/?id=6035030076",
        ["airplanemode_inactive"] = "http://www.roblox.com/asset/?id=6034983848",
        ["signal_wifi_0_bar"] = "http://www.roblox.com/asset/?id=6035030067",
        ["battery_full"] = "http://www.roblox.com/asset/?id=6034983854",
        ["gps_fixed"] = "http://www.roblox.com/asset/?id=6034989550",
        ["brightness_high"] = "http://www.roblox.com/asset/?id=6034989541",
        ["ad_units"] = "http://www.roblox.com/asset/?id=6034983845",
        ["signal_cellular_alt"] = "http://www.roblox.com/asset/?id=6035030079",
        ["bluetooth_connected"] = "http://www.roblox.com/asset/?id=6034983855",
        ["wifi_tethering"] = "http://www.roblox.com/asset/?id=6035039430",
        ["dvr"] = "http://www.roblox.com/asset/?id=6034989561",
        ["screen_search_desktop"] = "http://www.roblox.com/asset/?id=6034996711",
        ["network_wifi"] = "http://www.roblox.com/asset/?id=6034996712",
        ["access_alarms"] = "http://www.roblox.com/asset/?id=6034983853",
        ["nfc"] = "http://www.roblox.com/asset/?id=6034996698",
        ["location_disabled"] = "http://www.roblox.com/asset/?id=6034996694",
        ["signal_wifi_4_bar"] = "http://www.roblox.com/asset/?id=6035030077",
        ["access_time"] = "http://www.roblox.com/asset/?id=6034983856",
        ["mobile_off"] = "http://www.roblox.com/asset/?id=6034996702",
        ["battery_unknown"] = "http://www.roblox.com/asset/?id=6034983842",
        ["signal_cellular_null"] = "http://www.roblox.com/asset/?id=6035030075",
        ["bluetooth_disabled"] = "http://www.roblox.com/asset/?id=6034989562",
        ["developer_mode"] = "http://www.roblox.com/asset/?id=6034989549",
        ["network_cell"] = "http://www.roblox.com/asset/?id=6034996709",
        ["sd_storage"] = "http://www.roblox.com/asset/?id=6034996719",
        ["signal_cellular_no_sim"] = "http://www.roblox.com/asset/?id=6035030078",
        ["devices"] = "http://www.roblox.com/asset/?id=6034989540",
        ["screen_rotation"] = "http://www.roblox.com/asset/?id=6034996701",
        ["device_thermostat"] = "http://www.roblox.com/asset/?id=6034989544",
        ["signal_wifi_off"] = "http://www.roblox.com/asset/?id=6035030074",
        ["widgets"] = "http://www.roblox.com/asset/?id=6035039429",
        ["bluetooth"] = "http://www.roblox.com/asset/?id=6034983880",
        ["battery_charging_full"] = "http://www.roblox.com/asset/?id=6034983849",
        ["mobile_friendly"] = "http://www.roblox.com/asset/?id=6034996699",
        ["signal_cellular_0_bar"] = "http://www.roblox.com/asset/?id=6035030072",
        ["storage"] = "http://www.roblox.com/asset/?id=6035030083",
        ["send_to_mobile"] = "http://www.roblox.com/asset/?id=6034996697",
        ["location_searching"] = "http://www.roblox.com/asset/?id=6034996695",
        ["brightness_auto"] = "http://www.roblox.com/asset/?id=6034989545",
        ["wifi_lock"] = "http://www.roblox.com/asset/?id=6035039428",
        ["gps_not_fixed"] = "http://www.roblox.com/asset/?id=6034989547",
        ["access_alarm"] = "http://www.roblox.com/asset/?id=6034983844",
        ["battery_alert"] = "http://www.roblox.com/asset/?id=6034983843",
        ["signal_cellular_off"] = "http://www.roblox.com/asset/?id=6035030084",
        ["signal_cellular_connected_no_internet_4"] = "http://www.roblox.com/asset/?id=6035229858",
        ["gps_off"] = "http://www.roblox.com/asset/?id=6034989548",
        ["add_alarm"] = "http://www.roblox.com/asset/?id=6034983850",
        ["brightness_medium"] = "http://www.roblox.com/asset/?id=6034989543",
        ["usb"] = "http://www.roblox.com/asset/?id=6035030080",
        ["airplanemode_active"] = "http://www.roblox.com/asset/?id=6034983864",
        ["reset_tv"] = "http://www.roblox.com/asset/?id=6034996696",
        ["wallpaper"] = "http://www.roblox.com/asset/?id=6035030102",
        ["settings_system_daydream"] = "http://www.roblox.com/asset/?id=6035030081",
        ["bluetooth_searching"] = "http://www.roblox.com/asset/?id=6034989553",
        ["add_to_home_screen"] = "http://www.roblox.com/asset/?id=6034983858",
        ["screen_lock_portrait"] = "http://www.roblox.com/asset/?id=6034996706",
        ["data_usage"] = "http://www.roblox.com/asset/?id=6034989568",
        ["_auto_delete"] = "http://www.roblox.com/asset/?id=6031071068",
        ["_error"] = "http://www.roblox.com/asset/?id=6031071057",
        ["_notification_important"] = "http://www.roblox.com/asset/?id=6031071056",
        ["_add_alert"] = "http://www.roblox.com/asset/?id=6031071067",
        ["_warning"] = "http://www.roblox.com/asset/?id=6031071053",
        ["_error_outline"] = "http://www.roblox.com/asset/?id=6031071050",
        ["check_box_outline_blank"] = "http://www.roblox.com/asset/?id=6031068420",
        ["toggle_off"] = "http://www.roblox.com/asset/?id=6031068429",
        ["indeterminate_check_box"] = "http://www.roblox.com/asset/?id=6031068445",
        ["radio_button_checked"] = "http://www.roblox.com/asset/?id=6031068426",
        ["toggle_on"] = "http://www.roblox.com/asset/?id=6031068430",
        ["check_box"] = "http://www.roblox.com/asset/?id=6031068421",
        ["radio_button_unchecked"] = "http://www.roblox.com/asset/?id=6031068433",
        ["star"] = "http://www.roblox.com/asset/?id=6031068423",
        ["star_border"] = "http://www.roblox.com/asset/?id=6031068425",
        ["star_half"] = "http://www.roblox.com/asset/?id=6031068427",
        ["star_outline"] = "http://www.roblox.com/asset/?id=6031068428",
        ["multiline_chart"] = "http://www.roblox.com/asset/?id=6034941721",
        ["pie_chart"] = "http://www.roblox.com/asset/?id=6034973076",
        ["format_line_spacing"] = "http://www.roblox.com/asset/?id=6034910905",
        ["format_align_left"] = "http://www.roblox.com/asset/?id=6034900727",
        ["linear_scale"] = "http://www.roblox.com/asset/?id=6034941707",
        ["insert_photo"] = "http://www.roblox.com/asset/?id=6034941703",
        ["scatter_plot"] = "http://www.roblox.com/asset/?id=6034973094",
        ["post_add"] = "http://www.roblox.com/asset/?id=6034973083",
        ["format_textdirection_r_to_l"] = "http://www.roblox.com/asset/?id=6034925623",
        ["format_size"] = "http://www.roblox.com/asset/?id=6034910908",
        ["format_color_fill"] = "http://www.roblox.com/asset/?id=6034910903",
        ["format_paint"] = "http://www.roblox.com/asset/?id=6034925618",
        ["format_underlined"] = "http://www.roblox.com/asset/?id=6034925627",
        ["format_shapes"] = "http://www.roblox.com/asset/?id=6034910909",
        ["title"] = "http://www.roblox.com/asset/?id=6034934042",
        ["highlight"] = "http://www.roblox.com/asset/?id=6034925617",
        ["bar_chart"] = "http://www.roblox.com/asset/?id=6034898096",
        ["format_indent_increase"] = "http://www.roblox.com/asset/?id=6034900724",
        ["merge_type"] = "http://www.roblox.com/asset/?id=6034941705",
        ["bubble_chart"] = "http://www.roblox.com/asset/?id=6034925612",
        ["publish"] = "http://www.roblox.com/asset/?id=6034973085",
        ["format_indent_decrease"] = "http://www.roblox.com/asset/?id=6034900733",
        ["margin"] = "http://www.roblox.com/asset/?id=6034941701",
        ["table_rows"] = "http://www.roblox.com/asset/?id=6034934025",
        ["stacked_line_chart"] = "http://www.roblox.com/asset/?id=6034934039",
        ["border_clear"] = "http://www.roblox.com/asset/?id=6034898135",
        ["border_color"] = "http://www.roblox.com/asset/?id=6034898100",
        ["border_inner"] = "http://www.roblox.com/asset/?id=6034898131",
        ["insert_chart"] = "http://www.roblox.com/asset/?id=6034925628",
        ["border_top"] = "http://www.roblox.com/asset/?id=6034900726",
        ["padding"] = "http://www.roblox.com/asset/?id=6034973078",
        ["border_vertical"] = "http://www.roblox.com/asset/?id=6034900725",
        ["score"] = "http://www.roblox.com/asset/?id=6034934041",
        ["border_right"] = "http://www.roblox.com/asset/?id=6034898120",
        ["add_chart"] = "http://www.roblox.com/asset/?id=6034898093",
        ["space_bar"] = "http://www.roblox.com/asset/?id=6034934037",
        ["border_outer"] = "http://www.roblox.com/asset/?id=6034898104",
        ["mode_comment"] = "http://www.roblox.com/asset/?id=6034941700",
        ["attach_money"] = "http://www.roblox.com/asset/?id=6034898098",
        ["drag_handle"] = "http://www.roblox.com/asset/?id=6034910907",
        ["format_align_right"] = "http://www.roblox.com/asset/?id=6034900723",
        ["pie_chart_outlined"] = "http://www.roblox.com/asset/?id=6034973077",
        ["horizontal_rule"] = "http://www.roblox.com/asset/?id=6034925610",
        ["border_all"] = "http://www.roblox.com/asset/?id=6034898101",
        ["border_style"] = "http://www.roblox.com/asset/?id=6034898097",
        ["insert_comment"] = "http://www.roblox.com/asset/?id=6034925609",
        ["vertical_align_top"] = "http://www.roblox.com/asset/?id=6034973080",
        ["vertical_align_center"] = "http://www.roblox.com/asset/?id=6034934051",
        ["format_color_text"] = "http://www.roblox.com/asset/?id=6034910910",
        ["format_quote"] = "http://www.roblox.com/asset/?id=6034925629",
        ["height"] = "http://www.roblox.com/asset/?id=6034925613",
        ["add_comment"] = "http://www.roblox.com/asset/?id=6034898128",
        ["format_strikethrough"] = "http://www.roblox.com/asset/?id=6034910904",
        ["strikethrough_s"] = "http://www.roblox.com/asset/?id=6034934030",
        ["border_left"] = "http://www.roblox.com/asset/?id=6034898099",
        ["format_list_bulleted"] = "http://www.roblox.com/asset/?id=6034925620",
        ["format_italic"] = "http://www.roblox.com/asset/?id=6034910912",
        ["format_list_numbered"] = "http://www.roblox.com/asset/?id=6034925622",
        ["attach_file"] = "http://www.roblox.com/asset/?id=6034898102",
        ["wrap_text"] = "http://www.roblox.com/asset/?id=6034973118",
        ["insert_invitation"] = "http://www.roblox.com/asset/?id=6034973091",
        ["format_list_numbered_rtl"] = "http://www.roblox.com/asset/?id=6034910906",
        ["border_horizontal"] = "http://www.roblox.com/asset/?id=6034898105",
        ["format_align_center"] = "http://www.roblox.com/asset/?id=6034900718",
        ["format_textdirection_l_to_r"] = "http://www.roblox.com/asset/?id=6034925619",
        ["show_chart"] = "http://www.roblox.com/asset/?id=6034934032",
        ["insert_chart_outlined"] = "http://www.roblox.com/asset/?id=6034925606",
        ["vertical_align_bottom"] = "http://www.roblox.com/asset/?id=6034934023",
        ["subscript"] = "http://www.roblox.com/asset/?id=6034934059",
        ["format_align_justify"] = "http://www.roblox.com/asset/?id=6034900721",
        ["format_clear"] = "http://www.roblox.com/asset/?id=6034910902",
        ["notes"] = "http://www.roblox.com/asset/?id=6034973084",
        ["insert_drive_file"] = "http://www.roblox.com/asset/?id=6034941697",
        ["functions"] = "http://www.roblox.com/asset/?id=6034925614",
        ["insert_emoticon"] = "http://www.roblox.com/asset/?id=6034973079",
        ["insert_link"] = "http://www.roblox.com/asset/?id=6034973074",
        ["format_color_reset"] = "http://www.roblox.com/asset/?id=6034900743",
        ["monetization_on"] = "http://www.roblox.com/asset/?id=6034973115",
        ["short_text"] = "http://www.roblox.com/asset/?id=6034934035",
        ["mode_edit"] = "http://www.roblox.com/asset/?id=6034941708",
        ["superscript"] = "http://www.roblox.com/asset/?id=6034934034",
        ["table_chart"] = "http://www.roblox.com/asset/?id=6034973081",
        ["format_bold"] = "http://www.roblox.com/asset/?id=6034900732",
        ["money_off"] = "http://www.roblox.com/asset/?id=6034973088",
        ["border_bottom"] = "http://www.roblox.com/asset/?id=6034898094",
        ["text_fields"] = "http://www.roblox.com/asset/?id=6034934040",
        ["note"] = "http://www.roblox.com/asset/?id=6026663734",
        ["shuffle"] = "http://www.roblox.com/asset/?id=6026667003",
        ["library_books"] = "http://www.roblox.com/asset/?id=6026660085",
        ["library_music"] = "http://www.roblox.com/asset/?id=6026660075",
        ["surround_sound"] = "http://www.roblox.com/asset/?id=6026671209",
        ["forward_30"] = "http://www.roblox.com/asset/?id=6026660088",
        ["music_video"] = "http://www.roblox.com/asset/?id=6026663704",
        ["videocam_off"] = "http://www.roblox.com/asset/?id=6026671212",
        ["control_camera"] = "http://www.roblox.com/asset/?id=6026647916",
        ["explicit"] = "http://www.roblox.com/asset/?id=6026647913",
        ["3k_plus"] = "http://www.roblox.com/asset/?id=6026681598",
        ["fiber_pin"] = "http://www.roblox.com/asset/?id=6026660064",
        ["skip_previous"] = "http://www.roblox.com/asset/?id=6026667011",
        ["pause_circle_filled"] = "http://www.roblox.com/asset/?id=6026663718",
        ["video_settings"] = "http://www.roblox.com/asset/?id=6026671211",
        ["movie"] = "http://www.roblox.com/asset/?id=6026660081",
        ["add_to_queue"] = "http://www.roblox.com/asset/?id=6026647903",
        ["6k"] = "http://www.roblox.com/asset/?id=6026681579",
        ["web_asset"] = "http://www.roblox.com/asset/?id=6026671239",
        ["play_circle_outline"] = "http://www.roblox.com/asset/?id=6026663726",
        ["volume_off"] = "http://www.roblox.com/asset/?id=6026671224",
        ["mic_off"] = "http://www.roblox.com/asset/?id=6026660076",
        ["featured_play_list"] = "http://www.roblox.com/asset/?id=6026647932",
        ["pause_circle_outline"] = "http://www.roblox.com/asset/?id=6026663701",
        ["slow_motion_video"] = "http://www.roblox.com/asset/?id=6026681583",
        ["7k"] = "http://www.roblox.com/asset/?id=6026681584",
        ["playlist_add"] = "http://www.roblox.com/asset/?id=6026663728",
        ["fiber_smart_record"] = "http://www.roblox.com/asset/?id=6026660080",
        ["8k"] = "http://www.roblox.com/asset/?id=6026643014",
        ["hd"] = "http://www.roblox.com/asset/?id=6026660065",
        ["repeat_one_on"] = "http://www.roblox.com/asset/?id=6026666992",
        ["recent_actors"] = "http://www.roblox.com/asset/?id=6026663773",
        ["fiber_new"] = "http://www.roblox.com/asset/?id=6026647930",
        ["fiber_dvr"] = "http://www.roblox.com/asset/?id=6026647912",
        ["hearing_disabled"] = "http://www.roblox.com/asset/?id=6026660068",
        ["forward_10"] = "http://www.roblox.com/asset/?id=6026660062",
        ["4k_plus"] = "http://www.roblox.com/asset/?id=6026643005",
        ["repeat_one"] = "http://www.roblox.com/asset/?id=6026681590",
        ["equalizer"] = "http://www.roblox.com/asset/?id=6026647906",
        ["stop"] = "http://www.roblox.com/asset/?id=6026681576",
        ["2k"] = "http://www.roblox.com/asset/?id=6026643032",
        ["playlist_add_check"] = "http://www.roblox.com/asset/?id=6026663727",
        ["not_interested"] = "http://www.roblox.com/asset/?id=6026663743",
        ["videocam"] = "http://www.roblox.com/asset/?id=6026671213",
        ["sort_by_alpha"] = "http://www.roblox.com/asset/?id=6026667009",
        ["library_add"] = "http://www.roblox.com/asset/?id=6026660063",
        ["stop_circle"] = "http://www.roblox.com/asset/?id=6026681577",
        ["pause"] = "http://www.roblox.com/asset/?id=6026663719",
        ["new_releases"] = "http://www.roblox.com/asset/?id=6026663730",
        ["album"] = "http://www.roblox.com/asset/?id=6026647905",
        ["sd"] = "http://www.roblox.com/asset/?id=6026681582",
        ["volume_up"] = "http://www.roblox.com/asset/?id=6026671215",
        ["replay_5"] = "http://www.roblox.com/asset/?id=6026666993",
        ["high_quality"] = "http://www.roblox.com/asset/?id=6026660059",
        ["shuffle_on"] = "http://www.roblox.com/asset/?id=6026666996",
        ["play_arrow"] = "http://www.roblox.com/asset/?id=6026663699",
        ["snooze"] = "http://www.roblox.com/asset/?id=6026667006",
        ["closed_caption_disabled"] = "http://www.roblox.com/asset/?id=6026647900",
        ["subscriptions"] = "http://www.roblox.com/asset/?id=6026671207",
        ["skip_next"] = "http://www.roblox.com/asset/?id=6026667005",
        ["branding_watermark"] = "http://www.roblox.com/asset/?id=6026647911",
        ["speed"] = "http://www.roblox.com/asset/?id=6026681578",
        ["art_track"] = "http://www.roblox.com/asset/?id=6026647908",
        ["3k"] = "http://www.roblox.com/asset/?id=6026681574",
        ["4k"] = "http://www.roblox.com/asset/?id=6026643017",
        ["volume_mute"] = "http://www.roblox.com/asset/?id=6026671214",
        ["playlist_play"] = "http://www.roblox.com/asset/?id=6026663723",
        ["remove_from_queue"] = "http://www.roblox.com/asset/?id=6026663771",
        ["fast_forward"] = "http://www.roblox.com/asset/?id=6026647902",
        ["play_disabled"] = "http://www.roblox.com/asset/?id=6026663702",
        ["fast_rewind"] = "http://www.roblox.com/asset/?id=6026647942",
        ["5k"] = "http://www.roblox.com/asset/?id=6026681575",
        ["replay_10"] = "http://www.roblox.com/asset/?id=6026667007",
        ["video_library"] = "http://www.roblox.com/asset/?id=6026671208",
        ["loop"] = "http://www.roblox.com/asset/?id=6026660087",
        ["replay_circle_filled"] = "http://www.roblox.com/asset/?id=6026667002",
        ["5g"] = "http://www.roblox.com/asset/?id=6026643007",
        ["library_add_check"] = "http://www.roblox.com/asset/?id=6026660083",
        ["repeat"] = "http://www.roblox.com/asset/?id=6026666998",
        ["queue_play_next"] = "http://www.roblox.com/asset/?id=6026663700",
        ["forward_5"] = "http://www.roblox.com/asset/?id=6026660067",
        ["web"] = "http://www.roblox.com/asset/?id=6026671234",
        ["mic_none"] = "http://www.roblox.com/asset/?id=6026660066",
        ["queue"] = "http://www.roblox.com/asset/?id=6026663724",
        ["closed_caption_off"] = "http://www.roblox.com/asset/?id=6026647943",
        ["hearing"] = "http://www.roblox.com/asset/?id=6026660060",
        ["queue_music"] = "http://www.roblox.com/asset/?id=6026663725",
        ["airplay"] = "http://www.roblox.com/asset/?id=6026647929",
        ["9k"] = "http://www.roblox.com/asset/?id=6026643013",
        ["video_label"] = "http://www.roblox.com/asset/?id=6026671204",
        ["8k_plus"] = "http://www.roblox.com/asset/?id=6026643003",
        ["play_circle_filled"] = "http://www.roblox.com/asset/?id=6026663705",
        ["1k"] = "http://www.roblox.com/asset/?id=6026643002",
        ["fiber_manual_record"] = "http://www.roblox.com/asset/?id=6026647909",
        ["closed_caption"] = "http://www.roblox.com/asset/?id=6026647896",
        ["subtitles"] = "http://www.roblox.com/asset/?id=6026671203",
        ["featured_video"] = "http://www.roblox.com/asset/?id=6026647910",
        ["replay_30"] = "http://www.roblox.com/asset/?id=6026667010",
        ["10k"] = "http://www.roblox.com/asset/?id=6026643035",
        ["5k_plus"] = "http://www.roblox.com/asset/?id=6026643028",
        ["6k_plus"] = "http://www.roblox.com/asset/?id=6026643019",
        ["replay"] = "http://www.roblox.com/asset/?id=6026666999",
        ["repeat_on"] = "http://www.roblox.com/asset/?id=6026666994",
        ["1k_plus"] = "http://www.roblox.com/asset/?id=6026681580",
        ["2k_plus"] = "http://www.roblox.com/asset/?id=6026681588",
        ["games"] = "http://www.roblox.com/asset/?id=6026660074",
        ["volume_down"] = "http://www.roblox.com/asset/?id=6026671206",
        ["mic"] = "http://www.roblox.com/asset/?id=6026660078",
        ["call_to_action"] = "http://www.roblox.com/asset/?id=6026647898",
        ["7k_plus"] = "http://www.roblox.com/asset/?id=6026643012",
        ["av_timer"] = "http://www.roblox.com/asset/?id=6026647934",
        ["9k_plus"] = "http://www.roblox.com/asset/?id=6026681585",
        ["radio"] = "http://www.roblox.com/asset/?id=6026663698",
        ["10mp"] = "http://www.roblox.com/asset/?id=6031328149",
        ["20mp"] = "http://www.roblox.com/asset/?id=6031488940",
        ["wb_twighlight"] = "http://www.roblox.com/asset/?id=6034412760",
        ["movie_creation"] = "http://www.roblox.com/asset/?id=6034323681",
        ["crop_portrait"] = "http://www.roblox.com/asset/?id=6031630198",
        ["filter_5"] = "http://www.roblox.com/asset/?id=6031597518",
        ["broken_image"] = "http://www.roblox.com/asset/?id=6031471480",
        ["flip_camera_android"] = "http://www.roblox.com/asset/?id=6034333280",
        ["flip_camera_ios"] = "http://www.roblox.com/asset/?id=6034333267",
        ["circle"] = "http://www.roblox.com/asset/?id=6031625146",
        ["photo_camera_front"] = "http://www.roblox.com/asset/?id=6031771000",
        ["assistant"] = "http://www.roblox.com/asset/?id=6031360356",
        ["face_retouching_natural"] = "http://www.roblox.com/asset/?id=6034333274",
        ["palette"] = "http://www.roblox.com/asset/?id=6034316009",
        ["nature_people"] = "http://www.roblox.com/asset/?id=6034323711",
        ["14mp"] = "http://www.roblox.com/asset/?id=6031328161",
        ["gradient"] = "http://www.roblox.com/asset/?id=6034333261",
        ["filter_4"] = "http://www.roblox.com/asset/?id=6031597512",
        ["panorama_wide_angle_select"] = "http://www.roblox.com/asset/?id=6031770990",
        ["photo"] = "http://www.roblox.com/asset/?id=6031770993",
        ["grid_off"] = "http://www.roblox.com/asset/?id=6034333286",
        ["leak_add"] = "http://www.roblox.com/asset/?id=6034407074",
        ["landscape"] = "http://www.roblox.com/asset/?id=6034407069",
        ["exposure_plus_1"] = "http://www.roblox.com/asset/?id=6034328970",
        ["slideshow"] = "http://www.roblox.com/asset/?id=6031754546",
        ["camera_alt"] = "http://www.roblox.com/asset/?id=6031572307",
        ["audiotrack"] = "http://www.roblox.com/asset/?id=6031471489",
        ["filter_none"] = "http://www.roblox.com/asset/?id=6031600815",
        ["blur_off"] = "http://www.roblox.com/asset/?id=6031371055",
        ["crop_16_9"] = "http://www.roblox.com/asset/?id=6031630205",
        ["blur_on"] = "http://www.roblox.com/asset/?id=6031371068",
        ["brightness_4"] = "http://www.roblox.com/asset/?id=6031471483",
        ["details"] = "http://www.roblox.com/asset/?id=6034328968",
        ["panorama_horizontal"] = "http://www.roblox.com/asset/?id=6034315966",
        ["camera_rear"] = "http://www.roblox.com/asset/?id=6031572316",
        ["hdr_weak"] = "http://www.roblox.com/asset/?id=6034407083",
        ["collections"] = "http://www.roblox.com/asset/?id=6031625145",
        ["hdr_enhanced_select"] = "http://www.roblox.com/asset/?id=6034333281",
        ["adjust"] = "http://www.roblox.com/asset/?id=6031339048",
        ["burst_mode"] = "http://www.roblox.com/asset/?id=6031572306",
        ["nature"] = "http://www.roblox.com/asset/?id=6034323695",
        ["brightness_6"] = "http://www.roblox.com/asset/?id=6031572309",
        ["19mp"] = "http://www.roblox.com/asset/?id=6031339054",
        ["grain"] = "http://www.roblox.com/asset/?id=6034333288",
        ["receipt_long"] = "http://www.roblox.com/asset/?id=6031763428",
        ["photo_filter"] = "http://www.roblox.com/asset/?id=6031770992",
        ["edit"] = "http://www.roblox.com/asset/?id=6034328955",
        ["healing"] = "http://www.roblox.com/asset/?id=6034407071",
        ["exposure_neg_1"] = "http://www.roblox.com/asset/?id=6034328957",
        ["exposure"] = "http://www.roblox.com/asset/?id=6034328962",
        ["wb_shade"] = "http://www.roblox.com/asset/?id=6034315974",
        ["compare"] = "http://www.roblox.com/asset/?id=6031625151",
        ["cases"] = "http://www.roblox.com/asset/?id=6031572324",
        ["timer_3"] = "http://www.roblox.com/asset/?id=6031754540",
        ["exposure_plus_2"] = "http://www.roblox.com/asset/?id=6034328961",
        ["12mp"] = "http://www.roblox.com/asset/?id=6031328140",
        ["22mp"] = "http://www.roblox.com/asset/?id=6031360353",
        ["timer_off"] = "http://www.roblox.com/asset/?id=6031734881",
        ["auto_stories"] = "http://www.roblox.com/asset/?id=6031360360",
        ["rotate_left"] = "http://www.roblox.com/asset/?id=6031763427",
        ["wb_iridescent"] = "http://www.roblox.com/asset/?id=6034315972",
        ["shutter_speed"] = "http://www.roblox.com/asset/?id=6031763443",
        ["switch_video"] = "http://www.roblox.com/asset/?id=6031754536",
        ["23mp"] = "http://www.roblox.com/asset/?id=6031339045",
        ["euro"] = "http://www.roblox.com/asset/?id=6034328963",
        ["15mp"] = "http://www.roblox.com/asset/?id=6031328158",
        ["filter_center_focus"] = "http://www.roblox.com/asset/?id=6031600817",
        ["photo_library"] = "http://www.roblox.com/asset/?id=6031770998",
        ["mp"] = "http://www.roblox.com/asset/?id=6034323674",
        ["looks_4"] = "http://www.roblox.com/asset/?id=6034407089",
        ["filter_2"] = "http://www.roblox.com/asset/?id=6031597521",
        ["crop_3_2"] = "http://www.roblox.com/asset/?id=6034328956",
        ["auto_fix_normal"] = "http://www.roblox.com/asset/?id=6031371074",
        ["auto_fix_off"] = "http://www.roblox.com/asset/?id=6031360381",
        ["wb_auto"] = "http://www.roblox.com/asset/?id=6031734875",
        ["switch_camera"] = "http://www.roblox.com/asset/?id=6031754550",
        ["filter_vintage"] = "http://www.roblox.com/asset/?id=6031600811",
        ["photo_size_select_small"] = "http://www.roblox.com/asset/?id=6031763457",
        ["blur_linear"] = "http://www.roblox.com/asset/?id=6031488930",
        ["hdr_on"] = "http://www.roblox.com/asset/?id=6034333279",
        ["tag_faces"] = "http://www.roblox.com/asset/?id=6031754560",
        ["21mp"] = "http://www.roblox.com/asset/?id=6031339065",
        ["camera"] = "http://www.roblox.com/asset/?id=6031572312",
        ["image_aspect_ratio"] = "http://www.roblox.com/asset/?id=6034407073",
        ["filter_b_and_w"] = "http://www.roblox.com/asset/?id=6031600824",
        ["crop_landscape"] = "http://www.roblox.com/asset/?id=6031630202",
        ["13mp"] = "http://www.roblox.com/asset/?id=6031328137",
        ["grid_on"] = "http://www.roblox.com/asset/?id=6034333276",
        ["motion_photos_pause"] = "http://www.roblox.com/asset/?id=6034323668",
        ["filter_6"] = "http://www.roblox.com/asset/?id=6031597524",
        ["linked_camera"] = "http://www.roblox.com/asset/?id=6034407082",
        ["panorama_fish_eye"] = "http://www.roblox.com/asset/?id=6034315969",
        ["panorama"] = "http://www.roblox.com/asset/?id=6034315955",
        ["color_lens"] = "http://www.roblox.com/asset/?id=6031625148",
        ["lens"] = "http://www.roblox.com/asset/?id=6034407081",
        ["crop_din"] = "http://www.roblox.com/asset/?id=6031630208",
        ["exposure_neg_2"] = "http://www.roblox.com/asset/?id=6034328973",
        ["mic_external_off"] = "http://www.roblox.com/asset/?id=6034323672",
        ["crop_free"] = "http://www.roblox.com/asset/?id=6031630212",
        ["crop_original"] = "http://www.roblox.com/asset/?id=6031630204",
        ["panorama_photosphere_select"] = "http://www.roblox.com/asset/?id=6034315975",
        ["photo_size_select_actual"] = "http://www.roblox.com/asset/?id=6031771012",
        ["leak_remove"] = "http://www.roblox.com/asset/?id=6034407080",
        ["collections_bookmark"] = "http://www.roblox.com/asset/?id=6034328965",
        ["straighten"] = "http://www.roblox.com/asset/?id=6031754545",
        ["timelapse"] = "http://www.roblox.com/asset/?id=6031754541",
        ["picture_as_pdf"] = "http://www.roblox.com/asset/?id=6031763425",
        ["crop_rotate"] = "http://www.roblox.com/asset/?id=6031630203",
        ["control_point_duplicate"] = "http://www.roblox.com/asset/?id=6034328959",
        ["photo_camera_back"] = "http://www.roblox.com/asset/?id=6031771007",
        ["looks_3"] = "http://www.roblox.com/asset/?id=6034407088",
        ["motion_photos_off"] = "http://www.roblox.com/asset/?id=6034323670",
        ["rotate_right"] = "http://www.roblox.com/asset/?id=6031763429",
        ["view_compact"] = "http://www.roblox.com/asset/?id=6031734878",
        ["crop_7_5"] = "http://www.roblox.com/asset/?id=6031630197",
        ["style"] = "http://www.roblox.com/asset/?id=6031754538",
        ["exposure_zero"] = "http://www.roblox.com/asset/?id=6034329000",
        ["camera_front"] = "http://www.roblox.com/asset/?id=6031572318",
        ["hdr_strong"] = "http://www.roblox.com/asset/?id=6034333272",
        ["view_comfy"] = "http://www.roblox.com/asset/?id=6031734876",
        ["panorama_vertical"] = "http://www.roblox.com/asset/?id=6034315963",
        ["panorama_vertical_select"] = "http://www.roblox.com/asset/?id=6034315961",
        ["looks_two"] = "http://www.roblox.com/asset/?id=6034412757",
        ["filter_drama"] = "http://www.roblox.com/asset/?id=6031600813",
        ["center_focus_strong"] = "http://www.roblox.com/asset/?id=6031625147",
        ["18mp"] = "http://www.roblox.com/asset/?id=6031339064",
        ["7mp"] = "http://www.roblox.com/asset/?id=6031328139",
        ["wb_sunny"] = "http://www.roblox.com/asset/?id=6034412758",
        ["filter_9_plus"] = "http://www.roblox.com/asset/?id=6031600812",
        ["crop"] = "http://www.roblox.com/asset/?id=6034328964",
        ["vignette"] = "http://www.roblox.com/asset/?id=6031734905",
        ["brightness_2"] = "http://www.roblox.com/asset/?id=6031488938",
        ["crop_square"] = "http://www.roblox.com/asset/?id=6031630222",
        ["looks_5"] = "http://www.roblox.com/asset/?id=6034412764",
        ["flip"] = "http://www.roblox.com/asset/?id=6034333275",
        ["looks_one"] = "http://www.roblox.com/asset/?id=6034412761",
        ["flash_off"] = "http://www.roblox.com/asset/?id=6034333270",
        ["hdr_off"] = "http://www.roblox.com/asset/?id=6034333266",
        ["photo_album"] = "http://www.roblox.com/asset/?id=6031770989",
        ["motion_photos_paused"] = "http://www.roblox.com/asset/?id=6034323675",
        ["photo_camera"] = "http://www.roblox.com/asset/?id=6031770997",
        ["2mp"] = "http://www.roblox.com/asset/?id=6031328138",
        ["3mp"] = "http://www.roblox.com/asset/?id=6031328136",
        ["24mp"] = "http://www.roblox.com/asset/?id=6031360352",
        ["filter_9"] = "http://www.roblox.com/asset/?id=6031597534",
        ["6mp"] = "http://www.roblox.com/asset/?id=6031328131",
        ["remove_red_eye"] = "http://www.roblox.com/asset/?id=6031763426",
        ["4mp"] = "http://www.roblox.com/asset/?id=6031328152",
        ["add_a_photo"] = "http://www.roblox.com/asset/?id=6031339049",
        ["filter_3"] = "http://www.roblox.com/asset/?id=6031597513",
        ["crop_5_4"] = "http://www.roblox.com/asset/?id=6034328960",
        ["8mp"] = "http://www.roblox.com/asset/?id=6031328133",
        ["camera_roll"] = "http://www.roblox.com/asset/?id=6031572314",
        ["panorama_wide_angle"] = "http://www.roblox.com/asset/?id=6031770995",
        ["transform"] = "http://www.roblox.com/asset/?id=6031734873",
        ["flare"] = "http://www.roblox.com/asset/?id=6031600816",
        ["image_search"] = "http://www.roblox.com/asset/?id=6034407084",
        ["auto_awesome"] = "http://www.roblox.com/asset/?id=6031360365",
        ["motion_photos_on"] = "http://www.roblox.com/asset/?id=6034323669",
        ["rotate_90_degrees_ccw"] = "http://www.roblox.com/asset/?id=6031763456",
        ["filter_1"] = "http://www.roblox.com/asset/?id=6031597511",
        ["filter_tilt_shift"] = "http://www.roblox.com/asset/?id=6031600814",
        ["image"] = "http://www.roblox.com/asset/?id=6034407078",
        ["center_focus_weak"] = "http://www.roblox.com/asset/?id=6031625144",
        ["blur_circular"] = "http://www.roblox.com/asset/?id=6031488945",
        ["bedtime"] = "http://www.roblox.com/asset/?id=6031371054",
        ["auto_fix_high"] = "http://www.roblox.com/asset/?id=6031360355",
        ["monochrome_photos"] = "http://www.roblox.com/asset/?id=6034323678",
        ["flash_auto"] = "http://www.roblox.com/asset/?id=6034333287",
        ["5mp"] = "http://www.roblox.com/asset/?id=6031328144",
        ["photo_size_select_large"] = "http://www.roblox.com/asset/?id=6031763423",
        ["assistant_photo"] = "http://www.roblox.com/asset/?id=6031339052",
        ["animation"] = "http://www.roblox.com/asset/?id=6031625150",
        ["looks"] = "http://www.roblox.com/asset/?id=6034407096",
        ["17mp"] = "http://www.roblox.com/asset/?id=6031339055",
        ["panorama_horizontal_select"] = "http://www.roblox.com/asset/?id=6034315965",
        ["flash_on"] = "http://www.roblox.com/asset/?id=6034333271",
        ["iso"] = "http://www.roblox.com/asset/?id=6034407106",
        ["music_note"] = "http://www.roblox.com/asset/?id=6034323673",
        ["music_off"] = "http://www.roblox.com/asset/?id=6034323679",
        ["navigate_next"] = "http://www.roblox.com/asset/?id=6034315956",
        ["timer"] = "http://www.roblox.com/asset/?id=6031754564",
        ["loupe"] = "http://www.roblox.com/asset/?id=6034412770",
        ["navigate_before"] = "http://www.roblox.com/asset/?id=6034323696",
        ["brightness_1"] = "http://www.roblox.com/asset/?id=6031471488",
        ["brightness_7"] = "http://www.roblox.com/asset/?id=6031471491",
        ["tonality"] = "http://www.roblox.com/asset/?id=6031734891",
        ["brush"] = "http://www.roblox.com/asset/?id=6031572320",
        ["colorize"] = "http://www.roblox.com/asset/?id=6031625161",
        ["filter_7"] = "http://www.roblox.com/asset/?id=6031597515",
        ["16mp"] = "http://www.roblox.com/asset/?id=6031328168",
        ["timer_10"] = "http://www.roblox.com/asset/?id=6031734880",
        ["portrait"] = "http://www.roblox.com/asset/?id=6031763434",
        ["tune"] = "http://www.roblox.com/asset/?id=6031734877",
        ["image_not_supported"] = "http://www.roblox.com/asset/?id=6034407076",
        ["wb_cloudy"] = "http://www.roblox.com/asset/?id=6031734907",
        ["auto_awesome_motion"] = "http://www.roblox.com/asset/?id=6031360370",
        ["filter_8"] = "http://www.roblox.com/asset/?id=6031597532",
        ["brightness_5"] = "http://www.roblox.com/asset/?id=6031471479",
        ["movie_filter"] = "http://www.roblox.com/asset/?id=6034323687",
        ["add_photo_alternate"] = "http://www.roblox.com/asset/?id=6031471484",
        ["add_to_photos"] = "http://www.roblox.com/asset/?id=6031371075",
        ["texture"] = "http://www.roblox.com/asset/?id=6031754553",
        ["11mp"] = "http://www.roblox.com/asset/?id=6031328141",
        ["mic_external_on"] = "http://www.roblox.com/asset/?id=6034323671",
        ["looks_6"] = "http://www.roblox.com/asset/?id=6034412759",
        ["dehaze"] = "http://www.roblox.com/asset/?id=6031630200",
        ["control_point"] = "http://www.roblox.com/asset/?id=6031625131",
        ["panorama_photosphere"] = "http://www.roblox.com/asset/?id=6034412763",
        ["filter_frames"] = "http://www.roblox.com/asset/?id=6031600833",
        ["auto_awesome_mosaic"] = "http://www.roblox.com/asset/?id=6031371053",
        ["9mp"] = "http://www.roblox.com/asset/?id=6031328146",
        ["filter"] = "http://www.roblox.com/asset/?id=6031597514",
        ["brightness_3"] = "http://www.roblox.com/asset/?id=6031572317",
        ["dirty_lens"] = "http://www.roblox.com/asset/?id=6034328967",
        ["wb_incandescent"] = "http://www.roblox.com/asset/?id=6034316010",
        ["filter_hdr"] = "http://www.roblox.com/asset/?id=6031600819",
        ["textsms"] = "http://www.roblox.com/asset/?id=6035202006",
        ["comment"] = "http://www.roblox.com/asset/?id=6035181871",
        ["call_end"] = "http://www.roblox.com/asset/?id=6035173845",
        ["qr_code_scanner"] = "http://www.roblox.com/asset/?id=6035202022",
        ["phonelink_setup"] = "http://www.roblox.com/asset/?id=6035202025",
        ["call_merge"] = "http://www.roblox.com/asset/?id=6035173843",
        ["phonelink_erase"] = "http://www.roblox.com/asset/?id=6035202085",
        ["contact_mail"] = "http://www.roblox.com/asset/?id=6035181868",
        ["contact_phone"] = "http://www.roblox.com/asset/?id=6035181861",
        ["screen_share"] = "http://www.roblox.com/asset/?id=6035202008",
        ["present_to_all"] = "http://www.roblox.com/asset/?id=6035202020",
        ["stay_primary_portrait"] = "http://www.roblox.com/asset/?id=6035202009",
        ["message"] = "http://www.roblox.com/asset/?id=6035202033",
        ["sentiment_satisfied_alt"] = "http://www.roblox.com/asset/?id=6035202069",
        ["stay_current_portrait"] = "http://www.roblox.com/asset/?id=6035202004",
        ["voicemail"] = "http://www.roblox.com/asset/?id=6035202019",
        ["business"] = "http://www.roblox.com/asset/?id=6035173853",
        ["mail_outline"] = "http://www.roblox.com/asset/?id=6035190844",
        ["vpn_key"] = "http://www.roblox.com/asset/?id=6035202034",
        ["forward_to_inbox"] = "http://www.roblox.com/asset/?id=6035190840",
        ["contacts"] = "http://www.roblox.com/asset/?id=6035181864",
        ["phonelink_ring"] = "http://www.roblox.com/asset/?id=6035202066",
        ["domain_disabled"] = "http://www.roblox.com/asset/?id=6035181862",
        ["person_add_disabled"] = "http://www.roblox.com/asset/?id=6035202007",
        ["stay_primary_landscape"] = "http://www.roblox.com/asset/?id=6035202026",
        ["alternate_email"] = "http://www.roblox.com/asset/?id=6035173865",
        ["phone_disabled"] = "http://www.roblox.com/asset/?id=6035202028",
        ["email"] = "http://www.roblox.com/asset/?id=6035181866",
        ["mobile_screen_share"] = "http://www.roblox.com/asset/?id=6035202021",
        ["live_help"] = "http://www.roblox.com/asset/?id=6035190836",
        ["chat_bubble"] = "http://www.roblox.com/asset/?id=6035181858",
        ["stop_screen_share"] = "http://www.roblox.com/asset/?id=6035202042",
        ["location_on"] = "http://www.roblox.com/asset/?id=6035190846",
        ["chat_bubble_outline"] = "http://www.roblox.com/asset/?id=6035181869",
        ["dialer_sip"] = "http://www.roblox.com/asset/?id=6035181865",
        ["no_sim"] = "http://www.roblox.com/asset/?id=6035202030",
        ["list_alt"] = "http://www.roblox.com/asset/?id=6035190838",
        ["call"] = "http://www.roblox.com/asset/?id=6035173859",
        ["pause_presentation"] = "http://www.roblox.com/asset/?id=6035202015",
        ["invert_colors_off"] = "http://www.roblox.com/asset/?id=6035190842",
        ["call_missed_outgoing"] = "http://www.roblox.com/asset/?id=6035173847",
        ["stay_current_landscape"] = "http://www.roblox.com/asset/?id=6035202011",
        ["import_export"] = "http://www.roblox.com/asset/?id=6035202040",
        ["add_ic_call"] = "http://www.roblox.com/asset/?id=6035173839",
        ["dialpad"] = "http://www.roblox.com/asset/?id=6035181892",
        ["nat"] = "http://www.roblox.com/asset/?id=6035202082",
        ["unsubscribe"] = "http://www.roblox.com/asset/?id=6035202044",
        ["mark_chat_unread"] = "http://www.roblox.com/asset/?id=6035190841",
        ["portable_wifi_off"] = "http://www.roblox.com/asset/?id=6035202091",
        ["location_off"] = "http://www.roblox.com/asset/?id=6035202049",
        ["person_search"] = "http://www.roblox.com/asset/?id=6035202013",
        ["phonelink_lock"] = "http://www.roblox.com/asset/?id=6035202064",
        ["desktop_access_disabled"] = "http://www.roblox.com/asset/?id=6035181863",
        ["import_contacts"] = "http://www.roblox.com/asset/?id=6035190854",
        ["rss_feed"] = "http://www.roblox.com/asset/?id=6035202016",
        ["chat"] = "http://www.roblox.com/asset/?id=6035173838",
        ["print_disabled"] = "http://www.roblox.com/asset/?id=6035202041",
        ["mark_email_read"] = "http://www.roblox.com/asset/?id=6035202038",
        ["hourglass_top"] = "http://www.roblox.com/asset/?id=6035190886",
        ["clear_all"] = "http://www.roblox.com/asset/?id=6035181870",
        ["forum"] = "http://www.roblox.com/asset/?id=6035202002",
        ["qr_code"] = "http://www.roblox.com/asset/?id=6035202012",
        ["speaker_phone"] = "http://www.roblox.com/asset/?id=6035202018",
        ["rtt"] = "http://www.roblox.com/asset/?id=6035202010",
        ["domain_verification"] = "http://www.roblox.com/asset/?id=6035181867",
        ["app_registration"] = "http://www.roblox.com/asset/?id=6035173870",
        ["call_split"] = "http://www.roblox.com/asset/?id=6035173861",
        ["cell_wifi"] = "http://www.roblox.com/asset/?id=6035173852",
        ["phone_enabled"] = "http://www.roblox.com/asset/?id=6035202089",
        ["call_made"] = "http://www.roblox.com/asset/?id=6035173858",
        ["call_received"] = "http://www.roblox.com/asset/?id=6035173844",
        ["phone"] = "http://www.roblox.com/asset/?id=6035202017",
        ["ring_volume"] = "http://www.roblox.com/asset/?id=6035202032",
        ["mark_email_unread"] = "http://www.roblox.com/asset/?id=6035202027",
        ["hourglass_bottom"] = "http://www.roblox.com/asset/?id=6035202043",
        ["read_more"] = "http://www.roblox.com/asset/?id=6035202014",
        ["duo"] = "http://www.roblox.com/asset/?id=6035181860",
        ["more_time"] = "http://www.roblox.com/asset/?id=6035202036",
        ["wifi_calling"] = "http://www.roblox.com/asset/?id=6035202065",
        ["swap_calls"] = "http://www.roblox.com/asset/?id=6035202037",
        ["cancel_presentation"] = "http://www.roblox.com/asset/?id=6035173837",
        ["call_missed"] = "http://www.roblox.com/asset/?id=6035173850",
        ["mark_chat_read"] = "http://www.roblox.com/asset/?id=6035202031",
        ["text_snippet"] = "http://www.roblox.com/asset/?id=6031302995",
        ["snippet_folder"] = "http://www.roblox.com/asset/?id=6031302947",
        ["workspaces_outline"] = "http://www.roblox.com/asset/?id=6031302952",
        ["file_download"] = "http://www.roblox.com/asset/?id=6031302931",
        ["request_quote"] = "http://www.roblox.com/asset/?id=6031302941",
        ["approval"] = "http://www.roblox.com/asset/?id=6031302928",
        ["drive_folder_upload"] = "http://www.roblox.com/asset/?id=6031302929",
        ["rule_folder"] = "http://www.roblox.com/asset/?id=6031302940",
        ["attach_email"] = "http://www.roblox.com/asset/?id=6031302935",
        ["topic"] = "http://www.roblox.com/asset/?id=6031302976",
        ["upload_file"] = "http://www.roblox.com/asset/?id=6031302959",
        ["attachment"] = "http://www.roblox.com/asset/?id=6031302921",
        ["file_download_done"] = "http://www.roblox.com/asset/?id=6031302926",
        ["drive_file_move_outline"] = "http://www.roblox.com/asset/?id=6031302924",
        ["cloud_upload"] = "http://www.roblox.com/asset/?id=6031302992",
        ["cloud_circle"] = "http://www.roblox.com/asset/?id=6031302919",
        ["folder_shared"] = "http://www.roblox.com/asset/?id=6031302945",
        ["cloud_download"] = "http://www.roblox.com/asset/?id=6031302917",
        ["file_upload"] = "http://www.roblox.com/asset/?id=6031302996",
        ["workspaces_filled"] = "http://www.roblox.com/asset/?id=6031302961",
        ["cloud_queue"] = "http://www.roblox.com/asset/?id=6031302916",
        ["cloud"] = "http://www.roblox.com/asset/?id=6031302918",
        ["folder_open"] = "http://www.roblox.com/asset/?id=6031302934",
        ["grid_view"] = "http://www.roblox.com/asset/?id=6031302950",
        ["cloud_off"] = "http://www.roblox.com/asset/?id=6031302993",
        ["create_new_folder"] = "http://www.roblox.com/asset/?id=6031302933",
        ["cloud_done"] = "http://www.roblox.com/asset/?id=6031302927",
        ["folder"] = "http://www.roblox.com/asset/?id=6031302932",
        ["drive_file_move"] = "http://www.roblox.com/asset/?id=6031302922",
        ["drive_file_rename_outline"] = "http://www.roblox.com/asset/?id=6031302994",
        ["beach_access"] = "http://www.roblox.com/asset/?id=6035107923",
        ["stroller"] = "http://www.roblox.com/asset/?id=6035161535",
        ["family_restroom"] = "http://www.roblox.com/asset/?id=6035121916",
        ["corporate_fare"] = "http://www.roblox.com/asset/?id=6035121908",
        ["no_meeting_room"] = "http://www.roblox.com/asset/?id=6035153649",
        ["do_not_touch"] = "http://www.roblox.com/asset/?id=6035121915",
        ["ac_unit"] = "http://www.roblox.com/asset/?id=6035107929",
        ["business_center"] = "http://www.roblox.com/asset/?id=6035107933",
        ["spa"] = "http://www.roblox.com/asset/?id=6035153639",
        ["no_flash"] = "http://www.roblox.com/asset/?id=6035145424",
        ["no_cell"] = "http://www.roblox.com/asset/?id=6035145376",
        ["room_service"] = "http://www.roblox.com/asset/?id=6035153648",
        ["tapas"] = "http://www.roblox.com/asset/?id=6035161533",
        ["microwave"] = "http://www.roblox.com/asset/?id=6035145367",
        ["meeting_room"] = "http://www.roblox.com/asset/?id=6035145361",
        ["wash"] = "http://www.roblox.com/asset/?id=6035161540",
        ["escalator"] = "http://www.roblox.com/asset/?id=6035121939",
        ["house_siding"] = "http://www.roblox.com/asset/?id=6035145393",
        ["food_bank"] = "http://www.roblox.com/asset/?id=6035121921",
        ["foundation"] = "http://www.roblox.com/asset/?id=6035121918",
        ["elevator"] = "http://www.roblox.com/asset/?id=6035121912",
        ["room_preferences"] = "http://www.roblox.com/asset/?id=6035153642",
        ["do_not_step"] = "http://www.roblox.com/asset/?id=6035121910",
        ["free_breakfast"] = "http://www.roblox.com/asset/?id=6035145363",
        ["house"] = "http://www.roblox.com/asset/?id=6035145364",
        ["child_care"] = "http://www.roblox.com/asset/?id=6035107927",
        ["night_shelter"] = "http://www.roblox.com/asset/?id=6035145378",
        ["child_friendly"] = "http://www.roblox.com/asset/?id=6035121942",
        ["checkroom"] = "http://www.roblox.com/asset/?id=6035107931",
        ["hot_tub"] = "http://www.roblox.com/asset/?id=6035145382",
        ["dry"] = "http://www.roblox.com/asset/?id=6035121909",
        ["charging_station"] = "http://www.roblox.com/asset/?id=6035107925",
        ["all_inclusive"] = "http://www.roblox.com/asset/?id=6035107920",
        ["bento"] = "http://www.roblox.com/asset/?id=6035107924",
        ["no_backpack"] = "http://www.roblox.com/asset/?id=6035145368",
        ["storefront"] = "http://www.roblox.com/asset/?id=6035161534",
        ["no_food"] = "http://www.roblox.com/asset/?id=6035145372",
        ["backpack"] = "http://www.roblox.com/asset/?id=6035107928",
        ["stairs"] = "http://www.roblox.com/asset/?id=6035153637",
        ["carpenter"] = "http://www.roblox.com/asset/?id=6035107955",
        ["no_stroller"] = "http://www.roblox.com/asset/?id=6035153661",
        ["roofing"] = "http://www.roblox.com/asset/?id=6035153656",
        ["umbrella"] = "http://www.roblox.com/asset/?id=6035161550",
        ["sports_bar"] = "http://www.roblox.com/asset/?id=6035153638",
        ["apartment"] = "http://www.roblox.com/asset/?id=6035107922",
        ["smoke_free"] = "http://www.roblox.com/asset/?id=6035153647",
        ["pool"] = "http://www.roblox.com/asset/?id=6035153655",
        ["bathtub"] = "http://www.roblox.com/asset/?id=6035107939",
        ["no_drinks"] = "http://www.roblox.com/asset/?id=6035145390",
        ["escalator_warning"] = "http://www.roblox.com/asset/?id=6035121930",
        ["wheelchair_pickup"] = "http://www.roblox.com/asset/?id=6035161536",
        ["smoking_rooms"] = "http://www.roblox.com/asset/?id=6035153636",
        ["rice_bowl"] = "http://www.roblox.com/asset/?id=6035153662",
        ["tty"] = "http://www.roblox.com/asset/?id=6035161541",
        ["no_photography"] = "http://www.roblox.com/asset/?id=6035153664",
        ["casino"] = "http://www.roblox.com/asset/?id=6035107936",
        ["fence"] = "http://www.roblox.com/asset/?id=6035121923",
        ["grass"] = "http://www.roblox.com/asset/?id=6035145359",
        ["countertops"] = "http://www.roblox.com/asset/?id=6035121914",
        ["kitchen"] = "http://www.roblox.com/asset/?id=6035145362",
        ["golf_course"] = "http://www.roblox.com/asset/?id=6035145423",
        ["soap"] = "http://www.roblox.com/asset/?id=6035153645",
        ["water_damage"] = "http://www.roblox.com/asset/?id=6035161563",
        ["airport_shuttle"] = "http://www.roblox.com/asset/?id=6035107921",
        ["fitness_center"] = "http://www.roblox.com/asset/?id=6035121907",
        ["baby_changing_station"] = "http://www.roblox.com/asset/?id=6035107930",
        ["fire_extinguisher"] = "http://www.roblox.com/asset/?id=6035121913",
        ["sparkle"] = "http://www.roblox.com/asset/?id=4483362748"
    }
}

local IconAliases = {
    ["warning"]   = "_warning",
    ["error"]     = "_error",
    ["alert"]     = "report_problem",
    ["help"]      = "info",
    ["success"]   = "check_circle",
    ["crosshair"] = "my_location"
}

local function GetIcon(icon, source)
    if not icon or icon == "" then return nil end
    source = source or "Material"
    local strIcon = tostring(icon)

    if source == "Custom" or string.find(strIcon, "rbxassetid://") then
        return string.find(strIcon, "rbxassetid://") and strIcon or ("rbxassetid://" .. strIcon)
    elseif source == "Lucide" then
        if isStudio then
            return "rbxassetid://10723434557"
        else
            local okData, iconData = pcall(function()
                return game:HttpGet("https://raw.githubusercontent.com/latte-soft/lucide-roblox/refs/heads/master/lib/Icons.luau")
            end)
            if okData and iconData then
                local okLoad, icons = pcall(loadstring(iconData))
                if okLoad and type(icons) == "table" then
                    local clean = string.match(string.lower(strIcon), "^%s*(.*)%s*$")
                    local sizedicons = icons['48px']
                    local r = sizedicons and sizedicons[clean]
                    if r and type(r[1]) == "number" then
                        return {
                            id = r[1],
                            imageRectSize = Vector2.new(r[2][1], r[2][2]),
                            imageRectOffset = Vector2.new(r[3][1], r[3][2])
                        }
                    end
                end
            end
            return nil
        end
    else
        local resolved = IconAliases[strIcon] or strIcon
        if IconModule.Material[resolved] then
            return IconModule.Material[resolved]
        end
        return nil
    end
end

LouisHub.GetIcon = GetIcon

--[[
╔══════════════════════════════════════════════════════════════════════╗
                              LouisHub
                Master UI Suite: LouisHub Engine V4.0
         PART 1C: THEMES, GLASS BLUR, UTILITIES & TOOLTIPS
╚══════════════════════════════════════════════════════════════════════╝
]]

-- ══════════════════════════════════════════════════════════════
--  SECTION 8: TWO-LAYER THEME SYSTEM (BASE THEMES & ACCENTS)
-- ══════════════════════════════════════════════════════════════
local Themes = {}
Themes.Default = "Dark"

Themes.List = {
    Dark = {
        Background      = Color3.fromRGB(45, 48, 53),
        BackgroundDark  = Color3.fromRGB(32, 34, 38),
        BackgroundLight = Color3.fromRGB(55, 58, 64),
        Accent          = Color3.fromRGB(90, 140, 210),
        AccentLight     = Color3.fromRGB(130, 175, 230),
        Highlight       = Color3.fromRGB(180, 200, 230),
        Text            = Color3.fromRGB(240, 240, 240),
        TextDark        = Color3.fromRGB(230, 230, 230),
        Border          = Color3.fromRGB(12, 13, 15),
        Panel           = Color3.fromRGB(18, 19, 22),
        PanelLight      = Color3.fromRGB(26, 28, 32),
        Row             = Color3.fromRGB(32, 34, 38),
        Input           = Color3.fromRGB(15, 16, 19),
        Muted           = Color3.fromRGB(60, 60, 60),
    },
    White = {
        Background      = Color3.fromRGB(218, 218, 224),
        BackgroundDark  = Color3.fromRGB(198, 198, 205),
        BackgroundLight = Color3.fromRGB(240, 240, 245),
        Accent          = Color3.fromRGB(60, 120, 210),
        AccentLight     = Color3.fromRGB(100, 155, 230),
        Highlight       = Color3.fromRGB(40, 70, 130),
        Text            = Color3.fromRGB(25, 25, 30),
        TextDark        = Color3.fromRGB(20, 20, 20),
        Border          = Color3.fromRGB(195, 195, 200),
        Panel           = Color3.fromRGB(252, 252, 254),
        PanelLight      = Color3.fromRGB(240, 240, 244),
        Row             = Color3.fromRGB(232, 232, 237),
        Input           = Color3.fromRGB(220, 220, 226),
        Muted           = Color3.fromRGB(180, 180, 180),
    },
    Green = {
        Background      = Color3.fromRGB(58, 122, 68),
        BackgroundDark  = Color3.fromRGB(42, 92, 50),
        BackgroundLight = Color3.fromRGB(72, 145, 82),
        Accent          = Color3.fromRGB(90, 190, 120),
        AccentLight     = Color3.fromRGB(130, 215, 155),
        Highlight       = Color3.fromRGB(170, 230, 185),
        Text            = Color3.fromRGB(240, 240, 240),
        TextDark        = Color3.fromRGB(230, 230, 230),
        Border          = Color3.fromRGB(15, 30, 18),
        Panel           = Color3.fromRGB(24, 40, 27),
        PanelLight      = Color3.fromRGB(32, 52, 36),
        Row             = Color3.fromRGB(28, 46, 31),
        Input           = Color3.fromRGB(20, 34, 22),
        Muted           = Color3.fromRGB(60, 60, 60),
    },
    Purple = {
        Background      = Color3.fromRGB(78, 55, 120),
        BackgroundDark  = Color3.fromRGB(58, 40, 92),
        BackgroundLight = Color3.fromRGB(98, 72, 145),
        Accent          = Color3.fromRGB(140, 105, 210),
        AccentLight     = Color3.fromRGB(175, 145, 230),
        Highlight       = Color3.fromRGB(205, 185, 240),
        Text            = Color3.fromRGB(240, 240, 240),
        TextDark        = Color3.fromRGB(230, 230, 230),
        Border          = Color3.fromRGB(18, 12, 28),
        Panel           = Color3.fromRGB(26, 20, 36),
        PanelLight      = Color3.fromRGB(34, 27, 46),
        Row             = Color3.fromRGB(30, 24, 42),
        Input           = Color3.fromRGB(22, 17, 32),
        Muted           = Color3.fromRGB(60, 60, 60),
    },
    Red = {
        Background      = Color3.fromRGB(214, 70, 60),
        BackgroundDark  = Color3.fromRGB(164, 45, 40),
        BackgroundLight = Color3.fromRGB(230, 110, 100),
        Accent          = Color3.fromRGB(163, 45, 60),
        AccentLight     = Color3.fromRGB(204, 94, 100),
        Highlight       = Color3.fromRGB(234, 160, 160),
        Text            = Color3.fromRGB(255, 255, 255),
        TextDark        = Color3.fromRGB(25, 20, 20),
        Border          = Color3.fromRGB(35, 8, 8),
        Panel           = Color3.fromRGB(34, 20, 20),
        PanelLight      = Color3.fromRGB(44, 27, 27),
        Row             = Color3.fromRGB(38, 24, 24),
        Input           = Color3.fromRGB(28, 17, 17),
        Muted           = Color3.fromRGB(60, 60, 60),
    },
    Halloween = {
        Background      = Color3.fromRGB(32, 22, 45),
        BackgroundDark  = Color3.fromRGB(22, 14, 32),
        BackgroundLight = Color3.fromRGB(45, 32, 62),
        Accent          = Color3.fromRGB(255, 122, 24),
        AccentLight     = Color3.fromRGB(255, 168, 92),
        Highlight       = Color3.fromRGB(180, 240, 120),
        Text            = Color3.fromRGB(245, 240, 255),
        TextDark        = Color3.fromRGB(230, 220, 245),
        Border          = Color3.fromRGB(12, 8, 20),
        Panel           = Color3.fromRGB(38, 26, 52),
        PanelLight      = Color3.fromRGB(50, 35, 68),
        Row             = Color3.fromRGB(42, 30, 58),
        Input           = Color3.fromRGB(26, 17, 38),
        Muted           = Color3.fromRGB(70, 60, 80),
    }
}

local PresetGradients = {
    ["Nightlight (Classic)"] = {Color3.fromRGB(147, 255, 239), Color3.fromRGB(201, 211, 233), Color3.fromRGB(255, 167, 227)},
    ["Nightlight (Neo)"]     = {Color3.fromRGB(117, 164, 206), Color3.fromRGB(123, 201, 201), Color3.fromRGB(224, 138, 175)},
    ["Starlight"]            = {Color3.fromRGB(147, 255, 239), Color3.fromRGB(181, 206, 241), Color3.fromRGB(214, 158, 243)},
    ["Solar"]                = {Color3.fromRGB(242, 157, 76), Color3.fromRGB(240, 179, 81), Color3.fromRGB(238, 201, 86)},
    ["Sparkle"]              = {Color3.fromRGB(199, 130, 242), Color3.fromRGB(221, 130, 238), Color3.fromRGB(243, 129, 233)},
    ["Lime"]                 = {Color3.fromRGB(170, 255, 127), Color3.fromRGB(163, 220, 138), Color3.fromRGB(155, 185, 149)},
    ["Vine"]                 = {Color3.fromRGB(0, 191, 143), Color3.fromRGB(0, 126, 94), Color3.fromRGB(0, 61, 46)},
    ["Cherry"]               = {Color3.fromRGB(148, 54, 54), Color3.fromRGB(168, 67, 70), Color3.fromRGB(188, 80, 86)},
    ["Daylight"]             = {Color3.fromRGB(51, 156, 255), Color3.fromRGB(89, 171, 237), Color3.fromRGB(127, 186, 218)},
    ["Blossom"]              = {Color3.fromRGB(255, 165, 243), Color3.fromRGB(213, 129, 231), Color3.fromRGB(170, 92, 218)},
}

local Theme = {}
for k, v in pairs(Themes.List[Themes.Default]) do Theme[k] = v end
LouisHub.Theme = Theme
LouisHub.CurrentBaseTheme = Themes.Default
LouisHub.CurrentAccentPreset = "Default"

LouisHub.ThemeGradient = ColorSequence.new{
    ColorSequenceKeypoint.new(0.00, Theme.Accent),
    ColorSequenceKeypoint.new(0.50, Theme.AccentLight),
    ColorSequenceKeypoint.new(1.00, Theme.Highlight)
}

local themeRegistry = {}
local deadThemeEntries = 0

local function compactRegistry(registry)
    local j = 0
    for i = 1, #registry do
        local e = registry[i]
        if not e.dead then
            j = j + 1
            registry[j] = e
        end
    end
    for i = #registry, j + 1, -1 do registry[i] = nil end
end

function LouisHub:Register(instance, property, themeKey)
    local entry = {instance = instance, property = property, themeKey = themeKey}
    table.insert(themeRegistry, entry)
    if typeof(instance) == "Instance" then
        instance.Destroying:Connect(function()
            entry.dead = true
            deadThemeEntries = deadThemeEntries + 1
            if deadThemeEntries >= 64 and deadThemeEntries * 4 >= #themeRegistry then
                deadThemeEntries = 0
                compactRegistry(themeRegistry)
            end
        end)
    end
end

-- ══════════════════════════════════════════════════════════════
--  SECTION 9: MOTION, TWEENING & SINGLETON GLASS BLUR MODULE
-- ══════════════════════════════════════════════════════════════
LouisHub.Motion = {
    Instant         = 0,
    Press           = 0.14,
    Hover           = 0.25,
    HoverIntensity  = 0.20,
    FlashIn         = 0.08,
    FlashOut        = 0.35,
    Expand          = 0.30,
    Modal           = 0.35,
    Page            = 0.30,
    Spin            = 0.60,
    EaseEnter       = Enum.EasingStyle.Exponential,
    EaseExit        = Enum.EasingStyle.Exponential,
    EasePop         = Enum.EasingStyle.Back,
    EaseSmooth      = Enum.EasingStyle.Exponential,
    EaseLinear      = Enum.EasingStyle.Linear,
}

local COLOR_FLASH_SUCCESS = Color3.fromRGB(46, 204, 113)
local COLOR_FLASH_ERROR   = Color3.fromRGB(231, 76, 60)

local activeTweens = setmetatable({}, {__mode = "k"})

local function getPropertyKey(props)
    local names = {}
    for name in pairs(props) do table.insert(names, name) end
    table.sort(names)
    return table.concat(names, ",")
end

local Utils = {}

function Utils.Tween(obj, props, duration, style, direction, callback)
    if not obj or not obj.Parent then return nil end
    local key = getPropertyKey(props)
    local perObject = activeTweens[obj]
    local previous = perObject and perObject[key]
    if previous then pcall(function() previous:Cancel() end) end

    if duration == 0 then
        pcall(function()
            for prop, val in pairs(props) do obj[prop] = val end
        end)
        if callback then callback() end
        return nil
    end

    local info = TweenInfo.new(
        duration or LouisHub.Motion.Expand,
        style or LouisHub.Motion.EaseEnter,
        direction or Enum.EasingDirection.Out
    )
    local ok, tw = pcall(function()
        local t = TweenService:Create(obj, info, props)
        if callback then t.Completed:Connect(callback) end
        t:Play()
        return t
    end)
    if ok then
        activeTweens[obj] = activeTweens[obj] or {}
        activeTweens[obj][key] = tw
    end
    return ok and tw or nil
end

function tween(object, goal, callback, tweenin)
    return Utils.Tween(
        object,
        goal,
        tweenin and tweenin.Time or 0.3,
        tweenin and tweenin.EasingStyle or Enum.EasingStyle.Exponential,
        tweenin and tweenin.EasingDirection or Enum.EasingDirection.Out,
        callback
    )
end

local SingletonDOF = nil
local activeBlurCount = 0

local function ensureDOF()
    if SingletonDOF and SingletonDOF.Parent then return SingletonDOF end
    SingletonDOF = Instance.new('DepthOfFieldEffect')
    SingletonDOF.Name = "LouisHubGlobalDOF"
    SingletonDOF.FarIntensity = 0
    SingletonDOF.FocusDistance = 51.6
    SingletonDOF.InFocusRadius = 50
    SingletonDOF.NearIntensity = 4
    SingletonDOF.Parent = Lighting
    LouisHub:RegisterInstance(SingletonDOF)
    return SingletonDOF
end

local function BlurModule(Frame)
    local camera = Workspace.CurrentCamera
    local MTREL = "Glass"
    local root = Instance.new('Folder', camera)
    root.Name = 'LouisHubBlur'
    LouisHub:RegisterInstance(root)

    ensureDOF()
    activeBlurCount = activeBlurCount + 1

    local frame = Instance.new('Frame')
    frame.Parent = Frame
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundTransparency = 1

    local GenUid; do
        local id = 0
        function GenUid()
            id = id + 1
            return 'louishub::' .. tostring(id)
        end
    end

    local DrawQuad; do
        local acos, max, pi, sqrt = math.acos, math.max, math.pi, math.sqrt
        local sz = 0.22
        local function DrawTriangle(v1, v2, v3, p0, p1)
            local s1 = (v1 - v2).magnitude
            local s2 = (v2 - v3).magnitude
            local s3 = (v3 - v1).magnitude
            local smax = max(s1, s2, s3)
            local A, B, C
            if s1 == smax then A, B, C = v1, v2, v3
            elseif s2 == smax then A, B, C = v2, v3, v1
            elseif s3 == smax then A, B, C = v3, v1, v2 end

            local para = ((B-A).x*(C-A).x + (B-A).y*(C-A).y + (B-A).z*(C-A).z) / (A-B).magnitude
            local perp = sqrt((C-A).magnitude^2 - para*para)
            local dif_para = (A - B).magnitude - para
            local st = CFrame.new(B, A)
            local za = CFrame.Angles(pi/2, 0, 0)
            local cf0 = st
            local Top_Look = (cf0 * za).lookVector
            local Mid_Point = A + CFrame.new(A, B).lookVector * para
            local Needed_Look = CFrame.new(Mid_Point, C).lookVector
            local dot = Top_Look.x*Needed_Look.x + Top_Look.y*Needed_Look.y + Top_Look.z*Needed_Look.z
            local ac = CFrame.Angles(0, 0, acos(dot))

            cf0 = cf0 * ac
            if ((cf0 * za).lookVector - Needed_Look).magnitude > 0.01 then
                cf0 = cf0 * CFrame.Angles(0, 0, -2*acos(dot))
            end
            cf0 = cf0 * CFrame.new(0, perp/2, -(dif_para + para/2))

            local cf1 = st * ac * CFrame.Angles(0, pi, 0)
            if ((cf1 * za).lookVector - Needed_Look).magnitude > 0.01 then
                cf1 = cf1 * CFrame.Angles(0, 0, 2*acos(dot))
            end
            cf1 = cf1 * CFrame.new(0, perp/2, dif_para/2)

            if not p0 then
                p0 = Instance.new('Part')
                p0.FormFactor = 'Custom'
                p0.TopSurface = 0
                p0.BottomSurface = 0
                p0.Anchored = true
                p0.CanCollide = false
                p0.CastShadow = false
                p0.Material = MTREL
                p0.Size = Vector3.new(sz, sz, sz)
                local mesh = Instance.new('SpecialMesh', p0)
                mesh.MeshType = 2
                mesh.Name = 'WedgeMesh'
            end
            p0.WedgeMesh.Scale = Vector3.new(0, perp/sz, para/sz)
            p0.CFrame = cf0

            if not p1 then p1 = p0:clone() end
            p1.WedgeMesh.Scale = Vector3.new(0, perp/sz, dif_para/sz)
            p1.CFrame = cf1
            return p0, p1
        end

        function DrawQuad(v1, v2, v3, v4, parts)
            parts[1], parts[2] = DrawTriangle(v1, v2, v3, parts[1], parts[2])
            parts[3], parts[4] = DrawTriangle(v3, v2, v4, parts[3], parts[4])
        end
    end

    local uid = GenUid()
    local parts = {}
    local f = Instance.new('Folder', root)
    f.Name = frame.Name

    local parents = {}
    local function add(child)
        if child:IsA('GuiObject') then
            parents[#parents + 1] = child
            add(child.Parent)
        end
    end
    add(frame)

    local function UpdateOrientation(fetchProps)
        if not (frame and frame.Parent and Frame and Frame.Parent) then
            pcall(function() RunService:UnbindFromRenderStep(uid) end)
            pcall(function() root:Destroy() end)
            return
        end

        local ancestorVisible = true
        local cur = Frame
        while cur do
            if cur:IsA("GuiObject") and not cur.Visible then
                ancestorVisible = false
                break
            end
            cur = cur.Parent
        end

        if not ancestorVisible or Frame.AbsoluteSize.X <= 0 or Frame.AbsoluteSize.Y <= 0 then
            for _, pt in pairs(parts) do pt.CFrame = CFrame.new(0, 100000, 0) end
            return
        end

        local properties = {
            Transparency = 0.98,
            BrickColor = BrickColor.new('Institutional white'),
        }
        local zIndex = 1 - 0.05 * math.clamp(frame.ZIndex, 1, 10)
        local tl, br = frame.AbsolutePosition, frame.AbsolutePosition + frame.AbsoluteSize
        local tr, bl = Vector2.new(br.x, tl.y), Vector2.new(tl.x, br.y)
        do
            local rot = 0
            for _, v in ipairs(parents) do rot = rot + v.Rotation end
            if rot ~= 0 and rot%180 ~= 0 then
                local mid = tl:lerp(br, 0.5)
                local s, c = math.sin(math.rad(rot)), math.cos(math.rad(rot))
                local vec = tl
                tl = Vector2.new(c*(tl.x - mid.x) - s*(tl.y - mid.y), s*(tl.x - mid.x) + c*(tl.y - mid.y)) + mid
                tr = Vector2.new(c*(tr.x - mid.x) - s*(tr.y - mid.y), s*(tr.x - mid.x) + c*(tr.y - mid.y)) + mid
                bl = Vector2.new(c*(bl.x - mid.x) - s*(bl.y - mid.y), s*(bl.x - mid.x) + c*(bl.y - mid.y)) + mid
                br = Vector2.new(c*(br.x - mid.x) - s*(br.y - mid.y), s*(br.x - mid.x) + c*(br.y - mid.y)) + mid
            end
        end

        DrawQuad(
            camera:ViewportPointToRay(tl.x, tl.y, zIndex).Origin,
            camera:ViewportPointToRay(tr.x, tr.y, zIndex).Origin,
            camera:ViewportPointToRay(bl.x, bl.y, zIndex).Origin,
            camera:ViewportPointToRay(br.x, br.y, zIndex).Origin,
            parts
        )
        if fetchProps then
            for _, pt in pairs(parts) do pt.Parent = f end
            for propName, propValue in pairs(properties) do
                for _, pt in pairs(parts) do pt[propName] = propValue end
            end
        end
    end

    UpdateOrientation(true)
    RunService:BindToRenderStep(uid, 2000, UpdateOrientation)

    Frame.Destroying:Connect(function()
        pcall(function() RunService:UnbindFromRenderStep(uid) end)
        pcall(function() root:Destroy() end)
        activeBlurCount = math.max(0, activeBlurCount - 1)
        if activeBlurCount <= 0 and SingletonDOF then
            pcall(function() SingletonDOF:Destroy() end)
            SingletonDOF = nil
        end
    end)
    return { Root = root, Effect = SingletonDOF, Uid = uid }
end

-- ══════════════════════════════════════════════════════════════
--  SECTION 10: CORE UTILITIES & TEXT SCALING ENGINE
-- ══════════════════════════════════════════════════════════════
local _uiInstanceCounter = 0
local function trackInstanceCreated(inst)
    _uiInstanceCounter = _uiInstanceCounter + 1
    inst.Destroying:Connect(function()
        _uiInstanceCounter = _uiInstanceCounter - 1
    end)
    return inst
end

function Utils.Corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 6)
    c.Parent = parent
    return c
end

function Utils.Stroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(64, 61, 76)
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0.5
    s.Parent = parent
    return s
end

function Utils.AccentGradient(instance, rotation)
    local gradient = Instance.new("UIGradient")
    gradient.Color = LouisHub.ThemeGradient
    gradient.Rotation = rotation or 0
    gradient.Parent = instance
    LouisHub:Register(gradient, "Color", function()
        return LouisHub.ThemeGradient
    end)
    return gradient
end

function Utils.Hover(eventObj, colorObj, intensity, duration, getBaseColor)
    if not eventObj or not colorObj then return end
    colorObj = colorObj or eventObj
    intensity = intensity or LouisHub.Motion.HoverIntensity
    duration = duration or LouisHub.Motion.Hover

    local isHovered = false
    local restColor = nil
    local stroke = colorObj:FindFirstChildOfClass("UIStroke")

    LouisHub:RegisterConnection(eventObj.MouseEnter:Connect(function()
        if isHovered then return end
        isHovered = true
        pcall(function()
            local base = (getBaseColor and getBaseColor()) or colorObj.BackgroundColor3
            restColor = base
            Utils.Tween(colorObj, {
                BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), intensity)
            }, duration, LouisHub.Motion.EaseEnter)
            if stroke then
                Utils.Tween(stroke, {Color = Color3.fromRGB(87, 84, 104), Transparency = 0.3}, duration, LouisHub.Motion.EaseEnter)
            end
        end)
    end))

    LouisHub:RegisterConnection(eventObj.MouseLeave:Connect(function()
        if not isHovered then return end
        isHovered = false
        pcall(function()
            local target = (getBaseColor and getBaseColor()) or restColor
            if target then
                restColor = target
                Utils.Tween(colorObj, {BackgroundColor3 = target}, duration, LouisHub.Motion.EaseEnter)
            end
            if stroke then
                Utils.Tween(stroke, {Color = Color3.fromRGB(64, 61, 76), Transparency = 0.5}, duration, LouisHub.Motion.EaseEnter)
            end
        end)
    end))
end

function Utils.ClickFeedback(visualObj)
    if not visualObj or not visualObj.Parent then return end
    local scale = visualObj:FindFirstChild("__LouisHub_ClickScale")
    if not scale then
        scale = Instance.new("UIScale")
        scale.Name = "__LouisHub_ClickScale"
        scale.Scale = 1
        scale.Parent = visualObj
    end
    scale.Scale = 0.97
    Utils.Tween(scale, {Scale = 1}, LouisHub.Motion.Press, LouisHub.Motion.EasePop)
end

function Utils.ReliableClick(object, callback, visualObj)
    local CLICK_MOVE_THRESHOLD = 15
    local posDown = nil
    LouisHub:RegisterConnection(object.MouseButton1Down:Connect(function(x, y)
        posDown = Vector2.new(x, y)
        Utils.ClickFeedback(visualObj or object)
    end))
    LouisHub:RegisterConnection(object.MouseButton1Up:Connect(function(x, y)
        if not posDown then return end
        local moved = (Vector2.new(x, y) - posDown).Magnitude > CLICK_MOVE_THRESHOLD
        posDown = nil
        if moved then return end
        callback()
    end))
end

function Utils.ExpandedHitbox(button, padding)
    padding = padding or 0
    if padding <= 0 or not button then return button end
    local hitbox = Utils.BaseButton({
        Parent = button,
        Size = UDim2.new(1, padding * 2, 1, padding * 2),
        Position = UDim2.new(0, -padding, 0, -padding),
        Transparency = 1,
        Radius = false,
    })
    hitbox.ZIndex = button.ZIndex + 1
    return hitbox
end

function Utils.FlashFeedback(instance, isSuccess, normalColor)
    if not instance or not instance.Parent then return end
    local flashColor = isSuccess and COLOR_FLASH_SUCCESS or COLOR_FLASH_ERROR
    pcall(function()
        Utils.Tween(instance, {BackgroundColor3 = flashColor}, LouisHub.Motion.FlashIn)
        task.delay(LouisHub.Motion.FlashIn, function()
            pcall(function()
                Utils.Tween(instance, {BackgroundColor3 = normalColor}, LouisHub.Motion.FlashOut)
            end)
        end)
    end)
end

function Utils.Frame(cfg)
    cfg = cfg or {}
    local f = Instance.new("Frame")
    trackInstanceCreated(f)
    f.Size = cfg.Size or UDim2.new(1, 0, 0, cfg.Height or 26)
    f.Position = cfg.Position or UDim2.new(0, 0, 0, 0)
    if cfg.Anchor then f.AnchorPoint = cfg.Anchor end
    f.BackgroundColor3 = cfg.Color or Theme.Row
    f.BackgroundTransparency = cfg.Transparency or 0.5
    f.BorderSizePixel = 0
    f.ClipsDescendants = cfg.Clips or false
    f.LayoutOrder = cfg.Order or 0
    if cfg.Visible ~= nil then f.Visible = cfg.Visible end
    f.Parent = cfg.Parent
    if cfg.Radius ~= false then Utils.Corner(f, cfg.Radius or 6) end
    if cfg.Border ~= false then
        local stroke = Utils.Stroke(f, cfg.BorderColor or Color3.fromRGB(64, 61, 76), cfg.BorderThickness or 1, cfg.BorderTransparency or 0.5)
        if cfg.BorderThemeKey then
            LouisHub:Register(stroke, "Color", cfg.BorderThemeKey)
        end
    end
    return f
end

function Utils.Row(parent, height, order, color)
    return Utils.Frame({
        Parent = parent,
        Size = UDim2.new(1, 0, 0, height or 26),
        Order = order,
        Color = color or Theme.Row,
        Radius = 6,
        Transparency = 0.5,
        Border = true
    })
end

local textScaleRegistry = {}
local deadTextScaleEntries = 0
local textScales = { tabs = 1, general = 1, title = 1 }

local function hasHiddenAncestor(inst)
    local current = inst
    while current do
        if current:IsA("GuiObject") and not current.Visible then return true end
        current = current.Parent
    end
    return false
end

function Utils.UIScaleFactor(inst)
    local f = 1
    local current = inst
    while current do
        local ok, sc = pcall(function() return current:FindFirstChildOfClass("UIScale") end)
        if ok and sc then f = f * sc.Scale end
        current = current.Parent
    end
    return (f > 0) and f or 1
end

local function calculateAndApplyTextSize(entry)
    local inst = entry.instance
    if not (inst and inst.Parent) then return end
    local factor = textScales[entry.category] or 1
    local floorVal = 6
    local target = math.max(floorVal, math.floor(entry.base * factor + 0.5))

    if not entry.truncatable then
        pcall(function() inst.TextSize = target end)
        return
    end

    local globalScaleFactor = Utils.UIScaleFactor(inst)
    local availableWidth = inst.AbsoluteSize.X / globalScaleFactor
    if availableWidth <= 0 then
        if hasHiddenAncestor(inst) then return end
        entry.retries = (entry.retries or 0) + 1
        if entry.retries > 10 then return end
        task.defer(calculateAndApplyTextSize, entry)
        return
    end
    entry.retries = 0

    local availableHeight = (inst.AbsoluteSize.Y > 0 and (inst.AbsoluteSize.Y / globalScaleFactor)) or 100
    local size = target
    while size > floorVal do
        local okMeasure, width = pcall(function()
            return TextService:GetTextSize(inst.Text, size, inst.Font, Vector2.new(10000, availableHeight)).X
        end)
        if not okMeasure or width <= availableWidth then break end
        size = size - 1
    end
    pcall(function() inst.TextSize = size end)
end

local function registerTextScale(instance, baseSize, category, truncatable)
    category = category or "general"
    local entry = {
        instance    = instance,
        base        = baseSize,
        category    = category,
        truncatable = truncatable or false,
        retries     = 0,
    }
    table.insert(textScaleRegistry, entry)
    instance.Destroying:Connect(function()
        entry.dead = true
        deadTextScaleEntries = deadTextScaleEntries + 1
        if deadTextScaleEntries >= 64 and deadTextScaleEntries * 4 >= #textScaleRegistry then
            deadTextScaleEntries = 0
            compactRegistry(textScaleRegistry)
        end
    end)
    if truncatable then
        LouisHub:RegisterConnection(instance:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            calculateAndApplyTextSize(entry)
        end))
        task.defer(calculateAndApplyTextSize, entry)
    elseif (textScales[category] or 1) ~= 1 then
        calculateAndApplyTextSize(entry)
    end
end

function Utils.Text(cfg)
    cfg = cfg or {}
    local l = Instance.new("TextLabel")
    trackInstanceCreated(l)
    l.BackgroundTransparency = 1
    l.Size = cfg.Size or UDim2.new(1, -6, 1, 0)
    l.Position = cfg.Position or UDim2.new(0, 6, 0, 0)
    l.Font = cfg.Font or Enum.Font.GothamMedium
    local baseSize = cfg.TextSize or cfg.SizeValue or 11
    l.TextSize = baseSize
    l.TextColor3 = cfg.Color or Theme.Text
    l.TextXAlignment = cfg.Alignment or Enum.TextXAlignment.Left
    l.TextTruncate = cfg.Truncate and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None
    l.TextWrapped = cfg.Wrapped or false
    l.TextTransparency = cfg.TextTransparency or 0
    l.RichText = cfg.RichText or false
    l.Text = cfg.Text or ""
    l.LayoutOrder = cfg.Order or 0
    l.Parent = cfg.Parent

    if cfg.ThemeColor then
        LouisHub:Register(l, "TextColor3", cfg.ThemeColor)
    elseif not cfg.Color then
        LouisHub:Register(l, "TextColor3", "Text")
    end

    registerTextScale(l, baseSize, cfg.Category, cfg.Truncate)
    return l
end

function Utils.BaseButton(cfg)
    cfg = cfg or {}
    local b = Instance.new("TextButton")
    trackInstanceCreated(b)
    b.Size = cfg.Size or UDim2.new(1, 0, 0, cfg.Height or 26)
    b.Position = cfg.Position or UDim2.new(0, 0, 0, 0)
    if cfg.Anchor then b.AnchorPoint = cfg.Anchor end
    b.BackgroundTransparency = cfg.Transparency == nil and 1 or cfg.Transparency
    b.BackgroundColor3 = cfg.Color or Theme.Row
    b.AutoButtonColor = false
    b.Text = ""
    b.BorderSizePixel = 0
    b.LayoutOrder = cfg.Order or 0
    b.Parent = cfg.Parent
    if cfg.Radius ~= false then Utils.Corner(b, cfg.Radius or 6) end
    return b
end

function Utils.Defer(fn)
    local pending = false
    return function()
        if pending then return end
        pending = true
        task.delay(0.03, function()
            pending = false
            fn()
        end)
    end
end

function Utils.MakeDynamicRow(row, lbl, minHeight, padY)
    padY = padY or 5
    lbl.TextWrapped   = true
    lbl.TextTruncate  = Enum.TextTruncate.None
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.AnchorPoint   = Vector2.new(0, 0.5)
    lbl.Position      = UDim2.new(lbl.Position.X.Scale, lbl.Position.X.Offset, 0.5, 0)
    lbl.Size          = UDim2.new(lbl.Size.X.Scale, lbl.Size.X.Offset, 0, 0)
    local function recalculate()
        if not (row.Parent and lbl.Parent) then return end
        local h = lbl.AbsoluteSize.Y
        if h <= 0 then return end
        local newH = math.max(minHeight, math.ceil(h / Utils.UIScaleFactor(lbl)) + padY * 2)
        if row.Size.Y.Offset ~= newH then
            row.Size = UDim2.new(row.Size.X.Scale, row.Size.X.Offset, 0, newH)
        end
    end
    LouisHub:RegisterConnection(lbl:GetPropertyChangedSignal("AbsoluteSize"):Connect(Utils.Defer(recalculate)))
    task.defer(recalculate)
end

local EventManager = {}
EventManager._active = nil
EventManager._onFinished = nil

function EventManager:StartDrag(callback, onFinished)
    self._active = callback
    self._onFinished = onFinished
end

function EventManager:StopDrag()
    self._active = nil
    if self._onFinished then
        local cb = self._onFinished
        self._onFinished = nil
        pcall(cb)
    end
end

function EventManager:IsDragging()
    return self._active ~= nil
end

if type(_G.LouisHub_EventManagerConnections) == "table" then
    for _, c in ipairs(_G.LouisHub_EventManagerConnections) do
        pcall(function() if c and c.Connected then c:Disconnect() end end)
    end
end
_G.LouisHub_EventManagerConnections = {}

local connInputChanged = UserInputService.InputChanged:Connect(function(input)
    if EventManager._active and (
        input.UserInputType == Enum.UserInputType.MouseMovement or
        input.UserInputType == Enum.UserInputType.Touch
    ) then
        pcall(EventManager._active, input)
    end
end)

local connInputEnded = UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        EventManager:StopDrag()
    end
end)

table.insert(_G.LouisHub_EventManagerConnections, connInputChanged)
table.insert(_G.LouisHub_EventManagerConnections, connInputEnded)
LouisHub.EventManager = EventManager

function Utils.Draggable(trigger, target, eventMgr)
    local isDragging = false
    local dragStart, targetStart

    trigger.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging   = true
            dragStart    = Vector2.new(input.Position.X, input.Position.Y)
            targetStart  = target.Position

            local connDragEnd
            connDragEnd = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    isDragging = false
                    if eventMgr then eventMgr:StopDrag() end
                    if connDragEnd then
                        connDragEnd:Disconnect()
                        connDragEnd = nil
                    end
                end
            end)
            LouisHub:RegisterConnection(connDragEnd)

            if eventMgr then
                eventMgr:StartDrag(function(inp)
                    if not isDragging then return end
                    local delta = Vector2.new(inp.Position.X, inp.Position.Y) - dragStart
                    target.Position = UDim2.new(
                        targetStart.X.Scale,  targetStart.X.Offset + delta.X,
                        targetStart.Y.Scale,  targetStart.Y.Offset + delta.Y
                    )
                end, function()
                    isDragging = false
                    if connDragEnd then
                        connDragEnd:Disconnect()
                        connDragEnd = nil
                    end
                end)
            end
        end
    end)
end

local activeNumberTweens = setmetatable({}, {__mode = "k"})

function Utils.TweenNumber(from, to, duration, callback, style, direction, key)
    if type(callback) ~= "function" then return end
    if from == to then
        callback(to)
        return
    end

    local lookupKey = key or callback
    local previous = activeNumberTweens[lookupKey]
    if previous then
        pcall(function() previous.tween:Cancel() end)
        pcall(function() previous.valObj:Destroy() end)
    end

    local valObj = Instance.new("NumberValue")
    valObj.Value = from
    local conn = valObj:GetPropertyChangedSignal("Value"):Connect(function()
        pcall(callback, valObj.Value)
    end)

    local info = TweenInfo.new(
        duration or 0.22,
        style or LouisHub.Motion.EaseEnter,
        direction or Enum.EasingDirection.Out
    )
    local ok, tw = pcall(function()
        return TweenService:Create(valObj, info, {Value = to})
    end)
    if not ok then
        conn:Disconnect()
        valObj:Destroy()
        callback(to)
        return
    end

    local record = {tween = tw, valObj = valObj}
    activeNumberTweens[lookupKey] = record
    tw:Play()
    tw.Completed:Connect(function()
        conn:Disconnect()
        valObj:Destroy()
        if activeNumberTweens[lookupKey] == record then activeNumberTweens[lookupKey] = nil end
    end)
end

function Utils.WrapInstance(inst)
    local proxy = setmetatable({}, {
        __index = function(_, k)
            local ok, val = pcall(function() return inst[k] end)
            if not ok then return nil end
            if type(val) == "function" then
                return function(_, ...) return val(inst, ...) end
            end
            return val
        end,
        __newindex = function(_, k, val) inst[k] = val end,
    })
    rawset(proxy, "Instance", inst)
    return proxy
end

function Utils.AttachLock(elem, row)
    local overlay, lblReason, badge
    local isLocked, lockReason = false, nil
    local BADGE_POS = UDim2.new(1, -6, 0.5, 0)
    local shakeToken = 0
    rawset(elem, "Row", row)
    local stroke, highlightToken = nil, 0

    local function withoutSelf(a, b)
        if a == elem then return b end
        return a
    end

    local function refreshText()
        if lblReason then
            lblReason.Text = "🔒 " .. (lockReason and lockReason ~= "" and lockReason or "Locked")
        end
    end

    local function ensureOverlay()
        if overlay and overlay.Parent then return end
        overlay = Instance.new("TextButton")
        overlay.Name = "LouisHub_Locked"
        overlay.Size = UDim2.new(1, 0, 1, 0)
        overlay.BackgroundColor3 = Theme.BackgroundDark
        overlay.BackgroundTransparency = 0.35
        overlay.BorderSizePixel = 0
        overlay.AutoButtonColor = false
        overlay.Text = ""
        overlay.ZIndex = 100
        overlay.Visible = false
        overlay.Parent = row
        local corner = row:FindFirstChildOfClass("UICorner")
        if corner then Utils.Corner(overlay, corner.CornerRadius.Offset) end
        LouisHub:Register(overlay, "BackgroundColor3", "BackgroundDark")

        badge = Utils.Frame({
            Parent = overlay, Size = UDim2.new(0.55, -6, 0, 22),
            Position = BADGE_POS, Anchor = Vector2.new(1, 0.5),
            Color = Theme.Panel, Radius = 5,
        })
        badge.ZIndex = 101
        LouisHub:Register(badge, "BackgroundColor3", "Panel")

        lblReason = Utils.Text({
            Parent = badge, Text = "",
            Size = UDim2.new(1, -10, 1, 0), Position = UDim2.new(0, 5, 0, 0),
            Alignment = Enum.TextXAlignment.Center, TextSize = 11, Truncate = true,
        })
        lblReason.ZIndex = 102

        Utils.ReliableClick(overlay, function()
            if not (badge and badge.Parent) then return end
            shakeToken = shakeToken + 1
            local myToken = shakeToken
            Utils.FlashFeedback(badge, false, Theme.Panel)
            task.spawn(function()
                for _, dx in ipairs({-3, 3, -3, 3, 0}) do
                    if shakeToken ~= myToken or not (badge and badge.Parent) then return end
                    Utils.Tween(badge, {
                        Position = UDim2.new(BADGE_POS.X.Scale, BADGE_POS.X.Offset + dx, BADGE_POS.Y.Scale, BADGE_POS.Y.Offset),
                    }, 0.05, LouisHub.Motion.EaseSmooth)
                    task.wait(0.05)
                end
            end)
        end, badge)
    end

    local function animateLockEntry()
        local transOverlay = overlay.BackgroundTransparency
        local transBadge   = badge.BackgroundTransparency
        local transText    = lblReason.TextTransparency
        overlay.BackgroundTransparency = 1
        badge.BackgroundTransparency   = 1
        lblReason.TextTransparency     = 1
        badge.Position = UDim2.new(BADGE_POS.X.Scale, BADGE_POS.X.Offset + 20, BADGE_POS.Y.Scale, BADGE_POS.Y.Offset)
        Utils.Tween(overlay, {BackgroundTransparency = transOverlay}, LouisHub.Motion.Expand)
        Utils.Tween(badge, {BackgroundTransparency = transBadge, Position = BADGE_POS}, LouisHub.Motion.Expand, LouisHub.Motion.EasePop)
        Utils.Tween(lblReason, {TextTransparency = transText}, LouisHub.Motion.Expand)
    end

    local function lock(newReason, animate)
        local wasLocked = isLocked
        lockReason = newReason
        ensureOverlay()
        refreshText()
        overlay.Visible = true
        isLocked = true
        if animate and not wasLocked and row.AbsoluteSize.X > 0 then
            animateLockEntry()
        end
    end

    rawset(elem, "Lock", function(selfParam, reason)
        lock(withoutSelf(selfParam, reason), true)
    end)

    rawset(elem, "Unlock", function()
        local wasLocked = isLocked
        isLocked = false
        if overlay then overlay.Visible = false end
        if wasLocked and overlay and row.Parent and row.AbsoluteSize.X > 0 then
            local ghost = Instance.new("Frame")
            ghost.Name = "__LouisHub_LockFade"
            ghost.Size = UDim2.new(1, 0, 1, 0)
            ghost.BackgroundColor3 = overlay.BackgroundColor3
            ghost.BackgroundTransparency = overlay.BackgroundTransparency
            ghost.BorderSizePixel = 0
            ghost.Active = false
            ghost.ZIndex = overlay.ZIndex
            local cornerOverlay = overlay:FindFirstChildOfClass("UICorner")
            if cornerOverlay then Utils.Corner(ghost, cornerOverlay.CornerRadius.Offset) end
            ghost.Parent = row
            Utils.Tween(ghost, {BackgroundTransparency = 1}, LouisHub.Motion.Expand, LouisHub.Motion.EaseExit)
            task.delay(LouisHub.Motion.Expand + 0.05, function()
                if ghost.Parent then ghost:Destroy() end
            end)
        end
    end)

    rawset(elem, "IsLocked", function() return isLocked end)

    rawset(elem, "SetLockedTitle", function(selfParam, reason)
        lockReason = withoutSelf(selfParam, reason)
        refreshText()
    end)

    rawset(elem, "Highlight", function(selfParam, opts)
        local o = withoutSelf(selfParam, opts)
        local duration = 2
        if type(o) == "number" then
            duration = o
        elseif type(o) == "table" and type(o.Duration) == "number" then
            duration = o.Duration
        end
        duration = math.clamp(duration, 0.5, 10)

        highlightToken = highlightToken + 1
        local myToken = highlightToken
        if stroke then stroke:Destroy() end
        stroke = Instance.new("UIStroke")
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Thickness = 1.5
        stroke.Color = Theme.AccentLight
        stroke.Transparency = 1
        stroke.Parent = row

        local pulses = math.max(1, math.floor(duration / 0.8))
        local targetStroke = stroke
        local tw = TweenService:Create(targetStroke,
            TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, pulses - 1, true),
            {Transparency = 0})
        tw:Play()
        task.delay(duration + 0.2, function()
            if targetStroke.Parent then targetStroke:Destroy() end
            if highlightToken == myToken then stroke = nil end
        end)
    end)

    return function(newReason) lock(newReason, false) end
end

function Utils.WrapLockableControl(Section, container, name)
    local original = Section[name]
    if type(original) ~= "function" then return end
    Section[name] = function(self, cfg)
        local previous = {}
        for _, child in ipairs(container:GetDescendants()) do previous[child] = true end
        if self._col1 then for _, child in ipairs(self._col1:GetDescendants()) do previous[child] = true end end
        if self._col2 then for _, child in ipairs(self._col2:GetDescendants()) do previous[child] = true end end

        local result = original(self, cfg)
        local row = nil

        local function findNewIn(parentObj)
            if not parentObj then return end
            for _, child in ipairs(parentObj:GetChildren()) do
                if not previous[child] and child:IsA("GuiObject") then
                    if not row or child.LayoutOrder > row.LayoutOrder then
                        row = child
                    end
                end
            end
        end

        findNewIn(container)
        findNewIn(self._col1)
        findNewIn(self._col2)

        if not row then return result end
        local elem = result
        if typeof(result) == "Instance" then elem = Utils.WrapInstance(result) end
        if type(elem) ~= "table" then return result end
        local lockInitial = Utils.AttachLock(elem, row)
        if type(cfg) == "table" and cfg.Locked then lockInitial(cfg.LockedTitle) end
        return elem
    end
end

function Utils.FadeIn(root, duration, includeRoot)
    local targets = {}
    local function register(inst)
        if inst:IsA("GuiObject") then
            if inst.BackgroundTransparency < 0.99 then
                table.insert(targets, {inst, "BackgroundTransparency", inst.BackgroundTransparency})
            end
            if (inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox")) and inst.TextTransparency < 0.99 then
                table.insert(targets, {inst, "TextTransparency", inst.TextTransparency})
            end
            if (inst:IsA("ImageLabel") or inst:IsA("ImageButton")) and inst.ImageTransparency < 0.99 then
                table.insert(targets, {inst, "ImageTransparency", inst.ImageTransparency})
            end
        elseif inst:IsA("UIStroke") and inst.Transparency < 0.99 then
            table.insert(targets, {inst, "Transparency", inst.Transparency})
        end
    end
    if includeRoot then register(root) end
    for _, d in ipairs(root:GetDescendants()) do register(d) end
    for _, o in ipairs(targets) do o[1][o[2]] = 1 end
    for _, o in ipairs(targets) do
        Utils.Tween(o[1], {[o[2]] = o[3]}, duration, LouisHub.Motion.EaseEnter)
    end
end

function Utils.AnimateInsertion(frame, axis)
    if not (frame and frame.Parent) then return end
    local finalSize = frame.Size
    local origClip = frame.ClipsDescendants
    frame.ClipsDescendants = true
    if axis == "x" then
        frame.Size = UDim2.new(finalSize.X.Scale, 0, finalSize.Y.Scale, finalSize.Y.Offset)
    else
        frame.Size = UDim2.new(finalSize.X.Scale, finalSize.X.Offset, finalSize.Y.Scale, 0)
    end
    Utils.FadeIn(frame, LouisHub.Motion.Expand, false)
    Utils.Tween(frame, {Size = finalSize}, LouisHub.Motion.Expand, LouisHub.Motion.EaseEnter)
    task.delay(LouisHub.Motion.Expand + 0.05, function()
        if frame.Parent then
            frame.Size = finalSize
            frame.ClipsDescendants = origClip
        end
    end)
end

function Utils.ModalEntry(backdrop, card)
    local transBackdrop = backdrop.BackgroundTransparency
    backdrop.BackgroundTransparency = 1
    local scale = Instance.new("UIScale")
    scale.Scale = 0.95
    scale.Parent = card
    Utils.FadeIn(card, LouisHub.Motion.Modal, true)
    Utils.Tween(backdrop, {BackgroundTransparency = transBackdrop}, LouisHub.Motion.Expand, LouisHub.Motion.EaseEnter)
    Utils.Tween(scale, {Scale = 1}, LouisHub.Motion.Modal, LouisHub.Motion.EasePop)
end

function Utils.ImageIcon(parent, asset, color, size, position)
    local img = Instance.new("ImageLabel")
    img.BackgroundTransparency = 1
    img.BorderSizePixel = 0
    img.Image = asset
    img.ImageColor3 = color or Color3.new(1, 1, 1)
    img.ScaleType = Enum.ScaleType.Fit
    img.Size = UDim2.new(0, size, 0, size)
    img.AnchorPoint = Vector2.new(0.5, 0.5)
    img.Position = position
    img.Parent = parent
    return img
end

function Utils.AttachDescription(row, parent, order, text, zoneWidth)
    local panel = Utils.Frame({
        Parent = parent, Size = UDim2.new(1, 0, 0, 0),
        Color = Theme.Row, Order = order, Radius = 6,
    })
    panel.AutomaticSize = Enum.AutomaticSize.Y
    panel.Visible = false
    LouisHub:Register(panel, "BackgroundColor3", "Row")

    local padding = Instance.new("UIPadding")
    padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
    padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 24), UDim.new(0, 10)
    padding.Parent = panel

    local lblDesc = Utils.Text({
        Parent = panel, Text = tostring(text),
        Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0, 0, 0, 0),
        Wrapped = true, TextSize = 10, Color = Theme.TextDark, ThemeColor = "TextDark",
    })
    lblDesc.AutomaticSize = Enum.AutomaticSize.Y

    local zone = Utils.BaseButton({
        Parent = row, Size = zoneWidth or UDim2.new(1, 0, 1, 0),
        Color = Theme.Row, Transparency = 1, Radius = 6,
    })
    local arrow = Instance.new("ImageLabel")
    arrow.BackgroundTransparency = 1
    arrow.Image = "rbxassetid://83472139709682"
    arrow.ScaleType = Enum.ScaleType.Fit
    arrow.Size = UDim2.new(0, 9, 0, 9)
    arrow.AnchorPoint = Vector2.new(0.5, 0.5)
    arrow.Position = UDim2.new(0, 12, 0.5, 0)
    arrow.Rotation = -90
    arrow.Parent = row
    LouisHub:Register(arrow, "ImageColor3", "Text")

    Utils.ReliableClick(zone, function()
        panel.Visible = not panel.Visible
        Utils.Tween(arrow, {Rotation = panel.Visible and 0 or -90}, LouisHub.Motion.Expand)
    end)
    return panel
end

-- ══════════════════════════════════════════════════════════════
--  SECTION 11: TOOLTIP ENGINE (GLASS OVERLAY & TOUCH GESTURES)
-- ══════════════════════════════════════════════════════════════
local overlayGui, helpPanel, lblHelp, globalCloseConnection

local function getTooltipOverlay()
    if overlayGui and overlayGui.Parent then return overlayGui end

    overlayGui = Instance.new("ScreenGui")
    overlayGui.Name = "LouisHub_TooltipOverlay"
    overlayGui.ResetOnSpawn = false
    overlayGui.IgnoreGuiInset = true
    overlayGui.DisplayOrder = 9999999
    pcall(function() overlayGui.Parent = getGuiParent() end)
    protectGui(overlayGui)
    LouisHub:RegisterInstance(overlayGui)

    helpPanel = Instance.new("Frame")
    helpPanel.Name = "HelpPanel"
    helpPanel.BackgroundColor3 = Theme.Panel
    helpPanel.BackgroundTransparency = 0.2
    helpPanel.BorderSizePixel = 0
    helpPanel.Visible = false
    helpPanel.ZIndex = 1000
    helpPanel.Size = UDim2.new(0, 190, 0, 0)
    helpPanel.AutomaticSize = Enum.AutomaticSize.Y
    helpPanel.Parent = overlayGui
    LouisHub:Register(helpPanel, "BackgroundColor3", "Panel")
    Utils.Corner(helpPanel, 6)
    local strokeTooltip = Utils.Stroke(helpPanel, Theme.Accent, 1, 0.3)
    LouisHub:Register(strokeTooltip, "Color", "Accent")

    local blurTip = BlurModule(helpPanel)

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft, pad.PaddingRight   = UDim.new(0, 8), UDim.new(0, 8)
    pad.PaddingTop,  pad.PaddingBottom  = UDim.new(0, 6), UDim.new(0, 6)
    pad.Parent = helpPanel

    lblHelp = Utils.Text({
        Parent = helpPanel, Text = "",
        Size = UDim2.new(1, 0, 0, 0),
        TextSize = 10.5, Wrapped = true,
    })
    lblHelp.AutomaticSize = Enum.AutomaticSize.Y
    lblHelp.ZIndex = 1001
    LouisHub:Register(lblHelp, "TextColor3", "Text")

    return overlayGui
end

local function closeGlobalTooltip()
    if helpPanel then helpPanel.Visible = false end
    if globalCloseConnection then
        LouisHub:DisconnectAndClean(globalCloseConnection)
        globalCloseConnection = nil
    end
end

local function showTooltipAt(refElement, helpText)
    getTooltipOverlay()

    if helpPanel.Visible and lblHelp.Text == helpText then
        closeGlobalTooltip()
        return
    end

    closeGlobalTooltip()

    lblHelp.Text = helpText
    helpPanel.Size = UDim2.new(0, 190, 0, 0)

    local pos = refElement.AbsolutePosition
    local sz = refElement.AbsoluteSize
    local x = pos.X
    local y = pos.Y + sz.Y + 4
    local screenWidth = overlayGui.AbsoluteSize.X
    if screenWidth > 0 then
        x = math.min(x, screenWidth - 198)
    end
    helpPanel.Position = UDim2.new(0, math.max(4, x), 0, y)
    helpPanel.Visible = true

    local scaleTip = helpPanel:FindFirstChild("__LouisHub_TooltipScale")
    if not scaleTip then
        scaleTip = Instance.new("UIScale")
        scaleTip.Name = "__LouisHub_TooltipScale"
        scaleTip.Parent = helpPanel
    end
    scaleTip.Scale = 0.92
    Utils.Tween(scaleTip, {Scale = 1}, LouisHub.Motion.Expand, LouisHub.Motion.EasePop)

    globalCloseConnection = LouisHub:RegisterConnection(
        UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and
               input.UserInputType ~= Enum.UserInputType.Touch then return end
            closeGlobalTooltip()
        end)
    )
end

local function addTooltip(row, position, helpText)
    if not helpText then return end

    local btnInfo = Utils.BaseButton({
        Parent = row, Size = UDim2.new(0, 18, 0, 18),
        Position = position, Color = Theme.AccentLight,
        Transparency = 0.2, Radius = 9,
    })
    btnInfo.ZIndex = 5
    LouisHub:Register(btnInfo, "BackgroundColor3", "AccentLight")

    local lblMark = Utils.Text({
        Parent = btnInfo, Text = "?",
        Alignment = Enum.TextXAlignment.Center,
        Font = Enum.Font.GothamBold, TextSize = 11,
        Color = Theme.TextDark,
    })
    LouisHub:Register(lblMark, "TextColor3", "TextDark")

    btnInfo.MouseButton1Click:Connect(function()
        showTooltipAt(btnInfo, helpText)
    end)

    return btnInfo
end

local function addTextTooltip(row, labelText, helpText, lblInstance, rightOffset)
    if not helpText then return end
    if not (lblInstance and lblInstance.Size) then
        addTooltip(row, UDim2.new(0, 160, 0, 4), helpText)
        return
    end

    local INFO_SIZE = 18
    local RESERVE   = INFO_SIZE + 10
    local sx = lblInstance.Size.X.Scale
    local ox = rightOffset or lblInstance.Size.X.Offset
    local px = lblInstance.Position.X.Offset
    lblInstance.Size = UDim2.new(sx, ox - RESERVE - px,
        lblInstance.Size.Y.Scale, lblInstance.Size.Y.Offset)

    local xInfo = ox - INFO_SIZE - 4
    local btnInfo = addTooltip(row, UDim2.new(sx, xInfo, 0.5, 0), helpText)
    btnInfo.AnchorPoint = Vector2.new(0, 0.5)

    local function centerY()
        if not (btnInfo.Parent and lblInstance.Parent and row.Parent) then return end
        if lblInstance.AbsoluteSize.Y <= 0 then return end
        local e = Utils.UIScaleFactor(row)
        local cy = (lblInstance.AbsolutePosition.Y - row.AbsolutePosition.Y
            + lblInstance.AbsoluteSize.Y / 2) / e
        btnInfo.Position = UDim2.new(sx, xInfo, 0, math.floor(cy + 0.5))
    end
    LouisHub:RegisterConnection(lblInstance:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        centerY(); task.defer(centerY)
    end))
    LouisHub:RegisterConnection(row:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        centerY(); task.defer(centerY)
    end))
    task.defer(centerY)

    row.Active = true
    local MOVE_THRESHOLD = LouisHub.Capabilities.IsTouch and 18 or 10
    local HOLD_TIME = 0.45
    local currentTouch = nil

    local function openIfNotOpen()
        if helpPanel and helpPanel.Visible and lblHelp and lblHelp.Text == helpText then return end
        pcall(showTooltipAt, row, helpText)
    end

    row.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        currentTouch = input
        local initPos = Vector2.new(input.Position.X, input.Position.Y)
        local startTime = os.clock()
        task.spawn(function()
            while currentTouch == input do
                if not (row and row.Parent) then return end
                if input.UserInputState == Enum.UserInputState.End then return end
                local curPos = Vector2.new(input.Position.X, input.Position.Y)
                if (curPos - initPos).Magnitude > MOVE_THRESHOLD then return end
                if os.clock() - startTime >= HOLD_TIME then
                    currentTouch = nil
                    openIfNotOpen()
                    return
                end
                task.wait(0.05)
            end
        end)
    end)
    row.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        currentTouch = nil
    end)
    pcall(function()
        row.TouchLongPress:Connect(function(_, state)
            if state == Enum.UserInputState.Begin then openIfNotOpen() end
        end)
    end)

    return btnInfo
end

-- ══════════════════════════════════════════════════════════════
--  SECTION 12: THEME MANAGER (DUAL LAYER REFACTOR)
-- ══════════════════════════════════════════════════════════════
LouisHub.ThemeManager = {}
local TM = LouisHub.ThemeManager
TM.Themes = Themes.List

local _windowsWithThemeSelectors = setmetatable({}, {__mode = "k"})

local function broadcastThemeUpdate()
    local animate = LouisHub._windowRevealed == true
    local hiddenPages = {}
    if animate then
        local active = _G.LouisHub_Instance
        local win = active and active.Window
        if win and win.Tabs then
            for _, tab in ipairs(win.Tabs) do
                local page = tab.Page
                if page and not page.Visible then
                    table.insert(hiddenPages, page)
                end
            end
        end
    end

    local function isInHiddenPage(inst)
        for _, page in ipairs(hiddenPages) do
            if inst:IsDescendantOf(page) then return true end
        end
        return false
    end

    for i = #themeRegistry, 1, -1 do
        local entry = themeRegistry[i]
        if entry.instance and entry.instance.Parent then
            local newVal
            if type(entry.themeKey) == "function" then
                local ok, res = pcall(entry.themeKey)
                if ok then newVal = res end
            else
                newVal = Theme[entry.themeKey]
            end
            if newVal ~= nil then
                silentTry(
                    "ThemeManager: apply " .. tostring(entry.property),
                    function()
                        local inst, prop = entry.instance, entry.property
                        if animate and typeof(newVal) == "Color3"
                        and typeof(inst[prop]) == "Color3"
                        and not isInHiddenPage(inst) then
                            Utils.Tween(inst, {[prop] = newVal}, LouisHub.Motion.Page, LouisHub.Motion.EaseSmooth)
                        else
                            inst[prop] = newVal
                        end
                    end
                )
            end
        else
            entry.dead = true
        end
    end

    for win in pairs(_windowsWithThemeSelectors) do
        if win._SyncThemeSelector then
            pcall(win._SyncThemeSelector, LouisHub.CurrentBaseTheme)
        end
    end

    LouisHub.Events.ThemeChanged:Fire(LouisHub.CurrentBaseTheme, LouisHub.CurrentAccentPreset)
end

function TM:ApplyBaseTheme(themeName)
    local baseData = self.Themes[themeName]
    if not baseData then return end
    LouisHub.CurrentBaseTheme = themeName

    for k, v in pairs(baseData) do
        Theme[k] = v
    end

    LouisHub.CurrentAccentPreset = "Default"
    LouisHub.ThemeGradient = ColorSequence.new{
        ColorSequenceKeypoint.new(0.00, Theme.Accent),
        ColorSequenceKeypoint.new(0.50, Theme.AccentLight),
        ColorSequenceKeypoint.new(1.00, Theme.Highlight)
    }

    broadcastThemeUpdate()
end

function TM:ApplyAccentGradient(presetOrColors)
    local colors = nil
    if type(presetOrColors) == "string" then
        if PresetGradients[presetOrColors] then
            colors = PresetGradients[presetOrColors]
            LouisHub.CurrentAccentPreset = presetOrColors
        end
    elseif type(presetOrColors) == "table" and #presetOrColors >= 3 then
        colors = presetOrColors
        LouisHub.CurrentAccentPreset = "Custom"
    end

    if not colors then return end

    Theme.Accent      = colors[1]
    Theme.AccentLight = colors[2]
    Theme.Highlight   = colors[3]

    LouisHub.ThemeGradient = ColorSequence.new{
        ColorSequenceKeypoint.new(0.00, colors[1]),
        ColorSequenceKeypoint.new(0.50, colors[2]),
        ColorSequenceKeypoint.new(1.00, colors[3])
    }

    broadcastThemeUpdate()
end

function TM:ApplyTheme(nameOrTable)
    if type(nameOrTable) == "string" then
        if string.sub(nameOrTable, 1, 10) == "Gradient: " then
            local gradName = string.sub(nameOrTable, 11)
            self:ApplyAccentGradient(gradName)
            return
        end
        if self.Themes[nameOrTable] then
            self:ApplyBaseTheme(nameOrTable)
            return
        end
    elseif type(nameOrTable) == "table" then
        for k, v in pairs(nameOrTable) do Theme[k] = v end
        LouisHub.ThemeGradient = ColorSequence.new{
            ColorSequenceKeypoint.new(0.00, Theme.Accent),
            ColorSequenceKeypoint.new(0.50, Theme.AccentLight),
            ColorSequenceKeypoint.new(1.00, Theme.Highlight)
        }
        broadcastThemeUpdate()
    end
end

function TM:AddTheme(name, tbl)
    if type(name) == "string" and type(tbl) == "table" then
        self.Themes[name] = tbl
    end
end

--[[
╔══════════════════════════════════════════════════════════════════════╗
                              LouisHub
                Master UI Suite: LouisHub Engine V4.0
         PART 2A: WINDOW FRAME, RESPONSIVE SIZING & TOPBAR
╚══════════════════════════════════════════════════════════════════════╝
]]

-- ══════════════════════════════════════════════════════════════
--  SECTION 13: WINDOW CREATION, RESPONSIVE ENGINE & HEADER
-- ══════════════════════════════════════════════════════════════
local function getTextWidth(text, size)
    return TextService:GetTextSize(
        text or "", size or 11, Enum.Font.Gotham, Vector2.new(1000, 20)
    ).X
end

local searchIndex = {}
local registeredSections = {}

local function registerSearchable(row, text, visibleIf)
    table.insert(searchIndex, {row = row, text = (text or ""):lower()})
    if type(visibleIf) == "function" then
        registerConditionalVisibility(row, visibleIf)
    end
end

function LouisHub:CreateWindow(config)
    config = config or {}
    local title        = config.Title or config.Name or "LouisHub"
    local subtitle     = (config.Subtitle or "by LouisHub") .. "  •  v" .. LouisHub.Version
    local sizeX        = config.SizeX or 620
    local sizeY        = config.SizeY or 380
    local toggleKey    = config.ToggleKey or config.Bind or Enum.KeyCode.RightControl
    local isHorizontal = config.Orientation == "horizontal"

    cleanupPreviousInstance()
    _G.LouisHub_Instance = {
        Connections = {},
        Threads     = {},
        Drawings    = {},
        Instances   = {},
        Window      = nil,
        Title       = title,
    }

    local parentGui = getGuiParent()
    local sg = Instance.new("ScreenGui")
    sg.Name           = "LouisHub_ScreenGui"
    sg.ResetOnSpawn   = false
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = parentGui
    protectGui(sg)
    LouisHub:RegisterInstance(sg)

    ensureNotificationContainer()
    LouisHub._guiConfirm = sg

    local main = Utils.Frame({
        Parent = sg,
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Anchor = Vector2.new(0.5, 0.5),
        Color = Theme.Panel,
        Radius = 10,
        Clips = true,
        Border = true,
        BorderColor = Theme.Border,
        BorderThickness = 1.5,
        BorderThemeKey = "Border",
        Transparency = 0.25,
    })
    main.Active = true
    LouisHub:Register(main, "BackgroundColor3", "Panel")

    local blurData = BlurModule(main)

    local screenShadow = Utils.Frame({
        Parent = sg,
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        Color = Color3.new(0, 0, 0),
        Transparency = 1,
        Radius = false,
        Border = false,
    })
    screenShadow.ZIndex = -10
    Utils.Tween(screenShadow, {BackgroundTransparency = 0.94}, LouisHub.Motion.Modal)

    LouisHub:RegisterConnection(main:GetPropertyChangedSignal("Visible"):Connect(function()
        screenShadow.Visible = main.Visible
    end))

    local ORIGINAL_WINDOW_POS = UDim2.new(0.5, 0, 0.5, 0)
    Utils.Tween(main, {
        Size = UDim2.new(0, sizeX, 0, sizeY),
        Position = ORIGINAL_WINDOW_POS,
    }, LouisHub.Motion.Modal, LouisHub.Motion.EasePop)

    local uiScale = Instance.new("UIScale")
    uiScale.Scale = 1
    uiScale.Parent = main

    local manualScale = 1
    local baseSizeX, baseSizeY = sizeX, sizeY
    local scaleFactorX, scaleFactorY = 1, 1

    local function recalculateScale()
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local sz = cam.ViewportSize
        if sz.X <= 0 or sz.Y <= 0 then return end

        local isMobile = sz.X < 700 or sz.Y < 500
        local pctW = isMobile and 0.95 or 0.82
        local pctH = isMobile and 0.88 or 0.82

        local curW = baseSizeX * scaleFactorX
        local curH = baseSizeY * scaleFactorY

        local scaleByW = (sz.X * pctW) / curW
        local scaleByH = (sz.Y * pctH) / curH
        local autoScale = math.min(scaleByW, scaleByH, 1.15)
        autoScale = math.max(autoScale, 0.45)

        local limitScale = math.min((sz.X * 0.98) / curW, (sz.Y * 0.90) / curH)
        local finalScale = math.max(0.3, math.min(autoScale * manualScale, limitScale))
        local duration = EventManager:IsDragging() and LouisHub.Motion.Instant or LouisHub.Motion.Page
        Utils.Tween(uiScale, {Scale = finalScale}, duration, LouisHub.Motion.EaseEnter)
    end

    recalculateScale()

    local connViewport = nil
    local function hookCamera()
        if connViewport then
            LouisHub:DisconnectAndClean(connViewport)
            connViewport = nil
        end
        local curCam = Workspace.CurrentCamera
        if curCam then
            connViewport = LouisHub:RegisterConnection(
                curCam:GetPropertyChangedSignal("ViewportSize"):Connect(recalculateScale)
            )
        end
    end
    hookCamera()
    LouisHub:RegisterConnection(
        Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
            hookCamera()
            recalculateScale()
        end)
    )

    -- ── RESTORE PILL MINIMIZER ───────────────────────────────────
    local pillText = "⚡ " .. title
    local pillWidth = math.clamp(getTextWidth(pillText, 12) + 40, 130, 260)

    local pillRestore = Utils.BaseButton({
        Parent = sg,
        Size = UDim2.new(0, pillWidth, 0, 28),
        Position = UDim2.new(0.5, 0, 0, 25),
        Anchor = Vector2.new(0.5, 0.5),
        Color = Theme.Panel,
        Transparency = 0.2,
        Radius = 14,
        Border = true,
        BorderColor = Theme.Accent,
        BorderThickness = 1,
    })
    pillRestore.Visible = false
    pillRestore.ZIndex  = 50
    pillRestore.Active  = true
    LouisHub:Register(pillRestore, "BackgroundColor3", "Panel")

    local blurPill = BlurModule(pillRestore)

    Utils.Text({
        Parent = pillRestore, Text = pillText,
        Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 6, 0, 0),
        Alignment = Enum.TextXAlignment.Center, Truncate = true,
        Font = Enum.Font.GothamBold, TextSize = 11,
    })

    local isWindowOpen = true
    local isWindowAnimating = false
    local windowOpId = 0

    local function toggleWindow(open)
        if isWindowAnimating or open == isWindowOpen then return end
        isWindowAnimating = true
        isWindowOpen = open
        local currentOpId = windowOpId + 1
        windowOpId = currentOpId
        local function isOpActive() return windowOpId == currentOpId end

        if open then
            local targetSize = UDim2.new(0, baseSizeX * scaleFactorX, 0, baseSizeY * scaleFactorY)
            Utils.Tween(pillRestore, {Size = UDim2.new(0, 0, 0, 0)}, LouisHub.Motion.Expand, LouisHub.Motion.EaseExit)

            main.Visible = true
            main.Size = UDim2.new(0, 0, 0, 0)
            main.Position = ORIGINAL_WINDOW_POS
            Utils.Tween(main, {Size = targetSize}, LouisHub.Motion.Modal, LouisHub.Motion.EasePop)

            task.spawn(function()
                task.wait(LouisHub.Motion.Expand)
                if isOpActive() then
                    pillRestore.Visible = false
                    pillRestore.Size = UDim2.new(0, pillWidth, 0, 28)
                end
                task.wait(math.max(0, LouisHub.Motion.Modal - LouisHub.Motion.Expand))
                if isOpActive() then
                    main.Size = targetSize
                    isWindowAnimating = false
                end
            end)
        else
            Utils.Tween(main, {Size = UDim2.new(0, 0, 0, 0)}, LouisHub.Motion.Expand, LouisHub.Motion.EaseExit)
            task.spawn(function()
                task.wait(LouisHub.Motion.Expand + 0.04)
                if not isOpActive() then return end
                main.Visible = false
                main.Size = UDim2.new(0, 0, 0, 0)
                pillRestore.Size = UDim2.new(0, 0, 0, 0)
                pillRestore.Visible = true
                Utils.Tween(pillRestore, {Size = UDim2.new(0, pillWidth, 0, 28)}, LouisHub.Motion.Modal, LouisHub.Motion.EasePop)
                task.wait(LouisHub.Motion.Modal + 0.01)
                if isOpActive() then
                    pillRestore.Size = UDim2.new(0, pillWidth, 0, 28)
                    isWindowAnimating = false
                end
            end)
        end
    end

    pillRestore.MouseButton1Click:Connect(function() toggleWindow(true) end)

    -- ── HEADER / TOPBAR ─────────────────────────────────────────
    local titleBar = Utils.Frame({
        Parent = main, Size = UDim2.new(1, 0, 0, 32),
        Color = Theme.Background, Radius = 10, Transparency = 0.35,
        Border = false,
    })
    titleBar.Active = true
    LouisHub:Register(titleBar, "BackgroundColor3", "Background")

    local titleCover = Utils.Frame({
        Parent = titleBar, Size = UDim2.new(1, 0, 0, 8),
        Position = UDim2.new(0, 0, 1, -8),
        Color = Theme.Background, Radius = false, Border = false,
        Transparency = 0.35,
    })
    LouisHub:Register(titleCover, "BackgroundColor3", "Background")

    local accentLine = Utils.Frame({
        Parent = main, Size = UDim2.new(1, -20, 0, 2),
        Position = UDim2.new(0, 10, 0, 31), Color = Theme.Accent, Radius = false,
        Border = false, Transparency = 0.1,
    })
    accentLine.ZIndex = titleBar.ZIndex + 2
    LouisHub:Register(accentLine, "BackgroundColor3", "Accent")
    Utils.AccentGradient(accentLine)

    Utils.Draggable(titleBar, main, LouisHub.EventManager)

    local lblTitle = Utils.Text({
        Parent = titleBar, Text = title,
        Position = UDim2.new(0, 10, 0, 2), Size = UDim2.new(0.5, 0, 0, 16),
        Font = Enum.Font.GothamBold, TextSize = 13, Color = Theme.TextDark,
        Category = "title", Truncate = true,
    })
    LouisHub:Register(lblTitle, "TextColor3", "TextDark")

    local lblSub = Utils.Text({
        Parent = titleBar, Text = subtitle,
        Position = UDim2.new(0, 10, 0, 17), Size = UDim2.new(0.5, 0, 0, 12),
        TextSize = 10, Color = Theme.TextDark, TextTransparency = 0.25,
        Category = "title", Truncate = true,
    })
    LouisHub:Register(lblSub, "TextColor3", "TextDark")

    local btnClose = Utils.BaseButton({
        Parent = titleBar, Size = UDim2.new(0, 24, 0, 20),
        Position = UDim2.new(1, -16, 0.5, 0), Anchor = Vector2.new(0.5, 0.5),
        Color = Color3.fromRGB(180, 50, 50), Transparency = 1, Radius = 5,
    })
    local icoClose = Utils.Text({
        Parent = btnClose, Text = "✕",
        Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(0, 0, 0, 0),
        Alignment = Enum.TextXAlignment.Center, TextSize = 12, Font = Enum.Font.GothamBold,
    })
    btnClose.MouseButton1Down:Connect(function()
        Utils.Tween(btnClose, {BackgroundTransparency = 0.75}, LouisHub.Motion.FlashIn)
    end)
    btnClose.MouseButton1Up:Connect(function()
        Utils.Tween(btnClose, {BackgroundTransparency = 1}, LouisHub.Motion.Hover)
    end)

    local function showConfirmDestroy()
        LouisHub:Confirm({
            Title   = "⚠️ Close Interface?",
            Content = "Are you sure you want to destroy this interface? All active overlays and connections will be terminated.",
            Icon    = "warning",
            Buttons = {
                { Text = "Cancel", Variant = "neutral" },
                {
                    Text = "Destroy", Variant = "danger",
                    Callback = function()
                        LouisHub:Destroy()
                    end
                }
            }
        })
    end
    Utils.ReliableClick(btnClose, showConfirmDestroy)

    local btnMin = Utils.BaseButton({
        Parent = titleBar, Size = UDim2.new(0, 24, 0, 20),
        Position = UDim2.new(1, -44, 0.5, 0), Anchor = Vector2.new(0.5, 0.5),
        Color = Theme.BackgroundDark, Transparency = 1, Radius = 5,
    })
    Utils.Text({
        Parent = btnMin, Text = "—",
        Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(0, 0, 0, 0),
        Alignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold,
        TextSize = 13, Color = Theme.TextDark,
    })
    btnMin.MouseButton1Down:Connect(function()
        Utils.Tween(btnMin, {BackgroundTransparency = 0.7}, LouisHub.Motion.FlashIn)
    end)
    btnMin.MouseButton1Up:Connect(function()
        Utils.Tween(btnMin, {BackgroundTransparency = 1}, LouisHub.Motion.Hover)
    end)
    Utils.ReliableClick(btnMin, function() toggleWindow(false) end)

    -- ── BREADCRUMB & CONTENT CONTAINERS ─────────────────────────
    local sideBar = Instance.new("ScrollingFrame")
    sideBar.Size                = UDim2.new(0, 155, 1, -33)
    sideBar.Position            = UDim2.new(0, 0, 0, 33)
    sideBar.BackgroundColor3    = Theme.PanelLight
    sideBar.BackgroundTransparency = 0.4
    sideBar.BorderSizePixel     = 0
    sideBar.Visible             = not isHorizontal
    sideBar.ScrollingDirection  = Enum.ScrollingDirection.Y
    sideBar.ScrollBarThickness  = 3
    sideBar.ScrollBarImageColor3 = Theme.Accent
    sideBar.CanvasSize          = UDim2.new(0, 0, 0, 0)
    sideBar.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sideBar.Parent              = main
    LouisHub:Register(sideBar, "BackgroundColor3", "PanelLight")

    local layoutTabs = Instance.new("UIListLayout")
    layoutTabs.Padding   = UDim.new(0, 3)
    layoutTabs.SortOrder = Enum.SortOrder.LayoutOrder
    layoutTabs.Parent    = sideBar

    local padTabs = Instance.new("UIPadding")
    padTabs.PaddingTop   = UDim.new(0, 6)
    padTabs.PaddingLeft  = UDim.new(0, 5)
    padTabs.PaddingRight = UDim.new(0, 5)
    padTabs.Parent       = sideBar

    local horizBar = Instance.new("ScrollingFrame")
    horizBar.Size                = UDim2.new(1, 0, 0, 34)
    horizBar.Position            = UDim2.new(0, 0, 0, 33)
    horizBar.BackgroundColor3    = Theme.PanelLight
    horizBar.BackgroundTransparency = 0.4
    horizBar.BorderSizePixel     = 0
    horizBar.Visible             = isHorizontal
    horizBar.ScrollingDirection  = Enum.ScrollingDirection.X
    horizBar.ScrollBarThickness  = 3
    horizBar.ScrollBarImageColor3 = Theme.Accent
    horizBar.CanvasSize          = UDim2.new(0, 0, 0, 0)
    horizBar.AutomaticCanvasSize = Enum.AutomaticSize.X
    horizBar.Parent              = main
    LouisHub:Register(horizBar, "BackgroundColor3", "PanelLight")

    local layoutHoriz = Instance.new("UIListLayout")
    layoutHoriz.FillDirection     = Enum.FillDirection.Horizontal
    layoutHoriz.Padding           = UDim.new(0, 4)
    layoutHoriz.SortOrder         = Enum.SortOrder.LayoutOrder
    layoutHoriz.VerticalAlignment = Enum.VerticalAlignment.Center
    layoutHoriz.Parent            = horizBar

    local padHoriz = Instance.new("UIPadding")
    padHoriz.PaddingLeft, padHoriz.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
    padHoriz.PaddingTop, padHoriz.PaddingBottom = UDim.new(0, 3), UDim.new(0, 3)
    padHoriz.Parent                             = horizBar

    local function getPageContainerLayout()
        if isHorizontal then
            return UDim2.new(0, 0, 0, 68), UDim2.new(1, 0, 1, -68)
        else
            return UDim2.new(0, 155, 0, 33), UDim2.new(1, -155, 1, -33)
        end
    end

    local posP, sizeP = getPageContainerLayout()
    local pageContainer = Utils.Frame({
        Parent = main, Size = sizeP, Position = posP,
        Transparency = 1, Radius = false, Border = false,
    })

    local isBreadcrumbActive = true
    local breadcrumbFrame = Utils.Frame({
        Parent = pageContainer, Size = UDim2.new(1, -16, 0, 20),
        Position = UDim2.new(0, 8, 0, 4), Transparency = 1,
        Radius = false, Border = false, Order = 0,
    })
    local lblBreadcrumb = Utils.Text({
        Parent = breadcrumbFrame, Text = "",
        Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(0, 0, 0, 0),
        TextSize = 10, Color = Theme.TextDark, TextTransparency = 0.35,
        Font = Enum.Font.GothamMedium,
    })

    LouisHub:RegisterConnection(
        UserInputService.InputBegan:Connect(function(input, processed)
            if not processed and input.KeyCode == toggleKey then
                toggleWindow(not isWindowOpen)
            end
        end)
    )

    local Window = {
        Categories   = {},
        Tabs         = {},
        _main        = main,
        ConfigName   = config.ConfigName or "autosave",
        Bind         = toggleKey,
        State        = true,
    }

    function Window:Toggle()
        toggleWindow(not isWindowOpen)
    end

    function Window:SetState(state)
        toggleWindow(state == true)
    end

    function Window:Destroy()
        LouisHub:Destroy()
    end

    local activeCategoryName = nil
    local activeTabName = nil
    local activeSubTabName = nil

    local function refreshBreadcrumb()
        if not isBreadcrumbActive then
            breadcrumbFrame.Visible = false
            return
        end
        breadcrumbFrame.Visible = true
        local str = (activeCategoryName or "") .. " › " .. (activeTabName or "")
        if activeSubTabName and activeSubTabName ~= "Main" then
            str = str .. " › " .. activeSubTabName
        end
        lblBreadcrumb.Text = str
    end

    function Window:Breadcrumb(active)
        isBreadcrumbActive = (active ~= false)
        refreshBreadcrumb()
        return isBreadcrumbActive
    end

    function Window:CurrentCategory() return activeCategoryName end
    function Window:CurrentTab() return activeTabName end
    function Window:CurrentSubTab() return activeSubTabName end

    -- ── SEARCH ENGINE ───────────────────────────────────────────
    local function filterSearch(text)
        text = (text or ""):lower()
        local isSearching = text ~= ""

        for _, entry in ipairs(registeredSections) do
            if entry.collapsible then
                if isSearching then
                    if entry.collapsedBeforeSearch == nil then
                        entry.collapsedBeforeSearch = entry.collapsed
                    end
                    if entry.collapsed then entry.ApplyCollapsed(false) end
                else
                    if entry.collapsedBeforeSearch ~= nil then
                        entry.ApplyCollapsed(entry.collapsedBeforeSearch)
                        entry.collapsedBeforeSearch = nil
                    end
                end
            end
        end

        for _, entry in ipairs(searchIndex) do
            local matches = (text == "") or (entry.text:find(text, 1, true) ~= nil)
            entry.row.Visible = matches and checkConditionalVisibility(entry.row)
        end

        local firstMatchedTab = nil
        for _, cat in pairs(Window.Categories) do
            local catMatched = false
            for _, t in pairs(cat.Tabs) do
                local tabMatched = false
                for _, sub in pairs(t.SubTabs) do
                    for _, s in ipairs(sub.Sections) do
                        local secMatched = false
                        for _, child in ipairs(s.container:GetChildren()) do
                            if child:IsA("GuiObject") and child.Visible then
                                secMatched = true
                                break
                            end
                        end
                        s.frame.Visible = (text == "") or secMatched
                        if secMatched then tabMatched = true end
                    end
                end
                t.Button.Visible = (text == "") or tabMatched
                if tabMatched then
                    catMatched = true
                    if not firstMatchedTab then firstMatchedTab = t end
                end
            end
            if cat.HeaderSide then
                cat.HeaderSide.Visible = (text == "") or catMatched
                if isSearching and catMatched and cat.Collapsed then
                    cat:ToggleCollapse(false)
                end
            end
        end

        if isSearching and firstMatchedTab then
            firstMatchedTab:Select()
        end
    end

    function Window:Search(text)
        filterSearch(text)
    end

    if config.SearchBox ~= false then
        local searchId = 0
        local function hookSearchBox(box)
            box:GetPropertyChangedSignal("Text"):Connect(function()
                searchId = searchId + 1
                local curId = searchId
                local txt = box.Text
                task.delay(0.12, function()
                    if curId == searchId then filterSearch(txt) end
                end)
            end)
        end

        local function createSearchTextBox()
            local box = Instance.new("TextBox")
            box.BackgroundColor3 = Theme.Input
            box.BackgroundTransparency = 0.4
            box.PlaceholderText  = "🔍 Search..."
            box.Text             = ""
            box.TextColor3       = Theme.Text
            box.Font             = Enum.Font.Gotham
            box.TextSize         = 10
            box.ClearTextOnFocus = false
            box.BorderSizePixel  = 0
            Utils.Corner(box, 5)
            LouisHub:Register(box, "BackgroundColor3", "Input")
            LouisHub:Register(box, "TextColor3", "Text")
            hookSearchBox(box)
            return box
        end

        local searchBoxSide = createSearchTextBox()
        searchBoxSide.Size        = UDim2.new(1, 0, 0, 20)
        searchBoxSide.LayoutOrder = 0
        searchBoxSide.Parent      = sideBar

        local searchBoxHoriz = createSearchTextBox()
        searchBoxHoriz.Size     = UDim2.new(0, 130, 0, 22)
        searchBoxHoriz.Position = UDim2.new(1, -145, 0, 40)
        searchBoxHoriz.ZIndex   = 10
        searchBoxHoriz.Visible  = isHorizontal
        searchBoxHoriz.Parent   = main
        Window._searchBoxHoriz  = searchBoxHoriz
    end

--[[
╔══════════════════════════════════════════════════════════════════════╗
                              LouisHub
                Master UI Suite: LouisHub Engine V4.0
         PART 2B: CATEGORY, TAB & TWO-COLUMN SUBTAB ENGINE
╚══════════════════════════════════════════════════════════════════════╝
]]

-- ══════════════════════════════════════════════════════════════
--  SECTION 14: CATEGORIES, TABS & TWO-COLUMN SUBTAB SYSTEM
-- ══════════════════════════════════════════════════════════════
    local catOrder = 0
    local isFirstGlobalTab = true

    local _controlInjector = nil
    function LouisHub:_SetControlInjector(fn)
        _controlInjector = fn
    end

    function Window:CreateCategory(catCfg)
        if type(catCfg) == "string" then catCfg = { Name = catCfg } end
        catCfg = catCfg or {}
        local catName = catCfg.Name or "General"
        if self.Categories[catName] then return self.Categories[catName] end

        catOrder = catOrder + 1
        local isSystem = (catName == "System")
        local isCollapsed = (catCfg.Collapsed == true) and not isSystem

        local headerSide = Utils.Frame({
            Parent = sideBar, Size = UDim2.new(1, 0, 0, 22),
            Color = Theme.Panel, Transparency = 1, Order = isSystem and 9999 or (catOrder * 100),
            Radius = false, Border = false,
        })

        local btnHeader = Utils.BaseButton({
            Parent = headerSide, Size = UDim2.new(1, 0, 1, 0),
            Transparency = 1, Radius = false,
        })

        local arrowIcon = Instance.new("ImageLabel")
        arrowIcon.BackgroundTransparency = 1
        arrowIcon.Image = "rbxassetid://83472139709682"
        arrowIcon.Size = UDim2.new(0, 8, 0, 8)
        arrowIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        arrowIcon.Position = UDim2.new(0, 8, 0.5, 0)
        arrowIcon.Rotation = isCollapsed and -90 or 0
        arrowIcon.Visible = not isSystem
        arrowIcon.Parent = headerSide
        LouisHub:Register(arrowIcon, "ImageColor3", "TextDark")

        local icoParam = catCfg.Icon
        local lblCat = Utils.Text({
            Parent = headerSide,
            Text = (icoParam and (icoParam .. " ") or "") .. string.upper(catName),
            Size = UDim2.new(1, -20, 1, 0),
            Position = UDim2.new(0, isSystem and 6 or 16, 0, 0),
            Font = Enum.Font.GothamBold,
            TextSize = 9,
            Color = catCfg.Color or Theme.AccentLight,
            Truncate = true,
        })
        if not catCfg.Color then LouisHub:Register(lblCat, "TextColor3", "AccentLight") end

        local tabsContainer = Instance.new("Frame")
        tabsContainer.Name = "TabsContainer_" .. catName
        tabsContainer.BackgroundTransparency = 1
        tabsContainer.Size = UDim2.new(1, 0, 0, 0)
        tabsContainer.AutomaticSize = Enum.AutomaticSize.Y
        tabsContainer.LayoutOrder = isSystem and 10000 or ((catOrder * 100) + 1)
        tabsContainer.Visible = not isCollapsed
        tabsContainer.Parent = sideBar

        local catList = Instance.new("UIListLayout")
        catList.Padding = UDim.new(0, 2)
        catList.SortOrder = Enum.SortOrder.LayoutOrder
        catList.Parent = tabsContainer

        local CategoryObj = {
            Name        = catName,
            Collapsed   = isCollapsed,
            Tabs        = {},
            HeaderSide  = headerSide,
            Container   = tabsContainer,
        }

        function CategoryObj:ToggleCollapse(forceState)
            if isSystem then return end
            if forceState ~= nil then
                self.Collapsed = (forceState == true)
            else
                self.Collapsed = not self.Collapsed
            end
            tabsContainer.Visible = not self.Collapsed
            Utils.Tween(arrowIcon, {Rotation = self.Collapsed and -90 or 0}, 0.2)
        end

        if not isSystem then
            Utils.ReliableClick(btnHeader, function()
                CategoryObj:ToggleCollapse()
            end)
        end

        function CategoryObj:CreateTab(tabCfg, iconParamOverride)
            if type(tabCfg) == "string" then
                tabCfg = { Name = tabCfg, Icon = iconParamOverride }
            end
            tabCfg = tabCfg or {}
            local tabName = tabCfg.Name or "Tab"
            local tabIcon = tabCfg.Icon or "▪"
            local showTitle = tabCfg.ShowTitle ~= false

            local internalOrder = #self.Container:GetChildren()

            local btnSide = Utils.BaseButton({
                Parent = self.Container, Size = UDim2.new(1, 0, 0, 26),
                Color = Theme.Row, Transparency = 0.5,
                Order = internalOrder, Radius = 6,
            })
            local hitboxSide = Utils.ExpandedHitbox(btnSide, 6)
            Utils.Hover(hitboxSide, btnSide)
            LouisHub:Register(btnSide, "BackgroundColor3", "Row")

            local indicatorSide = Utils.Frame({
                Parent = btnSide, Size = UDim2.new(0, 2.5, 1, -6),
                Position = UDim2.new(0, 0, 0, 3),
                Color = Theme.Accent, Radius = 2, Border = false,
            })
            indicatorSide.BackgroundTransparency = 1
            LouisHub:Register(indicatorSide, "BackgroundColor3", "Accent")

            local icAsset = GetIcon(tabIcon, "Material")
            if icAsset then
                local img = Instance.new("ImageLabel")
                img.BackgroundTransparency = 1
                img.Size = UDim2.new(0, 14, 0, 14)
                img.Position = UDim2.new(0, 6, 0.5, -7)
                if type(icAsset) == "table" then
                    img.Image = "rbxassetid://" .. tostring(icAsset.id)
                    img.ImageRectSize = icAsset.imageRectSize
                    img.ImageRectOffset = icAsset.imageRectOffset
                else
                    img.Image = icAsset
                end
                img.Parent = btnSide
            else
                Utils.Text({
                    Parent = btnSide, Text = tabIcon,
                    Size = UDim2.new(0, 18, 1, 0), Position = UDim2.new(0, 4, 0, 0),
                    Alignment = Enum.TextXAlignment.Center, TextSize = 11,
                })
            end

            Utils.Text({
                Parent = btnSide, Text = tabName,
                Size = UDim2.new(1, -26, 1, 0), Position = UDim2.new(0, 24, 0, 0),
                Font = Enum.Font.GothamMedium, TextSize = 10.5,
                Category = "tabs", Truncate = true,
            })

            local btnHoriz = Utils.BaseButton({
                Parent = horizBar, Size = UDim2.new(0, 85, 0, 24),
                Color = Theme.Row, Transparency = 0.5,
                Order = internalOrder, Radius = 6,
            })
            btnHoriz.AutomaticSize = Enum.AutomaticSize.X
            local padH = Instance.new("UIPadding")
            padH.PaddingLeft, padH.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
            padH.Parent = btnHoriz

            local indicatorHoriz = Utils.Frame({
                Parent = btnHoriz, Size = UDim2.new(1, -6, 0, 2),
                Position = UDim2.new(0, 3, 1, -2), Color = Theme.Accent,
                Radius = 1, Border = false,
            })
            indicatorHoriz.BackgroundTransparency = 1
            LouisHub:Register(indicatorHoriz, "BackgroundColor3", "Accent")

            Utils.Text({
                Parent = btnHoriz, Text = tabName,
                Size = UDim2.new(1, 0, 1, 0), Alignment = Enum.TextXAlignment.Center,
                TextSize = 10, Font = Enum.Font.GothamMedium, Category = "tabs",
            })

            local tabPage = Instance.new("Frame")
            tabPage.Name = "TabPage_" .. tabName
            tabPage.Size = UDim2.new(1, 0, 1, -24)
            tabPage.Position = UDim2.new(0, 0, 0, 24)
            tabPage.BackgroundTransparency = 1
            tabPage.Visible = false
            tabPage.Parent = pageContainer

            if showTitle then
                local tLbl = Utils.Text({
                    Parent = tabPage, Text = tabName,
                    Size = UDim2.new(1, -20, 0, 20), Position = UDim2.new(0, 10, 0, 0),
                    Font = Enum.Font.GothamBold, TextSize = 14, Color = Theme.Highlight,
                })
                LouisHub:Register(tLbl, "TextColor3", "Highlight")
            end

            local subTabBar = Utils.Frame({
                Parent = tabPage, Size = UDim2.new(1, -16, 0, 24),
                Position = UDim2.new(0, 8, 0, showTitle and 22 or 2),
                Transparency = 1, Radius = false, Border = false,
            })
            subTabBar.Visible = false

            local subLayout = Instance.new("UIListLayout")
            subLayout.FillDirection = Enum.FillDirection.Horizontal
            subLayout.Padding = UDim.new(0, 4)
            subLayout.Parent = subTabBar

            local subTabContainer = Utils.Frame({
                Parent = tabPage,
                Size = UDim2.new(1, 0, 1, showTitle and -48 or -28),
                Position = UDim2.new(0, 0, 0, showTitle and 48 or 28),
                Transparency = 1, Radius = false, Border = false,
            })

            local TabObj = {
                Name            = tabName,
                Category        = catName,
                Button          = btnSide,
                ButtonHoriz     = btnHoriz,
                IndicatorSide   = indicatorSide,
                IndicatorHoriz  = indicatorHoriz,
                Page            = tabPage,
                SubTabBar       = subTabBar,
                SubTabContainer = subTabContainer,
                SubTabs         = {},
                SubTabsOrder    = {},
            }

            function TabObj:Select()
                for _, catIter in pairs(Window.Categories) do
                    for _, tIter in pairs(catIter.Tabs) do
                        tIter.Page.Visible = false
                        Utils.Tween(tIter.IndicatorSide,  {BackgroundTransparency = 1}, 0.2)
                        Utils.Tween(tIter.IndicatorHoriz, {BackgroundTransparency = 1}, 0.2)
                    end
                end
                self.Page.Visible = true
                Utils.Tween(self.IndicatorSide,  {BackgroundTransparency = 0}, 0.2)
                Utils.Tween(self.IndicatorHoriz, {BackgroundTransparency = 0}, 0.2)

                activeCategoryName = self.Category
                activeTabName = self.Name

                if #self.SubTabsOrder > 0 then
                    local activeSub = self.SubTabs[activeSubTabName] or self.SubTabsOrder[1]
                    if activeSub then activeSub:Select() end
                else
                    activeSubTabName = nil
                end
                refreshBreadcrumb()
                LouisHub.Events.TabChanged:Fire(self.Category, self.Name)
            end

            Utils.ReliableClick(hitboxSide, function() TabObj:Select() end, btnSide)
            Utils.ReliableClick(btnHoriz, function() TabObj:Select() end)

            -- ── TWO-COLUMN SUBTAB ENGINE ─────────────────────────────
            function TabObj:CreateSubTab(subCfg)
                if type(subCfg) == "string" then subCfg = { Name = subCfg } end
                subCfg = subCfg or {}
                local subName      = subCfg.Name or "Main"
                local layoutMode   = subCfg.Layout or "Single"
                local isTwoColumn  = (layoutMode == "TwoColumn")
                local allowMobile  = subCfg.MobileStack ~= false

                if self.SubTabs[subName] then return self.SubTabs[subName] end

                local subBtn = Utils.BaseButton({
                    Parent = self.SubTabBar, Size = UDim2.new(0, 70, 1, 0),
                    Color = Theme.Row, Transparency = 0.5, Radius = 5,
                })
                subBtn.AutomaticSize = Enum.AutomaticSize.X
                local sPad = Instance.new("UIPadding")
                sPad.PaddingLeft, sPad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
                sPad.Parent = subBtn

                Utils.Text({
                    Parent = subBtn, Text = subName,
                    Size = UDim2.new(1, 0, 1, 0), Alignment = Enum.TextXAlignment.Center,
                    TextSize = 10, Font = Enum.Font.GothamMedium,
                })

                local mainSubPage = Instance.new("ScrollingFrame")
                mainSubPage.Name                   = "SubPage_" .. subName
                mainSubPage.Size                   = UDim2.new(1, 0, 1, 0)
                mainSubPage.BackgroundTransparency = 1
                mainSubPage.BorderSizePixel        = 0
                mainSubPage.ScrollBarThickness     = 3
                mainSubPage.ScrollBarImageColor3   = Theme.Accent
                mainSubPage.CanvasSize             = UDim2.new(0, 0, 0, 0)
                mainSubPage.AutomaticCanvasSize    = Enum.AutomaticSize.Y
                mainSubPage.Visible                = (#self.SubTabsOrder == 0)
                mainSubPage.Parent                 = self.SubTabContainer

                local pLayout = Instance.new("UIListLayout")
                pLayout.Padding   = UDim.new(0, 8)
                pLayout.SortOrder = Enum.SortOrder.LayoutOrder
                pLayout.Parent    = mainSubPage

                local pPad = Instance.new("UIPadding")
                pPad.PaddingTop, pPad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 10)
                pPad.PaddingLeft, pPad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
                pPad.Parent = mainSubPage

                local leftColumnContainer  = nil
                local rightColumnContainer = nil
                local updateResponsiveLayout = nil

                if isTwoColumn then
                    mainSubPage.ScrollingEnabled = false
                    mainSubPage.ScrollBarThickness = 0
                    pLayout.Padding = UDim.new(0, 0)
                    pPad.PaddingTop, pPad.PaddingBottom = UDim.new(0, 0), UDim.new(0, 0)
                    pPad.PaddingLeft, pPad.PaddingRight = UDim.new(0, 4), UDim.new(0, 4)

                    local dualHolder = Instance.new("Frame")
                    dualHolder.Name = "TwoColumnHolder"
                    dualHolder.BackgroundTransparency = 1
                    dualHolder.Size = UDim2.new(1, 0, 1, 0)
                    dualHolder.Parent = mainSubPage

                    local function createPanel(name, xPos)
                        local panel = Instance.new("ScrollingFrame")
                        panel.Name                   = name
                        panel.Size                   = UDim2.new(0.5, -4, 1, 0)
                        panel.Position               = xPos
                        panel.BackgroundTransparency = 1
                        panel.BorderSizePixel        = 0
                        panel.ScrollBarThickness     = 3
                        panel.ScrollBarImageColor3   = Theme.Accent
                        panel.CanvasSize             = UDim2.new(0, 0, 0, 0)
                        panel.AutomaticCanvasSize    = Enum.AutomaticSize.Y
                        panel.ScrollingDirection     = Enum.ScrollingDirection.Y
                        panel.Parent                 = dualHolder

                        local l = Instance.new("UIListLayout")
                        l.Padding = UDim.new(0, 8)
                        l.SortOrder = Enum.SortOrder.LayoutOrder
                        l.Parent = panel

                        local pad = Instance.new("UIPadding")
                        pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 10)
                        pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 4), UDim.new(0, 4)
                        pad.Parent = panel

                        LouisHub:Register(panel, "ScrollBarImageColor3", "Accent")
                        return panel
                    end

                    leftColumnContainer  = createPanel("LeftPanel", UDim2.new(0, 0, 0, 0))
                    rightColumnContainer = createPanel("RightPanel", UDim2.new(0.5, 4, 0, 0))

                    updateResponsiveLayout = function()
                        if not (mainSubPage and mainSubPage.Parent and dualHolder and dualHolder.Parent) then return end
                        local cam = Workspace.CurrentCamera
                        local vw = cam and cam.ViewportSize.X or 800
                        local isMobileViewport = (vw < 600) or LouisHub.Capabilities.IsTouch

                        if allowMobile and isMobileViewport then
                            mainSubPage.ScrollingEnabled = true
                            mainSubPage.ScrollBarThickness = 3
                            dualHolder.Size = UDim2.new(1, 0, 0, 0)
                            dualHolder.AutomaticSize = Enum.AutomaticSize.Y

                            leftColumnContainer.Size = UDim2.new(1, 0, 0, 0)
                            leftColumnContainer.Position = UDim2.new(0, 0, 0, 0)
                            leftColumnContainer.AutomaticSize = Enum.AutomaticSize.Y
                            leftColumnContainer.ScrollingEnabled = false
                            leftColumnContainer.ScrollBarThickness = 0

                            rightColumnContainer.Size = UDim2.new(1, 0, 0, 0)
                            rightColumnContainer.Position = UDim2.new(0, 0, 0, 0)
                            rightColumnContainer.AutomaticSize = Enum.AutomaticSize.Y
                            rightColumnContainer.ScrollingEnabled = false
                            rightColumnContainer.ScrollBarThickness = 0

                            local hLayout = dualHolder:FindFirstChildOfClass("UIListLayout")
                            if not hLayout then
                                hLayout = Instance.new("UIListLayout")
                                hLayout.Padding = UDim.new(0, 8)
                                hLayout.SortOrder = Enum.SortOrder.LayoutOrder
                                hLayout.Parent = dualHolder
                            end
                            leftColumnContainer.LayoutOrder = 1
                            rightColumnContainer.LayoutOrder = 2
                        else
                            local hLayout = dualHolder:FindFirstChildOfClass("UIListLayout")
                            if hLayout then hLayout:Destroy() end

                            mainSubPage.ScrollingEnabled = false
                            mainSubPage.ScrollBarThickness = 0
                            dualHolder.Size = UDim2.new(1, 0, 1, 0)
                            dualHolder.AutomaticSize = Enum.AutomaticSize.None

                            leftColumnContainer.Size = UDim2.new(0.5, -4, 1, 0)
                            leftColumnContainer.Position = UDim2.new(0, 0, 0, 0)
                            leftColumnContainer.AutomaticSize = Enum.AutomaticSize.Y
                            leftColumnContainer.ScrollingEnabled = true
                            leftColumnContainer.ScrollBarThickness = 3

                            rightColumnContainer.Size = UDim2.new(0.5, -4, 1, 0)
                            rightColumnContainer.Position = UDim2.new(0.5, 4, 0, 0)
                            rightColumnContainer.AutomaticSize = Enum.AutomaticSize.Y
                            rightColumnContainer.ScrollingEnabled = true
                            rightColumnContainer.ScrollBarThickness = 3
                        end
                    end

                    updateResponsiveLayout()
                    local cam = Workspace.CurrentCamera
                    if cam then
                        LouisHub:RegisterConnection(cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout))
                    end
                end

                local SubTabObj = {
                    Name       = subName,
                    Layout     = layoutMode,
                    Button     = subBtn,
                    Page       = mainSubPage,
                    Sections   = {},
                    _sideCount = 0,
                }

                function SubTabObj:Select()
                    for _, s in pairs(TabObj.SubTabs) do
                        s.Page.Visible = false
                        Utils.Tween(s.Button, {BackgroundColor3 = Theme.Row}, 0.2)
                    end
                    self.Page.Visible = true
                    Utils.Tween(self.Button, {BackgroundColor3 = Theme.Accent}, 0.2)
                    activeSubTabName = self.Name
                    refreshBreadcrumb()
                    if updateResponsiveLayout then updateResponsiveLayout() end
                    LouisHub.Events.SubTabChanged:Fire(TabObj.Category, TabObj.Name, self.Name)
                end

                Utils.ReliableClick(subBtn, function() SubTabObj:Select() end)

                table.insert(TabObj.SubTabsOrder, SubTabObj)
                TabObj.SubTabs[subName] = SubTabObj

                if #TabObj.SubTabsOrder >= 2 then
                    TabObj.SubTabBar.Visible = true
                    TabObj.SubTabContainer.Position = UDim2.new(0, 0, 0, showTitle and 48 or 28)
                    TabObj.SubTabContainer.Size = UDim2.new(1, 0, 1, showTitle and -48 or -28)
                else
                    TabObj.SubTabBar.Visible = false
                    TabObj.SubTabContainer.Position = UDim2.new(0, 0, 0, showTitle and 24 or 4)
                    TabObj.SubTabContainer.Size = UDim2.new(1, 0, 1, showTitle and -24 or -4)
                end

                -- ── CREATE SECTION (PANEL PLACEMENT & INNER 2 COLUMNS) ────
                function SubTabObj:CreateSection(secName, secCfg)
                    secCfg = secCfg or {}
                    local numColumns         = secCfg.Columns or 1
                    local collapsible        = (secCfg.Collapsible ~= false)
                    local collapsedByDefault = collapsible and (secCfg.CollapsedByDefault == true)

                    local targetPanel = mainSubPage
                    if isTwoColumn then
                        local specifiedSide = secCfg.Side or (secCfg.Column == 1 and "Left") or (secCfg.Column == 2 and "Right")
                        if specifiedSide == "Left" then
                            targetPanel = leftColumnContainer
                        elseif specifiedSide == "Right" then
                            targetPanel = rightColumnContainer
                        else
                            self._sideCount = self._sideCount + 1
                            targetPanel = (self._sideCount % 2 == 1) and leftColumnContainer or rightColumnContainer
                        end
                    end

                    local frame = Utils.Frame({
                        Parent = targetPanel, Size = UDim2.new(1, 0, 0, 0),
                        Color = Theme.Panel, Radius = 6, Border = true,
                        BorderColor = Theme.Border, BorderThemeKey = "Border",
                        Transparency = 0.35,
                    })
                    frame.AutomaticSize = Enum.AutomaticSize.Y

                    local btnHeader, arrow, lblSec
                    if collapsible then
                        btnHeader = Utils.BaseButton({
                            Parent = frame, Size = UDim2.new(1, 0, 0, 24),
                            Transparency = 1, Radius = false,
                        })
                        Utils.Hover(btnHeader, frame, nil, nil, function() return Theme.Panel end)

                        arrow = Instance.new("ImageLabel")
                        arrow.BackgroundTransparency = 1
                        arrow.Image = "rbxassetid://83472139709682"
                        arrow.Size = UDim2.new(0, 10, 0, 10)
                        arrow.AnchorPoint = Vector2.new(0.5, 0.5)
                        arrow.Position = UDim2.new(0, 10, 0.5, 0)
                        arrow.Rotation = collapsedByDefault and -90 or 0
                        arrow.Parent = btnHeader
                        LouisHub:Register(arrow, "ImageColor3", "AccentLight")

                        lblSec = Utils.Text({
                            Parent = btnHeader, Text = secName or "Section",
                            Size = UDim2.new(1, -24, 1, 0), Position = UDim2.new(0, 20, 0, 0),
                            Font = Enum.Font.GothamBold, TextSize = 11, Color = Theme.AccentLight,
                        })
                        LouisHub:Register(lblSec, "TextColor3", "AccentLight")
                    else
                        lblSec = Utils.Text({
                            Parent = frame, Text = secName or "Section",
                            Size = UDim2.new(1, -12, 0, 20), Position = UDim2.new(0, 8, 0, 2),
                            Font = Enum.Font.GothamBold, TextSize = 11, Color = Theme.AccentLight,
                        })
                        LouisHub:Register(lblSec, "TextColor3", "AccentLight")
                    end

                    local bodyContainer = Utils.Frame({
                        Parent = frame, Size = UDim2.new(1, 0, 0, 0),
                        Position = UDim2.new(0, 0, 0, 24), Transparency = 1,
                        Radius = false, Border = false,
                    })
                    bodyContainer.AutomaticSize = Enum.AutomaticSize.Y
                    bodyContainer.Visible = not collapsedByDefault

                    local col1, col2 = nil, nil
                    if numColumns == 2 then
                        local rowCols = Instance.new("Frame")
                        rowCols.BackgroundTransparency = 1
                        rowCols.Size = UDim2.new(1, 0, 0, 0)
                        rowCols.AutomaticSize = Enum.AutomaticSize.Y
                        rowCols.Parent = bodyContainer

                        local padCols = Instance.new("UIPadding")
                        padCols.PaddingLeft, padCols.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
                        padCols.PaddingTop, padCols.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
                        padCols.Parent = rowCols

                        col1 = Instance.new("Frame")
                        col1.Name = "Column1"
                        col1.BackgroundTransparency = 1
                        col1.Size = UDim2.new(0.5, -4, 0, 0)
                        col1.Position = UDim2.new(0, 0, 0, 0)
                        col1.AutomaticSize = Enum.AutomaticSize.Y
                        col1.Parent = rowCols

                        local l1 = Instance.new("UIListLayout")
                        l1.Padding = UDim.new(0, 5)
                        l1.SortOrder = Enum.SortOrder.LayoutOrder
                        l1.Parent = col1

                        col2 = Instance.new("Frame")
                        col2.Name = "Column2"
                        col2.BackgroundTransparency = 1
                        col2.Size = UDim2.new(0.5, -4, 0, 0)
                        col2.Position = UDim2.new(0.5, 4, 0, 0)
                        col2.AutomaticSize = Enum.AutomaticSize.Y
                        col2.Parent = rowCols

                        local l2 = Instance.new("UIListLayout")
                        l2.Padding = UDim.new(0, 5)
                        l2.SortOrder = Enum.SortOrder.LayoutOrder
                        l2.Parent = col2
                    else
                        local padC = Instance.new("UIPadding")
                        padC.PaddingLeft, padC.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
                        padC.PaddingTop, padC.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
                        padC.Parent = bodyContainer

                        local lC = Instance.new("UIListLayout")
                        lC.Padding = UDim.new(0, 5)
                        lC.SortOrder = Enum.SortOrder.LayoutOrder
                        lC.Parent = bodyContainer
                    end

                    local secEntry = {
                        frame       = frame,
                        container   = bodyContainer,
                        arrow       = arrow,
                        collapsible = collapsible,
                        collapsed   = collapsedByDefault,
                    }

                    local function applyCollapsed(v, animate)
                        secEntry.collapsed = v
                        if arrow then
                            if animate then Utils.Tween(arrow, {Rotation = v and -90 or 0}, 0.2)
                            else arrow.Rotation = v and -90 or 0 end
                        end
                        if not animate then
                            bodyContainer.Visible = not v
                            return
                        end
                        if v then
                            Utils.Tween(bodyContainer, {Size = UDim2.new(1, 0, 0, 0)}, 0.25, LouisHub.Motion.EaseExit)
                            task.delay(0.25, function()
                                if secEntry.collapsed then bodyContainer.Visible = false end
                            end)
                        else
                            bodyContainer.Visible = true
                            Utils.Tween(bodyContainer, {Size = UDim2.new(1, 0, 0, bodyContainer.AbsoluteSize.Y)}, 0.25, LouisHub.Motion.EaseEnter)
                        end
                    end
                    secEntry.ApplyCollapsed = applyCollapsed

                    if collapsible and btnHeader then
                        Utils.ReliableClick(btnHeader, function()
                            applyCollapsed(not secEntry.collapsed, true)
                        end)
                    end

                    table.insert(SubTabObj.Sections, secEntry)
                    table.insert(registeredSections, secEntry)

                    local Section = {
                        frame        = frame,
                        container    = bodyContainer,
                        _col1        = col1,
                        _col2        = col2,
                        _itemCounter = 0,
                    }

                    local WIDE_CONTROLS = {
                        Slider = true, RangeSlider = true, Input = true,
                        ColorPicker = true, TagInput = true, Dropdown = true,
                        Paragraph = true, Image = true,
                    }

                    function Section:_GetTargetContainer(ctrlType, cfgCtrl)
                        if numColumns ~= 2 then return bodyContainer end
                        if cfgCtrl and cfgCtrl.Column == 1 then return col1 end
                        if cfgCtrl and cfgCtrl.Column == 2 then return col2 end

                        if WIDE_CONTROLS[ctrlType] and not (cfgCtrl and cfgCtrl.Column) then
                            return bodyContainer
                        end

                        self._itemCounter = self._itemCounter + 1
                        return (self._itemCounter % 2 == 1) and col1 or col2
                    end

                    if _controlInjector then
                        _controlInjector(Section)
                    end

                    return Section
                end

                return SubTabObj
            end

            -- Standard Alan API Tab-Level Section Delegation
            function TabObj:CreateSection(secName, secCfg)
                local subMain = self.SubTabs["Main"] or self:CreateSubTab("Main")
                return subMain:CreateSection(secName, secCfg)
            end

            table.insert(Window.Tabs, TabObj)
            self.Tabs[tabName] = TabObj

            if isFirstGlobalTab and not isSystem then
                TabObj:Select()
                isFirstGlobalTab = false
            end

            return TabObj
        end

        self.Categories[catName] = CategoryObj
        return CategoryObj
    end

    function Window:CreateTab(tabCfg, iconParamOverride)
        if type(tabCfg) == "string" then
            tabCfg = { Name = tabCfg, Icon = iconParamOverride }
        end
        local catGeneral = self.Categories["General"] or self:CreateCategory("General")
        return catGeneral:CreateTab(tabCfg)
    end

    if config.AutoSave ~= false and isFilesystemAvailable() then
        activeSaveWindow = Window
        task.defer(function()
            pcall(function() LouisHub.SaveManager:LoadSilent(Window.ConfigName) end)
            pcall(function() LouisHub.SaveManager:LoadUI("preinstalled") end)
            pcall(function() LouisHub:LoadAutoloadConfig() end)
        end)

        sg.Destroying:Connect(function()
            isAutosaveLoopActive = false
            pcall(function() LouisHub.SaveManager:SaveSilent(Window.ConfigName) end)
        end)
        startAutosaveLoop()
    end

    _G.LouisHub_Instance.Window = Window
    return Window
end

--[[
╔══════════════════════════════════════════════════════════════════════╗
                              LouisHub
                Master UI Suite: LouisHub Engine V4.0
         PART 2C: MODALS, POPUPS, HUD, FLOATING BUTTONS & CORE
╚══════════════════════════════════════════════════════════════════════╝
]]

-- ══════════════════════════════════════════════════════════════
--  SECTION 15: MODAL CONFIRMATION DIALOG SYSTEM
-- ══════════════════════════════════════════════════════════════
LouisHub._openModals = 0

function LouisHub:Confirm(cfg)
    cfg = cfg or {}
    local parent = getGuiParent()
    local gui = self._guiConfirm or (parent and parent:FindFirstChild("LouisHub_ScreenGui")) or (parent and parent:FindFirstChild("LouisHub_NotifGui"))
    if not (gui and gui.Parent) then
        self:_LogError("Confirm", "No active window available to display modal")
        return nil
    end

    local buttons = {}
    if type(cfg.Buttons) == "table" and #cfg.Buttons > 0 then
        for _, b in ipairs(cfg.Buttons) do table.insert(buttons, cloneTable(b)) end
    else
        if cfg.CancelButton then
            local b = cloneTable(cfg.CancelButton)
            b.Text = b.Text or "Cancel"
            b.Variant = b.Variant or "neutral"
            table.insert(buttons, b)
        end
        local accept = cloneTable(cfg.AcceptButton or {})
        accept.Text = accept.Text or "Accept"
        accept.Variant = accept.Variant or "primary"
        table.insert(buttons, accept)
    end

    self._openModals = (self._openModals or 0) + 1
    local zBase = 500 + (self._openModals - 1) * 10
    local titleErr = cfg.Title or "Confirm"

    local backdrop = Utils.Frame({
        Parent = gui, Size = UDim2.new(1, 0, 1, 0),
        Color = Color3.new(0, 0, 0), Transparency = 0.5, Radius = false,
        Border = false,
    })
    backdrop.ZIndex = zBase
    backdrop.Active = true

    local blurData = BlurModule(backdrop)

    local closed = false
    backdrop.Destroying:Connect(function()
        if closed then return end
        closed = true
        self._openModals = math.max(0, (self._openModals or 1) - 1)
        for i = #themeRegistry, 1, -1 do
            local inst = themeRegistry[i].instance
            if inst == backdrop or inst:IsDescendantOf(backdrop) then table.remove(themeRegistry, i) end
        end
        for i = #textScaleRegistry, 1, -1 do
            local inst = textScaleRegistry[i].instance
            if inst == backdrop or inst:IsDescendantOf(backdrop) then table.remove(textScaleRegistry, i) end
        end
        task.defer(function()
            local active = _G.LouisHub_Instance
            if not active then return end
            for i = #active.Connections, 1, -1 do
                if active.Connections[i].Connected == false then table.remove(active.Connections, i) end
            end
        end)
    end)

    local card = Utils.Frame({
        Parent = backdrop, Size = UDim2.new(0, 300, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0), Anchor = Vector2.new(0.5, 0.5),
        Color = Theme.Panel, Radius = 8,
        Border = true, BorderColor = Theme.Border, BorderThickness = 1,
        BorderThemeKey = "Border",
        Transparency = 0.25,
    })
    card.ZIndex = zBase + 1
    card.Active = true
    card.AutomaticSize = Enum.AutomaticSize.Y
    LouisHub:Register(card, "BackgroundColor3", "Panel")

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = card

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
    pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 14), UDim.new(0, 14)
    pad.Parent = card

    local order = 0
    local iconParam = cfg.Icon
    if iconParam then
        order = order + 1
        local iconAsset = GetIcon(iconParam, "Material")
        if iconAsset then
            local iconHolder = Instance.new("Frame")
            iconHolder.BackgroundTransparency = 1
            iconHolder.Size = UDim2.new(1, 0, 0, 28)
            iconHolder.LayoutOrder = order
            iconHolder.ZIndex = zBase + 2
            iconHolder.Parent = card

            local imgIco = Instance.new("ImageLabel")
            imgIco.BackgroundTransparency = 1
            imgIco.Size = UDim2.new(0, 26, 0, 26)
            imgIco.AnchorPoint = Vector2.new(0.5, 0.5)
            imgIco.Position = UDim2.new(0.5, 0, 0.5, 0)
            imgIco.ZIndex = zBase + 3
            if type(iconAsset) == "table" then
                imgIco.Image = "rbxassetid://" .. tostring(iconAsset.id)
                imgIco.ImageRectSize = iconAsset.imageRectSize
                imgIco.ImageRectOffset = iconAsset.imageRectOffset
            else
                imgIco.Image = iconAsset
            end
            imgIco.Parent = iconHolder
        else
            local lblIcon = Utils.Text({
                Parent = card, Text = tostring(iconParam),
                Size = UDim2.new(1, 0, 0, 26), Order = order,
                Alignment = Enum.TextXAlignment.Center, TextSize = 22,
            })
            lblIcon.ZIndex = zBase + 2
        end
    end

    local titleParam = cfg.Title
    if titleParam then
        order = order + 1
        local lblTitle = Utils.Text({
            Parent = card, Text = tostring(titleParam),
            Size = UDim2.new(1, 0, 0, 0), Order = order,
            Font = Enum.Font.GothamBold, TextSize = 14, Wrapped = true,
            Alignment = iconParam and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
            Color = Theme.Highlight,
        })
        lblTitle.AutomaticSize = Enum.AutomaticSize.Y
        lblTitle.ZIndex = zBase + 2
        LouisHub:Register(lblTitle, "TextColor3", "Highlight")
    end

    local contentParam = cfg.Content
    if contentParam then
        order = order + 1
        local lblBody = Utils.Text({
            Parent = card, Text = tostring(contentParam),
            Size = UDim2.new(1, 0, 0, 0), Order = order,
            Wrapped = true, TextSize = 11, TextTransparency = 0.15,
            Alignment = iconParam and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
        })
        lblBody.AutomaticSize = Enum.AutomaticSize.Y
        lblBody.ZIndex = zBase + 2
    end

    local total = #buttons
    local vertical = total > 3
    order = order + 1
    local buttonRow = Utils.Frame({
        Parent = card, Size = UDim2.new(1, 0, 0, vertical and 0 or 30),
        Transparency = 1, Order = order, Radius = false, Border = false,
    })
    buttonRow.ZIndex = zBase + 2
    if vertical then buttonRow.AutomaticSize = Enum.AutomaticSize.Y end

    local layoutButtons = Instance.new("UIListLayout")
    layoutButtons.FillDirection = vertical and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
    layoutButtons.Padding = UDim.new(0, 6)
    layoutButtons.SortOrder = Enum.SortOrder.LayoutOrder
    layoutButtons.Parent = buttonRow

    local white = Color3.fromRGB(255, 255, 255)
    local function close()
        if backdrop.Parent then backdrop:Destroy() end
    end
    local function press(i)
        local btn = buttons[i]
        if not btn then return end
        close()
        if type(btn.Callback) == "function" then
            executeWithFallback(btn.Callback, btn.Text or titleErr)
        end
    end

    for i, btnData in ipairs(buttons) do
        local variant = btnData.Variant or "neutral"
        local btnWidth = vertical and UDim2.new(1, 0, 0, 30)
            or UDim2.new(1 / total, -math.ceil(6 * (total - 1) / total), 1, 0)
        local color, themeKey, textColor, hasBorder = Theme.Row, "Row", nil, false
        local transparency = 0.3
        if variant == "primary" then
            color, themeKey, textColor = Theme.Accent, "Accent", white
        elseif variant == "danger" then
            color, themeKey, textColor = Color3.fromRGB(180, 50, 50), nil, white
        elseif variant == "tertiary" then
            color, themeKey, hasBorder, transparency = Theme.Panel, nil, true, 1
        end

        local btn = Utils.BaseButton({
            Parent = buttonRow, Size = btnWidth,
            Color = color, Transparency = transparency, Radius = 6,
        })
        btn.LayoutOrder = i
        btn.ZIndex = zBase + 3
        if themeKey then LouisHub:Register(btn, "BackgroundColor3", themeKey) end
        if hasBorder then
            local stroke = Utils.Stroke(btn, Theme.Border, 1, 0)
            LouisHub:Register(stroke, "Color", "Border")
        else
            Utils.Hover(btn, btn)
        end

        local lbl = Utils.Text({
            Parent = btn, Text = tostring(btnData.Text or "OK"),
            Alignment = Enum.TextXAlignment.Center, TextSize = 11,
            Font = Enum.Font.GothamMedium, Color = textColor, Truncate = true,
        })
        lbl.ZIndex = zBase + 4

        btn.MouseButton1Click:Connect(function() press(i) end)
    end

    Utils.ModalEntry(backdrop, card)

    return { Close = close, Press = press, Backdrop = backdrop }
end

-- ══════════════════════════════════════════════════════════════
--  SECTION 16: STACKABLE POPUP ENGINE (GLASS MODALS)
-- ══════════════════════════════════════════════════════════════
function LouisHub:Popup(cfg)
    cfg = cfg or {}
    local parent = getGuiParent()
    local sg = (parent and parent:FindFirstChild("LouisHub_ScreenGui")) or (parent and parent:FindFirstChild("LouisHub_NotifGui"))
    if not sg then
        sg = Instance.new("ScreenGui")
        sg.Name = "LouisHub_PopupGui"
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = true
        sg.DisplayOrder = 999999
        sg.Parent = parent
        protectGui(sg)
        LouisHub:RegisterInstance(sg)
    end

    self._openModals = (self._openModals or 0) + 1
    local zBase = 500 + (self._openModals - 1) * 10

    local backdrop = Instance.new("TextButton")
    backdrop.Name = "PopupBackdrop"
    backdrop.Size = UDim2.new(1, 0, 1, 0)
    backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
    backdrop.BackgroundTransparency = 1
    backdrop.AutoButtonColor = false
    backdrop.Text = ""
    backdrop.ZIndex = zBase
    backdrop.Parent = sg

    local blurData = BlurModule(backdrop)

    local cardWidth = math.clamp(cfg.Width or 340, 300, 420)
    local card = Instance.new("Frame")
    card.Name = "PopupCard"
    card.Size = UDim2.new(0, cardWidth, 0, 0)
    card.Position = UDim2.new(0.5, 0, 0.5, 0)
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.BackgroundColor3 = Theme.Panel
    card.BackgroundTransparency = 0.25
    card.BorderSizePixel = 0
    card.ClipsDescendants = true
    card.Active = true
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.ZIndex = zBase + 1
    card.Parent = backdrop

    Utils.Corner(card, 8)
    local cardStroke = Utils.Stroke(card, Theme.Accent, 1, 0.4)
    LouisHub:Register(cardStroke, "Color", "Accent")

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = card

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft   = UDim.new(0, 14)
    pad.PaddingRight  = UDim.new(0, 14)
    pad.PaddingTop    = UDim.new(0, 14)
    pad.PaddingBottom = UDim.new(0, 14)
    pad.Parent = card

    local order = 0
    local iconParam = cfg.Icon
    if iconParam then
        order = order + 1
        local iconFrame = Instance.new("ImageLabel")
        iconFrame.BackgroundTransparency = 1
        iconFrame.Size = UDim2.new(0, 26, 0, 26)
        iconFrame.LayoutOrder = order
        iconFrame.ZIndex = zBase + 2
        local ic = GetIcon(iconParam, "Material")
        if type(ic) == "table" then
            iconFrame.Image = "rbxassetid://" .. tostring(ic.id)
            iconFrame.ImageRectSize = ic.imageRectSize
            iconFrame.ImageRectOffset = ic.imageRectOffset
            iconFrame.Parent = card
        elseif type(ic) == "string" then
            iconFrame.Image = ic
            iconFrame.Parent = card
        end
    end

    local titleParam = cfg.Title
    if titleParam then
        order = order + 1
        local lblTitle = Utils.Text({
            Parent = card,
            Text = tostring(titleParam),
            Size = UDim2.new(1, 0, 0, 22),
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            Color = Theme.Highlight,
            Order = order,
        })
        lblTitle.ZIndex = zBase + 2
        LouisHub:Register(lblTitle, "TextColor3", "Highlight")
    end

    local contentContainer = nil
    local contentParam = cfg.Content
    if contentParam then
        order = order + 1
        if type(contentParam) == "function" then
            contentContainer = Instance.new("Frame")
            contentContainer.BackgroundTransparency = 1
            contentContainer.Size = UDim2.new(1, 0, 0, 0)
            contentContainer.AutomaticSize = Enum.AutomaticSize.Y
            contentContainer.LayoutOrder = order
            contentContainer.ZIndex = zBase + 2
            contentContainer.Parent = card
            pcall(contentParam, contentContainer)
        else
            local lblBody = Utils.Text({
                Parent = card,
                Text = tostring(contentParam),
                Size = UDim2.new(1, 0, 0, 0),
                Wrapped = true,
                TextSize = 11,
                Color = Theme.Text,
                Order = order,
            })
            lblBody.AutomaticSize = Enum.AutomaticSize.Y
            lblBody.ZIndex = zBase + 2
            LouisHub:Register(lblBody, "TextColor3", "Text")
        end
    end

    local buttons = cfg.Buttons or { { Text = "OK", Variant = "primary" } }
    order = order + 1

    local buttonRow = Instance.new("Frame")
    buttonRow.BackgroundTransparency = 1
    buttonRow.Size = UDim2.new(1, 0, 0, 28)
    buttonRow.LayoutOrder = order
    buttonRow.ZIndex = zBase + 2
    buttonRow.Parent = card

    local bLayout = Instance.new("UIListLayout")
    bLayout.FillDirection = Enum.FillDirection.Horizontal
    bLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    bLayout.Padding = UDim.new(0, 6)
    bLayout.Parent = buttonRow

    local closed = false
    local function closeModal()
        if closed then return end
        closed = true
        LouisHub._openModals = math.max(0, (LouisHub._openModals or 1) - 1)
        Utils.Tween(backdrop, {BackgroundTransparency = 1}, 0.25, LouisHub.Motion.EaseExit)
        Utils.Tween(card, {Position = UDim2.new(0.5, 0, 0.6, 0), BackgroundTransparency = 1}, 0.25, LouisHub.Motion.EaseExit)
        task.delay(0.26, function()
            pcall(function() backdrop:Destroy() end)
            if cfg.OnClose then pcall(cfg.OnClose) end
        end)
    end

    for _, bDef in ipairs(buttons) do
        local btn = Utils.BaseButton({
            Parent = buttonRow,
            Size = UDim2.new(0, 75, 1, 0),
            Color = Theme.Row,
            Transparency = 0.3,
            Radius = 6
        })
        btn.ZIndex = zBase + 3

        local bColor = Theme.Row
        local tColor = Theme.Text
        local variant = bDef.Variant
        if variant == "primary" then
            bColor = Theme.Accent
            tColor = Color3.fromRGB(255, 255, 255)
        elseif variant == "danger" then
            bColor = Color3.fromRGB(180, 50, 50)
            tColor = Color3.fromRGB(255, 255, 255)
        end
        btn.BackgroundColor3 = bColor
        Utils.Hover(btn, btn)

        local bLbl = Utils.Text({
            Parent = btn,
            Text = bDef.Text or "Button",
            Alignment = Enum.TextXAlignment.Center,
            TextSize = 11,
            Color = tColor,
            Size = UDim2.new(1, 0, 1, 0),
            Position = UDim2.new(0, 0, 0, 0)
        })
        bLbl.ZIndex = zBase + 4

        btn.MouseButton1Click:Connect(function()
            if bDef.Callback then executeWithFallback(bDef.Callback, bDef.Text or "PopupBtn") end
            closeModal()
        end)
    end

    if cfg.Closable ~= false then
        backdrop.MouseButton1Click:Connect(function()
            closeModal()
        end)
    end

    local autoCloseTime = cfg.AutoClose
    if autoCloseTime and tonumber(autoCloseTime) then
        task.delay(tonumber(autoCloseTime), closeModal)
    end

    local cardScale = Instance.new("UIScale")
    cardScale.Scale = 0.9
    cardScale.Parent = card
    Utils.Tween(backdrop, {BackgroundTransparency = 0.5}, 0.3, LouisHub.Motion.EaseEnter)
    Utils.Tween(cardScale, {Scale = 1}, 0.35, LouisHub.Motion.EasePop)

    return {
        Close = closeModal,
        Update = function(selfParam, newText)
            local targetText = (selfParam == selfParam and newText ~= nil) and newText or selfParam
            if contentContainer and contentContainer:FindFirstChildOfClass("TextLabel") then
                contentContainer:FindFirstChildOfClass("TextLabel").Text = tostring(targetText)
            end
        end,
        Container = contentContainer or card,
        Backdrop = backdrop,
    }
end

-- ══════════════════════════════════════════════════════════════
--  SECTION 17: HUD OVERLAY & FLOATING BUTTON ENGINE
-- ══════════════════════════════════════════════════════════════
local activeHUDs = {}

function LouisHub:HUD(cfg)
    cfg = cfg or {}
    local name = cfg.Name or "HUD"
    if activeHUDs[name] then return activeHUDs[name] end

    local parent = getGuiParent()
    local sg = (parent and parent:FindFirstChild("LouisHub_ScreenGui")) or (parent and parent:FindFirstChild("LouisHub_NotifGui"))
    if not sg then
        sg = Instance.new("ScreenGui")
        sg.Name = "LouisHub_ScreenGui"
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = true
        sg.Parent = parent
        protectGui(sg)
        LouisHub:RegisterInstance(sg)
    end

    local hudFolder = sg:FindFirstChild("LouisHub_HudOverlay") or Instance.new("Folder")
    hudFolder.Name = "LouisHub_HudOverlay"
    hudFolder.Parent = sg

    local anchorPoints = {
        TopLeft     = Vector2.new(0, 0),
        TopRight    = Vector2.new(1, 0),
        BottomLeft  = Vector2.new(0, 1),
        BottomRight = Vector2.new(1, 1),
        Top         = Vector2.new(0.5, 0)
    }

    local positions = {
        TopLeft     = UDim2.new(0, 15, 0, 15),
        TopRight    = UDim2.new(1, -15, 0, 15),
        BottomLeft  = UDim2.new(0, 15, 1, -15),
        BottomRight = UDim2.new(1, -15, 1, -15),
        Top         = UDim2.new(0.5, 0, 0, 15)
    }

    local posKey = type(cfg.Position) == "string" and cfg.Position or "TopLeft"
    local posInit = (typeof(cfg.Position) == "UDim2" and cfg.Position) or positions[posKey] or positions.TopLeft
    local anchorFinal = anchorPoints[posKey] or Vector2.new(0, 0)

    local hudFrame = Utils.Frame({
        Parent = hudFolder,
        Size = UDim2.new(0, 200, 0, 30),
        Position = posInit,
        Anchor = anchorFinal,
        Color = Theme.Panel,
        Transparency = 0.35,
        Radius = 8,
        Border = true,
        BorderColor = Theme.Border,
        BorderThemeKey = "Border"
    })
    hudFrame.Name = "HUD_" .. name
    hudFrame.AutomaticSize = Enum.AutomaticSize.XY
    hudFrame.Active = true

    local blurData = BlurModule(hudFrame)

    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Horizontal
    listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    listLayout.Padding = UDim.new(0, 8)
    listLayout.Parent = hudFrame

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft   = UDim.new(0, 8)
    pad.PaddingRight  = UDim.new(0, 8)
    pad.PaddingTop    = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 4)
    pad.Parent = hudFrame

    if cfg.Draggable ~= false then
        Utils.Draggable(hudFrame, hudFrame, LouisHub.EventManager)
    end

    local items = {}

    for _, eDef in ipairs(cfg.Elements or {}) do
        local itemFrame = Instance.new("Frame")
        itemFrame.BackgroundTransparency = 1
        itemFrame.Size = UDim2.new(0, 0, 1, 0)
        itemFrame.AutomaticSize = Enum.AutomaticSize.X
        itemFrame.Parent = hudFrame

        local iLayout = Instance.new("UIListLayout")
        iLayout.FillDirection = Enum.FillDirection.Horizontal
        iLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        iLayout.Padding = UDim.new(0, 4)
        iLayout.Parent = itemFrame

        local icoParam = eDef.Icon
        if icoParam then
            local ico = Instance.new("ImageLabel")
            ico.BackgroundTransparency = 1
            ico.Size = UDim2.new(0, 14, 0, 14)
            local icAsset = GetIcon(icoParam, "Material")
            if type(icAsset) == "table" then
                ico.Image = "rbxassetid://" .. tostring(icAsset.id)
                ico.ImageRectSize = icAsset.imageRectSize
                ico.ImageRectOffset = icAsset.imageRectOffset
                ico.Parent = itemFrame
            elseif type(icAsset) == "string" then
                ico.Image = icAsset
                ico.Parent = itemFrame
            end
        end

        local valParam = eDef.Value or "--"
        local sufParam = eDef.Suffix or ""
        local preParam = eDef.Label and (eDef.Label .. ": ") or ""

        local valLbl = Utils.Text({
            Parent = itemFrame,
            Text = tostring(preParam) .. tostring(valParam) .. tostring(sufParam),
            TextSize = 10,
            Color = Theme.Text,
            Size = UDim2.new(0, 0, 1, 0)
        })
        valLbl.AutomaticSize = Enum.AutomaticSize.X

        local barFill = nil
        local typeParam = eDef.Type
        if typeParam == "bar" then
            local maxVal = tonumber(eDef.Max) or 100
            if maxVal <= 0 then maxVal = 100 end
            local curVal = tonumber(valParam) or 0

            local bBg = Utils.Frame({
                Parent = itemFrame,
                Size = UDim2.new(0, 40, 0, 6),
                Color = Theme.Input,
                Radius = 3,
                Border = false
            })
            barFill = Utils.Frame({
                Parent = bBg,
                Size = UDim2.new(math.clamp(curVal / maxVal, 0, 1), 0, 1, 0),
                Color = Theme.Accent,
                Radius = 3,
                Border = false
            })
            Utils.AccentGradient(barFill)
        end

        items[eDef.Flag] = { Label = valLbl, Bar = barFill, Def = eDef }
    end

    local HUDObj = {}

    function HUDObj:Set(flag, val)
        local it = items[flag]
        if not it then return end
        local suf = it.Def.Suffix or ""
        local pre = it.Def.Label and (it.Def.Label .. ": ") or ""
        it.Label.Text = pre .. tostring(val) .. suf
        if it.Bar and it.Def.Max then
            local maxVal = tonumber(it.Def.Max) or 100
            if maxVal <= 0 then maxVal = 100 end
            local num = tonumber(val) or 0
            Utils.Tween(it.Bar, {Size = UDim2.new(math.clamp(num / maxVal, 0, 1), 0, 1, 0)}, 0.2)
        end
    end

    function HUDObj:Bind(flag, fn, interval)
        interval = interval or 0.5
        LouisHub:RegisterThread(task.spawn(function()
            while hudFrame and hudFrame.Parent do
                if hudFrame.Visible then
                    local ok, res = pcall(fn)
                    if ok and res ~= nil then self:Set(flag, res) end
                end
                task.wait(interval)
            end
        end))
    end

    function HUDObj:Show() hudFrame.Visible = true end
    function HUDObj:Hide() hudFrame.Visible = false end
    function HUDObj:Toggle() hudFrame.Visible = not hudFrame.Visible end

    function HUDObj:Destroy()
        activeHUDs[name] = nil
        pcall(function() hudFrame:Destroy() end)
    end

    if cfg.Update then pcall(cfg.Update, HUDObj) end

    activeHUDs[name] = HUDObj
    return HUDObj
end

local floatingButtonSlots = {}

function LouisHub:FloatingButton(cfg)
    cfg = cfg or {}
    local name = cfg.Name or ("FloatBtn_" .. math.random(1e5, 1e6))
    local parent = getGuiParent()
    local sg = (parent and parent:FindFirstChild("LouisHub_ScreenGui")) or (parent and parent:FindFirstChild("LouisHub_NotifGui"))
    if not sg then
        sg = Instance.new("ScreenGui")
        sg.Name = "LouisHub_ScreenGui"
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = true
        sg.Parent = parent
        protectGui(sg)
        LouisHub:RegisterInstance(sg)
    end

    local extFolder = sg:FindFirstChild("LouisHub_ExternalOverlay") or Instance.new("Folder")
    extFolder.Name = "LouisHub_ExternalOverlay"
    extFolder.Parent = sg

    local posSlot = type(cfg.Position) == "string" and cfg.Position or "RightCenter"
    floatingButtonSlots[posSlot] = (floatingButtonSlots[posSlot] or 0) + 1
    local slotIndex = floatingButtonSlots[posSlot]

    local positions = {
        RightCenter = UDim2.new(1, -55, 0.5, -25 + (slotIndex - 1) * 54),
        LeftCenter  = UDim2.new(0, 15, 0.5, -25 + (slotIndex - 1) * 54),
        BottomRight = UDim2.new(1, -55, 1, -65 - (slotIndex - 1) * 54)
    }

    local posFinal = (typeof(cfg.Position) == "UDim2" and cfg.Position) or positions[posSlot] or positions.RightCenter

    local btn = Utils.BaseButton({
        Parent = extFolder,
        Size = UDim2.new(0, 46, 0, 46),
        Position = posFinal,
        Color = Theme.Panel,
        Transparency = 0.35,
        Radius = 23,
    })
    btn.Name = name
    btn.Active = true
    btn.ZIndex = 50000

    local blurData = BlurModule(btn)
    local stroke = Utils.Stroke(btn, Theme.Border, 1.5, 0.3)
    LouisHub:Register(stroke, "Color", "Border")

    local icon = Instance.new("ImageLabel")
    icon.BackgroundTransparency = 1
    icon.Size = UDim2.new(0, 22, 0, 22)
    icon.Position = UDim2.new(0.5, -11, 0.5, -11)
    icon.ZIndex = 50002
    local icAsset = GetIcon(cfg.Icon or "crosshair", "Material")
    if type(icAsset) == "table" then
        icon.Image = "rbxassetid://" .. tostring(icAsset.id)
        icon.ImageRectSize = icAsset.imageRectSize
        icon.ImageRectOffset = icAsset.imageRectOffset
    elseif type(icAsset) == "string" then
        icon.Image = icAsset
    end
    icon.Parent = btn

    Utils.Draggable(btn, btn, LouisHub.EventManager)

    local state = false
    local inCooldown = false
    local mode = cfg.Mode or "Toggle"

    local pulseTween = nil
    local function setVisualState(on)
        if on then
            Utils.Tween(btn, {BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.15}, 0.25)
            Utils.Tween(stroke, {Color = Theme.Highlight, Transparency = 0}, 0.25)
            pulseTween = TweenService:Create(stroke, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Transparency = 0.7})
            pulseTween:Play()
        else
            if pulseTween then pulseTween:Cancel(); pulseTween = nil end
            Utils.Tween(btn, {BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.35}, 0.25)
            Utils.Tween(stroke, {Color = Theme.Border, Transparency = 0.4}, 0.25)
        end
    end

    local function trigger(forceState)
        if mode == "Toggle" then
            if forceState ~= nil then
                state = (forceState == true)
            else
                state = not state
            end
            setVisualState(state)
            if cfg.Callback then executeWithFallback(cfg.Callback, name, state) end
            if state and cfg.CallbackOn then executeWithFallback(cfg.CallbackOn, name) end
            if not state and cfg.CallbackOff then executeWithFallback(cfg.CallbackOff, name) end
        elseif mode == "Once" and not inCooldown then
            inCooldown = true
            state = true
            setVisualState(true)
            if cfg.Callback then executeWithFallback(cfg.Callback, name, true) end
            if cfg.CallbackOn then executeWithFallback(cfg.CallbackOn, name) end

            local dur = cfg.Duration or 2
            local cd  = cfg.Cooldown or 3

            local pRing = Instance.new("Frame")
            pRing.Size = UDim2.new(1, 0, 0, 3)
            pRing.Position = UDim2.new(0, 0, 1, -3)
            pRing.BackgroundColor3 = Theme.Highlight
            pRing.BorderSizePixel = 0
            pRing.ZIndex = 50003
            pRing.Parent = btn

            Utils.Tween(pRing, {Size = UDim2.new(0, 0, 0, 3)}, dur, Enum.EasingStyle.Linear)

            task.delay(dur, function()
                pcall(function() pRing:Destroy() end)
                state = false
                setVisualState(false)
                if cfg.Callback then executeWithFallback(cfg.Callback, name, false) end
                if cfg.CallbackOff then executeWithFallback(cfg.CallbackOff, name) end

                local cdLbl = Utils.Text({
                    Parent = btn,
                    Text = tostring(cd),
                    Size = UDim2.new(1, 0, 1, 0),
                    Position = UDim2.new(0, 0, 0, 0),
                    Alignment = Enum.TextXAlignment.Center,
                    TextSize = 14,
                    Font = Enum.Font.GothamBold,
                    Color = Color3.fromRGB(255, 100, 100)
                })
                cdLbl.ZIndex = 50004
                icon.ImageTransparency = 0.8

                for s = cd, 1, -1 do
                    cdLbl.Text = tostring(s)
                    task.wait(1)
                end
                pcall(function() cdLbl:Destroy() end)
                icon.ImageTransparency = 0
                inCooldown = false
            end)
        end
    end

    Utils.ReliableClick(btn, function() trigger() end)

    local keyParam = cfg.Key
    if keyParam then
        LouisHub:RegisterConnection(UserInputService.InputBegan:Connect(function(inp, gpe)
            if gpe then return end
            if inp.KeyCode == keyParam then trigger() end
        end))
    end

    local ExtObj = {
        Activate = function() trigger(true) end,
        Deactivate = function() trigger(false) end,
        Toggle   = function() trigger() end,
        GetState = function() return state end,
        SetPosition = function(selfParam, p)
            local pos = (selfParam == selfParam and p ~= nil) and p or selfParam
            if typeof(pos) == "UDim2" then btn.Position = pos end
        end,
        Destroy = function()
            if pulseTween then pulseTween:Cancel() end
            pcall(function() btn:Destroy() end)
        end,
    }
    return ExtObj
end

function LouisHub:CreateWindowSafely(config)
    config = config or {}
    local active = _G.LouisHub_Instance
    local currentWin = active and active.Window

    if not (currentWin and currentWin._main and currentWin._main.Parent) then
        return LouisHub:CreateWindow(config)
    end

    local currentTitle = active.Title or "Current Interface"
    local newTitle     = config.Title or config.Name or "New Script"

    LouisHub:Confirm({
        Title   = "⚠️ Active Script Detected",
        Content = string.format("Another window is currently active (\"%s\"). Would you like to terminate and replace it with \"%s\"?", currentTitle, newTitle),
        Icon    = "warning",
        Buttons = {
            { Text = "Cancel", Variant = "neutral" },
            {
                Text = "Replace",
                Variant = "primary",
                Callback = function()
                    if currentWin.Destroy then
                        pcall(function() currentWin:Destroy() end)
                    else
                        LouisHub:Destroy()
                    end
                    task.defer(function()
                        LouisHub:CreateWindow(config)
                    end)
                end
            },
        }
    })

    return currentWin
end

function LouisHub:Destroy()
    local inst = _G.LouisHub_Instance
    if inst and inst.Window and inst.Window._main and inst.Window._main.Parent then
        pcall(function() inst.Window._main.Parent:Destroy() end)
    end
    cleanupPreviousInstance()
end

--[[
╔══════════════════════════════════════════════════════════════════════╗
                              LouisHub
                Master UI Suite: LouisHub Engine V4.0
         PART 3A: CONTROLS 1–6 (BUTTON, TOGGLE, CHECKBOX,
               SLIDER, RANGE SLIDER, NUMBER STEPPER)
╚══════════════════════════════════════════════════════════════════════╝
]]

-- ══════════════════════════════════════════════════════════════
--  SECTION 18: SLIDER BAR UTILITIES & EXPANDABLE FRAME LOGIC
-- ══════════════════════════════════════════════════════════════
local function createDraggableBar(cfg)
    local minVal = cfg.Min or 0
    local maxVal = cfg.Max or 100
    local rangeDiff = math.max(maxVal - minVal, 0.0001)

    local background = Utils.Frame({
        Parent = cfg.Parent, Size = cfg.Size, Position = cfg.Position,
        Color = Theme.Input, Radius = 4, Transparency = 0.4,
    })
    LouisHub:Register(background, "BackgroundColor3", "Input")

    local dragRing = Utils.Stroke(background, Theme.AccentLight, 1.5, 1)
    LouisHub:Register(dragRing, "Color", "AccentLight")

    local function markDrag(active)
        Utils.Tween(dragRing, {Transparency = active and 0 or 1}, LouisHub.Motion.Hover)
    end

    local curVal = cfg.Value or minVal
    local fill = Utils.Frame({
        Parent = background,
        Size = UDim2.new(math.clamp((curVal - minVal) / rangeDiff, 0, 1), 0, 1, 0),
        Color = Theme.Accent, Radius = 4, Transparency = 0,
        Border = false,
    })
    LouisHub:Register(fill, "BackgroundColor3", "Accent")
    Utils.AccentGradient(fill, 0)

    local stepVal = cfg.Step or cfg.Increment
    if cfg.Steps and stepVal and stepVal > 0 then
        local totalSteps = math.floor(rangeDiff / stepVal + 0.5)
        if totalSteps >= 2 and totalSteps <= 40 then
            for i = 1, totalSteps - 1 do
                local rel = i / totalSteps
                local tickMark = Utils.Frame({
                    Parent = background, Size = UDim2.new(0, 1.5, 1, 0),
                    Position = UDim2.new(rel, -1, 0, 0),
                    Color = Theme.Border, Transparency = 0.4, Radius = false, Border = false,
                })
                tickMark.ZIndex = 2
                LouisHub:Register(tickMark, "BackgroundColor3", "Border")
            end
        end
    end

    local function setVisual(val)
        local rel = math.clamp((val - minVal) / rangeDiff, 0, 1)
        local duration = EventManager:IsDragging() and LouisHub.Motion.Instant or LouisHub.Motion.Page
        Utils.Tween(fill, {Size = UDim2.new(rel, 0, 1, 0)}, duration, LouisHub.Motion.EaseEnter)
    end

    local function calculateAndApply(input)
        local totalWidth = math.max(background.AbsoluteSize.X, 1)
        local rel = math.clamp((input.Position.X - background.AbsolutePosition.X) / totalWidth, 0, 1)
        local v = minVal + rel * rangeDiff
        Utils.Tween(fill, {Size = UDim2.new(rel, 0, 1, 0)}, LouisHub.Motion.Instant)
        if cfg.OnChange then cfg.OnChange(v) end
    end

    local inputTarget = background
    local hitboxH = cfg.HitboxHeight
    if hitboxH and hitboxH > 0 then
        local offsetY = cfg.HitboxOffsetY or 0
        local hitbox = Utils.Frame({
            Parent = cfg.Parent,
            Size = UDim2.new(cfg.Size.X.Scale, cfg.Size.X.Offset, 0, hitboxH),
            Position = UDim2.new(
                cfg.Size.X.Scale, cfg.Position and cfg.Position.X.Offset or 0,
                cfg.Size.Y.Scale, (cfg.Position and cfg.Position.Y.Offset or 0) - (hitboxH - cfg.Size.Y.Offset) / 2 + offsetY
            ),
            Transparency = 1, Radius = false, Border = false,
        })
        hitbox.ZIndex = background.ZIndex + 1
        inputTarget = hitbox
    end

    inputTarget.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if EventManager:IsDragging() then return end

            calculateAndApply(input)

            local GESTURE_THRESHOLD = 10
            local startPos = Vector2.new(input.Position.X, input.Position.Y)
            local isDecided = false
            local isDragging = false

            local ancestorScroll = background:FindFirstAncestorWhichIsA("ScrollingFrame")
            local scrollWasEnabled = ancestorScroll and ancestorScroll.ScrollingEnabled

            local function candidate(movedInput)
                if not isDecided then
                    local curPos = Vector2.new(movedInput.Position.X, movedInput.Position.Y)
                    local delta = curPos - startPos
                    if delta.Magnitude < GESTURE_THRESHOLD then return end
                    isDecided = true
                    if math.abs(delta.X) > math.abs(delta.Y) then
                        isDragging = true
                        if ancestorScroll then ancestorScroll.ScrollingEnabled = false end
                        markDrag(true)
                    else
                        EventManager:StopDrag()
                        return
                    end
                end
                if isDragging then
                    calculateAndApply(movedInput)
                end
            end

            EventManager:StartDrag(candidate, function()
                if isDragging then markDrag(false) end
                if ancestorScroll then ancestorScroll.ScrollingEnabled = scrollWasEnabled end
            end)
        end
    end)

    return background, fill, setVisual, (inputTarget ~= background) and inputTarget or nil
end

local function createDraggableRangeBar(cfg)
    local minVal = cfg.Min or 0
    local maxVal = cfg.Max or 100
    local rangeDiff = math.max(maxVal - minVal, 0.0001)

    local background = Utils.Frame({
        Parent = cfg.Parent, Size = cfg.Size, Position = cfg.Position,
        Color = Theme.Input, Radius = 4, Transparency = 0.4,
    })
    LouisHub:Register(background, "BackgroundColor3", "Input")

    local function relX(v)
        return math.clamp((v - minVal) / rangeDiff, 0, 1)
    end

    local curMin = cfg.MinValue or minVal
    local curMax = cfg.MaxValue or maxVal

    local fill = Utils.Frame({
        Parent = background,
        Position = UDim2.new(relX(curMin), 0, 0, 0),
        Size = UDim2.new(relX(curMax) - relX(curMin), 0, 1, 0),
        Color = Theme.Accent, Radius = 4, Transparency = 0,
        Border = false,
    })
    LouisHub:Register(fill, "BackgroundColor3", "Accent")
    Utils.AccentGradient(fill, 0)

    local HANDLE_DIAMETER = cfg.HandleDiameter or 14
    local function createHandle()
        local h = Utils.Frame({
            Parent = background,
            Size = UDim2.new(0, HANDLE_DIAMETER, 0, HANDLE_DIAMETER),
            Anchor = Vector2.new(0.5, 0.5),
            Color = Theme.Highlight, Radius = 999, Transparency = 0,
        })
        h.ZIndex = 3
        LouisHub:Register(h, "BackgroundColor3", "Highlight")
        local ring = Utils.Stroke(h, Theme.AccentLight, 1.5, 1)
        LouisHub:Register(ring, "Color", "AccentLight")
        return h, ring
    end
    local handleMin, ringMin = createHandle()
    local handleMax, ringMax = createHandle()

    local function positionHandle(handle, v)
        handle.Position = UDim2.new(relX(v), 0, 0.5, 0)
    end
    positionHandle(handleMin, curMin)
    positionHandle(handleMax, curMax)

    local function markHandleDrag(ring, active)
        Utils.Tween(ring, {Transparency = active and 0 or 1}, LouisHub.Motion.Hover)
    end

    local function setVisual(vMin, vMax)
        positionHandle(handleMin, vMin)
        positionHandle(handleMax, vMax)
        fill.Position = UDim2.new(relX(vMin), 0, 0, 0)
        fill.Size = UDim2.new(relX(vMax) - relX(vMin), 0, 1, 0)
    end

    local function calculateValue(input)
        local totalWidth = math.max(background.AbsoluteSize.X, 1)
        local rel = math.clamp((input.Position.X - background.AbsolutePosition.X) / totalWidth, 0, 1)
        return minVal + rel * rangeDiff
    end

    background.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if EventManager:IsDragging() then return end

            local GESTURE_THRESHOLD = 10
            local startPos = Vector2.new(input.Position.X, input.Position.Y)
            local isDecided = false
            local isDragging = false
            local isMovingMin = nil

            local getMinFn = cfg.GetMin
            local getMaxFn = cfg.GetMax
            local changeFn = cfg.OnChange

            local scrollAncestor = background:FindFirstAncestorWhichIsA("ScrollingFrame")
            local scrollWasEnabled = scrollAncestor and scrollAncestor.ScrollingEnabled

            local function pickHandle(initInput)
                local touchVal = calculateValue(initInput)
                local vMin, vMax = getMinFn(), getMaxFn()
                local distMin, distMax = math.abs(touchVal - vMin), math.abs(touchVal - vMax)
                if distMin < distMax then
                    isMovingMin = true
                elseif distMax < distMin then
                    isMovingMin = false
                else
                    isMovingMin = touchVal <= vMin
                end
            end

            pickHandle(input)
            local vInitial = calculateValue(input)
            local currentMin, currentMax = getMinFn(), getMaxFn()
            if isMovingMin then
                vInitial = math.min(vInitial, currentMax)
                positionHandle(handleMin, vInitial)
                if changeFn then changeFn(vInitial, currentMax) end
            else
                vInitial = math.max(vInitial, currentMin)
                positionHandle(handleMax, vInitial)
                if changeFn then changeFn(currentMin, vInitial) end
            end
            local rMin, rMax = getMinFn(), getMaxFn()
            fill.Position = UDim2.new(relX(rMin), 0, 0, 0)
            fill.Size = UDim2.new(relX(rMax) - relX(rMin), 0, 1, 0)

            local function candidate(movedInput)
                if not isDecided then
                    local curPos = Vector2.new(movedInput.Position.X, movedInput.Position.Y)
                    local delta = curPos - startPos
                    if delta.Magnitude < GESTURE_THRESHOLD then return end
                    isDecided = true
                    if math.abs(delta.X) > math.abs(delta.Y) then
                        isDragging = true
                        if scrollAncestor then scrollAncestor.ScrollingEnabled = false end
                        markHandleDrag(isMovingMin and ringMin or ringMax, true)
                    else
                        EventManager:StopDrag()
                        return
                    end
                end
                if not isDragging then return end

                local v = calculateValue(movedInput)
                local vMin, vMax = getMinFn(), getMaxFn()
                if isMovingMin then
                    v = math.min(v, vMax)
                    positionHandle(handleMin, v)
                    if changeFn then changeFn(v, vMax) end
                else
                    v = math.max(v, vMin)
                    positionHandle(handleMax, v)
                    if changeFn then changeFn(vMin, v) end
                end
                local vMinReal, vMaxReal = getMinFn(), getMaxFn()
                fill.Position = UDim2.new(relX(vMinReal), 0, 0, 0)
                fill.Size = UDim2.new(relX(vMaxReal) - relX(vMinReal), 0, 1, 0)
            end

            EventManager:StartDrag(candidate, function()
                if isDragging then
                    markHandleDrag(isMovingMin and ringMin or ringMax, false)
                end
                if scrollAncestor then scrollAncestor.ScrollingEnabled = scrollWasEnabled end
            end)
        end
    end)

    return background, setVisual
end

local function makeExpandable(frame, closedHeight, getOpenHeight, onCloseCallback)
    local isOpen = false
    local closeConnections = {}

    local function isOutside(input)
        local pos = frame.AbsolutePosition
        local sz = frame.AbsoluteSize
        local x, y = input.Position.X, input.Position.Y
        return x < pos.X or x > pos.X + sz.X or y < pos.Y or y > pos.Y + sz.Y
    end

    local function cleanCloseConnections()
        for _, conn in ipairs(closeConnections) do
            LouisHub:DisconnectAndClean(conn)
        end
        closeConnections = {}
    end

    local function toggle()
        isOpen = not isOpen
        local h = isOpen and getOpenHeight() or closedHeight
        Utils.Tween(frame, {Size = UDim2.new(1, 0, 0, h)}, LouisHub.Motion.Expand)

        cleanCloseConnections()

        if isOpen then
            local MOVE_THRESHOLD = LouisHub.Capabilities.IsTouch and 18 or 10
            local startData = nil
            table.insert(closeConnections, LouisHub:RegisterConnection(
                UserInputService.InputBegan:Connect(function(input)
                    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and
                       input.UserInputType ~= Enum.UserInputType.Touch then return end
                    if frame.Parent and isOutside(input) then
                        startData = {
                            inputType = input.UserInputType,
                            pos = Vector2.new(input.Position.X, input.Position.Y),
                        }
                    else
                        startData = nil
                    end
                end)
            ))
            table.insert(closeConnections, LouisHub:RegisterConnection(
                UserInputService.InputEnded:Connect(function(input)
                    if not startData or input.UserInputType ~= startData.inputType then return end
                    local moved = (Vector2.new(input.Position.X, input.Position.Y) - startData.pos).Magnitude > MOVE_THRESHOLD
                    startData = nil
                    if moved then return end
                    if frame.Parent and isOpen then
                        toggle()
                        if onCloseCallback then pcall(onCloseCallback) end
                    end
                end)
            ))
        else
            if onCloseCallback then pcall(onCloseCallback) end
        end

        return isOpen
    end
    return toggle
end

-- ══════════════════════════════════════════════════════════════
--  SECTION 19: CONTROL INJECTION (CONTROLS 1 TO 6)
-- ══════════════════════════════════════════════════════════════
local function applyBaseControlMethods(Section)
    local order = 0
    local function nextOrder() order = order + 1; return order end

    local function createHeader(height, text, labelWidth, offsetX, mode, targetContainer)
        local row = Utils.Row(targetContainer, height, nextOrder(), Theme.Row)
        LouisHub:Register(row, "BackgroundColor3", "Row")
        Utils.Hover(row, row)
        if mode ~= "fixed" then
            local lblD = Utils.Text({
                Parent = row, Text = text,
                Size = UDim2.new(labelWidth or 1, offsetX or -46, 1, 0),
                TextSize = 11, Wrapped = true,
            })
            if mode ~= "manual" then Utils.MakeDynamicRow(row, lblD, height, 5) end
            return row, lblD
        end
        local lbl = Utils.Text({
            Parent = row, Text = text,
            Size = UDim2.new(labelWidth or 1, offsetX or -46, 1, 0),
            TextSize = 11, Truncate = true,
        })
        return row, lbl
    end

    local function createBooleanControl(typeName, cfg, createVisual)
        cfg = cfg or {}
        validateCallback(typeName, cfg)
        local flag  = cfg.Flag or cfg.Text or cfg.Name or (typeName .. "_" .. tostring(math.random(1e5, 1e6)))
        local value = false
        if cfg.CurrentValue ~= nil then
            value = cfg.CurrentValue
        elseif cfg.Default ~= nil then
            value = cfg.Default
        end
        LouisHub.Flags[flag] = value

        local targetCont = Section:_GetTargetContainer(typeName, cfg)
        local row, lbl = createHeader(26, cfg.Text or cfg.Name or typeName, 1, -48, nil, targetCont)

        local icoParam = cfg.Icon
        if icoParam then
            local icData = GetIcon(icoParam, "Material")
            if icData then
                local icImg = Instance.new("ImageLabel")
                icImg.BackgroundTransparency = 1
                icImg.Size = UDim2.new(0, 14, 0, 14)
                icImg.Position = UDim2.new(0, 6, 0.5, -7)
                if type(icData) == "table" then
                    icImg.Image = "rbxassetid://" .. tostring(icData.id)
                    icImg.ImageRectSize = icData.imageRectSize
                    icImg.ImageRectOffset = icData.imageRectOffset
                else
                    icImg.Image = icData
                end
                icImg.Parent = row
                lbl.Position = UDim2.new(0, 24, 0, 0)
                lbl.Size = UDim2.new(lbl.Size.X.Scale, lbl.Size.X.Offset - 18, 1, 0)
            end
        end

        addTextTooltip(row, cfg.Text or cfg.Name or typeName, cfg.Tooltip or cfg.Description, lbl)
        registerSearchable(row, cfg.Text or cfg.Name or typeName, cfg.VisibleIf)

        local visual = createVisual(row, function() return value end)

        local function updateVal(v, fire)
            if type(v) ~= "boolean" then return end
            value = v
            LouisHub.Flags[flag] = v
            visual.updateVisual(v)

            local disableList = cfg.Disable
            if v == true and disableList then
                for _, otherFlag in ipairs(disableList) do
                    local ctrl = LouisHub.Elements[otherFlag]
                    if ctrl and ctrl:Get() == true then ctrl:Set(false, true) end
                end
            end

            if fire and cfg.Callback then
                executeWithFallback(cfg.Callback, cfg.Text or cfg.Name or "control", v)
            end
        end

        local hitbox = Utils.ExpandedHitbox(visual.clickable, 8)
        Utils.ReliableClick(hitbox, function() updateVal(not value, true) end, visual.clickable)

        local keyParam = cfg.Key
        if keyParam then
            LouisHub:RegisterConnection(UserInputService.InputBegan:Connect(function(input, processed)
                if processed then return end
                if input.KeyCode == keyParam then updateVal(not value, true) end
            end))
        end

        local elemObj = {
            Set = function(selfParam, v, fireCallback)
                local val = (selfParam == selfParam and fireCallback ~= nil) and v or (type(selfParam) == "boolean" and selfParam or v)
                local fire = (type(fireCallback) == "boolean") and fireCallback or false
                updateVal(val, fire)
            end,
            Get = function() return value end,
            Destroy = function()
                pcall(function() row:Destroy() end)
                LouisHub.Elements[flag] = nil
                LouisHub.Options[flag]  = nil
            end,
            CurrentValue = value,
        }

        elemObj.SetValue = elemObj.Set
        elemObj.SetState = elemObj.Set

        LouisHub.Elements[flag] = elemObj
        LouisHub.Options[flag]  = elemObj

        if cfg.FireOnCreate and cfg.Callback then
            executeWithFallback(cfg.Callback, cfg.Text or cfg.Name or "control", value)
        end
        return elemObj
    end

    -- 1. BUTTON
    function Section:Button(cfg)
        cfg = cfg or {}
        validateCallback("Button", cfg)
        local targetCont = self:_GetTargetContainer("Button", cfg)
        local row = Utils.BaseButton({
            Parent = targetCont, Size = UDim2.new(1, 0, 0, 26),
            Color = Theme.Row, Transparency = 0.5,
            Order = nextOrder(), Radius = 6,
        })
        LouisHub:Register(row, "BackgroundColor3", "Row")
        Utils.Hover(row, row)

        local textWithIcon = cfg.Text or cfg.Name or "Button"
        local icoParam = cfg.Icon
        local icAsset = icoParam and GetIcon(icoParam, "Material")
        if not icAsset and icoParam and type(icoParam) == "string" then
            textWithIcon = icoParam .. " " .. textWithIcon
        end

        if icAsset then
            local icImg = Instance.new("ImageLabel")
            icImg.BackgroundTransparency = 1
            icImg.Size = UDim2.new(0, 14, 0, 14)
            icImg.Position = UDim2.new(0, 6, 0.5, -7)
            if type(icAsset) == "table" then
                icImg.Image = "rbxassetid://" .. tostring(icAsset.id)
                icImg.ImageRectSize = icAsset.imageRectSize
                icImg.ImageRectOffset = icAsset.imageRectOffset
            else
                icImg.Image = icAsset
            end
            icImg.Parent = row
        end

        local lblButton = Utils.Text({
            Parent = row, Text = textWithIcon, RichText = cfg.RichText,
            Size = UDim2.new(1, icAsset and -24 or -10, 1, 0),
            Position = UDim2.new(0, icAsset and 22 or 6, 0, 0),
            TextSize = 11,
        })

        addTextTooltip(row, cfg.Text or cfg.Name or "Button", cfg.Tooltip or cfg.Description, lblButton)
        registerSearchable(row, cfg.Text or cfg.Name or "Button", cfg.VisibleIf)

        local spinner, spinThread
        local function activateSpinner(active)
            if active and not spinner then
                spinner = Utils.Text({
                    Parent = row, Text = "◐",
                    Size = UDim2.new(0, 16, 1, 0), Position = UDim2.new(1, -22, 0, 0),
                    Alignment = Enum.TextXAlignment.Center, TextSize = 12, Color = Theme.AccentLight,
                })
                LouisHub:Register(spinner, "TextColor3", "AccentLight")
            end
            if not spinner then return end
            spinner.Visible = active
            if active then
                spinThread = LouisHub:RegisterThread(task.spawn(function()
                    while spinner and spinner.Visible do
                        Utils.Tween(spinner, {Rotation = spinner.Rotation + 360}, LouisHub.Motion.Spin, LouisHub.Motion.EaseLinear)
                        task.wait(LouisHub.Motion.Spin)
                    end
                end))
            end
        end

        local flashId = 0
        local inProgress = false
        Utils.ReliableClick(row, function()
            if cfg.Async and inProgress then return end
            flashId = flashId + 1
            local curId = flashId
            Utils.Tween(row, {BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.2}, LouisHub.Motion.FlashIn)
            task.delay(0.12, function()
                if curId == flashId and row and row.Parent then
                    Utils.Tween(row, {BackgroundColor3 = Theme.Row, BackgroundTransparency = 0.5}, LouisHub.Motion.Expand)
                end
            end)
            if cfg.Callback then
                if cfg.Async then
                    inProgress = true
                    activateSpinner(true)
                    task.spawn(function()
                        executeWithFallback(cfg.Callback, cfg.Text or cfg.Name or "control")
                        inProgress = false
                        if row and row.Parent then activateSpinner(false) end
                    end)
                else
                    executeWithFallback(cfg.Callback, cfg.Text or cfg.Name or "control")
                end
            end
        end)

        local btnObj = Utils.WrapInstance(row)
        btnObj.Destroy = function()
            pcall(function() row:Destroy() end)
        end
        return btnObj
    end

    -- 2. TOGGLE
    function Section:Toggle(cfg)
        return createBooleanControl("Toggle", cfg, function(row, getVal)
            local knob = Utils.BaseButton({
                Parent = row, Size = UDim2.new(0, 36, 0, 18),
                Position = UDim2.new(1, -42, 0.5, -9),
                Color = getVal() and Theme.Accent or Theme.Muted,
                Transparency = 0.2, Radius = 9,
            })
            LouisHub:Register(knob, "BackgroundColor3", function()
                return getVal() and Theme.Accent or Theme.Muted
            end)

            local pGrad = Utils.AccentGradient(knob)
            pGrad.Enabled = getVal()

            local circle = Utils.Frame({
                Parent = knob, Size = UDim2.new(0, 14, 0, 14),
                Position = getVal() and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
                Color = Theme.Text, Radius = 7, Border = false, Transparency = 0,
            })
            LouisHub:Register(circle, "BackgroundColor3", "Text")

            return {
                clickable = knob,
                updateVisual = function(v)
                    pGrad.Enabled = v
                    Utils.Tween(knob, {BackgroundColor3 = v and Theme.Accent or Theme.Muted}, LouisHub.Motion.Expand)
                    Utils.Tween(circle, {
                        Position = v and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
                    }, LouisHub.Motion.Page, LouisHub.Motion.EasePop)
                end,
            }
        end)
    end

    -- 3. CHECKBOX
    function Section:Checkbox(cfg)
        return createBooleanControl("Checkbox", cfg, function(row, getVal)
            local box = Utils.BaseButton({
                Parent = row, Size = UDim2.new(0, 18, 0, 18),
                Position = UDim2.new(1, -26, 0.5, -9),
                Color = getVal() and Theme.Accent or Theme.Input,
                Transparency = 0.3, Radius = 4,
            })
            LouisHub:Register(box, "BackgroundColor3", function()
                return getVal() and Theme.Accent or Theme.Input
            end)
            local strokeBox = Utils.Stroke(box, Theme.Border, 1, 0.3)
            LouisHub:Register(strokeBox, "Color", "Border")

            local check = Utils.Frame({
                Parent = box, Size = UDim2.new(1, 0, 1, 0), Color = Theme.Text, Transparency = 1, Border = false,
            })
            local strokeShort = Utils.Frame({
                Parent = check, Size = UDim2.new(0, 5, 0, 2),
                Position = UDim2.new(0.5, -5, 0.5, 1), Color = Theme.Text,
                Transparency = getVal() and 0 or 1, Radius = 1, Border = false,
            })
            strokeShort.Rotation = 45
            local strokeLong = Utils.Frame({
                Parent = check, Size = UDim2.new(0, 10, 0, 2),
                Position = UDim2.new(0.5, -2, 0.5, -3), Color = Theme.Text,
                Transparency = getVal() and 0 or 1, Radius = 1, Border = false,
            })
            strokeLong.Rotation = -45
            LouisHub:Register(strokeShort, "BackgroundColor3", "Text")
            LouisHub:Register(strokeLong, "BackgroundColor3", "Text")

            return {
                clickable = box,
                updateVisual = function(v)
                    Utils.Tween(box, {BackgroundColor3 = v and Theme.Accent or Theme.Input}, LouisHub.Motion.Hover)
                    Utils.Tween(strokeShort, {BackgroundTransparency = v and 0 or 1}, LouisHub.Motion.Hover)
                    Utils.Tween(strokeLong, {BackgroundTransparency = v and 0 or 1}, LouisHub.Motion.Hover)
                end,
            }
        end)
    end

    -- 4. SLIDER
    function Section:Slider(cfg)
        cfg = cfg or {}
        validateCallback("Slider", cfg)
        local flag      = cfg.Flag or cfg.Text or cfg.Name or ("Slider_" .. tostring(math.random(1e5, 1e6)))
        local range     = cfg.Range or {cfg.Min or 0, cfg.Max or 100}
        local minVal    = range[1]
        local maxVal    = range[2]
        if minVal >= maxVal then maxVal = minVal + 1 end
        local stepVal   = cfg.Increment or cfg.Step or 1
        if stepVal <= 0 then stepVal = 1 end
        local suffix    = cfg.Suffix or ""
        local defaultV  = cfg.CurrentValue or cfg.Default or minVal
        local value     = math.clamp(defaultV, minVal, maxVal)
        LouisHub.Flags[flag] = value

        local targetCont = self:_GetTargetContainer("Slider", cfg)
        local row = Utils.Row(targetCont, 42, nextOrder(), Theme.Row)
        LouisHub:Register(row, "BackgroundColor3", "Row")
        Utils.Hover(row, row)
        registerSearchable(row, cfg.Text or cfg.Name or "Slider", cfg.VisibleIf)

        local lblSlider = Utils.Text({
            Parent = row, Text = cfg.Text or cfg.Name or "Slider",
            Size = UDim2.new(1, -90, 0, 16), Position = UDim2.new(0, 6, 0, 5),
            Truncate = true, TextSize = 11,
        })
        addTextTooltip(row, cfg.Text or cfg.Name or "Slider", cfg.Tooltip or cfg.Description, lblSlider, -90)

        local inputValBox = Instance.new("TextBox")
        inputValBox.Size             = UDim2.new(0, 80, 0, 18)
        inputValBox.Position         = UDim2.new(1, -86, 0, 4)
        inputValBox.BackgroundColor3 = Theme.Input
        inputValBox.BackgroundTransparency = 0.4
        inputValBox.Text             = tostring(value) .. suffix
        inputValBox.TextColor3       = Theme.Highlight
        inputValBox.Font             = Enum.Font.GothamBold
        inputValBox.TextSize         = 11
        inputValBox.TextXAlignment   = Enum.TextXAlignment.Right
        inputValBox.BorderSizePixel  = 0
        inputValBox.ClearTextOnFocus = false
        inputValBox.Parent           = row
        Utils.Corner(inputValBox, 4)
        LouisHub:Register(inputValBox, "BackgroundColor3", "Input")
        LouisHub:Register(inputValBox, "TextColor3", "Highlight")

        local function roundVal(v)
            local factor = 1 / stepVal
            return math.clamp(
                math.floor((v - minVal) * factor + 0.5) / factor + minVal,
                minVal, maxVal
            )
        end

        local function stripSuffix(txt)
            if suffix ~= "" and txt:sub(-#suffix) == suffix then
                return txt:sub(1, -#suffix - 1)
            end
            return txt
        end

        local decimals = 0
        local dec = tostring(stepVal):match("%.(%d+)$")
        if dec then decimals = #dec end
        local function formatNumber(n)
            if decimals > 0 then return string.format("%." .. decimals .. "f", n) end
            return tostring(math.floor(n + 0.5))
        end

        local lastProcessed = value
        local function animateDisplay(v, instant)
            if instant then
                inputValBox.Text = formatNumber(v) .. suffix
            else
                Utils.TweenNumber(lastProcessed, v, LouisHub.Motion.Page, function(n)
                    if inputValBox and inputValBox.Parent then
                        inputValBox.Text = formatNumber(roundVal(n)) .. suffix
                    end
                end)
            end
        end

        local function processNewVal(rawV)
            local v = roundVal(rawV)
            if v == lastProcessed then return end
            lastProcessed = v
            value = v
            LouisHub.Flags[flag] = v
            animateDisplay(v, true)
            if cfg.Callback then
                executeWithFallback(cfg.Callback, cfg.Text or cfg.Name or "control", v)
            end
        end

        local barBg, fill, setVisual = createDraggableBar({
            Parent = row,
            Size = UDim2.new(1, -12, 0, 7),
            Position = UDim2.new(0, 6, 0, 27),
            Min = minVal, Max = maxVal, Value = value,
            Increment = stepVal, Steps = cfg.Steps,
            HitboxHeight = 16, HitboxOffsetY = 0,
            OnChange = processNewVal,
        })

        inputValBox.FocusLost:Connect(function(enterPressed)
            if not enterPressed then return end
            local txt = stripSuffix(inputValBox.Text):gsub("%s+", "")
            local num = tonumber(txt)
            if num then
                num = roundVal(num)
                lastProcessed = num
                value = num
                LouisHub.Flags[flag] = num
                animateDisplay(num, true)
                setVisual(num)
                Utils.FlashFeedback(inputValBox, true, Theme.Input)
                if cfg.Callback then
                    executeWithFallback(cfg.Callback, cfg.Text or cfg.Name or "Slider", num)
                end
            else
                animateDisplay(value, true)
                Utils.FlashFeedback(inputValBox, false, Theme.Input)
            end
        end)

        local elemObj = {
            Set = function(selfParam, v, fireCallback)
                local val = (selfParam == selfParam and fireCallback ~= nil) and v or (type(selfParam) == "number" and selfParam or v)
                if typeof(val) ~= "number" then return end
                val = roundVal(val)
                lastProcessed = val
                value = val
                LouisHub.Flags[flag] = val
                animateDisplay(val, false)
                setVisual(val)
                local fire = (type(fireCallback) == "boolean") and fireCallback or false
                if fire and cfg.Callback then
                    executeWithFallback(cfg.Callback, cfg.Text or cfg.Name or "control", val)
                end
            end,
            Get = function() return value end,
            Destroy = function()
                pcall(function() row:Destroy() end)
                LouisHub.Elements[flag] = nil
                LouisHub.Options[flag]  = nil
            end,
            CurrentValue = value,
        }
        elemObj.SetValue = elemObj.Set

        LouisHub.Elements[flag] = elemObj
        LouisHub.Options[flag]  = elemObj

        return elemObj
    end

    -- 5. RANGE SLIDER
    function Section:RangeSlider(cfg)
        cfg = cfg or {}
        validateCallback("RangeSlider", cfg)
        local flag      = cfg.Flag or cfg.Text or ("RangeSlider_" .. tostring(math.random(1e5, 1e6)))
        local range     = cfg.Range or {cfg.Min or 0, cfg.Max or 100}
        local minVal    = range[1]
        local maxVal    = range[2]
        if minVal >= maxVal then maxVal = minVal + 1 end
        local stepVal   = cfg.Increment or 1
        local suffix    = cfg.Suffix or ""
        local defaultT  = cfg.Default or {min = minVal, max = maxVal}
        local valMin    = math.clamp(defaultT.min or minVal, minVal, maxVal)
        local valMax    = math.clamp(defaultT.max or maxVal, minVal, maxVal)
        if valMin > valMax then valMin, valMax = valMax, valMin end

        local function currentRange() return {min = valMin, max = valMax} end
        LouisHub.Flags[flag] = currentRange()

        local targetCont = self:_GetTargetContainer("RangeSlider", cfg)
        local row = Utils.Row(targetCont, 42, nextOrder(), Theme.Row)
        LouisHub:Register(row, "BackgroundColor3", "Row")
        Utils.Hover(row, row)
        registerSearchable(row, cfg.Text or "RangeSlider", cfg.VisibleIf)

        local lblSlider = Utils.Text({
            Parent = row, Text = cfg.Text or "RangeSlider",
            Size = UDim2.new(1, -130, 0, 16), Position = UDim2.new(0, 6, 0, 5),
            Truncate = true, TextSize = 11,
        })
        addTextTooltip(row, cfg.Text or "RangeSlider", cfg.Tooltip, lblSlider, -130)

        local lblValues = Utils.Text({
            Parent = row, Size = UDim2.new(0, 120, 0, 16),
            Position = UDim2.new(1, -126, 0, 5), Alignment = Enum.TextXAlignment.Right,
            Font = Enum.Font.GothamBold, TextSize = 11, Color = Theme.Highlight,
        })
        LouisHub:Register(lblValues, "TextColor3", "Highlight")

        local function roundVal(v)
            local factor = 1 / stepVal
            return math.clamp(
                math.floor((v - minVal) * factor + 0.5) / factor + minVal,
                minVal, maxVal
            )
        end

        local function updateDisplay()
            lblValues.Text = tostring(valMin) .. suffix .. " – " .. tostring(valMax) .. suffix
        end
        updateDisplay()

        local lastMin, lastMax = valMin, valMax
        local function processNewRange(rawMin, rawMax)
            local vMin = roundVal(rawMin)
            local vMax = roundVal(rawMax)
            if vMin > vMax then vMin, vMax = vMax, vMin end
            if vMin == lastMin and vMax == lastMax then return end
            lastMin, lastMax = vMin, vMax
            valMin, valMax = vMin, vMax
            LouisHub.Flags[flag] = currentRange()
            updateDisplay()
            if cfg.Callback then
                executeWithFallback(cfg.Callback, cfg.Text or "control", currentRange())
            end
        end

        local _, setVisual = createDraggableRangeBar({
            Parent = row, Size = UDim2.new(1, -12, 0, 7),
            Position = UDim2.new(0, 6, 0, 27),
            Min = minVal, Max = maxVal, MinValue = valMin, MaxValue = valMax,
            GetMin = function() return lastMin end,
            GetMax = function() return lastMax end,
            OnChange = processNewRange,
        })

        local elemObj = {
            Set = function(selfParam, v, fireCallback)
                local val = (selfParam == selfParam and fireCallback ~= nil) and v or (type(selfParam) == "table" and selfParam or v)
                if type(val) ~= "table" or val.min == nil or val.max == nil then return end
                local vMin = roundVal(math.clamp(val.min, minVal, maxVal))
                local vMax = roundVal(math.clamp(val.max, minVal, maxVal))
                if vMin > vMax then vMin, vMax = vMax, vMin end
                lastMin, lastMax = vMin, vMax
                valMin, valMax = vMin, vMax
                LouisHub.Flags[flag] = currentRange()
                updateDisplay()
                setVisual(vMin, vMax)
                local fire = (type(fireCallback) == "boolean") and fireCallback or false
                if fire and cfg.Callback then
                    executeWithFallback(cfg.Callback, cfg.Text or "control", currentRange())
                end
            end,
            Get = function() return currentRange() end,
            Destroy = function()
                pcall(function() row:Destroy() end)
                LouisHub.Elements[flag] = nil
                LouisHub.Options[flag]  = nil
            end,
        }
        LouisHub.Elements[flag] = elemObj
        LouisHub.Options[flag]  = elemObj

        return elemObj
    end

    -- 6. NUMBER STEPPER
    function Section:NumberStepper(cfg)
        cfg = cfg or {}
        validateCallback("NumberStepper", cfg)
        local flag     = cfg.Flag or cfg.Text or ("NumberStepper_" .. tostring(math.random(1e5, 1e6)))
        local minVal   = cfg.Min or 0
        local maxVal   = cfg.Max or 100
        if minVal >= maxVal then maxVal = minVal + 1 end
        local stepVal  = cfg.Increment or 1
        local decimals = cfg.Decimals or (tostring(stepVal):find("%.") and (#tostring(stepVal) - tostring(stepVal):find("%.")) or 0)
        local prefix   = cfg.Prefix or ""
        local suffix   = cfg.Suffix or ""

        local function roundVal(v)
            local factor = 1 / stepVal
            return math.clamp(
                math.floor((v - minVal) * factor + 0.5) / factor + minVal,
                minVal, maxVal
            )
        end

        local value = roundVal(math.clamp(cfg.Default or minVal, minVal, maxVal))
        LouisHub.Flags[flag] = value

        local function formatText(v)
            local txt = (decimals > 0) and string.format("%." .. decimals .. "f", v) or tostring(math.floor(v + 0.5))
            return prefix .. txt .. suffix
        end

        local function stripAffixes(txt)
            if prefix ~= "" and txt:sub(1, #prefix) == prefix then txt = txt:sub(#prefix + 1) end
            if suffix ~= "" and txt:sub(-#suffix) == suffix then txt = txt:sub(1, -#suffix - 1) end
            return txt
        end

        local targetCont = self:_GetTargetContainer("NumberStepper", cfg)
        local row, lbl = createHeader(26, cfg.Text or "NumberStepper", 1, -120, nil, targetCont)
        addTextTooltip(row, cfg.Text or "NumberStepper", cfg.Tooltip, lbl)
        registerSearchable(row, cfg.Text or "NumberStepper", cfg.VisibleIf)

        local BTN_WIDTH = 20
        local BOX_WIDTH = 54
        local GAP = 3
        local CTRL_HEIGHT = 18

        local btnMinus = Utils.BaseButton({
            Parent = row, Color = Theme.Input, Transparency = 0.4, Radius = 4,
            Size = UDim2.new(0, BTN_WIDTH, 0, CTRL_HEIGHT),
            Position = UDim2.new(1, -(BTN_WIDTH * 2 + BOX_WIDTH + GAP * 2 + 6), 0.5, -CTRL_HEIGHT/2),
        })
        LouisHub:Register(btnMinus, "BackgroundColor3", "Input")
        Utils.Text({
            Parent = btnMinus, Text = "−", Size = UDim2.new(1, 0, 1, 0),
            Alignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold, TextSize = 12,
        })

        local textBox = Instance.new("TextBox")
        textBox.Size = UDim2.new(0, BOX_WIDTH, 0, CTRL_HEIGHT)
        textBox.Position = UDim2.new(1, -(BTN_WIDTH + BOX_WIDTH + GAP + 6), 0.5, -CTRL_HEIGHT/2)
        textBox.BackgroundColor3 = Theme.Input
        textBox.BackgroundTransparency = 0.4
        textBox.Text = formatText(value)
        textBox.TextColor3 = Theme.Highlight
        textBox.Font = Enum.Font.GothamBold
        textBox.TextSize = 10.5
        textBox.TextXAlignment = Enum.TextXAlignment.Center
        textBox.ClearTextOnFocus = false
        textBox.BorderSizePixel = 0
        textBox.Parent = row
        Utils.Corner(textBox, 4)
        LouisHub:Register(textBox, "BackgroundColor3", "Input")
        LouisHub:Register(textBox, "TextColor3", "Highlight")

        local btnPlus = Utils.BaseButton({
            Parent = row, Color = Theme.Input, Transparency = 0.4, Radius = 4,
            Size = UDim2.new(0, BTN_WIDTH, 0, CTRL_HEIGHT),
            Position = UDim2.new(1, -(BTN_WIDTH + 6), 0.5, -CTRL_HEIGHT/2),
        })
        LouisHub:Register(btnPlus, "BackgroundColor3", "Input")
        Utils.Text({
            Parent = btnPlus, Text = "+", Size = UDim2.new(1, 0, 1, 0),
            Alignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold, TextSize = 12,
        })

        local function applyStep(sign)
            local newV = roundVal(value + sign * stepVal)
            if newV == value then return end
            value = newV
            LouisHub.Flags[flag] = value
            textBox.Text = formatText(value)
            if cfg.Callback then executeWithFallback(cfg.Callback, cfg.Text or "control", value) end
        end

        local pressId = 0
        local function startHold(sign, refBtn)
            pressId = pressId + 1
            local myId = pressId
            applyStep(sign)
            task.spawn(function()
                task.wait(0.4)
                while pressId == myId and refBtn.Parent do
                    applyStep(sign)
                    task.wait(0.1)
                end
            end)
        end
        local function stopHold() pressId = pressId + 1 end

        LouisHub:RegisterConnection(btnMinus.MouseButton1Down:Connect(function() startHold(-1, btnMinus) end))
        LouisHub:RegisterConnection(btnMinus.MouseButton1Up:Connect(stopHold))
        LouisHub:RegisterConnection(btnMinus.MouseLeave:Connect(stopHold))

        LouisHub:RegisterConnection(btnPlus.MouseButton1Down:Connect(function() startHold(1, btnPlus) end))
        LouisHub:RegisterConnection(btnPlus.MouseButton1Up:Connect(stopHold))
        LouisHub:RegisterConnection(btnPlus.MouseLeave:Connect(stopHold))

        textBox.FocusLost:Connect(function(enterPressed)
            if not enterPressed then return end
            local txt = stripAffixes(textBox.Text)
            local num = tonumber(txt)
            if not num then
                textBox.Text = formatText(value)
                Utils.FlashFeedback(textBox, false, Theme.Input)
                return
            end
            local newV = roundVal(num)
            value = newV
            LouisHub.Flags[flag] = value
            textBox.Text = formatText(value)
            Utils.FlashFeedback(textBox, true, Theme.Input)
            if cfg.Callback then executeWithFallback(cfg.Callback, cfg.Text or "control", value) end
        end)

        local elemObj = {
            Set = function(selfParam, v, fireCallback)
                local val = (selfParam == selfParam and fireCallback ~= nil) and v or (type(selfParam) == "number" and selfParam or v)
                if type(val) ~= "number" then return end
                value = roundVal(val)
                LouisHub.Flags[flag] = value
                textBox.Text = formatText(value)
                local fire = (type(fireCallback) == "boolean") and fireCallback or false
                if fire and cfg.Callback then
                    executeWithFallback(cfg.Callback, cfg.Text or "control", value)
                end
            end,
            Get = function() return value end,
            Destroy = function()
                pcall(function() row:Destroy() end)
                LouisHub.Elements[flag] = nil
                LouisHub.Options[flag]  = nil
            end,
        }
        LouisHub.Elements[flag] = elemObj
        LouisHub.Options[flag]  = elemObj

        return elemObj
    end

    for _, n in ipairs({"Button", "Toggle", "Checkbox", "Slider", "RangeSlider", "NumberStepper"}) do
        Utils.WrapLockableControl(Section, Section.container, n)
    end
end

LouisHub._BaseControlMethods = applyBaseControlMethods

--[[
╔══════════════════════════════════════════════════════════════════════╗
                              LouisHub
                Master UI Suite: LouisHub Engine V4.0
         PART 3B: CONTROLS 7–12 (INPUT, TAG INPUT, RADIO GROUP,
               DROPDOWN, COLOR PICKER, KEYBIND)
╚══════════════════════════════════════════════════════════════════════╝
]]

-- ══════════════════════════════════════════════════════════════
--  SECTION 20: CONTROL INJECTION (CONTROLS 7 TO 12)
-- ══════════════════════════════════════════════════════════════
local function applyAdvancedControlMethods(Section)
    local order = 100
    local function nextOrder() order = order + 1; return order end

    local function createHeader(height, text, labelWidth, offsetX, mode, targetContainer)
        local row = Utils.Row(targetContainer, height, nextOrder(), Theme.Row)
        LouisHub:Register(row, "BackgroundColor3", "Row")
        Utils.Hover(row, row)
        if mode ~= "fixed" then
            local lblD = Utils.Text({
                Parent = row, Text = text,
                Size = UDim2.new(labelWidth or 1, offsetX or -46, 1, 0),
                TextSize = 11, Wrapped = true,
            })
            if mode ~= "manual" then Utils.MakeDynamicRow(row, lblD, height, 5) end
            return row, lblD
        end
        local lbl = Utils.Text({
            Parent = row, Text = text,
            Size = UDim2.new(labelWidth or 1, offsetX or -46, 1, 0),
            TextSize = 11, Truncate = true,
        })
        return row, lbl
    end

    -- 7. INPUT
    function Section:Input(cfg)
        cfg = cfg or {}
        validateCallback("Input", cfg)
        local flag  = cfg.Flag or cfg.Text or cfg.Name or ("Input_" .. tostring(math.random(1e5, 1e6)))
        local value = cfg.CurrentValue or cfg.Default or ""
        LouisHub.Flags[flag] = value

        local isArea = cfg.Type == "textarea"
        local areaHeight = math.clamp(cfg.Height or 70, 45, 300)
        local targetCont = self:_GetTargetContainer("Input", cfg)

        local row, lblInput
        if isArea then
            row, lblInput = createHeader(26, cfg.Text or cfg.Name or "Input", nil, nil, "manual", targetCont)
            lblInput.AutomaticSize = Enum.AutomaticSize.Y
            lblInput.Size = UDim2.new(1, -16, 0, 0)
            lblInput.Position = UDim2.new(0, 6, 0, 6)
        else
            row, lblInput = createHeader(26, cfg.Text or cfg.Name or "Input", 0.45, nil, nil, targetCont)
        end

        addTextTooltip(row, cfg.Text or cfg.Name or "Input", cfg.Tooltip or cfg.Description, lblInput)
        registerSearchable(row, cfg.Text or cfg.Name or "Input", cfg.VisibleIf)

        local box = Instance.new("TextBox")
        box.Size             = UDim2.new(0.5, -10, 0, 20)
        box.Position         = UDim2.new(0.5, 2, 0.5, -10)
        box.BackgroundColor3 = Theme.Input
        box.BackgroundTransparency = 0.4
        box.Text             = tostring(value)
        box.PlaceholderText  = cfg.Placeholder or cfg.PlaceholderText or ""
        box.TextColor3       = Theme.Highlight
        box.Font             = Enum.Font.Gotham
        box.TextSize         = 11
        box.ClearTextOnFocus = (cfg.ClearTextOnFocus or cfg.RemoveTextAfterFocusLost) or false
        box.BorderSizePixel  = 0
        box.Parent           = row
        Utils.Corner(box, 4)
        LouisHub:Register(box, "BackgroundColor3", "Input")
        LouisHub:Register(box, "TextColor3", "Highlight")

        if isArea then
            box.Size             = UDim2.new(1, -12, 0, areaHeight)
            box.Position         = UDim2.new(0, 6, 0, 24)
            box.MultiLine        = true
            box.TextWrapped      = true
            box.TextXAlignment   = Enum.TextXAlignment.Left
            box.TextYAlignment   = Enum.TextYAlignment.Top
            local padArea = Instance.new("UIPadding")
            padArea.PaddingLeft, padArea.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
            padArea.PaddingTop, padArea.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)
            padArea.Parent = box

            row.Size = UDim2.new(1, 0, 0, areaHeight + 30)
        end

        local maxChars = cfg.MaxCharacters or (isArea and 2000 or 200)

        box:GetPropertyChangedSignal("Text"):Connect(function()
            if cfg.Numeric then
                local txt = box.Text
                local parts = string.split(txt, ".")
                if #parts > 2 then
                    box.Text = parts[1] .. "." .. table.concat(parts, "", 2)
                else
                    box.Text = txt:gsub("[^%d%.%-]", "")
                end
            end
            if #box.Text > maxChars then
                box.Text = box.Text:sub(1, maxChars)
                Utils.FlashFeedback(box, false, Theme.Input)
            end
            if not cfg.Enter and not isArea then
                value = box.Text
                LouisHub.Flags[flag] = value
                if cfg.Callback then executeWithFallback(cfg.Callback, cfg.Text or "Input", value) end
            end
        end)

        box.FocusLost:Connect(function(enterPressed)
            local cleanTxt = box.Text:gsub("^%s+", ""):gsub("%s+$", "")
            local finalVal = cleanTxt

            if cfg.Type == "number" or cfg.Numeric then
                local n = tonumber(cleanTxt)
                if not n and cleanTxt ~= "" then
                    box.Text = tostring(value)
                    Utils.FlashFeedback(box, false, Theme.Input)
                    return
                elseif n then
                    if cfg.Min and n < cfg.Min then n = cfg.Min end
                    if cfg.Max and n > cfg.Max then n = cfg.Max end
                    finalVal = n
                end
            elseif cfg.Type == "pattern" and (cfg.Regex or cfg.Pattern) then
                local pat = (cfg.Regex or cfg.Pattern):gsub("^%^", ""):gsub("%$$", "")
                if not cleanTxt:match("^" .. pat .. "$") then
                    box.Text = tostring(value)
                    Utils.FlashFeedback(box, false, Theme.Input)
                    return
                end
            end

            value = finalVal
            box.Text = tostring(finalVal)
            LouisHub.Flags[flag] = value
            if (enterPressed or isArea or cfg.Enter) and cfg.Callback then
                executeWithFallback(cfg.Callback, cfg.Text or "Input", value)
            end
        end)

        local elemObj = {
            Set = function(selfParam, v, fireCallback)
                local val = (selfParam == selfParam and fireCallback ~= nil) and v or (type(selfParam) == "string" and selfParam or (type(selfParam) == "number" and tostring(selfParam) or v))
                value = val
                box.Text = tostring(val or "")
                LouisHub.Flags[flag] = val
                local fire = (type(fireCallback) == "boolean") and fireCallback or false
                if fire and cfg.Callback then
                    executeWithFallback(cfg.Callback, cfg.Text or "Input", val)
                end
            end,
            Get = function() return value end,
            Destroy = function()
                pcall(function() row:Destroy() end)
                LouisHub.Elements[flag] = nil
                LouisHub.Options[flag]  = nil
            end,
            CurrentValue = value,
        }
        LouisHub.Elements[flag] = elemObj
        LouisHub.Options[flag]  = elemObj

        return elemObj
    end

    -- 8. TAG INPUT
    function Section:TagInput(cfg)
        cfg = cfg or {}
        validateCallback("TagInput", cfg)
        local flag     = cfg.Flag or cfg.Text or ("TagInput_" .. tostring(math.random(1e5, 1e6)))
        local maxChars = cfg.MaxCharacters or 200
        local maxTags  = cfg.MaxTags

        local tags = {}
        local tagsLower = {}
        for _, t in ipairs(cfg.Default or {}) do
            if type(t) == "string" then
                local clean = t:gsub("^%s+", ""):gsub("%s+$", "")
                if clean ~= "" and not tagsLower[clean:lower()] then
                    table.insert(tags, clean)
                    tagsLower[clean:lower()] = true
                end
            end
        end

        local function currentTags()
            local copy = {}
            for i, t in ipairs(tags) do copy[i] = t end
            return copy
        end
        LouisHub.Flags[flag] = currentTags()

        local targetCont = self:_GetTargetContainer("TagInput", cfg)
        local row = Utils.Row(targetCont, 56, nextOrder(), Theme.Row)
        LouisHub:Register(row, "BackgroundColor3", "Row")
        Utils.Hover(row, row)
        registerSearchable(row, cfg.Text or "TagInput", cfg.VisibleIf)

        local lblTitle = Utils.Text({
            Parent = row, Text = cfg.Text or "TagInput",
            Size = UDim2.new(1, -12, 0, 16), Position = UDim2.new(0, 6, 0, 4),
            Truncate = true, TextSize = 11,
        })
        addTextTooltip(row, cfg.Text or "TagInput", cfg.Tooltip, lblTitle)

        local chipsContainer = Utils.Frame({
            Parent = row, Size = UDim2.new(1, -12, 0, 0),
            Position = UDim2.new(0, 6, 0, 22), Transparency = 1,
            Radius = false, Border = false,
        })
        local layoutChips = Instance.new("UIListLayout")
        layoutChips.FillDirection = Enum.FillDirection.Horizontal
        layoutChips.Wraps = true
        layoutChips.Padding = UDim.new(0, 4)
        layoutChips.Parent = chipsContainer

        local box = Instance.new("TextBox")
        box.Size             = UDim2.new(1, -12, 0, 22)
        box.Position         = UDim2.new(0, 6, 0, 26)
        box.BackgroundColor3 = Theme.Input
        box.BackgroundTransparency = 0.4
        box.PlaceholderText  = cfg.Placeholder or "Type and press Enter..."
        box.Text             = ""
        box.TextColor3       = Theme.Highlight
        box.Font             = Enum.Font.Gotham
        box.TextSize         = 10.5
        box.ClearTextOnFocus = false
        box.BorderSizePixel  = 0
        box.Parent           = row
        Utils.Corner(box, 4)
        LouisHub:Register(box, "BackgroundColor3", "Input")
        LouisHub:Register(box, "TextColor3", "Highlight")

        local drawChips

        local function addOneTag(raw)
            local clean = raw:gsub("^%s+", ""):gsub("%s+$", "")
            if clean == "" then return false end
            if tagsLower[clean:lower()] then return false end
            if maxTags and #tags >= maxTags then
                Utils.FlashFeedback(box, false, Theme.Input)
                return false
            end
            table.insert(tags, clean)
            tagsLower[clean:lower()] = true
            return true
        end

        local function commitBox()
            local hadChange = false
            for frag in (box.Text .. ","):gmatch("([^,]*),") do
                if addOneTag(frag) then hadChange = true end
            end
            if hadChange then
                LouisHub.Flags[flag] = currentTags()
                drawChips()
                if cfg.Callback then executeWithFallback(cfg.Callback, cfg.Text or "control", currentTags()) end
            end
            box.Text = ""
        end

        box.FocusLost:Connect(commitBox)

        local function reLayoutChips()
            if not (row and row.Parent) then return end
            local e = Utils.UIScaleFactor(row)
            local chipsH = (#tags > 0) and math.ceil(layoutChips.AbsoluteContentSize.Y / e) or 0
            chipsContainer.Size = UDim2.new(1, -12, 0, chipsH)
            local yBox = 22 + chipsH + (chipsH > 0 and 5 or 3)
            box.Position = UDim2.new(0, 6, 0, yBox)
            row.Size = UDim2.new(1, 0, 0, yBox + 22 + 6)
        end
        LouisHub:RegisterConnection(layoutChips:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(Utils.Defer(reLayoutChips)))

        drawChips = function()
            for _, child in ipairs(chipsContainer:GetChildren()) do
                if child:IsA("Frame") then child:Destroy() end
            end
            for i, t in ipairs(tags) do
                local tWidth = math.ceil(TextService:GetTextSize(t, 10.5, Enum.Font.GothamBold, Vector2.new(1000, 20)).X)
                local chip = Utils.Frame({
                    Parent = chipsContainer,
                    Size = UDim2.new(0, tWidth + 26, 0, 18),
                    Color = Theme.Accent, Radius = 9, Transparency = 0.2,
                })
                LouisHub:Register(chip, "BackgroundColor3", "Accent")
                Utils.AccentGradient(chip)

                Utils.Text({
                    Parent = chip, Text = t, Size = UDim2.new(0, tWidth, 1, 0),
                    Position = UDim2.new(0, 6, 0, 0), TextSize = 10, Font = Enum.Font.GothamBold,
                    Color = Color3.fromRGB(255, 255, 255),
                })
                local btnX = Instance.new("TextButton")
                btnX.BackgroundTransparency = 1
                btnX.Text = "×"
                btnX.Font = Enum.Font.GothamBold
                btnX.TextSize = 13
                btnX.TextColor3 = Color3.fromRGB(255, 255, 255)
                btnX.Size = UDim2.new(0, 14, 1, 0)
                btnX.Position = UDim2.new(1, -16, 0, 0)
                btnX.Parent = chip
                btnX.MouseButton1Click:Connect(function()
                    table.remove(tags, i)
                    tagsLower[t:lower()] = nil
                    LouisHub.Flags[flag] = currentTags()
                    drawChips()
                    if cfg.Callback then executeWithFallback(cfg.Callback, cfg.Text or "control", currentTags()) end
                end)
            end
            task.defer(reLayoutChips)
        end
        drawChips()

        local elemObj = {
            Set = function(selfParam, v, fireCallback)
                local val = (selfParam == selfParam and fireCallback ~= nil) and v or (type(selfParam) == "table" and selfParam or v)
                if type(val) ~= "table" then return end
                tags = {}
                tagsLower = {}
                for _, t in ipairs(val) do
                    if type(t) == "string" and not tagsLower[t:lower()] then
                        table.insert(tags, t)
                        tagsLower[t:lower()] = true
                    end
                end
                LouisHub.Flags[flag] = currentTags()
                drawChips()
                local fire = (type(fireCallback) == "boolean") and fireCallback or false
                if fire and cfg.Callback then
                    executeWithFallback(cfg.Callback, cfg.Text or "control", currentTags())
                end
            end,
            Get = function() return currentTags() end,
            Destroy = function()
                pcall(function() row:Destroy() end)
                LouisHub.Elements[flag] = nil
                LouisHub.Options[flag]  = nil
            end,
        }
        LouisHub.Elements[flag] = elemObj
        LouisHub.Options[flag]  = elemObj

        return elemObj
    end

    -- 9. RADIO GROUP
    function Section:RadioGroup(cfg)
        cfg = cfg or {}
        validateCallback("RadioGroup", cfg)
        local flag     = cfg.Flag or cfg.Text or ("RadioGroup_" .. tostring(math.random(1e5, 1e6)))
        local options  = cfg.Options or {}
        local value    = cfg.Default or options[1]
        LouisHub.Flags[flag] = value

        local targetCont = self:_GetTargetContainer("RadioGroup", cfg)
        local row, lbl = createHeader(50, cfg.Text or "RadioGroup", nil, nil, "manual", targetCont)
        lbl.AutomaticSize = Enum.AutomaticSize.Y
        lbl.Size = UDim2.new(1, -16, 0, 0)
        lbl.Position = UDim2.new(0, 6, 0, 6)
        addTextTooltip(row, cfg.Text or "RadioGroup", cfg.Tooltip, lbl)
        registerSearchable(row, cfg.Text or "RadioGroup", cfg.VisibleIf)

        local btnRow = Utils.Frame({
            Parent = row, Size = UDim2.new(1, -12, 0, 22),
            Position = UDim2.new(0, 6, 0, 24), Transparency = 1,
            Radius = false, Border = false,
        })
        local layoutButtons = Instance.new("UIListLayout")
        layoutButtons.FillDirection = Enum.FillDirection.Horizontal
        layoutButtons.Padding       = UDim.new(0, 4)
        layoutButtons.Parent        = btnRow

        local opButtons = {}
        local function refreshVisual()
            for opt, btn in pairs(opButtons) do
                local isActive = (opt == value)
                Utils.Tween(btn, {
                    BackgroundColor3 = isActive and Theme.Accent or Theme.Input,
                    BackgroundTransparency = isActive and 0.2 or 0.5,
                }, LouisHub.Motion.Hover)
                local lblBtn = btn:FindFirstChildOfClass("TextLabel")
                if lblBtn then lblBtn.TextColor3 = isActive and Theme.Text or Theme.TextDark end
            end
        end

        local function pickOption(opt)
            if opt == value then return end
            value = opt
            LouisHub.Flags[flag] = value
            refreshVisual()
            if cfg.Callback then executeWithFallback(cfg.Callback, cfg.Text or "RadioGroup", value) end
        end

        for i, opt in ipairs(options) do
            local isActive = (opt == value)
            local btn = Utils.BaseButton({
                Parent = btnRow,
                Size = UDim2.new(1 / math.max(#options, 1), -math.floor(4 * (#options - 1) / #options), 1, 0),
                Color = isActive and Theme.Accent or Theme.Input,
                Transparency = isActive and 0.2 or 0.5, Radius = 5, Order = i,
            })
            LouisHub:Register(btn, "BackgroundColor3", function()
                return (opt == value) and Theme.Accent or Theme.Input
            end)
            Utils.Text({
                Parent = btn, Text = tostring(opt), Size = UDim2.new(1, 0, 1, 0),
                Alignment = Enum.TextXAlignment.Center, TextSize = 10.5, Truncate = true,
                Color = isActive and Theme.Text or Theme.TextDark,
            })
            Utils.ReliableClick(btn, function() pickOption(opt) end)
            opButtons[opt] = btn
        end

        local elemObj = {
            Set = function(selfParam, v, fireCallback)
                local val = (selfParam == selfParam and fireCallback ~= nil) and v or (selfParam ~= nil and selfParam or v)
                value = val
                LouisHub.Flags[flag] = val
                refreshVisual()
                local fire = (type(fireCallback) == "boolean") and fireCallback or false
                if fire and cfg.Callback then
                    executeWithFallback(cfg.Callback, cfg.Text or "RadioGroup", val)
                end
            end,
            Get = function() return value end,
            Destroy = function()
                pcall(function() row:Destroy() end)
                LouisHub.Elements[flag] = nil
                LouisHub.Options[flag]  = nil
            end,
        }
        LouisHub.Elements[flag] = elemObj
        LouisHub.Options[flag]  = elemObj

        return elemObj
    end

    -- 10. DROPDOWN
    function Section:Dropdown(cfg)
        cfg = cfg or {}
        validateCallback("Dropdown", cfg)
        local flag     = cfg.Flag or cfg.Text or cfg.Name or ("Dropdown_" .. tostring(math.random(1e5, 1e6)))
        local options  = cloneTable(cfg.Options or {})
        local multi    = (cfg.MultipleOptions ~= nil and cfg.MultipleOptions) or (cfg.Multi ~= nil and cfg.Multi) or false
        local selection = {}

        if multi then
            local def = cfg.CurrentOption or cfg.Default or {}
            if type(def) == "table" then
                if #def > 0 then
                    for _, v in ipairs(def) do selection[v] = true end
                else
                    for k, v in pairs(def) do if v then selection[k] = true end end
                end
            elseif type(def) == "string" then
                selection[def] = true
            end
        else
            local def = cfg.CurrentOption or cfg.Default
            if type(def) == "table" then def = def[1] end
            if def then selection[def] = true end
        end

        LouisHub.Flags[flag] = multi and cloneTable(selection) or (cfg.CurrentOption or cfg.Default)

        local SEARCH_THRESHOLD = 8
        local hasSearch       = #options > SEARCH_THRESHOLD
        local ROW_HEIGHT      = 26
        local SEARCH_HEIGHT   = hasSearch and 22 or 0
        local MAX_LIST_HEIGHT = 132

        local targetCont = self:_GetTargetContainer("Dropdown", cfg)
        local frame = Utils.Frame({
            Parent = targetCont, Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
            Color = Theme.Row, Order = nextOrder(), Clips = true,
            Transparency = 0.5,
        })
        LouisHub:Register(frame, "BackgroundColor3", "Row")
        registerSearchable(frame, cfg.Text or cfg.Name or "Dropdown", cfg.VisibleIf)

        local headerBtn = Utils.BaseButton({Parent = frame, Size = UDim2.new(1, 0, 0, ROW_HEIGHT)})
        Utils.Hover(headerBtn, frame)

        local lbl = Utils.Text({
            Parent = frame, Size = UDim2.new(1, -26, 0, ROW_HEIGHT),
            Truncate = true, TextSize = 11,
        })
        local arrow = Instance.new("ImageLabel")
        arrow.BackgroundTransparency = 1
        arrow.Image = "rbxassetid://83472139709682"
        arrow.Size = UDim2.new(0, 9, 0, 9)
        arrow.AnchorPoint = Vector2.new(0.5, 0.5)
        arrow.Position = UDim2.new(1, -12, 0.5, 0)
        arrow.Parent = frame
        LouisHub:Register(arrow, "ImageColor3", "Text")

        addTextTooltip(frame, cfg.Text or cfg.Name or "Dropdown", cfg.Tooltip or cfg.Description, lbl)

        local searchBox = nil
        if hasSearch then
            searchBox = Instance.new("TextBox")
            searchBox.Size             = UDim2.new(1, -8, 0, SEARCH_HEIGHT - 2)
            searchBox.Position         = UDim2.new(0, 4, 0, ROW_HEIGHT + 2)
            searchBox.BackgroundColor3 = Theme.Input
            searchBox.BackgroundTransparency = 0.4
            searchBox.PlaceholderText  = "🔍 Search option..."
            searchBox.Text             = ""
            searchBox.TextColor3       = Theme.Text
            searchBox.Font             = Enum.Font.Gotham
            searchBox.TextSize         = 10
            searchBox.BorderSizePixel  = 0
            searchBox.ClearTextOnFocus = false
            searchBox.Parent           = frame
            Utils.Corner(searchBox, 4)
            LouisHub:Register(searchBox, "BackgroundColor3", "Input")
            LouisHub:Register(searchBox, "TextColor3", "Text")
        end

        local optionsScroll = Instance.new("ScrollingFrame")
        optionsScroll.Name                   = "DropdownScroll"
        optionsScroll.BackgroundTransparency = 1
        optionsScroll.BorderSizePixel        = 0
        optionsScroll.ScrollBarThickness     = 2
        optionsScroll.ScrollBarImageColor3   = Theme.Accent
        optionsScroll.CanvasSize             = UDim2.new(0, 0, 0, #options * 22)
        optionsScroll.AutomaticCanvasSize    = Enum.AutomaticSize.None
        optionsScroll.Size                   = UDim2.new(1, 0, 0, math.min(#options * 22, MAX_LIST_HEIGHT))
        optionsScroll.Position               = UDim2.new(0, 0, 0, ROW_HEIGHT + SEARCH_HEIGHT + 2)
        optionsScroll.Parent                 = frame

        local layoutOp = Instance.new("UIListLayout")
        layoutOp.Padding = UDim.new(0, 2)
        layoutOp.SortOrder = Enum.SortOrder.LayoutOrder
        layoutOp.Parent = optionsScroll

        local function getDisplayText()
            if multi then
                local names = {}
                for _, o in ipairs(options) do
                    if selection[o] then table.insert(names, tostring(o)) end
                end
                return #names > 0 and table.concat(names, ", ") or "None"
            end
            for k, v in pairs(selection) do if v then return tostring(k) end end
            return "None"
        end

        local function updateLabel()
            lbl.Text = (cfg.Text or cfg.Name or "Dropdown") .. ": " .. getDisplayText()
        end
        updateLabel()

        local opButtons = {}
        local toggleDropdown

        local function pickOpt(opt, keepOpen)
            if multi then
                selection[opt] = not selection[opt] or nil
            else
                selection = {[opt] = true}
            end
            local res = multi and cloneTable(selection) or opt
            LouisHub.Flags[flag] = res
            for o, btn in pairs(opButtons) do
                btn.BackgroundColor3 = selection[o] and Theme.Accent or Theme.Input
                btn.BackgroundTransparency = selection[o] and 0.2 or 0.5
            end
            updateLabel()
            if cfg.Callback then executeWithFallback(cfg.Callback, cfg.Text or cfg.Name or "Dropdown", res) end
            if not multi and not keepOpen and toggleDropdown then toggleDropdown() end
        end

        local function buildOptionButtons()
            for _, child in ipairs(optionsScroll:GetChildren()) do
                if child:IsA("GuiObject") and not child:IsA("UIListLayout") then
                    child:Destroy()
                end
            end
            opButtons = {}

            optionsScroll.CanvasSize = UDim2.new(0, 0, 0, #options * 22)
            optionsScroll.Size = UDim2.new(1, 0, 0, math.min(#options * 22, MAX_LIST_HEIGHT))

            for i, opt in ipairs(options) do
                local btn = Utils.BaseButton({
                    Parent = optionsScroll, Size = UDim2.new(1, -8, 0, 20),
                    Position = UDim2.new(0, 4, 0, 0),
                    Color = selection[opt] and Theme.Accent or Theme.Input,
                    Transparency = selection[opt] and 0.2 or 0.5,
                    Order = i, Radius = 4,
                })
                LouisHub:Register(btn, "BackgroundColor3", function()
                    return selection[opt] and Theme.Accent or Theme.Input
                end)
                Utils.Text({
                    Parent = btn, Text = tostring(opt), Size = UDim2.new(1, -8, 1, 0),
                    Position = UDim2.new(0, 6, 0, 0), TextSize = 10.5, Truncate = true,
                })
                Utils.ReliableClick(btn, function() pickOpt(opt) end)
                opButtons[opt] = btn
            end
        end

        buildOptionButtons()

        toggleDropdown = makeExpandable(frame, ROW_HEIGHT, function()
            local contentH = math.min(#options * 22, MAX_LIST_HEIGHT)
            return ROW_HEIGHT + SEARCH_HEIGHT + contentH + 6
        end, function()
            Utils.Tween(arrow, {Rotation = 0}, LouisHub.Motion.Expand)
            if searchBox then searchBox.Visible = false end
        end)

        Utils.ReliableClick(headerBtn, function()
            local openState = toggleDropdown()
            Utils.Tween(arrow, {Rotation = openState and 180 or 0}, LouisHub.Motion.Expand)
            if searchBox then searchBox.Visible = openState end
        end)

        if searchBox then
            searchBox:GetPropertyChangedSignal("Text"):Connect(function()
                local t = searchBox.Text:lower()
                for opt, btn in pairs(opButtons) do
                    btn.Visible = (t == "") or (tostring(opt):lower():find(t, 1, true) ~= nil)
                end
            end)
        end

        local function getSelectedValue()
            if multi then return cloneTable(selection) end
            for k, v in pairs(selection) do if v then return k end end
            return nil
        end

        local function updateOptionsExternal(selfParam, newOpts)
            local opts = (selfParam == selfParam and newOpts ~= nil) and newOpts or (type(selfParam) == "table" and selfParam or newOpts)
            options = cloneTable(opts or {})
            buildOptionButtons()
            updateLabel()
        end

        local elemObj = {
            Set = function(selfParam, v, fireCallback)
                local val = (selfParam == selfParam and fireCallback ~= nil) and v or (selfParam ~= nil and selfParam or v)
                if multi then
                    selection = {}
                    if type(val) == "table" then
                        if #val > 0 then
                            for _, item in ipairs(val) do selection[item] = true end
                        else
                            for item, isSel in pairs(val) do if isSel then selection[item] = true end end
                        end
                    elseif type(val) == "string" then
                        selection[val] = true
                    end
                else
                    selection = {[val] = true}
                end
                for opt, btn in pairs(opButtons) do
                    btn.BackgroundColor3 = selection[opt] and Theme.Accent or Theme.Input
                    btn.BackgroundTransparency = selection[opt] and 0.2 or 0.5
                end
                updateLabel()
                LouisHub.Flags[flag] = multi and cloneTable(selection) or val
                local fire = (type(fireCallback) == "boolean") and fireCallback or false
                if fire and cfg.Callback then
                    executeWithFallback(cfg.Callback, cfg.Text or cfg.Name or "Dropdown", LouisHub.Flags[flag])
                end
            end,
            SetOptions    = updateOptionsExternal,
            Refresh       = updateOptionsExternal,
            Get           = getSelectedValue,
            Destroy = function()
                pcall(function() frame:Destroy() end)
                LouisHub.Elements[flag] = nil
                LouisHub.Options[flag]  = nil
            end,
            CurrentOption = multi and cloneTable(selection) or (cfg.CurrentOption or cfg.Default),
        }
        elemObj.SetOption = elemObj.Set

        LouisHub.Elements[flag] = elemObj
        LouisHub.Options[flag]  = elemObj

        return elemObj
    end

    -- 11. COLOR PICKER
    function Section:ColorPicker(cfg, flagArg)
        cfg = cfg or {}
        validateCallback("ColorPicker", cfg)
        local flag         = cfg.Flag or flagArg or cfg.Text or cfg.Name or ("Color_" .. tostring(math.random(1e5, 1e6)))
        local currentColor = cfg.Color or cfg.Default or Color3.fromRGB(255, 255, 255)
        LouisHub.Flags[flag] = currentColor

        local ROW_HEIGHT = 26
        local targetCont = self:_GetTargetContainer("ColorPicker", cfg)
        local frame = Utils.Frame({
            Parent = targetCont, Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
            Color = Theme.Row, Order = nextOrder(), Clips = true,
            Transparency = 0.5,
        })
        LouisHub:Register(frame, "BackgroundColor3", "Row")

        local headerBtn = Utils.BaseButton({Parent = frame, Size = UDim2.new(1, 0, 0, ROW_HEIGHT)})
        Utils.Hover(headerBtn, frame)

        local lbl = Utils.Text({
            Parent = frame, Text = cfg.Text or cfg.Name or "Color",
            Size = UDim2.new(1, -44, 0, ROW_HEIGHT), Truncate = true, TextSize = 11,
        })
        local swatch = Utils.Frame({
            Parent = frame, Size = UDim2.new(0, 24, 0, 14),
            Position = UDim2.new(1, -30, 0.5, -7),
            Color = currentColor, Radius = 3, Transparency = 0,
        })

        addTextTooltip(frame, cfg.Text or cfg.Name or "Color", cfg.Tooltip, lbl, -44)
        registerSearchable(frame, cfg.Text or cfg.Name or "Color", cfg.VisibleIf)

        local panel = Utils.Frame({
            Parent = frame, Size = UDim2.new(1, -12, 0, 105),
            Position = UDim2.new(0, 6, 0, ROW_HEIGHT + 2), Transparency = 1,
            Radius = false, Border = false,
        })
        local layoutP = Instance.new("UIListLayout")
        layoutP.Padding = UDim.new(0, 4)
        layoutP.Parent = panel

        local r = currentColor.R * 255
        local g = currentColor.G * 255
        local b = currentColor.B * 255
        local setVisualR, setVisualG, setVisualB
        local hexBox = nil

        local elemObj = {}

        local function toHex(c)
            return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
        end

        local function triggerColorCallback(c)
            local cb = elemObj.Callback or cfg.Callback
            if cb then executeWithFallback(cb, cfg.Text or cfg.Name or "ColorPicker", c) end
        end

        local function updateColor()
            local newC = Color3.fromRGB(math.floor(r + 0.5), math.floor(g + 0.5), math.floor(b + 0.5))
            currentColor = newC
            swatch.BackgroundColor3 = newC
            if hexBox then hexBox.Text = toHex(newC) end
            LouisHub.Flags[flag] = newC
            elemObj.Color = newC
            triggerColorCallback(newC)
        end

        local function makeChannelRow(chName, orderIdx, getV, setV)
            local rowC = Utils.Frame({
                Parent = panel, Size = UDim2.new(1, 0, 0, 18),
                Order = orderIdx, Transparency = 1, Radius = false, Border = false,
            })
            Utils.Text({
                Parent = rowC, Text = chName, Size = UDim2.new(0, 14, 1, 0),
                Font = Enum.Font.GothamBold, TextSize = 9.5,
            })
            local _, _, sv = createDraggableBar({
                Parent = rowC, Size = UDim2.new(1, -16, 0, 6),
                Position = UDim2.new(0, 16, 0.5, -3),
                Min = 0, Max = 255, Value = getV(),
                OnChange = function(v) setV(v); updateColor() end,
            })
            return sv
        end

        setVisualR = makeChannelRow("R", 1, function() return r end, function(v) r = v end)
        setVisualG = makeChannelRow("G", 2, function() return g end, function(v) g = v end)
        setVisualB = makeChannelRow("B", 3, function() return b end, function(v) b = v end)

        local rowHex = Utils.Frame({
            Parent = panel, Size = UDim2.new(1, 0, 0, 18),
            Order = 4, Transparency = 1, Radius = false, Border = false,
        })
        Utils.Text({
            Parent = rowHex, Text = "Hex", Size = UDim2.new(0, 24, 1, 0),
            Font = Enum.Font.GothamBold, TextSize = 9.5,
        })
        hexBox = Instance.new("TextBox")
        hexBox.Size = UDim2.new(1, -26, 1, 0)
        hexBox.Position = UDim2.new(0, 26, 0, 0)
        hexBox.BackgroundColor3 = Theme.Input
        hexBox.BackgroundTransparency = 0.4
        hexBox.BorderSizePixel = 0
        hexBox.Font = Enum.Font.Code
        hexBox.TextSize = 10.5
        hexBox.TextColor3 = Theme.Text
        hexBox.Text = toHex(currentColor)
        hexBox.ClearTextOnFocus = false
        hexBox.Parent = rowHex
        Utils.Corner(hexBox, 3)
        LouisHub:Register(hexBox, "BackgroundColor3", "Input")
        LouisHub:Register(hexBox, "TextColor3", "Text")

        hexBox.FocusLost:Connect(function()
            local cleanHex = hexBox.Text:gsub("^#", ""):gsub("%s", "")
            if #cleanHex == 6 and not cleanHex:match("%X") then
                r = tonumber(cleanHex:sub(1,2), 16)
                g = tonumber(cleanHex:sub(3,4), 16)
                b = tonumber(cleanHex:sub(5,6), 16)
                setVisualR(r); setVisualG(g); setVisualB(b)
                updateColor()
                Utils.FlashFeedback(hexBox, true, Theme.Input)
            else
                hexBox.Text = toHex(currentColor)
                Utils.FlashFeedback(hexBox, false, Theme.Input)
            end
        end)

        local togglePicker = makeExpandable(frame, ROW_HEIGHT, function() return ROW_HEIGHT + 112 end)
        Utils.ReliableClick(headerBtn, function() togglePicker() end)

        elemObj.Set = function(selfParam, v, fireCallback)
            local val = (selfParam == selfParam and fireCallback ~= nil) and v or (typeof(selfParam) == "Color3" and selfParam or v)
            if typeof(val) ~= "Color3" then return end
            currentColor = val
            r = val.R * 255; g = val.G * 255; b = val.B * 255
            swatch.BackgroundColor3 = val
            if hexBox then hexBox.Text = toHex(val) end
            LouisHub.Flags[flag] = val
            elemObj.Color = val
            setVisualR(r); setVisualG(g); setVisualB(b)
            local fire = (type(fireCallback) == "boolean") and fireCallback or false
            if fire then
                triggerColorCallback(val)
            end
        end

        elemObj.Get = function() return currentColor end
        elemObj.Destroy = function()
            pcall(function() frame:Destroy() end)
            LouisHub.Elements[flag] = nil
            LouisHub.Options[flag]  = nil
        end
        elemObj.Color = currentColor
        elemObj.Callback = cfg.Callback

        LouisHub.Elements[flag] = elemObj
        LouisHub.Options[flag]  = elemObj

        return elemObj
    end

    -- 12. KEYBIND
    function Section:Keybind(cfg)
        cfg = cfg or {}
        validateCallback("Keybind", cfg)
        local flag     = cfg.Flag or cfg.Text or cfg.Name or ("Keybind_" .. tostring(math.random(1e5, 1e6)))
        local withMods = cfg.WithModifiers or false
        local defaultK = cfg.CurrentBind or cfg.Default or (withMods and {KeyCode = Enum.KeyCode.Unknown} or Enum.KeyCode.Unknown)
        if withMods and typeof(defaultK) ~= "table" then
            defaultK = {KeyCode = defaultK, Ctrl = false, Shift = false, Alt = false}
        end
        local value = defaultK
        local isWaiting = false
        local connCapture = nil
        local _assignedThisFrame = false
        local waitToken = 0
        LouisHub.Flags[flag] = value

        local conflictEntry = { flag = flag, text = cfg.Text or cfg.Name or "Keybind" }
        conflictEntry.GetValue = function() return value end
        table.insert(_registeredKeybinds, conflictEntry)

        local function formatKeyText(v)
            if not withMods then
                return (v == Enum.KeyCode.Unknown) and "None" or v.Name
            end
            if typeof(v) ~= "table" then v = {KeyCode = v, Ctrl = false, Shift = false, Alt = false} end
            if not v or v.KeyCode == Enum.KeyCode.Unknown then return "None" end
            local parts = {}
            if v.Ctrl then table.insert(parts, "Ctrl") end
            if v.Shift then table.insert(parts, "Shift") end
            if v.Alt then table.insert(parts, "Alt") end
            table.insert(parts, v.KeyCode.Name)
            return table.concat(parts, "+")
        end

        local targetCont = self:_GetTargetContainer("Keybind", cfg)
        local row, lbl = createHeader(26, cfg.Text or cfg.Name or "Keybind", 1, -64, nil, targetCont)
        addTextTooltip(row, cfg.Text or cfg.Name or "Keybind", cfg.Tooltip or cfg.Description, lbl)
        registerSearchable(row, cfg.Text or cfg.Name or "Keybind", cfg.VisibleIf)

        local btnKey = Utils.BaseButton({
            Parent = row, Size = UDim2.new(0, 54, 0, 18),
            Position = UDim2.new(1, -58, 0.5, -9),
            Color = Theme.Input, Transparency = 0.4, Radius = 4,
        })
        LouisHub:Register(btnKey, "BackgroundColor3", "Input")
        Utils.Hover(btnKey, btnKey)

        local lblKey = Utils.Text({
            Parent = btnKey, Text = formatKeyText(value),
            Alignment = Enum.TextXAlignment.Center,
            Color = Theme.Highlight, TextSize = 9.5, Truncate = true,
        })
        LouisHub:Register(lblKey, "TextColor3", "Highlight")

        local function updateKey(keyVal, fire)
            value = keyVal
            LouisHub.Flags[flag] = keyVal
            lblKey.Text = formatKeyText(keyVal)
            if fire and cfg.Callback then
                executeWithFallback(cfg.Callback, cfg.Text or cfg.Name or "Keybind", keyVal)
            end
        end

        local function cancelListening()
            if not isWaiting then return end
            isWaiting = false
            btnKey.BackgroundColor3 = Theme.Input
            lblKey.Text = formatKeyText(value)
            if connCapture then
                connCapture:Disconnect()
                connCapture = nil
            end
        end

        LouisHub:RegisterConnection(UserInputService.InputBegan:Connect(function(input, processed)
            if processed or isWaiting or _assignedThisFrame then return end
            local k, c, s, a = _decomposeKey(value)
            if k == Enum.KeyCode.Unknown or input.KeyCode ~= k then return end

            if withMods then
                local ctrlDown = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
                local shiftDown = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
                local altDown = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
                if ctrlDown ~= c or shiftDown ~= s or altDown ~= a then return end
            end

            if cfg.Callback then
                executeWithFallback(cfg.Callback, cfg.Text or cfg.Name or "Keybind", value)
            end
        end))

        Utils.ReliableClick(btnKey, function()
            if isWaiting then
                cancelListening()
                return
            end
            isWaiting = true
            lblKey.Text = "..."
            btnKey.BackgroundColor3 = Theme.Accent

            waitToken = waitToken + 1
            local myToken = waitToken

            task.delay(5, function()
                if isWaiting and waitToken == myToken then
                    cancelListening()
                end
            end)

            connCapture = UserInputService.InputBegan:Connect(function(input, processed)
                if processed or not isWaiting then return end
                if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
                    local isModKey = withMods and (
                        input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl or
                        input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift or
                        input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.RightAlt
                    )
                    if isModKey then return end

                    isWaiting = false
                    btnKey.BackgroundColor3 = Theme.Input
                    if connCapture then connCapture:Disconnect(); connCapture = nil end

                    local newVal = withMods and {
                        KeyCode = input.KeyCode,
                        Ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl),
                        Shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift),
                        Alt = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt),
                    } or input.KeyCode

                    _checkKeybindConflict(conflictEntry, newVal)
                    _assignedThisFrame = true
                    task.defer(function() _assignedThisFrame = false end)
                    updateKey(newVal, false)
                end
            end)
            LouisHub:RegisterConnection(connCapture)
        end)

        local elemObj = {
            Set = function(selfParam, v, fireCallback)
                local val = (selfParam == selfParam and fireCallback ~= nil) and v or (selfParam ~= nil and selfParam or v)
                local fire = (type(fireCallback) == "boolean") and fireCallback or false
                updateKey(val, fire)
            end,
            Get = function() return value end,
            Destroy = function()
                pcall(function() row:Destroy() end)
                local idx = table.find(_registeredKeybinds, conflictEntry)
                if idx then table.remove(_registeredKeybinds, idx) end
                LouisHub.Elements[flag] = nil
                LouisHub.Options[flag]  = nil
            end,
            CurrentBind = value,
        }
        LouisHub.Elements[flag] = elemObj
        LouisHub.Options[flag]  = elemObj

        return elemObj
    end

    for _, n in ipairs({"Input", "TagInput", "RadioGroup", "Dropdown", "ColorPicker", "Keybind"}) do
        Utils.WrapLockableControl(Section, Section.container, n)
    end
end

LouisHub._AdvancedControlMethods = applyAdvancedControlMethods

--[[
╔══════════════════════════════════════════════════════════════════════╗
                              LouisHub
                Master UI Suite: LouisHub Engine V4.0
         PART 3C: CONTROLS 13–18 (LABEL, PROGRESS, PARAGRAPH,
           DIVIDER, IMAGE, GROUP) & INJECTOR FINALIZATION
╚══════════════════════════════════════════════════════════════════════╝
]]

-- ══════════════════════════════════════════════════════════════
--  SECTION 21: CONDITIONAL VISIBILITY & AUTO-UPDATING LABELS
-- ══════════════════════════════════════════════════════════════
local _autoUpdateLabels = setmetatable({}, {__mode = "k"})

table.insert(_G.LouisHub_Instance.Connections, RunService.Heartbeat:Connect(function()
    local now = os.clock()
    for entry, cfg in pairs(_autoUpdateLabels) do
        if not (entry and entry.Parent) then
            _autoUpdateLabels[entry] = nil
        elseif now >= cfg.nextTime then
            cfg.nextTime = now + cfg.interval
            local ok, newVal = pcall(cfg.fn)
            if ok and newVal ~= nil then
                pcall(cfg.apply, newVal)
            elseif not ok then
                LouisHub:_LogError("Label auto-update ('" .. tostring(cfg.flag) .. "')", newVal)
            end
        end
    end
end))

local visibilityRegistry = setmetatable({}, {__mode = "k"})

function checkConditionalVisibility(row)
    local condition = visibilityRegistry[row]
    if not condition then return true end
    local ok, res = pcall(condition)
    if not ok then
        LouisHub:_LogError("VisibleIf", res)
        return true
    end
    return res and true or false
end

function registerConditionalVisibility(row, visibleIf)
    if type(visibleIf) ~= "function" or not row then return end
    visibilityRegistry[row] = visibleIf
    row.Visible = checkConditionalVisibility(row)
end

local function reevaluateConditionalVisibility()
    for row in pairs(visibilityRegistry) do
        if row and row.Parent then
            row.Visible = checkConditionalVisibility(row)
        end
    end
end

table.insert(_G.LouisHub_Instance.Connections, LouisHub.Events.FlagChanged:Connect(reevaluateConditionalVisibility))

-- ══════════════════════════════════════════════════════════════
--  SECTION 22: CONTROL INJECTION (CONTROLS 13 TO 18)
-- ══════════════════════════════════════════════════════════════
local function applyExtraControlMethods(Section)
    local order = 200
    local function nextOrder() order = order + 1; return order end

    local function createHeader(height, text, labelWidth, offsetX, mode, targetContainer)
        local row = Utils.Row(targetContainer, height, nextOrder(), Theme.Row)
        LouisHub:Register(row, "BackgroundColor3", "Row")
        Utils.Hover(row, row)
        if mode ~= "fixed" then
            local lblD = Utils.Text({
                Parent = row, Text = text,
                Size = UDim2.new(labelWidth or 1, offsetX or -46, 1, 0),
                TextSize = 11, Wrapped = true,
            })
            if mode ~= "manual" then Utils.MakeDynamicRow(row, lblD, height, 5) end
            return row, lblD
        end
        local lbl = Utils.Text({
            Parent = row, Text = text,
            Size = UDim2.new(labelWidth or 1, offsetX or -46, 1, 0),
            TextSize = 11, Truncate = true,
        })
        return row, lbl
    end

    -- 13. LABEL
    function Section:Label(cfg)
        cfg = cfg or {}
        local flag  = cfg.Flag or ("Label_" .. tostring(math.random(1e5, 1e6)))
        local isPlainLabel = (cfg.Value == nil)
        local valueStr = tostring(cfg.Value or "")
        _nonPersistentFlags[flag] = true

        local targetCont = self:_GetTargetContainer("Label", cfg)
        local row, lbl = createHeader(26, cfg.Text or "Label", 1, isPlainLabel and -16 or -100, nil, targetCont)
        addTextTooltip(row, cfg.Text or "Label", cfg.Tooltip or cfg.Description, lbl)
        registerSearchable(row, cfg.Text or "Label", cfg.VisibleIf)

        local lblValue = nil
        if not isPlainLabel then
            lblValue = Utils.Text({
                Parent = row, Text = valueStr, Size = UDim2.new(0, 90, 1, 0),
                Position = UDim2.new(1, -96, 0, 0), Alignment = Enum.TextXAlignment.Right,
                Color = Theme.AccentLight, TextSize = 10.5, Truncate = true,
            })
            LouisHub:Register(lblValue, "TextColor3", "AccentLight")
        end

        local function setVal(v)
            local txt = tostring(v)
            _realFlags[flag] = v
            if isPlainLabel then
                lbl.Text = txt
            else
                valueStr = txt
                if lblValue then lblValue.Text = valueStr end
            end
        end

        _realFlags[flag] = cfg.Value or cfg.Text
        local elemObj = {
            Set = function(selfParam, v)
                local targetV = (selfParam == selfParam and v ~= nil) and v or selfParam
                setVal(targetV)
            end,
            Get = function() return isPlainLabel and lbl.Text or valueStr end,
            Destroy = function()
                pcall(function() row:Destroy() end)
                if lblValue then _autoUpdateLabels[lblValue] = nil end
                _autoUpdateLabels[lbl] = nil
                LouisHub.Elements[flag] = nil
                LouisHub.Options[flag]  = nil
            end,
            Row = row,
        }
        elemObj.SetText = elemObj.Set

        LouisHub.Elements[flag] = elemObj

        local updateInterval = tonumber(cfg.Every)
        local updateFn = cfg.Update
        if updateInterval and updateFn and type(updateFn) == "function" and updateInterval >= 0.05 then
            _autoUpdateLabels[lblValue or lbl] = {
                interval = updateInterval,
                fn = updateFn,
                apply = setVal,
                flag = flag,
                nextTime = os.clock() + updateInterval,
            }
        end

        return elemObj
    end

    -- 14. PROGRESS
    function Section:Progress(cfg)
        cfg = cfg or {}
        local flag  = cfg.Flag or ("Progress_" .. tostring(math.random(1e5, 1e6)))
        local value = math.clamp(cfg.Default or 0, 0, 100)
        _nonPersistentFlags[flag] = true
        _realFlags[flag] = value

        local targetCont = self:_GetTargetContainer("Progress", cfg)
        local row, lbl = createHeader(34, cfg.Text or "Progress", nil, nil, "fixed", targetCont)
        lbl.Size = UDim2.new(1, -55, 0, 16)
        lbl.Position = UDim2.new(0, 6, 0, 2)
        addTextTooltip(row, cfg.Text or "Progress", cfg.Tooltip, lbl)
        registerSearchable(row, cfg.Text or "Progress", cfg.VisibleIf)

        local lblVal = Utils.Text({
            Parent = row, Text = math.floor(value) .. "%",
            Size = UDim2.new(0, 45, 0, 16), Position = UDim2.new(1, -50, 0, 2),
            Alignment = Enum.TextXAlignment.Right, Color = Theme.AccentLight, TextSize = 10,
        })
        LouisHub:Register(lblVal, "TextColor3", "AccentLight")

        local bg = Utils.Frame({
            Parent = row, Size = UDim2.new(1, -12, 0, 5),
            Position = UDim2.new(0, 6, 0, 22), Color = Theme.Input,
            Radius = 3, Transparency = 0.4,
        })
        LouisHub:Register(bg, "BackgroundColor3", "Input")

        local fill = Utils.Frame({
            Parent = bg, Size = UDim2.new(value / 100, 0, 1, 0),
            Color = Theme.Accent, Radius = 3, Transparency = 0, Border = false,
        })
        LouisHub:Register(fill, "BackgroundColor3", "Accent")
        Utils.AccentGradient(fill)

        local function setProgress(v)
            if type(v) ~= "number" then return end
            value = math.clamp(v, 0, 100)
            Utils.Tween(fill, {Size = UDim2.new(value / 100, 0, 1, 0)}, LouisHub.Motion.Expand)
            lblVal.Text = math.floor(value + 0.5) .. "%"
            _realFlags[flag] = value
        end

        local elemObj = {
            Set = function(selfParam, v)
                local targetV = (selfParam == selfParam and v ~= nil) and v or selfParam
                setProgress(targetV)
            end,
            Get = function() return value end,
            Destroy = function()
                pcall(function() row:Destroy() end)
                LouisHub.Elements[flag] = nil
                LouisHub.Options[flag]  = nil
            end,
        }
        LouisHub.Elements[flag] = elemObj
        return elemObj
    end

    -- 15. PARAGRAPH
    function Section:Paragraph(cfg)
        cfg = cfg or {}
        local targetCont = self:_GetTargetContainer("Paragraph", cfg)
        local frame = Utils.Frame({
            Parent = targetCont, Size = UDim2.new(1, 0, 0, 0),
            Color = Theme.Row, Order = nextOrder(), Radius = 6,
            Transparency = 0.5,
        })
        frame.AutomaticSize = Enum.AutomaticSize.Y
        LouisHub:Register(frame, "BackgroundColor3", "Row")

        local pad = Instance.new("UIPadding")
        pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
        pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
        pad.Parent = frame

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 2)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = frame

        local titleParam = cfg.Title
        local lblTit = nil
        if titleParam then
            lblTit = Utils.Text({
                Parent = frame, Text = titleParam,
                Size = UDim2.new(1, 0, 0, 0), Font = Enum.Font.GothamBold,
                TextSize = 11, Color = Theme.Highlight, Wrapped = true, Order = 1,
            })
            lblTit.AutomaticSize = Enum.AutomaticSize.Y
            LouisHub:Register(lblTit, "TextColor3", "Highlight")
        end

        local bodyParam = cfg.Content or cfg.Text or ""
        local lblBody = Utils.Text({
            Parent = frame, Text = bodyParam,
            Size = UDim2.new(1, 0, 0, 0), TextSize = 10.5, Color = Theme.Text,
            Wrapped = true, Order = 2,
        })
        lblBody.AutomaticSize = Enum.AutomaticSize.Y
        LouisHub:Register(lblBody, "TextColor3", "Text")

        local elemObj = {
            Instance = frame,
            Set = function(selfParam, v)
                local targetV = (selfParam == selfParam and v ~= nil) and v or selfParam
                if type(targetV) == "table" then
                    if targetV.Title and lblTit then lblTit.Text = tostring(targetV.Title) end
                    if targetV.Content then lblBody.Text = tostring(targetV.Content) end
                else
                    lblBody.Text = tostring(targetV)
                end
            end,
            Get = function()
                return {
                    Title = lblTit and lblTit.Text or nil,
                    Content = lblBody.Text
                }
            end,
            Destroy = function()
                pcall(function() frame:Destroy() end)
            end,
        }
        return elemObj
    end

    -- 16. DIVIDER
    function Section:Divider(cfg)
        cfg = cfg or {}
        local textParam = cfg.Text
        local targetCont = self:_GetTargetContainer("Divider", cfg)
        local row = Utils.Frame({
            Parent = targetCont, Size = UDim2.new(1, 0, 0, textParam and 24 or 12),
            Order = nextOrder(), Transparency = 1, Radius = false, Border = false,
        })
        if textParam then
            Utils.Text({
                Parent = row, Text = tostring(textParam),
                Size = UDim2.new(1, -12, 0, 14), Position = UDim2.new(0, 6, 0, 0),
                Font = Enum.Font.GothamBold, TextSize = 9.5, ThemeColor = "AccentLight",
            })
        end
        local line = Utils.Frame({
            Parent = row, Size = UDim2.new(1, 0, 0, 1.5),
            Position = UDim2.new(0, 0, 1, -2), Color = Theme.Accent,
            Radius = false, Border = false, Transparency = 0.3,
        })
        LouisHub:Register(line, "BackgroundColor3", "Accent")
        Utils.AccentGradient(line)

        return {
            Instance = row,
            Destroy = function()
                pcall(function() row:Destroy() end)
            end,
        }
    end

    -- 17. IMAGE
    function Section:Image(cfg)
        cfg = cfg or {}
        local targetCont = self:_GetTargetContainer("Image", cfg)
        local fixedHeight = math.clamp(cfg.Height or 90, 30, 350)
        local row = Utils.Frame({
            Parent = targetCont, Size = UDim2.new(1, 0, 0, fixedHeight),
            Transparency = 1, Order = nextOrder(), Radius = false, Border = false,
        })
        local img = Instance.new("ImageLabel")
        img.BackgroundColor3 = Theme.Row
        img.BackgroundTransparency = 0.5
        img.BorderSizePixel = 0

        local initialUrl = type(cfg.Url) == "string" and cfg.Url or ""
        if initialUrl ~= "" and not string.find(initialUrl, "rbxassetid://") and not string.find(initialUrl, "http") then
            initialUrl = "rbxassetid://" .. initialUrl
        end
        img.Image = initialUrl
        img.ScaleType = Enum.ScaleType.Fit
        img.Size = UDim2.new(1, 0, 1, 0)
        img.Parent = row
        Utils.Corner(img, 6)
        LouisHub:Register(img, "BackgroundColor3", "Row")

        return {
            Set = function(selfParam, u)
                local targetU = (selfParam == selfParam and u ~= nil) and u or selfParam
                if type(targetU) == "string" then
                    if not string.find(targetU, "rbxassetid://") and not string.find(targetU, "http") then
                        targetU = "rbxassetid://" .. targetU
                    end
                    img.Image = targetU
                end
            end,
            Get = function() return img.Image end,
            Instance = img,
            Destroy = function()
                pcall(function() row:Destroy() end)
            end,
        }
    end

    -- 18. GROUP
    function Section:Group(cfg)
        cfg = cfg or {}
        local targetCont = self:_GetTargetContainer("Group", cfg)
        local GROUP_H = 26
        local rowG = Utils.Frame({
            Parent = targetCont, Size = UDim2.new(1, 0, 0, GROUP_H),
            Transparency = 1, Order = nextOrder(), Radius = false, Border = false,
        })
        local layG = Instance.new("UIListLayout")
        layG.FillDirection = Enum.FillDirection.Horizontal
        layG.Padding = UDim.new(0, 6)
        layG.Parent = rowG

        local groupButtons = {}
        local groupObj = {
            Instance = rowG,
            Destroy = function()
                pcall(function() rowG:Destroy() end)
            end,
        }

        function groupObj:Button(cfgB)
            local btn = Section:Button(cfgB)
            btn.Parent = rowG
            table.insert(groupButtons, btn)
            local tot = #groupButtons
            for _, b in ipairs(groupButtons) do
                b.Size = UDim2.new(1 / tot, -math.ceil(6 * (tot - 1) / tot), 1, 0)
            end
            return btn
        end

        return groupObj
    end

    -- BUILD HELPER
    function Section:Build(list)
        local res = {}
        for i, def in ipairs(list or {}) do
            local ctrlType = def.Control or def.Type
            if ctrlType and type(self[ctrlType]) == "function" then
                local obj = self[ctrlType](self, def)
                res[i] = obj
                if def.Flag then res[def.Flag] = obj end
            end
        end
        return res
    end

    for _, n in ipairs({"Label", "Progress", "Paragraph", "Divider", "Image", "Group"}) do
        Utils.WrapLockableControl(Section, Section.container, n)
    end
end

-- ══════════════════════════════════════════════════════════════
--  SECTION 23: INJECTOR COMPOSER & HOOK DISPATCH
-- ══════════════════════════════════════════════════════════════
LouisHub:_SetControlInjector(function(Section)
    if LouisHub._BaseControlMethods then
        LouisHub._BaseControlMethods(Section)
    end
    if LouisHub._AdvancedControlMethods then
        LouisHub._AdvancedControlMethods(Section)
    end
    applyExtraControlMethods(Section)
end)

--[[
╔══════════════════════════════════════════════════════════════════════╗
                              LouisHub
                Master UI Suite: LouisHub Engine V4.0
         PART 4A: UNDO/REDO ENGINE & UNIFIED SAVE MANAGER V3
╚══════════════════════════════════════════════════════════════════════╝
]]

-- ══════════════════════════════════════════════════════════════
--  SECTION 24: UNDO / REDO HISTORY ENGINE
-- ══════════════════════════════════════════════════════════════
LouisHub._history = { undo = {}, redo = {}, lastValues = {}, pause = 0 }
local MAX_HISTORY = 50

local function notifyHistoryChanged()
    local h = LouisHub._history
    LouisHub.Events.HistoryChanged:Fire(#h.undo, #h.redo)
end

table.insert(_G.LouisHub_Instance.Connections, LouisHub.Events.FlagChanged:Connect(function(flag, val)
    local h = LouisHub._history
    local prev = h.lastValues[flag]
    h.lastValues[flag] = copyDefault(val)
    if h.pause > 0 or _uiFlags[flag] or _nonPersistentFlags[flag] then return end
    local elem = LouisHub.Elements[flag]
    if prev == nil and elem then prev = elem._default end
    if prev == nil then return end
    if type(val) ~= "table" and prev == val then return end

    local now = os.clock()
    local lastEntry = h.undo[#h.undo]
    if lastEntry and #lastEntry.changes == 1 and lastEntry.changes[1].flag == flag and now - lastEntry.t < 0.6 then
        lastEntry.changes[1].after = copyDefault(val)
        lastEntry.t = now
        if type(val) ~= "table" and lastEntry.changes[1].before == val then
            table.remove(h.undo)
        end
    elseif lastEntry and now - lastEntry.t < 0.05 then
        table.insert(lastEntry.changes, { flag = flag, before = copyDefault(prev), after = copyDefault(val) })
        lastEntry.t = now
    else
        table.insert(h.undo, {
            t = now,
            changes = { { flag = flag, before = copyDefault(prev), after = copyDefault(val) } },
        })
        if #h.undo > MAX_HISTORY then table.remove(h.undo, 1) end
    end
    h.redo = {}
    notifyHistoryChanged()
end))

local function applyHistoryChanges(changes, useBefore, inReverse)
    local h = LouisHub._history
    h.pause = h.pause + 1
    local total = #changes
    for i = 1, total do
        local c = changes[inReverse and (total - i + 1) or i]
        local elem = LouisHub.Elements[c.flag]
        if elem and type(elem.Set) == "function" then
            local source = useBefore and c.before or c.after
            local val = copyDefault(source)
            pcall(function() elem:Set(val, true) end)
            h.lastValues[c.flag] = copyDefault(val)
        end
    end
    h.pause = h.pause - 1
end

function LouisHub:Undo()
    local h = self._history
    local entry = table.remove(h.undo)
    if not entry then return false end
    applyHistoryChanges(entry.changes, true, true)
    table.insert(h.redo, entry)
    notifyHistoryChanged()
    return true, entry
end

function LouisHub:Redo()
    local h = self._history
    local entry = table.remove(h.redo)
    if not entry then return false end
    applyHistoryChanges(entry.changes, false, false)
    table.insert(h.undo, entry)
    notifyHistoryChanged()
    return true, entry
end

function LouisHub:CanUndo() return #self._history.undo > 0 end
function LouisHub:CanRedo() return #self._history.redo > 0 end
function LouisHub:GetHistory() return { Undo = #self._history.undo, Redo = #self._history.redo } end

function LouisHub:ClearHistory()
    local h = self._history
    h.undo, h.redo, h.lastValues = {}, {}, {}
    for flag, elem in pairs(self.Elements) do
        if type(elem) == "table" and type(elem.Get) == "function" then
            local ok, val = pcall(function() return elem:Get() end)
            if ok and val ~= nil then h.lastValues[flag] = copyDefault(val) end
        end
    end
    notifyHistoryChanged()
end

function LouisHub:DescribeChange(entry)
    if type(entry) ~= "table" or not entry.changes or #entry.changes == 0 then return "" end
    local first = entry.changes[1]
    local function text(v)
        if type(v) == "table" then return "[table]" end
        return tostring(v)
    end
    local summary = tostring(first.flag) .. ": " .. text(first.before) .. " -> " .. text(first.after)
    if #entry.changes > 1 then summary = summary .. " (+" .. (#entry.changes - 1) .. ")" end
    return summary
end

-- ══════════════════════════════════════════════════════════════
--  SECTION 25: UNIFIED SAVE MANAGER V3 (PROFILE SYSTEM)
-- ══════════════════════════════════════════════════════════════
local SAVE_FORMAT_VERSION = 3
_G.LouisHub_NavigationState = { cat = nil, tab = nil, sub = nil }

local function isColor3Type(v) return typeof and typeof(v) == "Color3" end
local function isEnumType(v) return typeof and typeof(v) == "EnumItem" end

local function packFlagsForSaving(flags, uiOnly)
    local result = {
        __version = SAVE_FORMAT_VERSION,
        __navigation = _G.LouisHub_NavigationState,
        __baseTheme = LouisHub.CurrentBaseTheme,
        __accentPreset = LouisHub.CurrentAccentPreset,
    }
    for key, val in pairs(flags) do
        local skip = _nonPersistentFlags[key]
            or (uiOnly and not _uiFlags[key])
            or (not uiOnly and _uiFlags[key])
        if not skip then
            if isColor3Type(val) then
                result[key] = {
                    __color3 = true,
                    R = math.floor(val.R * 255 + 0.5),
                    G = math.floor(val.G * 255 + 0.5),
                    B = math.floor(val.B * 255 + 0.5),
                }
            elseif isEnumType(val) then
                result[key] = {
                    __enum = true,
                    EnumType = tostring(val.EnumType),
                    Name = val.Name,
                }
            elseif type(val) == "table" and isEnumType(val.KeyCode) then
                result[key] = {
                    __keybindMods = true,
                    KeyCode = val.KeyCode.Name,
                    Ctrl = val.Ctrl or false,
                    Shift = val.Shift or false,
                    Alt = val.Alt or false,
                }
            else
                result[key] = val
            end
        end
    end
    return result
end

local function unpackLoadedValue(val)
    if type(val) == "table" and val.__color3 then
        return Color3.fromRGB(val.R or 0, val.G or 0, val.B or 0)
    end
    if type(val) == "table" and val.__enum then
        local ok, enumItem = pcall(function() return Enum[val.EnumType][val.Name] end)
        return (ok and enumItem) or Enum.KeyCode.Unknown
    end
    if type(val) == "table" and val.__keybindMods then
        local ok, keyCode = pcall(function() return Enum.KeyCode[val.KeyCode] end)
        return {
            KeyCode = ok and keyCode or Enum.KeyCode.Unknown,
            Ctrl = val.Ctrl or false,
            Shift = val.Shift or false,
            Alt = val.Alt or false,
        }
    end
    return val
end

local function _checkConflictsOnLoad()
    if #_registeredKeybinds < 2 then return end
    local bySignature = {}
    for _, entry in ipairs(_registeredKeybinds) do
        local ok, val = pcall(function() return entry:GetValue() end)
        if ok then
            local k, c, s, a = _decomposeKey(val)
            if k and k ~= Enum.KeyCode.Unknown then
                local sig = k.Name .. "|" .. tostring(c) .. "|" .. tostring(s) .. "|" .. tostring(a)
                bySignature[sig] = bySignature[sig] or {
                    k = k, c = c, s = s, a = a, texts = {},
                }
                table.insert(bySignature[sig].texts, entry.text or "Keybind")
            end
        end
    end

    for _, group in pairs(bySignature) do
        if #group.texts >= 2 then
            pcall(function()
                LouisHub:Notify({
                    Title    = "⚠️ Keybind Conflict",
                    Content  = "'" .. _formatKey(group.k, group.c, group.s, group.a) .. "' is assigned to: " .. table.concat(group.texts, ", "),
                    Duration = 6,
                    Icon     = "warning"
                })
            end)
        end
    end
end

local function prepareLoadedData(data)
    if type(data) ~= "table" then return {} end

    if type(data.objects) == "table" then
        local migrated = {}
        for _, obj in ipairs(data.objects) do
            if obj.flag then
                if obj.state ~= nil then
                    migrated[obj.flag] = obj.state
                elseif obj.value ~= nil then
                    migrated[obj.flag] = tonumber(obj.value) or obj.value
                elseif obj.text ~= nil then
                    migrated[obj.flag] = obj.text
                elseif obj.color ~= nil then
                    if type(obj.color) == "string" and obj.color:sub(1,1) == "#" then
                        local r = tonumber(obj.color:sub(2, 3), 16) or 255
                        local g = tonumber(obj.color:sub(4, 5), 16) or 255
                        local b = tonumber(obj.color:sub(6, 7), 16) or 255
                        migrated[obj.flag] = Color3.fromRGB(r, g, b)
                    end
                end
            end
        end
        return migrated
    end

    local sourceVersion = tonumber(data.__version) or 1
    data.__version = nil

    if data.__navigation and type(data.__navigation) == "table" then
        _G.LouisHub_NavigationState = data.__navigation
        data.__navigation = nil
    end

    if data.__baseTheme and LouisHub.ThemeManager then
        pcall(function() LouisHub.ThemeManager:ApplyBaseTheme(data.__baseTheme) end)
        data.__baseTheme = nil
    end

    if data.__accentPreset and LouisHub.ThemeManager and data.__accentPreset ~= "Default" then
        pcall(function() LouisHub.ThemeManager:ApplyAccentGradient(data.__accentPreset) end)
        data.__accentPreset = nil
    end

    if sourceVersion > SAVE_FORMAT_VERSION then
        pcall(function()
            LouisHub:Notify({
                Title    = "⚠️ Newer Config",
                Content  = "The config file is from a newer version (v" .. sourceVersion .. ").",
                Duration = 5,
                Icon     = "warning"
            })
        end)
    end

    return data
end

LouisHub.SaveManager = {}
local SM = LouisHub.SaveManager
SM.Folder = "LouisHub/Config"
SM.FolderUI = "LouisHub/Config/_ui"

function SM:Configure(folder)
    self.Folder = folder or self.Folder
end

local function ensureFolder()
    if not (isFilesystemAvailable() and type(isfolder) == "function" and type(makefolder) == "function") then return end
    local path = ""
    for part in SM.Folder:gmatch("[^/]+") do
        path = path == "" and part or (path .. "/" .. part)
        if not isfolder(path) then pcall(makefolder, path) end
    end
end

local function ensureFolderUI()
    if not (isFilesystemAvailable() and type(isfolder) == "function" and type(makefolder) == "function") then return end
    local path = ""
    for part in SM.FolderUI:gmatch("[^/]+") do
        path = path == "" and part or (path .. "/" .. part)
        if not isfolder(path) then pcall(makefolder, path) end
    end
end

function SM:Save(name)
    name = name or "default"
    if not isFilesystemAvailable() then
        LouisHub:Notify({Title = "SaveManager", Content = "Executor missing filesystem support.", Duration = 4, Icon = "warning"})
        return false, "No filesystem support"
    end
    ensureFolder()
    local path = SM.Folder .. "/" .. name .. ".json"
    local hadChanges = true
    local ok, err = pcall(function()
        local data = packFlagsForSaving(_realFlags)
        local json = HttpService:JSONEncode(data)
        if type(isfile) == "function" and isfile(path) then
            local okRead, existingJson = pcall(readfile, path)
            if okRead and existingJson == json then
                hadChanges = false
            end
        end
        if hadChanges then writefile(path, json) end
    end)
    if ok then
        if hadChanges then
            LouisHub:Notify({Title = "Config Saved", Content = name .. ".json", Duration = 3, Icon = "check_circle"})
        else
            LouisHub:Notify({Title = "✅ Already Up to Date", Content = name .. ".json has no changes", Duration = 3, Icon = "info"})
        end
    else
        LouisHub:_LogError("SaveManager:Save", err)
        LouisHub:Notify({Title = "❌ Save Error", Content = tostring(err):sub(1, 100), Duration = 5, Icon = "warning"})
    end
    return ok, err
end

function SM:SaveSilent(name)
    name = name or "default"
    if not isFilesystemAvailable() then return false end
    ensureFolder()
    local ok, err = pcall(function()
        local data = packFlagsForSaving(_realFlags)
        local json = HttpService:JSONEncode(data)
        writefile(SM.Folder .. "/" .. name .. ".json", json)
    end)
    if not ok then LouisHub:_LogError("SaveManager:SaveSilent", err) end
    return ok
end

function SM:Load(name)
    name = name or "default"
    local path = SM.Folder .. "/" .. name .. ".json"
    if not (isFilesystemAvailable() and type(isfile) == "function" and isfile(path)) then return false end

    local okRead, content = pcall(readfile, path)
    if not okRead then
        LouisHub:_LogError("SaveManager:Load (read)", content)
        return false
    end
    local okDecode, data = pcall(function() return HttpService:JSONDecode(content) end)
    if not okDecode then
        LouisHub:_LogError("SaveManager:Load (JSONDecode)", data)
        return false
    end
    data = prepareLoadedData(data)

    _isLoadingFromFile = true
    local okLoop, errLoop = pcall(function()
        for flag, rawVal in pairs(data) do
            local val = unpackLoadedValue(rawVal)
            LouisHub.Flags[flag] = val
            if LouisHub.Elements[flag] then
                pcall(function() LouisHub.Elements[flag]:Set(val, true) end)
            end
        end
    end)
    _isLoadingFromFile = false
    if not okLoop then LouisHub:_LogError("SaveManager:Load (loop)", errLoop) end
    _checkConflictsOnLoad()
    LouisHub:Notify({Title = "Config Loaded", Content = name .. ".json", Duration = 3, Icon = "check_circle"})
    return true
end

function SM:LoadSilent(name)
    name = name or "default"
    local path = SM.Folder .. "/" .. name .. ".json"
    if not (isFilesystemAvailable() and type(isfile) == "function" and isfile(path)) then return false end

    local okRead, content = pcall(readfile, path)
    if not okRead then return false end
    local okDecode, data = pcall(function() return HttpService:JSONDecode(content) end)
    if not okDecode then return false end
    data = prepareLoadedData(data)

    _isLoadingFromFile = true
    pcall(function()
        for flag, rawVal in pairs(data) do
            local val = unpackLoadedValue(rawVal)
            LouisHub.Flags[flag] = val
            if LouisHub.Elements[flag] then
                pcall(function() LouisHub.Elements[flag]:Set(val, false) end)
            end
        end
    end)
    _isLoadingFromFile = false
    _checkConflictsOnLoad()
    return true
end

function SM:List()
    if not (isFilesystemAvailable() and type(listfiles) == "function") then return {} end
    ensureFolder()
    local result = {}
    local ok, files = pcall(listfiles, SM.Folder)
    if ok then
        for _, path in ipairs(files) do
            local name = path:match("([^/\\]+)%.json$")
            if name and not name:match("^_") then table.insert(result, name) end
        end
    end
    return result
end

function SM:Delete(name)
    if type(name) ~= "string" or name == "" then return false end
    if not (isFilesystemAvailable() and type(isfile) == "function" and type(delfile) == "function") then return false end
    local path = SM.Folder .. "/" .. name .. ".json"
    if not isfile(path) then return false end
    return (pcall(delfile, path))
end

function SM:SwitchProfile(window, name)
    if type(window) ~= "table" or type(name) ~= "string" or name == "" then return false end
    if window.ConfigName then self:SaveSilent(window.ConfigName) end
    window.ConfigName = name
    local exists = self:Load(name)
    if not exists then
        LouisHub:Notify({Title = "New Profile", Content = "'" .. name .. "' has no previous save", Duration = 3, Icon = "info"})
    end
    return true
end

local function validProfileName(name)
    if type(name) ~= "string" then return false end
    local clean = name:match("^%s*(.-)%s*$")
    if clean == "" or #clean > 60 or clean:find('[/\\:*?"<>|%c]') then return false end
    return true, clean
end

function SM:Duplicate(source, destination)
    local okS, nameS = validProfileName(source)
    local okD, nameD = validProfileName(destination)
    if not (okS and okD) then return false, "Invalid profile name" end
    if not (isFilesystemAvailable() and type(isfile) == "function") then return false, "No filesystem support" end
    ensureFolder()
    local pathS = SM.Folder .. "/" .. nameS .. ".json"
    local pathD = SM.Folder .. "/" .. nameD .. ".json"
    if not isfile(pathS) then return false, "Source profile does not exist" end
    if isfile(pathD) then return false, "Destination profile already exists" end
    local ok, err = pcall(function() writefile(pathD, readfile(pathS)) end)
    return ok, err
end

function SM:Rename(source, destination)
    local ok, reason = self:Duplicate(source, destination)
    if not ok then return false, reason end
    local _, nameS = validProfileName(source)
    self:Delete(nameS)
    return true
end

function SM:Export(name)
    local okN, clean = validProfileName(name)
    if not okN or not isFilesystemAvailable() then return nil, "File error" end
    local path = SM.Folder .. "/" .. clean .. ".json"
    if not isfile(path) then return nil, "Profile does not exist" end
    local okR, text = pcall(readfile, path)
    if not okR then return nil, "Read error" end
    local copied = false
    if type(setclipboard) == "function" then copied = (pcall(setclipboard, text)) end
    return text, copied
end

function SM:Import(name, text, overwrite)
    local okN, clean = validProfileName(name)
    if not okN or type(text) ~= "string" or not isFilesystemAvailable() then return false, "Invalid data" end
    local okJ, data = pcall(function() return HttpService:JSONDecode(text) end)
    if not okJ or type(data) ~= "table" then return false, "Invalid JSON" end
    ensureFolder()
    local path = SM.Folder .. "/" .. clean .. ".json"
    if isfile(path) and not overwrite then return false, "Profile already exists" end
    local ok, err = pcall(writefile, path, text)
    return ok, err
end

function SM:SaveUI(name)
    name = name or "default"
    if not isFilesystemAvailable() then return false end
    ensureFolderUI()
    local path = SM.FolderUI .. "/" .. name .. ".json"
    local ok = pcall(function()
        local data = packFlagsForSaving(_realFlags, true)
        writefile(path, HttpService:JSONEncode(data))
    end)
    return ok
end

function SM:LoadUI(name)
    name = name or "default"
    local path = SM.FolderUI .. "/" .. name .. ".json"
    if not (isFilesystemAvailable() and type(isfile) == "function" and isfile(path)) then return false end
    local okRead, content = pcall(readfile, path)
    if not okRead then return false end
    local okDecode, data = pcall(function() return HttpService:JSONDecode(content) end)
    if not okDecode then return false end
    data = prepareLoadedData(data)

    _isLoadingFromFile = true
    pcall(function()
        for flag, rawVal in pairs(data) do
            if _uiFlags[flag] then
                local val = unpackLoadedValue(rawVal)
                LouisHub.Flags[flag] = val
                if LouisHub.Elements[flag] then
                    pcall(function() LouisHub.Elements[flag]:Set(val, false) end)
                end
            end
        end
    end)
    _isLoadingFromFile = false
    _checkConflictsOnLoad()
    return true
end

function SM:ListUI()
    if not (isFilesystemAvailable() and type(listfiles) == "function") then return {} end
    ensureFolderUI()
    local result = {}
    local ok, files = pcall(listfiles, SM.FolderUI)
    if ok then
        for _, path in ipairs(files) do
            local n = path:match("([^/\\]+)%.json$")
            if n then table.insert(result, n) end
        end
    end
    return result
end

function SM:DeleteUI(name)
    if not (isFilesystemAvailable() and type(isfile) == "function" and type(delfile) == "function") then return false end
    local path = SM.FolderUI .. "/" .. (name or "default") .. ".json"
    if not isfile(path) then return false end
    return (pcall(delfile, path))
end

function LouisHub:SaveConfig(path)
    return self.SaveManager:Save(path)
end

function LouisHub:LoadConfig(path)
    return self.SaveManager:Load(path)
end

function LouisHub:RefreshConfigList()
    return self.SaveManager:List()
end

function LouisHub:LoadAutoloadConfig()
    if not isFilesystemAvailable() then return false end
    local path = self.Folder .. "/autoload.txt"
    if type(isfile) == "function" and isfile(path) then
        local ok, n = pcall(readfile, path)
        if ok and n and n ~= "" then
            return self.SaveManager:Load(n)
        end
    end
    return false
end

--[[
╔══════════════════════════════════════════════════════════════════════╗
                              LouisHub
                Master UI Suite: LouisHub Engine V4.0
         PART 4B: BUILT-IN TABS (HOME, CONFIG, SYSTEM) & CORE EXPORTS
╚══════════════════════════════════════════════════════════════════════╝
]]

-- ══════════════════════════════════════════════════════════════
--  SECTION 26: HOME DASHBOARD & STATS TAB
-- ══════════════════════════════════════════════════════════════
local function createLunaHomeTab(Window, HomeTabSettings)
    HomeTabSettings = Kwargify({
        Icon = 1,
        SupportedExecutors = {"Vega X", "Delta", "Nihon", "Xeno", "Synapse X", "Krnl", "Fluxus"},
        DiscordInvite = "nebula"
    }, HomeTabSettings or {})

    local catGeneral = Window.Categories["General"] or Window:CreateCategory("General")
    local homeTab = catGeneral:CreateTab({
        Name = "Home",
        Icon = (HomeTabSettings.Icon == 2) and "dashboard" or "home",
        ShowTitle = true
    })

    local secProfile = homeTab:CreateSection("Player Profile", { Columns = 2 })

    local headshot = ""
    if LocalPlayer then
        pcall(function()
            headshot = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
        end)
    end

    secProfile:Image({
        Url = headshot,
        Height = 80,
        Column = 1
    })

    secProfile:Label({ Text = "Display Name", Value = LocalPlayer and LocalPlayer.DisplayName or "Player", Column = 2 })
    secProfile:Label({ Text = "Username", Value = "@" .. (LocalPlayer and LocalPlayer.Name or "Player"), Column = 2 })
    secProfile:Label({ Text = "Account ID", Value = tostring(LocalPlayer and LocalPlayer.UserId or 0), Column = 2 })

    local secClient = homeTab:CreateSection("Client & Server Status", { Columns = 2 })

    local execName = (isStudio and "Roblox Studio (Debugging)") or detectExecutor()
    secClient:Label({ Text = "Executor", Value = execName, Column = 1 })

    local isSupported = false
    for _, ex in pairs(HomeTabSettings.SupportedExecutors) do
        if ex == execName or isStudio then isSupported = true; break end
    end
    secClient:Label({
        Text = "Compatibility",
        Value = isSupported and "🟢 Supported" or "🟡 Untested",
        Column = 1
    })

    local pingLbl = secClient:Label({ Text = "Latency", Value = "0 ms", Column = 1 })
    local timeLbl = secClient:Label({ Text = "Server Time", Value = "00:00:00", Column = 2 })
    local playersLbl = secClient:Label({ Text = "Players", Value = "-- / --", Column = 2 })

    local regionStr = "Global"
    if LocalPlayer then
        pcall(function() regionStr = Localization:GetCountryRegionForPlayerAsync(LocalPlayer) end)
    end
    secClient:Label({ Text = "Region", Value = regionStr, Column = 2 })

    local secDiscord = homeTab:CreateSection("Discord Community", { Columns = 1 })
    secDiscord:Button({
        Text = "Join Official Discord Server",
        Icon = "chat",
        Callback = function()
            local link = "https://discord.gg/" .. tostring(HomeTabSettings.DiscordInvite)
            if setclipboard then setclipboard(link) end
            if request then
                pcall(function()
                    request({
                        Url = 'http://127.0.0.1:6463/rpc?v=1',
                        Method = 'POST',
                        Headers = {
                            ['Content-Type'] = 'application/json',
                            Origin = 'https://discord.com'
                        },
                        Body = HttpService:JSONEncode({
                            cmd = 'INVITE_BROWSER',
                            nonce = HttpService:GenerateGUID(false),
                            args = {code = HomeTabSettings.DiscordInvite}
                        })
                    })
                end)
            end
            LouisHub:Notify({
                Title = "Discord Invite",
                Content = "Link copied to clipboard: " .. link,
                Duration = 3,
                Icon = "check_circle"
            })
        end
    })

    local function formatDigits(int) return string.format("%02i", int) end
    local function convertToHMS(seconds)
        local m = (seconds - seconds % 60) / 60
        seconds = seconds - m * 60
        local h = (m - m % 60) / 60
        m = m - h * 60
        return formatDigits(h) .. ":" .. formatDigits(m) .. ":" .. formatDigits(seconds)
    end

    local function getPing()
        local s = game:GetService("Stats")
        if s and s:FindFirstChild("Network") and s.Network:FindFirstChild("ServerStatsItem") then
            local p = s.Network.ServerStatsItem:FindFirstChild("Data Ping")
            if p then return math.clamp(p:GetValue(), 5, 1000) end
        end
        return 50
    end

    LouisHub:RegisterThread(task.spawn(function()
        while homeTab and homeTab.Page and homeTab.Page.Parent do
            if Window._main.Visible and homeTab.Page.Visible then
                local ms = isStudio and (LocalPlayer and math.round((LocalPlayer:GetNetworkPing() * 2) / 0.01) or 0) or math.floor(getPing())
                pingLbl:Set(tostring(ms) .. " ms")
                timeLbl:Set(convertToHMS(time()))
                playersLbl:Set(#Players:GetPlayers() .. " / " .. Players.MaxPlayers)
            end
            task.wait(1)
        end
    end))

    homeTab:Select()
    return homeTab
end

-- ══════════════════════════════════════════════════════════════
--  SECTION 27: CONFIG & CUSTOM THEME SECTION BUILDER
-- ══════════════════════════════════════════════════════════════
local function buildConfigSection(tab)
    if not isFilesystemAvailable() then
        local secErr = tab:CreateSection("Configurations", { Columns = 1 })
        secErr:Label({ Text = "Config system unavailable (No filesystem support)." })
        return
    end

    local inputPath = nil
    local selectedConfig = nil

    local secCreator = tab:CreateSection("Config Creator", { Columns = 1 })

    secCreator:Input({
        Text = "Config Name",
        Placeholder = "Name",
        Default = "",
        Callback = function(input)
            inputPath = input
        end,
    })

    local configSelection

    secCreator:Button({
        Text = "Create Config",
        Tooltip = "Create a config with all of your current settings.",
        Callback = function()
            if not inputPath or string.gsub(inputPath, " ", "") == "" then
                LouisHub:Notify({
                    Title = "Interface",
                    Icon = "warning",
                    Content = "Config name cannot be empty."
                })
                return
            end

            local success, returned = LouisHub.SaveManager:Save(inputPath)
            if not success then
                LouisHub:Notify({
                    Title = "Interface",
                    Icon = "warning",
                    Content = "Unable to save config: " .. tostring(returned)
                })
            else
                LouisHub:Notify({
                    Title = "Interface",
                    Icon = "info",
                    Content = string.format("Created config %q", inputPath),
                })
            end

            if configSelection and configSelection.Refresh then
                configSelection:Refresh(LouisHub.SaveManager:List())
            end
        end
    })

    local secSettings = tab:CreateSection("Config Load/Settings", { Columns = 1 })

    configSelection = secSettings:Dropdown({
        Text = "Select Config",
        Tooltip = "Select a config to load your settings from.",
        Options = LouisHub.SaveManager:List(),
        Default = {},
        MultipleOptions = false,
        Callback = function(val)
            selectedConfig = val
        end,
    })

    secSettings:Button({
        Text = "Load Config",
        Tooltip = "Load your saved config settings.",
        Callback = function()
            if not selectedConfig then return end
            local success, returned = LouisHub.SaveManager:Load(selectedConfig)
            if not success then
                LouisHub:Notify({
                    Title = "Interface",
                    Icon = "warning",
                    Content = "Unable to load config: " .. tostring(returned)
                })
                return
            end

            LouisHub:Notify({
                Title = "Interface",
                Icon = "info",
                Content = string.format("Loaded config %q", selectedConfig),
            })
        end
    })

    secSettings:Button({
        Text = "Overwrite Config",
        Tooltip = "Overwrite your current config settings.",
        Callback = function()
            if not selectedConfig then return end
            local success, returned = LouisHub.SaveManager:Save(selectedConfig)
            if not success then
                LouisHub:Notify({
                    Title = "Interface",
                    Icon = "warning",
                    Content = "Unable to overwrite config: " .. tostring(returned)
                })
                return
            end

            LouisHub:Notify({
                Title = "Interface",
                Icon = "info",
                Content = string.format("Overwrote config %q", selectedConfig),
            })
        end
    })

    secSettings:Button({
        Text = "Refresh Config List",
        Tooltip = "Refresh the current config list.",
        Callback = function()
            if configSelection and configSelection.Refresh then
                configSelection:Refresh(LouisHub.SaveManager:List())
            end
        end,
    })

    local loadLabel
    secSettings:Button({
        Text = "Set as autoload",
        Tooltip = "Set a config to auto load in your next session.",
        Callback = function()
            if not selectedConfig or not isFilesystemAvailable() then return end
            local name = selectedConfig
            pcall(function()
                writefile(LouisHub.Folder .. "/autoload.txt", name)
            end)
            if loadLabel then
                loadLabel:Set("Current autoload config: " .. name)
            end

            LouisHub:Notify({
                Title = "Interface",
                Icon = "info",
                Content = string.format("Set %q to auto load", name),
            })
        end,
    })

    loadLabel = secSettings:Paragraph({
        Title = "Current Auto Load",
        Content = "None"
    })

    secSettings:Button({
        Text = "Delete Autoload",
        Tooltip = "Delete the autoload config pointer file.",
        Callback = function()
            if isFilesystemAvailable() and type(isfile) == "function" and isfile(LouisHub.Folder .. "/autoload.txt") then
                pcall(delfile, LouisHub.Folder .. "/autoload.txt")
            end
            if loadLabel then
                loadLabel:Set("None")
            end

            LouisHub:Notify({
                Title = "Interface",
                Icon = "info",
                Content = "Deleted Autoload file.",
            })
        end,
    })

    if isFilesystemAvailable() and type(isfile) == "function" and isfile(LouisHub.Folder .. "/autoload.txt") then
        local okRead, name = pcall(readfile, LouisHub.Folder .. "/autoload.txt")
        if okRead and name and loadLabel then
            loadLabel:Set("Current autoload config: " .. name)
        end
    end
end

local function buildThemeSection(tab)
    local secEditor = tab:CreateSection("Custom Gradient Editor", { Columns = 1 })

    local c1cp = secEditor:ColorPicker({
        Text = "Color 1 (Accent)",
        Color = Theme.Accent,
    })

    local c2cp = secEditor:ColorPicker({
        Text = "Color 2 (Accent Light)",
        Color = Theme.AccentLight,
    })

    local c3cp = secEditor:ColorPicker({
        Text = "Color 3 (Highlight)",
        Color = Theme.Highlight,
    })

    local function updateGradient()
        local c1 = (c1cp and c1cp:Get()) or Theme.Accent
        local c2 = (c2cp and c2cp:Get()) or Theme.AccentLight
        local c3 = (c3cp and c3cp:Get()) or Theme.Highlight

        LouisHub.ThemeManager:ApplyAccentGradient({c1, c2, c3})
    end

    task.spawn(function()
        task.wait(0.2)
        if c1cp then c1cp.Callback = updateGradient end
        if c2cp then c2cp.Callback = updateGradient end
        if c3cp then c3cp.Callback = updateGradient end
    end)

    local secPresets = tab:CreateSection("Preset Gradients", { Columns = 2 })

    for presetName, colors in pairs(PresetGradients) do
        secPresets:Button({
            Text = tostring(presetName),
            Callback = function()
                if c1cp then c1cp:Set(colors[1], false) end
                if c2cp then c2cp:Set(colors[2], false) end
                if c3cp then c3cp:Set(colors[3], false) end
                LouisHub.ThemeManager:ApplyAccentGradient(presetName)
            end,
        })
    end
end

-- ══════════════════════════════════════════════════════════════
--  SECTION 28: PREINSTALLED SYSTEM & HARDWARE DIAGNOSTICS TAB
-- ══════════════════════════════════════════════════════════════
local function addCompletePreinstalledTab(Window, cfg)
    cfg = cfg or {}

    local catSystem = Window.Categories["System"] or Window:CreateCategory({ Name = "System", Icon = "settings" })
    local sysTab = catSystem:CreateTab({
        Name = cfg.Name or "Preinstalled",
        Icon = "settings",
        ShowTitle = true
    })

    local secInfo = sysTab:CreateSection("Information", { Columns = 2 })
    secInfo:Label({ Text = "Executor", Value = detectExecutor(), Column = 1 })
    secInfo:Label({ Text = "LouisHub Version", Value = LouisHub.Version, Column = 1 })
    secInfo:Label({ Text = "Engineered By", Value = "LouisHub", Column = 1 })

    local lblFps = secInfo:Label({ Text = "FPS", Value = "–", Column = 2 })
    local lblFrameTime = secInfo:Label({ Text = "Frame Time", Value = "–", Column = 2 })
    local lblState = secInfo:Label({ Text = "State", Value = "–", Column = 2 })
    secInfo:Label({
        Text    = "Interface Health",
        Value   = "🟢 Optimal",
        Tooltip = "Evaluates memory footprint, instance lifecycle, and framerate stability.",
        Column  = 2
    })

    local statsOk, statsService = pcall(function() return game:GetService("Stats") end)
    local lblMemory = nil
    if statsOk and statsService then
        lblMemory = secInfo:Label({ Text = "Memory Usage", Value = "–", Column = 1 })
    end

    local lastTick, frames = os.clock(), 0
    LouisHub:RegisterConnection(RunService.Heartbeat:Connect(function()
        frames = frames + 1
        local now = os.clock()
        if now - lastTick >= 1 then
            local delta = now - lastTick
            local fps = math.round(frames / delta)
            local ft = math.round((delta / frames) * 1000 * 10) / 10
            lblFps:Set(fps .. " FPS")
            lblFrameTime:Set(ft .. " ms")

            if fps >= 50 then lblState:Set("🟢 Excellent")
            elseif fps >= 30 then lblState:Set("🟡 Normal")
            else lblState:Set("🔴 Degraded") end

            if lblMemory then
                local okMem, m = pcall(function() return statsService:GetTotalMemoryUsageMb() end)
                if okMem and m then lblMemory:Set("~" .. math.round(m) .. " MB") end
            end

            frames, lastTick = 0, now
        end
    end))

    local secDiag = sysTab:CreateSection("Hardware Diagnostics", { Columns = 2 })
    local C = LouisHub.Capabilities
    secDiag:Label({ Text = "Device Type", Value = C.Type .. " (" .. C:PlatformName() .. ")", Column = 1 })
    secDiag:Label({ Text = "Screen Resolution", Value = math.floor(C.ViewportSize.X) .. "x" .. math.floor(C.ViewportSize.Y), Column = 1 })

    local fSupported, fTotal = 0, 0
    for _, f in ipairs(LouisHub.Features) do
        fTotal = fTotal + 1
        if LouisHub:VerifySupport(f.name).ok then fSupported = fSupported + 1 end
    end
    secDiag:Label({ Text = "Supported Features", Value = fSupported .. " / " .. fTotal, Column = 2 })

    secDiag:Dropdown({
        Text = "Force Device Emulation",
        Options = {"Auto", "PC", "Mobile", "Tablet", "Console"},
        Default = _G.LouisHub_ForcedType or "Auto",
        Column = 2,
        Callback = function(v)
            if v == "Auto" then LouisHub:ReleaseForcedType() else LouisHub:ForceType(v) end
        end
    })

    local secAp = sysTab:CreateSection("Appearance & Dimensions", { Columns = 2 })
    local themeNames = {}
    for n in pairs(LouisHub.ThemeManager.Themes) do table.insert(themeNames, n) end
    table.sort(themeNames)

    secAp:Dropdown({
        Text = "Base Theme Palette",
        Flag = "sys_theme",
        Options = themeNames,
        Default = Themes.Default,
        Column = 1,
        Callback = function(v)
            LouisHub.ThemeManager:ApplyBaseTheme(v)
            LouisHub:Notify({ Title = "Appearance", Content = "Base theme " .. v .. " applied.", Duration = 2 })
            LouisHub.SaveManager:SaveUI("preinstalled")
        end
    })

    local presetList = {}
    for n in pairs(PresetGradients) do table.insert(presetList, n) end
    table.sort(presetList)

    secAp:Dropdown({
        Text = "Accent Gradient Preset",
        Flag = "sys_accent_preset",
        Options = presetList,
        Default = presetList[1] or "Nightlight (Classic)",
        Column = 1,
        Callback = function(v)
            LouisHub.ThemeManager:ApplyAccentGradient(v)
            LouisHub:Notify({ Title = "Appearance", Content = "Accent gradient " .. v .. " applied.", Duration = 2 })
            LouisHub.SaveManager:SaveUI("preinstalled")
        end
    })

    secAp:Slider({
        Text = "Interface Scale",
        Flag = "sys_scale",
        Min = 70, Max = 130, Increment = 5, Suffix = "%", Default = 100,
        Column = 2,
        Callback = function(v)
            if Window._main and Window._main:FindFirstChildOfClass("UIScale") then
                Window._main:FindFirstChildOfClass("UIScale").Scale = (v / 100)
            end
            LouisHub.SaveManager:SaveUI("preinstalled")
        end
    })

    secAp:Slider({
        Text = "Window Width",
        Flag = "sys_width",
        Min = 70, Max = 130, Increment = 5, Suffix = "%", Default = 100,
        Column = 2,
        Callback = function(v)
            local factor = v / 100
            local newWidth = 620 * factor
            Utils.Tween(Window._main, {Size = UDim2.new(0, newWidth, 0, Window._main.Size.Y.Offset)}, 0.2)
            LouisHub.SaveManager:SaveUI("preinstalled")
        end
    })

    secAp:Slider({
        Text = "Window Height",
        Flag = "sys_height",
        Min = 70, Max = 130, Increment = 5, Suffix = "%", Default = 100,
        Column = 2,
        Callback = function(v)
            local factor = v / 100
            local newHeight = 380 * factor
            Utils.Tween(Window._main, {Size = UDim2.new(0, Window._main.Size.X.Offset, 0, newHeight)}, 0.2)
            LouisHub.SaveManager:SaveUI("preinstalled")
        end
    })

    LouisHub:MarkAsUI({"sys_theme", "sys_accent_preset", "sys_scale", "sys_width", "sys_height"})

    local secProfiles = sysTab:CreateSection("Profiles & Storage", { Columns = 2 })
    local selectedProfile = nil

    local dropP = secProfiles:Dropdown({
        Text = "Profile",
        Options = LouisHub.SaveManager:List(),
        Column = 1,
        Callback = function(v) selectedProfile = v end
    })

    secProfiles:Button({
        Text = "Load Selected Profile",
        Column = 1,
        Callback = function()
            if selectedProfile then LouisHub.SaveManager:Load(selectedProfile) end
        end
    })

    local newProfileName = ""
    secProfiles:Input({
        Text = "New Profile Name",
        Placeholder = "Name...",
        Column = 2,
        Callback = function(v) newProfileName = v end
    })

    secProfiles:Button({
        Text = "Save New Profile",
        Column = 2,
        Callback = function()
            if newProfileName ~= "" then
                LouisHub.SaveManager:Save(newProfileName)
                if dropP and dropP.Refresh then
                    dropP:Refresh(LouisHub.SaveManager:List())
                end
            end
        end
    })

    local secHistory = sysTab:CreateSection("Modification History", { Columns = 2 })
    local lblHist = secHistory:Label({ Text = "Status", Value = "No changes", Column = 1 })

    LouisHub:RegisterConnection(LouisHub.Events.HistoryChanged:Connect(function(u, r)
        lblHist:Set(u .. " Undo · " .. r .. " Redo")
    end))

    secHistory:Button({
        Text = "↩️ Undo",
        Column = 2,
        Callback = function() LouisHub:Undo() end
    })

    secHistory:Button({
        Text = "↪️ Redo",
        Column = 2,
        Callback = function() LouisHub:Redo() end
    })

    return sysTab
end

-- ══════════════════════════════════════════════════════════════
--  SECTION 29: PIPELINE INITIALIZATION & FINAL EXPORTS
-- ══════════════════════════════════════════════════════════════
local _originalCreateWindow = LouisHub.CreateWindow
function LouisHub:CreateWindow(config)
    config = config or {}
    local Window = _originalCreateWindow(self, config)

    function Window:CreateHomeTab(hSettings)
        return createLunaHomeTab(Window, hSettings)
    end

    local catSystem = Window:CreateCategory({ Name = "System", Icon = "settings" })

    local tabConfig = catSystem:CreateTab({
        Name = "Config",
        Icon = "settings",
        ShowTitle = true
    })
    buildConfigSection(tabConfig)
    buildThemeSection(tabConfig)

    if config.PreinstalledTab ~= false then
        addCompletePreinstalledTab(Window, config)
    end

    return Window
end

if getgenv then
    getgenv().LouisHub = LouisHub
end

return LouisHub
