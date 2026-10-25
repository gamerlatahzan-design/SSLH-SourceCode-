--[[
    ╔══════════════════════════════════════════════════════════════════════╗
                                LouisHub Engine
                     Modern UI Suite & Execution Framework
                                 Version 5.0.0
                               Full English Core
    ╚══════════════════════════════════════════════════════════════════════╝
]]

-- =====================================================================
-- SECTION 1: LOW-LEVEL RUNTIME COMPATIBILITY & TASK POLYFILLS
-- =====================================================================
if type(task) ~= "table" then task = {} end

if type(task.wait) ~= "function" then
    task.wait = function(duration)
        if type(wait) == "function" then return wait(duration) end
        return duration or 0
    end
end

if type(task.spawn) ~= "function" then
    task.spawn = function(func, ...)
        if type(spawn) == "function" then
            return spawn(function(...) func(...) end, ...)
        end
        local thread = coroutine.create(func)
        local success, result = coroutine.resume(thread, ...)
        if not success then
            warn("[LouisHub Core] Polyfill task.spawn error: " .. tostring(result))
        end
        return thread
    end
end

if type(task.delay) ~= "function" then
    task.delay = function(duration, func, ...)
        local parameters = {...}
        if type(delay) == "function" then
            delay(duration, function() func(table.unpack(parameters)) end)
        else
            coroutine.wrap(function()
                if type(wait) == "function" then wait(duration) end
                func(table.unpack(parameters))
            end)()
        end
    end
end

if type(task.defer) ~= "function" then
    task.defer = task.spawn
end

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

local function cloneTable(targetTable)
    if type(targetTable) ~= "table" then return {} end
    if type(table.clone) == "function" then return table.clone(targetTable) end
    local cloned = {}
    for key, value in pairs(targetTable) do
        cloned[key] = value
    end
    return cloned
end

local function copyDefault(value)
    if type(value) == "table" then return cloneTable(value) end
    return value
end

local function normalizeArgSet(...)
    if select('#', ...) >= 2 then
        return (select(2, ...))
    end
    return (select(1, ...))
end

local function kwargify(defaults, passed)
    passed = passed or {}
    for key, value in pairs(defaults) do
        if passed[key] == nil then
            passed[key] = value
        end
    end
    return passed
end

local function packColor(color)
    return {R = color.R * 255, G = color.G * 255, B = color.B * 255}
end

local function unpackColor(color)
    return Color3.fromRGB(color.R, color.G, color.B)
end

-- =====================================================================
-- SECTION 2: ROBLOX ENGINE SERVICES & ENVIRONMENT INITIALIZATION
-- =====================================================================
local UserInputService    = game:GetService("UserInputService")
local TweenService        = game:GetService("TweenService")
local HttpService         = game:GetService("HttpService")
local RunService          = game:GetService("RunService")
local LocalizationService = game:GetService("LocalizationService")
local Players             = game:GetService("Players")
local Workspace           = game:GetService("Workspace")
local Lighting            = game:GetService("Lighting")
local CoreGui             = game:GetService("CoreGui")
local TextService         = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    pcall(function()
        LocalPlayer = Players.PlayerAdded:Wait()
    end)
end

local isStudio = RunService:IsStudio()
local executeRequest = (syn and syn.request) or (http and http.request) or http_request or nil

local function isFilesystemAvailable()
    return type(writefile) == "function" and type(readfile) == "function"
end

local function getGuiContainer()
    local successHui, hui = pcall(function() return gethui() end)
    if successHui and hui then return hui end

    if LocalPlayer then
        local successPgui, playerGui = pcall(function() return LocalPlayer:WaitForChild("PlayerGui", 5) end)
        if successPgui and playerGui then return playerGui end
    end

    local successCore, core = pcall(function() return CoreGui end)
    if successCore and core then return core end

    return nil
end

local function protectGuiElement(guiElement)
    pcall(function()
        if syn and syn.protect_gui then
            syn.protect_gui(guiElement)
        elseif protectgui then
            protectgui(guiElement)
        end
    end)
end

-- =====================================================================
-- SECTION 3: LOUISHUB NAMESPACE & DEEP CLEANUP REGISTRY
-- =====================================================================
local LouisHub = {}
LouisHub.Version = "5.0.0"
LouisHub.DebugMode = false
LouisHub.ShowUIErrors = true
LouisHub.ConfigFolder = "LouisHub/Config"

local function cleanupPreviousInstance()
    local previous = _G.LouisHub_Instance
    if type(previous) ~= "table" then return end

    if type(previous.Connections) == "table" then
        for _, connection in ipairs(previous.Connections) do
            pcall(function()
                if connection and connection.Connected then
                    connection:Disconnect()
                end
            end)
        end
    end

    if type(previous.Threads) == "table" then
        for _, thread in ipairs(previous.Threads) do
            pcall(function()
                if thread and coroutine.status(thread) ~= "dead" then
                    task.cancel(thread)
                end
            end)
        end
    end

    if type(previous.Drawings) == "table" then
        for _, drawingObject in ipairs(previous.Drawings) do
            pcall(function()
                if drawingObject then
                    drawingObject:Remove()
                end
            end)
        end
    end

    if type(previous.Instances) == "table" then
        for _, instanceObject in ipairs(previous.Instances) do
            pcall(function()
                if instanceObject and instanceObject.Parent then
                    instanceObject:Destroy()
                end
            end)
        end
    end

    pcall(function()
        local container = getGuiContainer()
        if container then
            local targets = {
                "LouisHub_ScreenGui",
                "LouisHub_NotificationGui",
                "LouisHub_TooltipOverlay",
                "LouisHub_PopupGui",
                "LouisHubGlobalDOF"
            }
            for _, guiName in ipairs(targets) do
                local found = container:FindFirstChild(guiName)
                if found then found:Destroy() end
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

function LouisHub:DisconnectConnection(connection)
    if not connection then return end
    pcall(function() connection:Disconnect() end)
    if _G.LouisHub_Instance then
        local connectionList = _G.LouisHub_Instance.Connections
        local index = table.find(connectionList, connection)
        if index then table.remove(connectionList, index) end
    end
end

function LouisHub:RegisterThread(thread)
    if _G.LouisHub_Instance and thread then
        table.insert(_G.LouisHub_Instance.Threads, thread)
    end
    return thread
end

function LouisHub:RegisterDrawing(drawingObject)
    if _G.LouisHub_Instance and drawingObject then
        table.insert(_G.LouisHub_Instance.Drawings, drawingObject)
    end
    return drawingObject
end

function LouisHub:RegisterInstance(instanceObject)
    if _G.LouisHub_Instance and instanceObject then
        table.insert(_G.LouisHub_Instance.Instances, instanceObject)
    end
    return instanceObject
end

-- =====================================================================
-- SECTION 4: ERROR LOGGING & PROTECTED CALL ENGINE
-- =====================================================================
local MAX_ERROR_LOGS = 50
LouisHub._Logs = {}

function LouisHub:_LogError(context, message)
    table.insert(self._Logs, {
        Time    = os.time(),
        Context = tostring(context or "Unknown Context"),
        Message = tostring(message or "Unknown Error"),
    })
    if #self._Logs > MAX_ERROR_LOGS then
        table.remove(self._Logs, 1)
    end
    warn("[LouisHub] Error in '" .. tostring(context or "Unknown Context") .. "': " .. tostring(message or ""))
end

function LouisHub:GetErrors()
    local errorDump = {}
    for index, entry in ipairs(self._Logs) do
        errorDump[index] = cloneTable(entry)
    end
    return errorDump
end

local function silentTry(description, targetFunction, ...)
    local success, result = pcall(targetFunction, ...)
    if not success and LouisHub.DebugMode then
        warn("[LouisHub Debug] '" .. tostring(description) .. "' failed: " .. tostring(result))
    end
    return success, result
end

local function warnDeveloper(controlType, controlName, message)
    warn(string.format("[LouisHub Dev] %s \"%s\": %s", tostring(controlType), tostring(controlName or "Unnamed"), tostring(message)))
end

local function executeWithFallback(callback, context, ...)
    if not callback then return end
    local arguments = {...}
    local success, executionError = pcall(function()
        return callback(table.unpack(arguments))
    end)
    if not success then
        LouisHub:_LogError(context, executionError)
        local rawErrorString = tostring(executionError)
        local displayString = rawErrorString:sub(1, 120)
        if #rawErrorString > 120 then
            displayString = displayString .. "... (Inspect LouisHub:GetErrors())"
        end
        if LouisHub.ShowUIErrors ~= false and LouisHub.Notify then
            pcall(function()
                LouisHub:Notify({
                    Title    = "Error in " .. tostring(context or "Control"),
                    Content  = displayString,
                    Duration = 6,
                    Icon     = "warning"
                })
            end)
        end
        warn("[LouisHub Callback Error] Context: (" .. tostring(context or "Unknown") .. "):", executionError)
    end
    return success
end

local function validateCallback(controlType, configuration)
    if configuration.Callback ~= nil and type(configuration.Callback) ~= "function" then
        warnDeveloper(controlType, configuration.Text or configuration.Name, "'Callback' provided is not a function (got " .. typeof(configuration.Callback) .. "). Ignored.")
        configuration.Callback = nil
    end
end

-- =====================================================================
-- SECTION 5: HARDWARE CAPABILITIES, ENVIRONMENT & PROFILER
-- =====================================================================
local function detectExecutor()
    if type(getexecutorname) == "function" then
        local success, name = pcall(getexecutorname)
        if success and name and name ~= "" then return name end
    end
    local detectionList = {
        {function() return syn ~= nil end, "Synapse X"},
        {function() return krnl ~= nil end, "Krnl"},
        {function() return fluxus ~= nil end, "Fluxus"},
        {function() return sirhurt ~= nil end, "SirHurt"},
        {function() return PROTOSMASHER_LOADED ~= nil end, "ProtoSmasher"},
        {function() return is_sirhurt_closure ~= nil end, "SirHurt (alt)"},
        {function() return identifyexecutor ~= nil end, (identifyexecutor and identifyexecutor()) or "Identified Executor"},
    }
    for _, item in ipairs(detectionList) do
        local ok, matched = pcall(item[1])
        if ok and matched then return item[2] end
    end
    return isStudio and "Roblox Studio" or "Unknown Executor"
end

local validEnvironmentTypes = {
    PC = true,
    Mobile = true,
    Tablet = true,
    Console = true,
    Studio = true,
    Unknown = true,
}

LouisHub.Capabilities = {
    Filesystem   = isFilesystemAvailable(),
    Drawing      = type(Drawing) == "table" and type(Drawing.new) == "function",
    ProtectGUI   = (type(syn) == "table" and type(syn.protect_gui) == "function") or type(protectgui) == "function",
    GetHUI       = type(gethui) == "function",
    Keyboard     = UserInputService.KeyboardEnabled,
    Gamepad      = UserInputService.GamepadEnabled,
    IsStudio     = isStudio,
    TouchEnabled = UserInputService.TouchEnabled,
    MouseEnabled = UserInputService.MouseEnabled,
    Platform     = (function()
        local success, platform = pcall(function() return UserInputService:GetPlatform() end)
        return (success and platform) or nil
    end)(),
    ViewportSize = (function()
        local cam = Workspace.CurrentCamera
        return cam and cam.ViewportSize or Vector2.new(0, 0)
    end)(),
    Type         = "Unknown",
    IsTouch      = false,
    IsDesktop    = false,
    IsTouchOnly  = false,
}

function LouisHub.Capabilities:PlatformName()
    local platform = self.Platform
    if not platform then return "Unknown" end
    return platform.Name or tostring(platform)
end

function LouisHub:RecalculateEnvironmentDerivatives()
    local capabilities = self.Capabilities
    local consolePlatforms = {
        XboxOne = true, XboxSeriesX = true, XboxSeriesS = true,
        PS4 = true, PS5 = true, UWP = true,
    }
    local platformName = capabilities.Platform and capabilities.Platform.Name
    local detectedType

    if _G.LouisHub_ForcedType and validEnvironmentTypes[_G.LouisHub_ForcedType] then
        detectedType = _G.LouisHub_ForcedType
    elseif capabilities.IsStudio then
        detectedType = "Studio"
    elseif platformName and consolePlatforms[platformName] then
        detectedType = "Console"
    elseif capabilities.MouseEnabled and capabilities.Keyboard then
        detectedType = "PC"
    elseif capabilities.TouchEnabled then
        if capabilities.ViewportSize.Y < 500 or capabilities.ViewportSize.X < 600 then
            detectedType = "Mobile"
        else
            detectedType = "Tablet"
        end
    elseif capabilities.Keyboard then
        detectedType = "PC"
    else
        detectedType = "Unknown"
    end

    capabilities.Type        = detectedType
    capabilities.IsTouch     = (detectedType == "Mobile" or detectedType == "Tablet")
    capabilities.IsDesktop   = (detectedType == "PC" or detectedType == "Console")
    capabilities.IsTouchOnly = capabilities.TouchEnabled and not capabilities.MouseEnabled and not capabilities.Keyboard

    if self.Events and self.Events.TypeChanged then
        self.Events.TypeChanged:Fire(detectedType)
    end
    return detectedType
end

LouisHub:RecalculateEnvironmentDerivatives()

local function hookViewportCapabilities(camera)
    if not camera then return end
    LouisHub:RegisterConnection(
        camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            LouisHub.Capabilities.ViewportSize = camera.ViewportSize
            LouisHub:RecalculateEnvironmentDerivatives()
        end)
    )
end

hookViewportCapabilities(Workspace.CurrentCamera)
LouisHub:RegisterConnection(
    Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        local camera = Workspace.CurrentCamera
        if not camera then return end
        LouisHub.Capabilities.ViewportSize = camera.ViewportSize
        LouisHub:RecalculateEnvironmentDerivatives()
        hookViewportCapabilities(camera)
    end)
)

LouisHub.Features = {
    { name = "GUI",          test = function() return true end, level = "required" },
    { name = "Filesystem",   capKey = "Filesystem",    level = "recommended", message = "Configurations will not save to disk." },
    { name = "Drawing",      capKey = "Drawing",       level = "recommended", message = "Visual ESP components will not function." },
    { name = "ProtectGUI",   capKey = "ProtectGUI",    level = "recommended", message = "GUI might be detected by client checks." },
    { name = "GetHUI",       capKey = "GetHUI",        level = "recommended", message = "GUI might render behind CoreGui elements." },
    { name = "Keyboard",     capKey = "Keyboard",      level = "optional",    message = "Keybinds will default to touch-cancel mode." },
    { name = "Gamepad",      capKey = "Gamepad",       level = "optional",    message = "Gamepad shortcuts will be unavailable." },
    { name = "Loadstring",   test = function() return type(loadstring) == "function" end, level = "optional", message = "External scripts cannot be evaluated." },
    { name = "SetClipboard", test = function() return type(setclipboard) == "function" end, level = "optional", message = "Cannot copy text to system clipboard." },
}

local featuresIndex = {}
for _, feature in ipairs(LouisHub.Features) do
    featuresIndex[feature.name] = feature
end

function LouisHub:VerifySupport(featureName)
    local targetFeature = featuresIndex[featureName]
    if not targetFeature then
        return { ok = false, level = "unknown", name = featureName, message = "Feature not recognized by LouisHub." }
    end
    local isSupported = false
    if targetFeature.capKey then
        isSupported = self.Capabilities[targetFeature.capKey] == true
    elseif targetFeature.test then
        local success, result = pcall(targetFeature.test)
        isSupported = success and result == true
    end
    return { ok = isSupported, level = targetFeature.level, name = targetFeature.name, message = isSupported and nil or targetFeature.message }
end

function LouisHub:ForceType(envType)
    if envType and not validEnvironmentTypes[envType] then
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
    local capabilities = self.Capabilities
    local supportedCount, totalCount, warnings = 0, 0, {}
    for _, feature in ipairs(self.Features) do
        totalCount = totalCount + 1
        local result = self:VerifySupport(feature.name)
        if result.ok then
            supportedCount = supportedCount + 1
        elseif feature.level ~= "required" then
            table.insert(warnings, {
                name    = feature.name,
                level   = feature.level,
                message = result.message,
            })
        end
    end
    return {
        Type          = capabilities.Type,
        Platform      = capabilities:PlatformName(),
        IsStudio      = capabilities.IsStudio,
        Executor      = detectExecutor(),
        Viewport      = capabilities.ViewportSize,
        ForcedType    = _G.LouisHub_ForcedType,
        FeaturesOk    = supportedCount,
        FeaturesTotal = totalCount,
        Warnings      = warnings,
        Capabilities  = capabilities,
    }
end

function LouisHub:Profiler()
    local data = {
        Flags       = 0,
        Elements    = 0,
        Connections = 0,
        Threads     = 0,
        Drawings    = 0,
        Instances   = 0,
        GuiObjects  = 0,
        MemoryMb    = nil,
    }
    if LouisHub.Flags then
        for _ in pairs(LouisHub.Flags) do data.Flags = data.Flags + 1 end
    end
    if LouisHub.Elements then
        for _ in pairs(LouisHub.Elements) do data.Elements = data.Elements + 1 end
    end
    local instanceRecord = _G.LouisHub_Instance
    if instanceRecord then
        data.Connections = #(instanceRecord.Connections or {})
        data.Threads     = #(instanceRecord.Threads or {})
        data.Drawings    = #(instanceRecord.Drawings or {})
        data.Instances   = #(instanceRecord.Instances or {})
    end
    local okGui, parentGui = pcall(getGuiContainer)
    if okGui and parentGui then
        local screenGui = parentGui:FindFirstChild("LouisHub_ScreenGui")
        if screenGui then
            local okDesc, descendants = pcall(function() return screenGui:GetDescendants() end)
            if okDesc then data.GuiObjects = #descendants end
        end
    end
    local okStats, statsService = pcall(function() return game:GetService("Stats") end)
    if okStats and statsService then
        local okMem, memoryUsage = pcall(function() return statsService:GetTotalMemoryUsageMb() end)
        if okMem and type(memoryUsage) == "number" and memoryUsage > 0 then
            data.MemoryMb = math.floor(memoryUsage + 0.5)
        end
    end
    print(string.format("[LouisHub Profiler] Flags:%d | Elements:%d | Connections:%d | Threads:%d | Drawings:%d | Instances:%d | GuiObjects:%d | Memory:%s",
        data.Flags, data.Elements, data.Connections, data.Threads,
        data.Drawings, data.Instances, data.GuiObjects,
        data.MemoryMb and ("~" .. data.MemoryMb .. "MB") or "N/A"))
    return data
end

-- =====================================================================
-- SECTION 6: ISOLATED GLASSMORPHISM SHADER ENGINE
-- =====================================================================
local singletonDepthOfField = nil
local activeBlurCount = 0

local function ensureDepthOfField()
    if singletonDepthOfField and singletonDepthOfField.Parent then
        return singletonDepthOfField
    end
    singletonDepthOfField = Instance.new("DepthOfFieldEffect")
    singletonDepthOfField.Name = "LouisHubGlobalDOF"
    singletonDepthOfField.FarIntensity = 0
    singletonDepthOfField.FocusDistance = 51.6
    singletonDepthOfField.InFocusRadius = 50
    singletonDepthOfField.NearIntensity = 4
    singletonDepthOfField.Parent = Lighting
    LouisHub:RegisterInstance(singletonDepthOfField)
    return singletonDepthOfField
end

local function attachGlassShader(targetFrame)
    local currentCamera = Workspace.CurrentCamera
    local materialType = "Glass"
    local shaderRoot = Instance.new("Folder", currentCamera)
    shaderRoot.Name = "LouisHubBlur"
    LouisHub:RegisterInstance(shaderRoot)

    ensureDepthOfField()
    activeBlurCount = activeBlurCount + 1

    local placeholderFrame = Instance.new("Frame")
    placeholderFrame.Parent = targetFrame
    placeholderFrame.Size = UDim2.new(1, 0, 1, 0)
    placeholderFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    placeholderFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    placeholderFrame.BackgroundTransparency = 1

    local generateUniqueId
    do
        local counter = 0
        function generateUniqueId()
            counter = counter + 1
            return "louishub::glass::" .. tostring(counter)
        end
    end

    local drawQuadSurface
    do
        local acos, max, pi, sqrt = math.acos, math.max, math.pi, math.sqrt
        local wedgeScale = 0.22

        local function drawTriangle(vertex1, vertex2, vertex3, part0, part1)
            local dist1 = (vertex1 - vertex2).Magnitude
            local dist2 = (vertex2 - vertex3).Magnitude
            local dist3 = (vertex3 - vertex1).Magnitude
            local maxDist = max(dist1, dist2, dist3)
            local pointA, pointB, pointC

            if dist1 == maxDist then
                pointA, pointB, pointC = vertex1, vertex2, vertex3
            elseif dist2 == maxDist then
                pointA, pointB, pointC = vertex2, vertex3, vertex1
            else
                pointA, pointB, pointC = vertex3, vertex1, vertex2
            end

            local para = ((pointB - pointA).X * (pointC - pointA).X + (pointB - pointA).Y * (pointC - pointA).Y + (pointB - pointA).Z * (pointC - pointA).Z) / (pointA - pointB).Magnitude
            local perp = sqrt((pointC - pointA).Magnitude^2 - para * para)
            local difPara = (pointA - pointB).Magnitude - para
            local standardFrame = CFrame.new(pointB, pointA)
            local angleAdjustment = CFrame.Angles(pi / 2, 0, 0)
            local topLook = (standardFrame * angleAdjustment).LookVector
            local midPoint = pointA + CFrame.new(pointA, pointB).LookVector * para
            local neededLook = CFrame.new(midPoint, pointC).LookVector
            local dotProduct = topLook.X * neededLook.X + topLook.Y * neededLook.Y + topLook.Z * neededLook.Z
            local angleCos = CFrame.Angles(0, 0, acos(dotProduct))

            local frame0 = standardFrame * angleCos
            if ((frame0 * angleAdjustment).LookVector - neededLook).Magnitude > 0.01 then
                frame0 = frame0 * CFrame.Angles(0, 0, -2 * acos(dotProduct))
            end
            frame0 = frame0 * CFrame.new(0, perp / 2, -(difPara + para / 2))

            local frame1 = standardFrame * angleCos * CFrame.Angles(0, pi, 0)
            if ((frame1 * angleAdjustment).LookVector - neededLook).Magnitude > 0.01 then
                frame1 = frame1 * CFrame.Angles(0, 0, 2 * acos(dotProduct))
            end
            frame1 = frame1 * CFrame.new(0, perp / 2, difPara / 2)

            if not part0 then
                part0 = Instance.new("Part")
                part0.TopSurface = Enum.SurfaceType.Smooth
                part0.BottomSurface = Enum.SurfaceType.Smooth
                part0.Anchored = true
                part0.CanCollide = false
                part0.CastShadow = false
                part0.Material = materialType
                part0.Size = Vector3.new(wedgeScale, wedgeScale, wedgeScale)
                local mesh = Instance.new("SpecialMesh", part0)
                mesh.MeshType = Enum.MeshType.Wedge
                mesh.Name = "WedgeMesh"
            end
            part0.WedgeMesh.Scale = Vector3.new(0, perp / wedgeScale, para / wedgeScale)
            part0.CFrame = frame0

            if not part1 then part1 = part0:Clone() end
            part1.WedgeMesh.Scale = Vector3.new(0, perp / wedgeScale, difPara / wedgeScale)
            part1.CFrame = frame1
            return part0, part1
        end

        function drawQuadSurface(vert1, vert2, vert3, vert4, partsArray)
            partsArray[1], partsArray[2] = drawTriangle(vert1, vert2, vert3, partsArray[1], partsArray[2])
            partsArray[3], partsArray[4] = drawTriangle(vert3, vert2, vert4, partsArray[3], partsArray[4])
        end
    end

    local uniqueRenderId = generateUniqueId()
    local wedgeParts = {}
    local shaderContainer = Instance.new("Folder", shaderRoot)
    shaderContainer.Name = placeholderFrame.Name

    local ancestors = {}
    local function collectAncestors(child)
        if child:IsA("GuiObject") then
            ancestors[#ancestors + 1] = child
            collectAncestors(child.Parent)
        end
    end
    collectAncestors(placeholderFrame)

    local function updateShaderOrientation(fetchProperties)
        if not (placeholderFrame and placeholderFrame.Parent and targetFrame and targetFrame.Parent) then
            pcall(function() RunService:UnbindFromRenderStep(uniqueRenderId) end)
            pcall(function() shaderRoot:Destroy() end)
            return
        end

        local isAncestorVisible = true
        local current = targetFrame
        while current do
            if current:IsA("GuiObject") and not current.Visible then
                isAncestorVisible = false
                break
            end
            current = current.Parent
        end

        if not isAncestorVisible or targetFrame.AbsoluteSize.X <= 0 or targetFrame.AbsoluteSize.Y <= 0 then
            for _, wedge in pairs(wedgeParts) do wedge.CFrame = CFrame.new(0, 100000, 0) end
            return
        end

        local properties = {
            Transparency = 0.98,
            BrickColor = BrickColor.new("Institutional white"),
        }
        local zIndexDepth = 1 - 0.05 * math.clamp(placeholderFrame.ZIndex, 1, 10)
        local topLeft = placeholderFrame.AbsolutePosition
        local bottomRight = placeholderFrame.AbsolutePosition + placeholderFrame.AbsoluteSize
        local topRight = Vector2.new(bottomRight.X, topLeft.Y)
        local bottomLeft = Vector2.new(topLeft.X, bottomRight.Y)

        do
            local totalRotation = 0
            for _, ancestor in ipairs(ancestors) do totalRotation = totalRotation + ancestor.Rotation end
            if totalRotation ~= 0 and totalRotation % 180 ~= 0 then
                local midpoint = topLeft:Lerp(bottomRight, 0.5)
                local sinVal, cosVal = math.sin(math.rad(totalRotation)), math.cos(math.rad(totalRotation))
                topLeft = Vector2.new(cosVal * (topLeft.X - midpoint.X) - sinVal * (topLeft.Y - midpoint.Y), sinVal * (topLeft.X - midpoint.X) + cosVal * (topLeft.Y - midpoint.Y)) + midpoint
                topRight = Vector2.new(cosVal * (topRight.X - midpoint.X) - sinVal * (topRight.Y - midpoint.Y), sinVal * (topRight.X - midpoint.X) + cosVal * (topRight.Y - midpoint.Y)) + midpoint
                bottomLeft = Vector2.new(cosVal * (bottomLeft.X - midpoint.X) - sinVal * (bottomLeft.Y - midpoint.Y), sinVal * (bottomLeft.X - midpoint.X) + cosVal * (bottomLeft.Y - midpoint.Y)) + midpoint
                bottomRight = Vector2.new(cosVal * (bottomRight.X - midpoint.X) - sinVal * (bottomRight.Y - midpoint.Y), sinVal * (bottomRight.X - midpoint.X) + cosVal * (bottomRight.Y - midpoint.Y)) + midpoint
            end
        end

        drawQuadSurface(
            currentCamera:ViewportPointToRay(topLeft.X, topLeft.Y, zIndexDepth).Origin,
            currentCamera:ViewportPointToRay(topRight.X, topRight.Y, zIndexDepth).Origin,
            currentCamera:ViewportPointToRay(bottomLeft.X, bottomLeft.Y, zIndexDepth).Origin,
            currentCamera:ViewportPointToRay(bottomRight.X, bottomRight.Y, zIndexDepth).Origin,
            wedgeParts
        )

        if fetchProperties then
            for _, wedge in pairs(wedgeParts) do wedge.Parent = shaderContainer end
            for propName, propValue in pairs(properties) do
                for _, wedge in pairs(wedgeParts) do wedge[propName] = propValue end
            end
        end
    end

    updateShaderOrientation(true)
    RunService:BindToRenderStep(uniqueRenderId, 2000, updateShaderOrientation)

    targetFrame.Destroying:Connect(function()
        pcall(function() RunService:UnbindFromRenderStep(uniqueRenderId) end)
        pcall(function() shaderRoot:Destroy() end)
        activeBlurCount = math.max(0, activeBlurCount - 1)
        if activeBlurCount <= 0 and singletonDepthOfField then
            pcall(function() singletonDepthOfField:Destroy() end)
            singletonDepthOfField = nil
        end
    end)

    return { Root = shaderRoot, Effect = singletonDepthOfField, Uid = uniqueRenderId }
end
LouisHub.AttachGlassShader = attachGlassShader

-- =====================================================================
-- SECTION 7: COMPLETE ICON MODULE (MATERIAL & LUCIDE MAPPINGS)
-- =====================================================================
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
        ["notifications_active"] = "http://www.roblox.com/asset/?id=6034304908",
        ["sentiment_neutral"] = "http://www.roblox.com/asset/?id=6034230636",
        ["sick"] = "http://www.roblox.com/asset/?id=6034230642",
        ["poll"] = "http://www.roblox.com/asset/?id=6034267991",
        ["emoji_events"] = "http://www.roblox.com/asset/?id=6034275726",
        ["groups"] = "http://www.roblox.com/asset/?id=6034281935",
        ["sports_soccer"] = "http://www.roblox.com/asset/?id=6034227075",
        ["person_add"] = "http://www.roblox.com/asset/?id=6034287514",
        ["mood_bad"] = "http://www.roblox.com/asset/?id=6034295706",
        ["person_remove_alt_1"] = "http://www.roblox.com/asset/?id=6034287515",
        ["king_bed"] = "http://www.roblox.com/asset/?id=6034281948",
        ["architecture"] = "http://www.roblox.com/asset/?id=6034275730",
        ["deck"] = "http://www.roblox.com/asset/?id=6034295703",
        ["group_add"] = "http://www.roblox.com/asset/?id=6034281909",
        ["sports_basketball"] = "http://www.roblox.com/asset/?id=6034230649",
        ["emoji_symbols"] = "http://www.roblox.com/asset/?id=6034281899",
        ["switch_account"] = "http://www.roblox.com/asset/?id=6034227138",
        ["remove_moderator"] = "http://www.roblox.com/asset/?id=6034267998",
        ["coronavirus"] = "http://www.roblox.com/asset/?id=6034275724",
        ["people"] = "http://www.roblox.com/asset/?id=6034287513",
        ["person"] = "http://www.roblox.com/asset/?id=6034287594",
        ["elderly"] = "http://www.roblox.com/asset/?id=6034295698",
        ["clean_hands"] = "http://www.roblox.com/asset/?id=6034275729",
        ["emoji_flags"] = "http://www.roblox.com/asset/?id=6034304898",
        ["psychology"] = "http://www.roblox.com/asset/?id=6034287516",
        ["person_add_alt"] = "http://www.roblox.com/asset/?id=6034267994",
        ["sports_volleyball"] = "http://www.roblox.com/asset/?id=6034227139",
        ["domain"] = "http://www.roblox.com/asset/?id=6034275722",
        ["emoji_objects"] = "http://www.roblox.com/asset/?id=6034281900",
        ["ios_share"] = "http://www.roblox.com/asset/?id=6034281941",
        ["history_edu"] = "http://www.roblox.com/asset/?id=6034281934",
        ["share"] = "http://www.roblox.com/asset/?id=6034230648",
        ["military_tech"] = "http://www.roblox.com/asset/?id=6034295711",
        ["sports_kabaddi"] = "http://www.roblox.com/asset/?id=6034227141",
        ["cake"] = "http://www.roblox.com/asset/?id=6034295702",
        ["engineering"] = "http://www.roblox.com/asset/?id=6034281908",
        ["emoji_food_beverage"] = "http://www.roblox.com/asset/?id=6034304883",
        ["notifications_none"] = "http://www.roblox.com/asset/?id=6034308947",
        ["emoji_people"] = "http://www.roblox.com/asset/?id=6034281904",
        ["thumb_down_alt"] = "http://www.roblox.com/asset/?id=6034227069",
        ["sentiment_very_satisfied"] = "http://www.roblox.com/asset/?id=6034230650",
        ["nights_stay"] = "http://www.roblox.com/asset/?id=6034304881",
        ["reduce_capacity"] = "http://www.roblox.com/asset/?id=6034268013",
        ["add_moderator"] = "http://www.roblox.com/asset/?id=6034295699",
        ["science"] = "http://www.roblox.com/asset/?id=6034230640",
        ["pages"] = "http://www.roblox.com/asset/?id=6034304892",
        ["sentiment_satisfied"] = "http://www.roblox.com/asset/?id=6034230668",
        ["plus_one"] = "http://www.roblox.com/asset/?id=6034268012",
        ["party_mode"] = "http://www.roblox.com/asset/?id=6034287521",
        ["person_remove"] = "http://www.roblox.com/asset/?id=6034267996",
        ["single_bed"] = "http://www.roblox.com/asset/?id=6034230651",
        ["mood"] = "http://www.roblox.com/asset/?id=6034295704",
        ["public"] = "http://www.roblox.com/asset/?id=6034287522",
        ["sports_rugby"] = "http://www.roblox.com/asset/?id=6034227073",
        ["sports_handball"] = "http://www.roblox.com/asset/?id=6034227074",
        ["person_add_alt_1"] = "http://www.roblox.com/asset/?id=6034287519",
        ["people_alt"] = "http://www.roblox.com/asset/?id=6034287518",
        ["notifications_off"] = "http://www.roblox.com/asset/?id=6034304894",
        ["whatshot"] = "http://www.roblox.com/asset/?id=6034287525",
        ["emoji_transportation"] = "http://www.roblox.com/asset/?id=6034281894",
        ["outdoor_grill"] = "http://www.roblox.com/asset/?id=6034304900",
        ["sentiment_very_dissatisfied"] = "http://www.roblox.com/asset/?id=6034230659",
        ["masks"] = "http://www.roblox.com/asset/?id=6034295710",
        ["luggage"] = "http://www.roblox.com/asset/?id=6034295708",
        ["sports_motorsports"] = "http://www.roblox.com/asset/?id=6034227071",
        ["sports_esports"] = "http://www.roblox.com/asset/?id=6034227061",
        ["location_city"] = "http://www.roblox.com/asset/?id=6034304889",
        ["sports_golf"] = "http://www.roblox.com/asset/?id=6034227060",
        ["sentiment_dissatisfied"] = "http://www.roblox.com/asset/?id=6034230637",
        ["no_luggage"] = "http://www.roblox.com/asset/?id=6034304891",
        ["fireplace"] = "http://www.roblox.com/asset/?id=6034281910",
        ["emoji_nature"] = "http://www.roblox.com/asset/?id=6034281896",
        ["group"] = "http://www.roblox.com/asset/?id=6034281901",
        ["thumb_up_alt"] = "http://www.roblox.com/asset/?id=6034227076",
        ["sports_tennis"] = "http://www.roblox.com/asset/?id=6034227068",
        ["facebook"] = "http://www.roblox.com/asset/?id=6034281898",
        ["sports_mma"] = "http://www.roblox.com/asset/?id=6034227072",
        ["person_outline"] = "http://www.roblox.com/asset/?id=6034268008",
        ["sports_baseball"] = "http://www.roblox.com/asset/?id=6034230652",
        ["sports_cricket"] = "http://www.roblox.com/asset/?id=6034230660",
        ["people_outline"] = "http://www.roblox.com/asset/?id=6034287528",
        ["notifications_paused"] = "http://www.roblox.com/asset/?id=6034304896",
        ["emoji_emotions"] = "http://www.roblox.com/asset/?id=6034275731",
        ["follow_the_signs"] = "http://www.roblox.com/asset/?id=6034281911",
        ["sanitizer"] = "http://www.roblox.com/asset/?id=6034287586",
        ["self_improvement"] = "http://www.roblox.com/asset/?id=6034230634",
        ["notifications"] = "http://www.roblox.com/asset/?id=6034308946",
        ["public_off"] = "http://www.roblox.com/asset/?id=6034287538",
        ["recommend"] = "http://www.roblox.com/asset/?id=6034287524",
        ["sports_football"] = "http://www.roblox.com/asset/?id=6034227067",
        ["sports_hockey"] = "http://www.roblox.com/asset/?id=6034227064",
        ["school"] = "http://www.roblox.com/asset/?id=6034230641",
        ["connect_without_contact"] = "http://www.roblox.com/asset/?id=6034275800",
        ["sports"] = "http://www.roblox.com/asset/?id=6034230647",
        ["construction"] = "http://www.roblox.com/asset/?id=6034275725",
        ["inventory"] = "http://www.roblox.com/asset/?id=6035056487",
        ["add_box"] = "http://www.roblox.com/asset/?id=6035047375",
        ["how_to_reg"] = "http://www.roblox.com/asset/?id=6035053288",
        ["unarchive"] = "http://www.roblox.com/asset/?id=6035078921",
        ["block_flipped"] = "http://www.roblox.com/asset/?id=6035047378",
        ["file_copy"] = "http://www.roblox.com/asset/?id=6035053293",
        ["bolt"] = "http://www.roblox.com/asset/?id=6035047381",
        ["remove_circle_outline"] = "http://www.roblox.com/asset/?id=6035067843",
        ["move_to_inbox"] = "http://www.roblox.com/asset/?id=6035067838",
        ["save_alt"] = "http://www.roblox.com/asset/?id=6035067842",
        ["weekend"] = "http://www.roblox.com/asset/?id=6035078894",
        ["where_to_vote"] = "http://www.roblox.com/asset/?id=6035078913",
        ["biotech"] = "http://www.roblox.com/asset/?id=6035047385",
        ["report_off"] = "http://www.roblox.com/asset/?id=6035067830",
        ["clear"] = "http://www.roblox.com/asset/?id=6035047409",
        ["redo"] = "http://www.roblox.com/asset/?id=6035056483",
        ["link"] = "http://www.roblox.com/asset/?id=6035056475",
        ["drafts"] = "http://www.roblox.com/asset/?id=6035053297",
        ["push_pin"] = "http://www.roblox.com/asset/?id=6035056481",
        ["reply"] = "http://www.roblox.com/asset/?id=6035067844",
        ["undo"] = "http://www.roblox.com/asset/?id=6035078896",
        ["archive"] = "http://www.roblox.com/asset/?id=6035047379",
        ["add"] = "http://www.roblox.com/asset/?id=6035047377",
        ["insights"] = "http://www.roblox.com/asset/?id=6035067839",
        ["flag"] = "http://www.roblox.com/asset/?id=6035053279",
        ["save"] = "http://www.roblox.com/asset/?id=6035067857",
        ["text_format"] = "http://www.roblox.com/asset/?id=6035078890",
        ["content_cut"] = "http://www.roblox.com/asset/?id=6035053280",
        ["ballot"] = "http://www.roblox.com/asset/?id=6035047386",
        ["remove"] = "http://www.roblox.com/asset/?id=6035067836",
        ["calculate"] = "http://www.roblox.com/asset/?id=6035047384",
        ["report"] = "http://www.roblox.com/asset/?id=6035067826",
        ["markunread"] = "http://www.roblox.com/asset/?id=6035056476",
        ["delete_sweep"] = "http://www.roblox.com/asset/?id=6035053301",
        ["gesture"] = "http://www.roblox.com/asset/?id=6035053287",
        ["link_off"] = "http://www.roblox.com/asset/?id=6035056484",
        ["forward"] = "http://www.roblox.com/asset/?id=6035053298",
        ["reply_all"] = "http://www.roblox.com/asset/?id=6035067824",
        ["how_to_vote"] = "http://www.roblox.com/asset/?id=6035053295",
        ["square_foot"] = "http://www.roblox.com/asset/?id=6035078918",
        ["outlined_flag"] = "http://www.roblox.com/asset/?id=6035056486",
        ["add_circle"] = "http://www.roblox.com/asset/?id=6035047380",
        ["stacked_bar_chart"] = "http://www.roblox.com/asset/?id=6035078892",
        ["policy"] = "http://www.roblox.com/asset/?id=6035056512",
        ["backspace"] = "http://www.roblox.com/asset/?id=6035047397",
        ["sort"] = "http://www.roblox.com/asset/?id=6035078888",
        ["content_paste"] = "http://www.roblox.com/asset/?id=6035053285",
        ["low_priority"] = "http://www.roblox.com/asset/?id=6035056491",
        ["font_download"] = "http://www.roblox.com/asset/?id=6035053275",
        ["shield"] = "http://www.roblox.com/asset/?id=6035078889",
        ["waves"] = "http://www.roblox.com/asset/?id=6035078898",
        ["select_all"] = "http://www.roblox.com/asset/?id=6035067834",
        ["dynamic_feed"] = "http://www.roblox.com/asset/?id=6035053289",
        ["mail"] = "http://www.roblox.com/asset/?id=6035056477",
        ["amp_stories"] = "http://www.roblox.com/asset/?id=6035047382",
        ["filter_list"] = "http://www.roblox.com/asset/?id=6035053294",
        ["send"] = "http://www.roblox.com/asset/?id=6035067832",
        ["create"] = "http://www.roblox.com/asset/?id=6035053304",
        ["stream"] = "http://www.roblox.com/asset/?id=6035078897",
        ["next_week"] = "http://www.roblox.com/asset/?id=6035067835",
        ["inbox"] = "http://www.roblox.com/asset/?id=6035067831",
        ["add_link"] = "http://www.roblox.com/asset/?id=6035047374",
        ["content_copy"] = "http://www.roblox.com/asset/?id=6035053278",
        ["remove_circle"] = "http://www.roblox.com/asset/?id=6035067837",
        ["add_circle_outline"] = "http://www.roblox.com/asset/?id=6035047391",
        ["block"] = "http://www.roblox.com/asset/?id=6035047387",
        ["tag"] = "http://www.roblox.com/asset/?id=6035078895",
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

local function resolveIcon(iconIdentifier, source)
    if not iconIdentifier or iconIdentifier == "" then return nil end
    source = source or "Material"
    local stringIcon = tostring(iconIdentifier)

    if source == "Custom" or string.find(stringIcon, "rbxassetid://") then
        return string.find(stringIcon, "rbxassetid://") and stringIcon or ("rbxassetid://" .. stringIcon)
    elseif source == "Lucide" then
        if isStudio then
            return "rbxassetid://10723434557"
        else
            local successData, iconData = pcall(function()
                return game:HttpGet("https://raw.githubusercontent.com/latte-soft/lucide-roblox/refs/heads/master/lib/Icons.luau")
            end)
            if successData and iconData then
                local successLoad, icons = pcall(loadstring(iconData))
                if successLoad and type(icons) == "table" then
                    local cleanName = string.match(string.lower(stringIcon), "^%s*(.*)%s*$")
                    local sizedIcons = icons['48px']
                    local targetRecord = sizedIcons and sizedIcons[cleanName]
                    if targetRecord and type(targetRecord[1]) == "number" then
                        return {
                            id = targetRecord[1],
                            imageRectSize = Vector2.new(targetRecord[2][1], targetRecord[2][2]),
                            imageRectOffset = Vector2.new(targetRecord[3][1], targetRecord[3][2])
                        }
                    end
                end
            end
            return nil
        end
    else
        local resolved = IconAliases[stringIcon] or stringIcon
        if IconModule.Material[resolved] then
            return IconModule.Material[resolved]
        end
        return nil
    end
end

LouisHub.GetIcon = resolveIcon

-- =====================================================================
-- SECTION 8: THEMES, GRADIENTS & DYNAMIC PALETTE SYSTEM
-- =====================================================================
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
for key, value in pairs(Themes.List[Themes.Default]) do
    Theme[key] = value
end
LouisHub.Theme = Theme

LouisHub.ThemeGradient = ColorSequence.new{
    ColorSequenceKeypoint.new(0.00, Theme.Accent),
    ColorSequenceKeypoint.new(0.50, Theme.AccentLight),
    ColorSequenceKeypoint.new(1.00, Theme.Highlight)
}

local themeRegistry = {}
local deadThemeEntries = 0

local function compactRegistry(registry)
    local pointer = 0
    for i = 1, #registry do
        local entry = registry[i]
        if not entry.dead then
            pointer = pointer + 1
            registry[pointer] = entry
        end
    end
    for i = #registry, pointer + 1, -1 do
        registry[i] = nil
    end
end

function LouisHub:RegisterThemeObject(instance, property, themeKey)
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
LouisHub.Register = LouisHub.RegisterThemeObject

-- =====================================================================
-- SECTION 9: MOTION, TWEEN ENGINE & EASING CONSTANTS
-- =====================================================================
LouisHub.Motion = {
    Instant        = 0,
    Press          = 0.14,
    Hover          = 0.25,
    HoverIntensity = 0.20,
    FlashIn        = 0.08,
    FlashOut       = 0.35,
    Expand         = 0.30,
    Modal          = 0.35,
    Page           = 0.30,
    Spin           = 0.60,
    EaseEnter      = Enum.EasingStyle.Exponential,
    EaseExit       = Enum.EasingStyle.Exponential,
    EasePop        = Enum.EasingStyle.Back,
    EaseSmooth     = Enum.EasingStyle.Exponential,
    EaseLinear     = Enum.EasingStyle.Linear,
}

local COLOR_FLASH_SUCCESS = Color3.fromRGB(46, 204, 113)
local COLOR_FLASH_ERROR   = Color3.fromRGB(231, 76, 60)

local activeTweens = setmetatable({}, {__mode = "k"})

local function getPropertyKey(properties)
    local names = {}
    for name in pairs(properties) do
        table.insert(names, name)
    end
    table.sort(names)
    return table.concat(names, ",")
end

local Utils = {}

function Utils.Tween(instance, properties, duration, style, direction, callback)
    if not instance or not instance.Parent then return nil end
    local key = getPropertyKey(properties)
    local perObject = activeTweens[instance]
    local previous = perObject and perObject[key]
    if previous then
        pcall(function() previous:Cancel() end)
    end

    if duration == 0 then
        pcall(function()
            for prop, val in pairs(properties) do
                instance[prop] = val
            end
        end)
        if callback then callback() end
        return nil
    end

    local info = TweenInfo.new(
        duration or LouisHub.Motion.Expand,
        style or LouisHub.Motion.EaseEnter,
        direction or Enum.EasingDirection.Out
    )
    local success, tweenObject = pcall(function()
        local tw = TweenService:Create(instance, info, properties)
        if callback then
            tw.Completed:Connect(callback)
        end
        tw:Play()
        return tw
    end)
    if success then
        activeTweens[instance] = activeTweens[instance] or {}
        activeTweens[instance][key] = tweenObject
    end
    return success and tweenObject or nil
end

local activeNumberTweens = setmetatable({}, {__mode = "k"})

function Utils.TweenNumber(fromValue, toValue, duration, callback, style, direction, key)
    if type(callback) ~= "function" then return end
    if fromValue == toValue then
        callback(toValue)
        return
    end

    local lookupKey = key or callback
    local previous = activeNumberTweens[lookupKey]
    if previous then
        pcall(function() previous.tween:Cancel() end)
        pcall(function() previous.valObj:Destroy() end)
    end

    local valObj = Instance.new("NumberValue")
    valObj.Value = fromValue
    local conn = valObj:GetPropertyChangedSignal("Value"):Connect(function()
        pcall(callback, valObj.Value)
    end)

    local info = TweenInfo.new(
        duration or 0.22,
        style or LouisHub.Motion.EaseEnter,
        direction or Enum.EasingDirection.Out
    )
    local success, tw = pcall(function()
        return TweenService:Create(valObj, info, {Value = toValue})
    end)
    if not success then
        conn:Disconnect()
        valObj:Destroy()
        callback(toValue)
        return
    end

    local record = {tween = tw, valObj = valObj}
    activeNumberTweens[lookupKey] = record
    tw:Play()
    tw.Completed:Connect(function()
        conn:Disconnect()
        valObj:Destroy()
        if activeNumberTweens[lookupKey] == record then
            activeNumberTweens[lookupKey] = nil
        end
    end)
end

-- =====================================================================
-- SECTION 10: CUSTOM FAST-SIGNAL ENGINE
-- =====================================================================
local function createSignal()
    local subscribers = {}
    local signal = {}

    function signal:Connect(callback)
        if type(callback) ~= "function" then
            return {Disconnect = function() end}
        end
        local record = {active = true, callback = callback}
        table.insert(subscribers, record)
        return {
            Disconnect = function()
                record.active = false
            end
        }
    end

    function signal:Fire(...)
        local snapshot = table.move(subscribers, 1, #subscribers, 1, {})
        for _, record in ipairs(snapshot) do
            if record.active then
                local success, err = pcall(record.callback, ...)
                if not success then
                    LouisHub:_LogError("Signal:Fire", err)
                end
            end
        end
    end

    return signal
end

LouisHub.Events = {
    FlagChanged       = createSignal(),
    TabChanged        = createSignal(),
    ThemeChanged      = createSignal(),
    ControlRegistered = createSignal(),
    TypeChanged       = createSignal(),
    HistoryChanged    = createSignal(),
    CategoryChanged   = createSignal(),
    SubTabChanged     = createSignal(),
}

-- =====================================================================
-- SECTION 11: TWO-WAY STATE CONTROLLER (FLAGS & OPTIONS)
-- =====================================================================
local function newElementTable()
    return setmetatable({}, {
        __newindex = function(tbl, flag, element)
            rawset(tbl, flag, element)
            if type(element) == "table" and type(element.Get) == "function" then
                local success, value = pcall(element.Get)
                if success and value ~= nil then
                    element._default = copyDefault(value)
                end
            end
        end,
    })
end

LouisHub.Elements = newElementTable()
LouisHub.Options  = {}

local activeSaveWindow = nil
local hasPendingUnsavedChanges = false
local isAutosaveLoopActive = false
local isLoadingFromFile = false

local function markPendingChange()
    if isLoadingFromFile then return end
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

local windowsWithThemeSelectors = setmetatable({}, {__mode = "k"})
local realFlags = {}
local nonPersistentFlags = {}
local uiFlags = {}
local registeredKeybinds = {}

local function decomposeKey(keyData)
    if typeof(keyData) == "table" then
        return keyData.KeyCode, keyData.Ctrl or false, keyData.Shift or false, keyData.Alt or false
    end
    return keyData, false, false, false
end

local function formatKeyText(keyCode, ctrl, shift, alt)
    if not keyCode or keyCode == Enum.KeyCode.Unknown then return "None" end
    local parts = {}
    if ctrl then table.insert(parts, "Ctrl") end
    if shift then table.insert(parts, "Shift") end
    if alt then table.insert(parts, "Alt") end
    table.insert(parts, keyCode.Name)
    return table.concat(parts, "+")
end

local function areKeysConflicting(keyA, keyB)
    local kA, cA, sA, aA = decomposeKey(keyA)
    local kB, cB, sB, aB = decomposeKey(keyB)
    if not kA or not kB then return false end
    if kA == Enum.KeyCode.Unknown or kB == Enum.KeyCode.Unknown then return false end
    return kA == kB and cA == cB and sA == sB and aA == aB
end

local function checkKeybindConflict(ownEntry, newValue)
    local conflicts = {}
    for _, entry in ipairs(registeredKeybinds) do
        if entry ~= ownEntry then
            local success, otherVal = pcall(entry.GetValue)
            if success and areKeysConflicting(newValue, otherVal) then
                table.insert(conflicts, entry.text or "Keybind")
            end
        end
    end
    if #conflicts > 0 then
        local k, c, s, a = decomposeKey(newValue)
        pcall(function()
            LouisHub:Notify({
                Title    = "Keybind in Use",
                Content  = "'" .. formatKeyText(k, c, s, a) .. "' is already assigned to: " .. table.concat(conflicts, ", "),
                Duration = 4,
                Icon     = "warning"
            })
        end)
    end
end

local function checkConflictsOnLoad()
    if #registeredKeybinds < 2 then return end
    local bySignature = {}
    for _, entry in ipairs(registeredKeybinds) do
        local success, val = pcall(entry.GetValue)
        if success then
            local k, c, s, a = decomposeKey(val)
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
                    Title    = "Keybind Conflict",
                    Content  = "'" .. formatKeyText(group.k, group.c, group.s, group.a) .. "' is assigned to: " .. table.concat(group.texts, ", "),
                    Duration = 6,
                    Icon     = "warning"
                })
            end)
        end
    end
end

LouisHub.Flags = setmetatable({}, {
    __index = realFlags,
    __newindex = function(_, key, value)
        if type(value) ~= "table" and realFlags[key] == value then
            return
        end
        realFlags[key] = value
        markPendingChange()
        if LouisHub.Events and LouisHub.Events.FlagChanged then
            LouisHub.Events.FlagChanged:Fire(key, value)
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
    return pcall(elem.Set, text)
end

function LouisHub:MarkAsUI(flagOrTable)
    if type(flagOrTable) == "table" then
        for _, f in ipairs(flagOrTable) do
            uiFlags[f] = true
        end
    else
        uiFlags[flagOrTable] = true
    end
end

function LouisHub:Try(flag, fallback)
    local elem = self.Elements[flag]
    if not elem then return fallback end
    local success, val = pcall(elem.Get)
    if not success or val == nil then return fallback end
    return val
end

-- =====================================================================
-- SECTION 12: UNDO / REDO HISTORY ENGINE
-- =====================================================================
LouisHub._history = { undo = {}, redo = {}, lastValues = {}, pause = 0 }
local MAX_HISTORY = 50

local function notifyHistoryChanged()
    local h = LouisHub._history
    LouisHub.Events.HistoryChanged:Fire(#h.undo, #h.redo)
end

LouisHub:RegisterConnection(LouisHub.Events.FlagChanged:Connect(function(flag, value)
    local h = LouisHub._history
    local prev = h.lastValues[flag]
    h.lastValues[flag] = copyDefault(value)
    if h.pause > 0 or uiFlags[flag] or nonPersistentFlags[flag] then return end
    local elem = LouisHub.Elements[flag]
    if prev == nil and elem then prev = elem._default end
    if prev == nil then return end
    if type(value) ~= "table" and prev == value then return end

    local now = os.clock()
    local lastEntry = h.undo[#h.undo]
    if lastEntry and #lastEntry.changes == 1 and lastEntry.changes[1].flag == flag and now - lastEntry.t < 0.6 then
        lastEntry.changes[1].after = copyDefault(value)
        lastEntry.t = now
        if type(value) ~= "table" and lastEntry.changes[1].before == value then
            table.remove(h.undo)
        end
    elseif lastEntry and now - lastEntry.t < 0.05 then
        table.insert(lastEntry.changes, { flag = flag, before = copyDefault(prev), after = copyDefault(value) })
        lastEntry.t = now
    else
        table.insert(h.undo, {
            t = now,
            changes = { { flag = flag, before = copyDefault(prev), after = copyDefault(value) } },
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
        local change = changes[inReverse and (total - i + 1) or i]
        local elem = LouisHub.Elements[change.flag]
        if elem and type(elem.Set) == "function" then
            local source = useBefore and change.before or change.after
            local val = copyDefault(source)
            pcall(elem.Set, val, true)
            h.lastValues[change.flag] = copyDefault(val)
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
            local success, val = pcall(elem.Get)
            if success and val ~= nil then
                h.lastValues[flag] = copyDefault(val)
            end
        end
    end
    notifyHistoryChanged()
end

function LouisHub:DescribeChange(entry)
    if type(entry) ~= "table" or not entry.changes or #entry.changes == 0 then return "" end
    local first = entry.changes[1]
    local function text(val)
        if type(val) == "table" then return "[table]" end
        return tostring(val)
    end
    local summary = tostring(first.flag) .. ": " .. text(first.before) .. " -> " .. text(first.after)
    if #entry.changes > 1 then summary = summary .. " (+" .. (#entry.changes - 1) .. ")" end
    return summary
end

-- =====================================================================
-- SECTION 13: THEME MANAGER (DYNAMIC THEMING & LIVE GRADIENT APPLY)
-- =====================================================================
LouisHub.ThemeManager = {}
local TM = LouisHub.ThemeManager
TM.Themes = Themes.List

function TM:ApplyTheme(nameOrTable)
    local isPreset = false
    local presetColors = nil

    if type(nameOrTable) == "string" and string.sub(nameOrTable, 1, 10) == "Gradient: " then
        local rawName = string.sub(nameOrTable, 11)
        if PresetGradients[rawName] then
            isPreset = true
            presetColors = PresetGradients[rawName]
            Theme.Accent      = presetColors[1]
            Theme.AccentLight = presetColors[2]
            Theme.Highlight   = presetColors[3]
            LouisHub.ThemeGradient = ColorSequence.new{
                ColorSequenceKeypoint.new(0.00, presetColors[1]),
                ColorSequenceKeypoint.new(0.50, presetColors[2]),
                ColorSequenceKeypoint.new(1.00, presetColors[3])
            }
        end
    end

    if not isPreset then
        local targetTheme = type(nameOrTable) == "string" and self.Themes[nameOrTable] or nameOrTable
        if not targetTheme then return end
        for key, value in pairs(targetTheme) do
            Theme[key] = value
        end
        LouisHub.ThemeGradient = ColorSequence.new{
            ColorSequenceKeypoint.new(0.00, Theme.Accent),
            ColorSequenceKeypoint.new(0.50, Theme.AccentLight),
            ColorSequenceKeypoint.new(1.00, Theme.Highlight)
        }
    end

    local animate = (LouisHub._windowRevealed == true)
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

    local function isInHiddenPage(instance)
        for _, page in ipairs(hiddenPages) do
            if instance:IsDescendantOf(page) then return true end
        end
        return false
    end

    for i = #themeRegistry, 1, -1 do
        local entry = themeRegistry[i]
        if entry.instance and entry.instance.Parent then
            local newValue
            if type(entry.themeKey) == "function" then
                local success, result = pcall(entry.themeKey)
                if success then newValue = result end
            else
                newValue = Theme[entry.themeKey]
            end
            if newValue ~= nil then
                silentTry("ThemeManager: Apply " .. tostring(entry.property), function()
                    local inst, prop = entry.instance, entry.property
                    if animate and typeof(newValue) == "Color3" and typeof(inst[prop]) == "Color3" and not isInHiddenPage(inst) then
                        Utils.Tween(inst, {[prop] = newValue}, LouisHub.Motion.Page, LouisHub.Motion.EaseSmooth)
                    else
                        inst[prop] = newValue
                    end
                end)
            end
        else
            entry.dead = true
        end
    end

    local appliedThemeName = type(nameOrTable) == "string" and nameOrTable or nil
    for win in pairs(windowsWithThemeSelectors) do
        if win._SyncThemeSelector then
            pcall(win._SyncThemeSelector, appliedThemeName)
        end
    end

    LouisHub.Events.ThemeChanged:Fire(appliedThemeName)
end

function TM:AddTheme(name, themeData)
    if type(name) == "string" and type(themeData) == "table" then
        self.Themes[name] = themeData
    end
end

function TM:SaveCurrentTheme()
    if not isFilesystemAvailable() then return false end
    if not isfolder(LouisHub.ConfigFolder) then pcall(makefolder, LouisHub.ConfigFolder) end
    local success, json = pcall(function()
        local data = {}
        for key, color in pairs(Theme) do
            data[key] = {color.R, color.G, color.B}
        end
        return HttpService:JSONEncode(data)
    end)
    if not success then return false end
    return pcall(writefile, LouisHub.ConfigFolder .. "/theme.json", json)
end

-- =====================================================================
-- SECTION 14: UI PRIMITIVES & EVENT ENGINE (LAYOUTS & HELPERS)
-- =====================================================================
local _uiInstanceCounter = 0
local function trackInstanceCreated(instance)
    _uiInstanceCounter = _uiInstanceCounter + 1
    instance.Destroying:Connect(function()
        _uiInstanceCounter = _uiInstanceCounter - 1
    end)
    return instance
end

function Utils.Corner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 6)
    corner.Parent = parent
    return corner
end

function Utils.Stroke(parent, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Color3.fromRGB(64, 61, 76)
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0.5
    stroke.Parent = parent
    return stroke
end

function Utils.AccentGradient(instance, rotation)
    local gradient = Instance.new("UIGradient")
    gradient.Color = LouisHub.ThemeGradient
    gradient.Rotation = rotation or 0
    gradient.Parent = instance
    LouisHub:RegisterThemeObject(gradient, "Color", function()
        return LouisHub.ThemeGradient
    end)
    return gradient
end

function Utils.Hover(eventObject, colorObject, intensity, duration, getBaseColor)
    if not eventObject or not colorObject then return end
    colorObject = colorObject or eventObject
    intensity = intensity or LouisHub.Motion.HoverIntensity
    duration = duration or LouisHub.Motion.Hover

    local isHovered = false
    local restColor = nil
    local stroke = colorObject:FindFirstChildOfClass("UIStroke")

    LouisHub:RegisterConnection(eventObject.MouseEnter:Connect(function()
        if isHovered then return end
        isHovered = true
        pcall(function()
            local base = (getBaseColor and getBaseColor()) or colorObject.BackgroundColor3
            restColor = base
            Utils.Tween(colorObject, {
                BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), intensity)
            }, duration, LouisHub.Motion.EaseEnter)
            if stroke then
                Utils.Tween(stroke, {Color = Color3.fromRGB(87, 84, 104), Transparency = 0.3}, duration, LouisHub.Motion.EaseEnter)
            end
        end)
    end))

    LouisHub:RegisterConnection(eventObject.MouseLeave:Connect(function()
        if not isHovered then return end
        isHovered = false
        pcall(function()
            local target = (getBaseColor and getBaseColor()) or restColor
            if target then
                restColor = target
                Utils.Tween(colorObject, {BackgroundColor3 = target}, duration, LouisHub.Motion.EaseEnter)
            end
            if stroke then
                Utils.Tween(stroke, {Color = Color3.fromRGB(64, 61, 76), Transparency = 0.5}, duration, LouisHub.Motion.EaseEnter)
            end
        end)
    end))
end

function Utils.ClickFeedback(visualObject)
    if not visualObject or not visualObject.Parent then return end
    local scale = visualObject:FindFirstChild("__LouisHub_ClickScale")
    if not scale then
        scale = Instance.new("UIScale")
        scale.Name = "__LouisHub_ClickScale"
        scale.Scale = 1
        scale.Parent = visualObject
    end
    scale.Scale = 0.97
    Utils.Tween(scale, {Scale = 1}, LouisHub.Motion.Press, LouisHub.Motion.EasePop)
end

function Utils.ReliableClick(targetButton, callback, visualObject)
    local CLICK_MOVE_THRESHOLD = 15
    local posDown = nil
    LouisHub:RegisterConnection(targetButton.MouseButton1Down:Connect(function(x, y)
        posDown = Vector2.new(x, y)
        Utils.ClickFeedback(visualObject or targetButton)
    end))
    LouisHub:RegisterConnection(targetButton.MouseButton1Up:Connect(function(x, y)
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
    local frame = Instance.new("Frame")
    trackInstanceCreated(frame)
    frame.Size = cfg.Size or UDim2.new(1, 0, 0, cfg.Height or 26)
    frame.Position = cfg.Position or UDim2.new(0, 0, 0, 0)
    if cfg.Anchor then frame.AnchorPoint = cfg.Anchor end
    frame.BackgroundColor3 = cfg.Color or Theme.Row
    frame.BackgroundTransparency = cfg.Transparency or 0.5
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = cfg.Clips or false
    frame.LayoutOrder = cfg.Order or 0
    if cfg.Visible ~= nil then frame.Visible = cfg.Visible end
    frame.Parent = cfg.Parent
    if cfg.Radius ~= false then Utils.Corner(frame, cfg.Radius or 6) end
    if cfg.Border ~= false then
        local stroke = Utils.Stroke(frame, cfg.BorderColor or Color3.fromRGB(64, 61, 76), cfg.BorderThickness or 1, cfg.BorderTransparency or 0.5)
        if cfg.BorderThemeKey then
            LouisHub:RegisterThemeObject(stroke, "Color", cfg.BorderThemeKey)
        end
    end
    return frame
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

local function hasHiddenAncestor(instance)
    local current = instance
    while current do
        if current:IsA("GuiObject") and not current.Visible then return true end
        current = current.Parent
    end
    return false
end

function Utils.UIScaleFactor(instance)
    local factor = 1
    local current = instance
    while current do
        local success, sc = pcall(function() return current:FindFirstChildOfClass("UIScale") end)
        if success and sc then factor = factor * sc.Scale end
        current = current.Parent
    end
    return (factor > 0) and factor or 1
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
        local successMeasure, width = pcall(function()
            return TextService:GetTextSize(inst.Text, size, inst.Font, Vector2.new(10000, availableHeight)).X
        end)
        if not successMeasure or width <= availableWidth then break end
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
    local label = Instance.new("TextLabel")
    trackInstanceCreated(label)
    label.BackgroundTransparency = 1
    label.Size = cfg.Size or UDim2.new(1, -6, 1, 0)
    label.Position = cfg.Position or UDim2.new(0, 6, 0, 0)
    label.Font = cfg.Font or Enum.Font.GothamMedium
    local baseSize = cfg.TextSize or cfg.SizeValue or 11
    label.TextSize = baseSize
    label.TextColor3 = cfg.Color or Theme.Text
    label.TextXAlignment = cfg.Alignment or Enum.TextXAlignment.Left
    label.TextTruncate = cfg.Truncate and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None
    label.TextWrapped = cfg.Wrapped or false
    label.TextTransparency = cfg.TextTransparency or 0
    label.RichText = cfg.RichText or false
    label.Text = cfg.Text or ""
    label.LayoutOrder = cfg.Order or 0
    label.Parent = cfg.Parent

    if cfg.ThemeColor then
        LouisHub:RegisterThemeObject(label, "TextColor3", cfg.ThemeColor)
    elseif not cfg.Color then
        LouisHub:RegisterThemeObject(label, "TextColor3", "Text")
    end

    registerTextScale(label, baseSize, cfg.Category, cfg.Truncate)
    return label
end

function Utils.BaseButton(cfg)
    cfg = cfg or {}
    local button = Instance.new("TextButton")
    trackInstanceCreated(button)
    button.Size = cfg.Size or UDim2.new(1, 0, 0, cfg.Height or 26)
    button.Position = cfg.Position or UDim2.new(0, 0, 0, 0)
    if cfg.Anchor then button.AnchorPoint = cfg.Anchor end
    button.BackgroundTransparency = (cfg.Transparency == nil) and 1 or cfg.Transparency
    button.BackgroundColor3 = cfg.Color or Theme.Row
    button.AutoButtonColor = false
    button.Text = ""
    button.BorderSizePixel = 0
    button.LayoutOrder = cfg.Order or 0
    button.Parent = cfg.Parent
    if cfg.Radius ~= false then Utils.Corner(button, cfg.Radius or 6) end
    return button
end

function Utils.Defer(func)
    local isPending = false
    return function()
        if isPending then return end
        isPending = true
        task.delay(0.03, function()
            isPending = false
            func()
        end)
    end
end

function Utils.MakeDynamicRow(row, label, minHeight, paddingY)
    paddingY = paddingY or 5
    label.TextWrapped   = true
    label.TextTruncate  = Enum.TextTruncate.None
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.AnchorPoint   = Vector2.new(0, 0.5)
    label.Position      = UDim2.new(label.Position.X.Scale, label.Position.X.Offset, 0.5, 0)
    label.Size          = UDim2.new(label.Size.X.Scale, label.Size.X.Offset, 0, 0)

    local function recalculate()
        if not (row.Parent and label.Parent) then return end
        local height = label.AbsoluteSize.Y
        if height <= 0 then return end
        local newH = math.max(minHeight, math.ceil(height / Utils.UIScaleFactor(label)) + paddingY * 2)
        if row.Size.Y.Offset ~= newH then
            row.Size = UDim2.new(row.Size.X.Scale, row.Size.X.Offset, 0, newH)
        end
    end

    LouisHub:RegisterConnection(label:GetPropertyChangedSignal("AbsoluteSize"):Connect(Utils.Defer(recalculate)))
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
        local finishedCallback = self._onFinished
        self._onFinished = nil
        pcall(finishedCallback)
    end
end

function EventManager:IsDragging()
    return self._active ~= nil
end

LouisHub:RegisterConnection(UserInputService.InputChanged:Connect(function(input)
    if EventManager._active and (
        input.UserInputType == Enum.UserInputType.MouseMovement or
        input.UserInputType == Enum.UserInputType.Touch
    ) then
        pcall(EventManager._active, input)
    end
end))

LouisHub:RegisterConnection(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        EventManager:StopDrag()
    end
end))

LouisHub.EventManager = EventManager

function Utils.Draggable(trigger, target, eventManager)
    local isDragging = false
    local dragStart, targetStart

    trigger.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging   = true
            dragStart    = Vector2.new(input.Position.X, input.Position.Y)
            targetStart  = target.Position

            local connInputChanged
            connInputChanged = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    isDragging = false
                    if eventManager then eventManager:StopDrag() end
                    if connInputChanged then
                        connInputChanged:Disconnect()
                        connInputChanged = nil
                    end
                end
            end)
            LouisHub:RegisterConnection(connInputChanged)

            if eventManager then
                eventManager:StartDrag(function(movedInput)
                    if not isDragging then return end
                    local delta = Vector2.new(movedInput.Position.X, movedInput.Position.Y) - dragStart
                    target.Position = UDim2.new(
                        targetStart.X.Scale,  targetStart.X.Offset + delta.X,
                        targetStart.Y.Scale,  targetStart.Y.Offset + delta.Y
                    )
                end, function()
                    isDragging = false
                    if connInputChanged then
                        connInputChanged:Disconnect()
                        connInputChanged = nil
                    end
                end)
            end
        end
    end)
end

function Utils.WrapInstance(instance)
    local proxy = setmetatable({}, {
        __index = function(_, key)
            local success, val = pcall(function() return instance[key] end)
            if not success then return nil end
            if type(val) == "function" then
                return function(_, ...) return val(instance, ...) end
            end
            return val
        end,
        __newindex = function(_, key, val) instance[key] = val end,
    })
    rawset(proxy, "Instance", instance)
    return proxy
end

function Utils.AttachLock(element, row)
    local overlay, lblReason, badge
    local isLocked, lockReason = false, nil
    local BADGE_POS = UDim2.new(1, -6, 0.5, 0)
    local shakeToken = 0
    rawset(element, "Row", row)
    local stroke, highlightToken = nil, 0

    local function withoutSelf(a, b)
        if a == element then return b end
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
        LouisHub:RegisterThemeObject(overlay, "BackgroundColor3", "BackgroundDark")

        badge = Utils.Frame({
            Parent = overlay, Size = UDim2.new(0.55, -6, 0, 22),
            Position = BADGE_POS, Anchor = Vector2.new(1, 0.5),
            Color = Theme.Panel, Radius = 5,
        })
        badge.ZIndex = 101
        LouisHub:RegisterThemeObject(badge, "BackgroundColor3", "Panel")

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

    rawset(element, "Lock", function(a, b)
        lock(withoutSelf(a, b), true)
    end)

    rawset(element, "Unlock", function()
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

    rawset(element, "IsLocked", function() return isLocked end)

    rawset(element, "SetLockedTitle", function(a, b)
        lockReason = withoutSelf(a, b)
        refreshText()
    end)

    rawset(element, "Highlight", function(a, b)
        local opts = withoutSelf(a, b)
        local duration = 2
        if type(opts) == "number" then
            duration = opts
        elseif type(opts) == "table" and type(opts.Duration) == "number" then
            duration = opts.Duration
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

-- =====================================================================
-- SECTION 15: VISUAL TRANSITIONS, ANIMATIONS & HELPER PRIMITIVES
-- =====================================================================
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
    for _, descendant in ipairs(root:GetDescendants()) do
        register(descendant)
    end
    for _, target in ipairs(targets) do
        target[1][target[2]] = 1
    end
    for _, target in ipairs(targets) do
        Utils.Tween(target[1], {[target[2]] = target[3]}, duration, LouisHub.Motion.EaseEnter)
    end
end

function Utils.AnimateInsertion(frame, axis)
    if not (frame and frame.Parent) then return end
    local finalSize = frame.Size
    local originalClips = frame.ClipsDescendants
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
            frame.ClipsDescendants = originalClips
        end
    end)
end

function Utils.ModalEntry(backdrop, card)
    local targetBackdropTransparency = backdrop.BackgroundTransparency
    backdrop.BackgroundTransparency = 1
    local scale = Instance.new("UIScale")
    scale.Scale = 0.95
    scale.Parent = card
    Utils.FadeIn(card, LouisHub.Motion.Modal, true)
    Utils.Tween(backdrop, {BackgroundTransparency = targetBackdropTransparency}, LouisHub.Motion.Expand, LouisHub.Motion.EaseEnter)
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
    LouisHub:RegisterThemeObject(panel, "BackgroundColor3", "Row")

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
    LouisHub:RegisterThemeObject(arrow, "ImageColor3", "Text")

    Utils.ReliableClick(zone, function()
        panel.Visible = not panel.Visible
        Utils.Tween(arrow, {Rotation = panel.Visible and 0 or -90}, LouisHub.Motion.Expand)
    end)
    return panel
end

-- =====================================================================
-- SECTION 16: AUTO-UPDATING LABELS & CONDITIONAL VISIBILITY
-- =====================================================================
local autoUpdateLabels = setmetatable({}, {__mode = "k"})

LouisHub:RegisterConnection(RunService.Heartbeat:Connect(function()
    local now = os.clock()
    for entry, cfg in pairs(autoUpdateLabels) do
        if not (entry and entry.Parent) then
            autoUpdateLabels[entry] = nil
        elseif now >= cfg.nextTime then
            cfg.nextTime = now + cfg.interval
            local success, newVal = pcall(cfg.fn)
            if success and newVal ~= nil then
                pcall(cfg.apply, newVal)
            elseif not success then
                LouisHub:_LogError("Label auto-update ('" .. tostring(cfg.flag) .. "')", newVal)
            end
        end
    end
end))

local visibilityRegistry = setmetatable({}, {__mode = "k"})

local function checkConditionalVisibility(row)
    local condition = visibilityRegistry[row]
    if not condition then return true end
    local success, result = pcall(condition)
    if not success then
        LouisHub:_LogError("VisibleIf", result)
        return true
    end
    return result and true or false
end

local function registerConditionalVisibility(row, visibleIf)
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

LouisHub:RegisterConnection(LouisHub.Events.FlagChanged:Connect(reevaluateConditionalVisibility))

local searchIndex = {}
local registeredSections = {}

local function registerSearchable(row, text, visibleIf)
    table.insert(searchIndex, {row = row, text = (text or ""):lower()})
    registerConditionalVisibility(row, visibleIf)
end

-- =====================================================================
-- SECTION 17: UNIFIED SAVE MANAGER V3 (MULTI-FORMAT CONFIG ENGINE)
-- =====================================================================
local SAVE_FORMAT_VERSION = 3
_G.LouisHub_NavigationState = { cat = nil, tab = nil, sub = nil }

local function isColor3Type(v) return typeof and typeof(v) == "Color3" end
local function isEnumType(v) return typeof and typeof(v) == "EnumItem" end

local function packFlagsForSaving(flags, uiOnly)
    local result = {
        __version = SAVE_FORMAT_VERSION,
        __navigation = _G.LouisHub_NavigationState
    }
    for key, val in pairs(flags) do
        local skip = nonPersistentFlags[key]
            or (uiOnly and not uiFlags[key])
            or (not uiOnly and uiFlags[key])
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
        local success, enumItem = pcall(function() return Enum[val.EnumType][val.Name] end)
        return (success and enumItem) or Enum.KeyCode.Unknown
    end
    if type(val) == "table" and val.__keybindMods then
        local success, keyCode = pcall(function() return Enum.KeyCode[val.KeyCode] end)
        return {
            KeyCode = success and keyCode or Enum.KeyCode.Unknown,
            Ctrl = val.Ctrl or false,
            Shift = val.Shift or false,
            Alt = val.Alt or false,
        }
    end
    return val
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

    if sourceVersion > SAVE_FORMAT_VERSION then
        pcall(function()
            LouisHub:Notify({
                Title    = "Newer Config",
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

local function ensureConfigFolder()
    if not (isFilesystemAvailable() and type(isfolder) == "function" and type(makefolder) == "function") then return end
    local path = ""
    for part in SM.Folder:gmatch("[^/]+") do
        path = path == "" and part or (path .. "/" .. part)
        if not isfolder(path) then pcall(makefolder, path) end
    end
end

local function ensureConfigFolderUI()
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
    ensureConfigFolder()
    local path = SM.Folder .. "/" .. name .. ".json"
    local hadChanges = true
    local success, err = pcall(function()
        local data = packFlagsForSaving(realFlags)
        local json = HttpService:JSONEncode(data)
        if type(isfile) == "function" and isfile(path) then
            local successRead, existingJson = pcall(readfile, path)
            if successRead and existingJson == json then
                hadChanges = false
            end
        end
        if hadChanges then writefile(path, json) end
    end)
    if success then
        if hadChanges then
            LouisHub:Notify({Title = "Config Saved", Content = name .. ".json", Duration = 3, Icon = "check_circle"})
        else
            LouisHub:Notify({Title = "Already Up to Date", Content = name .. ".json has no changes", Duration = 3, Icon = "info"})
        end
    else
        LouisHub:_LogError("SaveManager:Save", err)
        LouisHub:Notify({Title = "Save Error", Content = tostring(err):sub(1, 100), Duration = 5, Icon = "warning"})
    end
    return success, err
end

function SM:SaveSilent(name)
    name = name or "default"
    if not isFilesystemAvailable() then return false end
    ensureConfigFolder()
    local success, err = pcall(function()
        local data = packFlagsForSaving(realFlags)
        local json = HttpService:JSONEncode(data)
        writefile(SM.Folder .. "/" .. name .. ".json", json)
    end)
    if not success then LouisHub:_LogError("SaveManager:SaveSilent", err) end
    return success
end

function SM:Load(name)
    name = name or "default"
    local path = SM.Folder .. "/" .. name .. ".json"
    if not (isFilesystemAvailable() and type(isfile) == "function" and isfile(path)) then return false end

    local successRead, content = pcall(readfile, path)
    if not successRead then
        LouisHub:_LogError("SaveManager:Load (read)", content)
        return false
    end
    local successDecode, data = pcall(function() return HttpService:JSONDecode(content) end)
    if not successDecode then
        LouisHub:_LogError("SaveManager:Load (JSONDecode)", data)
        return false
    end
    data = prepareLoadedData(data)

    isLoadingFromFile = true
    local successLoop, errLoop = pcall(function()
        for flag, rawVal in pairs(data) do
            local val = unpackLoadedValue(rawVal)
            LouisHub.Flags[flag] = val
            if LouisHub.Elements[flag] then
                pcall(LouisHub.Elements[flag].Set, val, true)
            end
        end
    end)
    isLoadingFromFile = false
    if not successLoop then LouisHub:_LogError("SaveManager:Load (loop)", errLoop) end
    checkConflictsOnLoad()
    LouisHub:Notify({Title = "Config Loaded", Content = name .. ".json", Duration = 3, Icon = "check_circle"})
    return true
end

function SM:LoadSilent(name)
    name = name or "default"
    local path = SM.Folder .. "/" .. name .. ".json"
    if not (isFilesystemAvailable() and type(isfile) == "function" and isfile(path)) then return false end

    local successRead, content = pcall(readfile, path)
    if not successRead then return false end
    local successDecode, data = pcall(function() return HttpService:JSONDecode(content) end)
    if not successDecode then return false end
    data = prepareLoadedData(data)

    isLoadingFromFile = true
    pcall(function()
        for flag, rawVal in pairs(data) do
            local val = unpackLoadedValue(rawVal)
            LouisHub.Flags[flag] = val
            if LouisHub.Elements[flag] then
                pcall(LouisHub.Elements[flag].Set, val, false)
            end
        end
    end)
    isLoadingFromFile = false
    checkConflictsOnLoad()
    return true
end

function SM:List()
    if not (isFilesystemAvailable() and type(listfiles) == "function") then return {} end
    ensureConfigFolder()
    local result = {}
    local success, files = pcall(listfiles, SM.Folder)
    if success then
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
    if window.ConfigName then SM:SaveSilent(window.ConfigName) end
    window.ConfigName = name
    local exists = SM:Load(name)
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
    ensureConfigFolder()
    local pathS = SM.Folder .. "/" .. nameS .. ".json"
    local pathD = SM.Folder .. "/" .. nameD .. ".json"
    if not isfile(pathS) then return false, "Source profile does not exist" end
    if isfile(pathD) then return false, "Destination profile already exists" end
    local success, err = pcall(function() writefile(pathD, readfile(pathS)) end)
    return success, err
end

function SM:Rename(source, destination)
    local success, reason = SM:Duplicate(source, destination)
    if not success then return false, reason end
    local _, nameS = validProfileName(source)
    SM:Delete(nameS)
    return true
end

function SM:Export(name)
    local okN, clean = validProfileName(name)
    if not okN or not isFilesystemAvailable() then return nil, "File error" end
    local path = SM.Folder .. "/" .. clean .. ".json"
    if not isfile(path) then return nil, "Profile does not exist" end
    local successR, text = pcall(readfile, path)
    if not successR then return nil, "Read error" end
    local copied = false
    if type(setclipboard) == "function" then copied = (pcall(setclipboard, text)) end
    return text, copied
end

function SM:Import(name, text, overwrite)
    local okN, clean = validProfileName(name)
    if not okN or type(text) ~= "string" or not isFilesystemAvailable() then return false, "Invalid data" end
    local successJ, data = pcall(function() return HttpService:JSONDecode(text) end)
    if not successJ or type(data) ~= "table" then return false, "Invalid JSON" end
    ensureConfigFolder()
    local path = SM.Folder .. "/" .. clean .. ".json"
    if isfile(path) and not overwrite then return false, "Profile already exists" end
    local success, err = pcall(writefile, path, text)
    return success, err
end

function SM:SaveUI(name)
    name = name or "default"
    if not isFilesystemAvailable() then return false end
    ensureConfigFolderUI()
    local path = SM.FolderUI .. "/" .. name .. ".json"
    local success = pcall(function()
        local data = packFlagsForSaving(realFlags, true)
        writefile(path, HttpService:JSONEncode(data))
    end)
    return success
end

function SM:LoadUI(name)
    name = name or "default"
    local path = SM.FolderUI .. "/" .. name .. ".json"
    if not (isFilesystemAvailable() and type(isfile) == "function" and isfile(path)) then return false end
    local successRead, content = pcall(readfile, path)
    if not successRead then return false end
    local successDecode, data = pcall(function() return HttpService:JSONDecode(content) end)
    if not successDecode then return false end
    data = prepareLoadedData(data)

    isLoadingFromFile = true
    pcall(function()
        for flag, rawVal in pairs(data) do
            if uiFlags[flag] then
                local val = unpackLoadedValue(rawVal)
                LouisHub.Flags[flag] = val
                if LouisHub.Elements[flag] then
                    pcall(LouisHub.Elements[flag].Set, val, false)
                end
            end
        end
    end)
    isLoadingFromFile = false
    checkConflictsOnLoad()
    return true
end

function SM:ListUI()
    if not (isFilesystemAvailable() and type(listfiles) == "function") then return {} end
    ensureConfigFolderUI()
    local result = {}
    local success, files = pcall(listfiles, SM.FolderUI)
    if success then
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
    local path = self.ConfigFolder .. "/autoload.txt"
    if type(isfile) == "function" and isfile(path) then
        local success, n = pcall(readfile, path)
        if success and n and n ~= "" then
            return self.SaveManager:Load(n)
        end
    end
    return false
end

-- =====================================================================
-- SECTION 18: INTERACTIVE POPUP ENGINE (STACKABLE MODALS)
-- =====================================================================
LouisHub._openModals = 0

function LouisHub:Popup(cfg)
    cfg = cfg or {}
    local parent = getGuiContainer()
    local sg = (parent and (parent:FindFirstChild("LouisHub_ScreenGui") or parent:FindFirstChild("LouisHub_NotificationGui")))
    if not sg then
        sg = Instance.new("ScreenGui")
        sg.Name = "LouisHub_PopupGui"
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = true
        sg.DisplayOrder = 999999
        sg.Parent = parent
        protectGuiElement(sg)
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

    local blurData = attachGlassShader(backdrop)

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
    LouisHub:RegisterThemeObject(cardStroke, "Color", "Accent")

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
        local ic = resolveIcon(iconParam, "Material")
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
        LouisHub:RegisterThemeObject(lblTitle, "TextColor3", "Highlight")
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
            LouisHub:RegisterThemeObject(lblBody, "TextColor3", "Text")
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
        Update = function(_, newText)
            if contentContainer and contentContainer:FindFirstChildOfClass("TextLabel") then
                contentContainer:FindFirstChildOfClass("TextLabel").Text = tostring(newText)
            end
        end,
        Container = contentContainer or card,
        Backdrop = backdrop,
    }
end

-- =====================================================================
-- SECTION 19: HUD STATS OVERLAY ENGINE
-- =====================================================================
local activeHUDs = {}

function LouisHub:HUD(cfg)
    cfg = cfg or {}
    local name = cfg.Name or "HUD"
    if activeHUDs[name] then return activeHUDs[name] end

    local parent = getGuiContainer()
    local sg = (parent and (parent:FindFirstChild("LouisHub_ScreenGui") or parent:FindFirstChild("LouisHub_NotificationGui")))
    if not sg then
        sg = Instance.new("ScreenGui")
        sg.Name = "LouisHub_ScreenGui"
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = true
        sg.Parent = parent
        protectGuiElement(sg)
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

    local blurData = attachGlassShader(hudFrame)

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
            local icAsset = resolveIcon(icoParam, "Material")
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
                    local success, res = pcall(fn)
                    if success and res ~= nil then HUDObj:Set(flag, res) end
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

-- =====================================================================
-- SECTION 20: FLOATING ACTION BUTTON ENGINE (QUICK TOGGLES)
-- =====================================================================
local floatingButtonSlots = {}

function LouisHub:FloatingButton(cfg)
    cfg = cfg or {}
    local name = cfg.Name or ("FloatBtn_" .. math.random(1e5, 1e6))
    local parent = getGuiContainer()
    local sg = (parent and (parent:FindFirstChild("LouisHub_ScreenGui") or parent:FindFirstChild("LouisHub_NotificationGui")))
    if not sg then
        sg = Instance.new("ScreenGui")
        sg.Name = "LouisHub_ScreenGui"
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = true
        sg.Parent = parent
        protectGuiElement(sg)
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

    local blurData = attachGlassShader(btn)
    local stroke = Utils.Stroke(btn, Theme.Border, 1.5, 0.3)
    LouisHub:RegisterThemeObject(stroke, "Color", "Border")

    local icon = Instance.new("ImageLabel")
    icon.BackgroundTransparency = 1
    icon.Size = UDim2.new(0, 22, 0, 22)
    icon.Position = UDim2.new(0.5, -11, 0.5, -11)
    icon.ZIndex = 50002
    local icAsset = resolveIcon(cfg.Icon or "crosshair", "Material")
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
        SetPosition = function(_, p)
            if typeof(p) == "UDim2" then btn.Position = p end
        end,
        Destroy = function()
            if pulseTween then pulseTween:Cancel() end
            pcall(function() btn:Destroy() end)
        end
    }
    return ExtObj
end

-- =====================================================================
-- SECTION 21: WINDOW SHELL, VIEWPORT AUTOSCALER & HEADER ENGINE
-- =====================================================================
local function getTextWidth(text, size)
    return TextService:GetTextSize(
        text or "", size or 11, Enum.Font.Gotham, Vector2.new(1000, 20)
    ).X
end

function LouisHub:CreateWindow(config)
    config = config or {}
    local title     = config.Title or config.Name or "LouisHub"
    local subtitle  = (config.Subtitle or "by LouisHub") .. "  •  v" .. LouisHub.Version
    local sizeX     = config.SizeX or 620
    local sizeY     = config.SizeY or 380
    local toggleKey = config.ToggleKey or config.Bind or Enum.KeyCode.RightControl
    local isHorizontal = (config.Orientation == "horizontal")

    cleanupPreviousInstance()
    _G.LouisHub_Instance = {
        Connections = {},
        Threads     = {},
        Drawings    = {},
        Instances   = {},
        Window      = nil,
        Title       = title,
    }

    local parentGui = getGuiContainer()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name           = "LouisHub_ScreenGui"
    screenGui.ResetOnSpawn   = false
    screenGui.IgnoreGuiInset = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent         = parentGui
    protectGuiElement(screenGui)
    LouisHub:RegisterInstance(screenGui)

    LouisHub._guiConfirm = screenGui

    local mainWindow = Utils.Frame({
        Parent = screenGui,
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
    mainWindow.Active = true
    LouisHub:RegisterThemeObject(mainWindow, "BackgroundColor3", "Panel")

    local blurData = attachGlassShader(mainWindow)

    local screenShadow = Utils.Frame({
        Parent = screenGui,
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        Color = Color3.new(0, 0, 0),
        Transparency = 1,
        Radius = false,
        Border = false,
    })
    screenShadow.ZIndex = -10
    Utils.Tween(screenShadow, {BackgroundTransparency = 0.94}, LouisHub.Motion.Modal)

    LouisHub:RegisterConnection(mainWindow:GetPropertyChangedSignal("Visible"):Connect(function()
        screenShadow.Visible = mainWindow.Visible
    end))

    local ORIGINAL_WINDOW_POS = UDim2.new(0.5, 0, 0.5, 0)
    Utils.Tween(mainWindow, {
        Size = UDim2.new(0, sizeX, 0, sizeY),
        Position = ORIGINAL_WINDOW_POS,
    }, LouisHub.Motion.Modal, LouisHub.Motion.EasePop)

    local uiScale = Instance.new("UIScale")
    uiScale.Scale = 1
    uiScale.Parent = mainWindow

    local manualScale = 1
    local baseSizeX, baseSizeY = sizeX, sizeY
    local scaleFactorX, scaleFactorY = 1, 1

    local function recalculateScale()
        local camera = Workspace.CurrentCamera
        if not camera then return end
        local viewportSize = camera.ViewportSize
        if viewportSize.X <= 0 or viewportSize.Y <= 0 then return end

        local isMobile = viewportSize.X < 700 or viewportSize.Y < 500
        local pctW = isMobile and 0.95 or 0.82
        local pctH = isMobile and 0.88 or 0.82

        local currentW = baseSizeX * scaleFactorX
        local currentH = baseSizeY * scaleFactorY

        local scaleByW = (viewportSize.X * pctW) / currentW
        local scaleByH = (viewportSize.Y * pctH) / currentH
        local autoScale = math.min(scaleByW, scaleByH, 1.15)
        autoScale = math.max(autoScale, 0.45)

        local limitScale = math.min((viewportSize.X * 0.98) / currentW, (viewportSize.Y * 0.90) / currentH)
        local finalScale = math.max(0.3, math.min(autoScale * manualScale, limitScale))
        local duration = EventManager:IsDragging() and LouisHub.Motion.Instant or LouisHub.Motion.Page
        Utils.Tween(uiScale, {Scale = finalScale}, duration, LouisHub.Motion.EaseEnter)
    end

    recalculateScale()

    local connViewport = nil
    local function hookCamera()
        if connViewport then
            LouisHub:DisconnectConnection(connViewport)
            connViewport = nil
        end
        local currentCamera = Workspace.CurrentCamera
        if currentCamera then
            connViewport = LouisHub:RegisterConnection(
                currentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(recalculateScale)
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
        Parent = screenGui,
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
    LouisHub:RegisterThemeObject(pillRestore, "BackgroundColor3", "Panel")

    local blurPill = attachGlassShader(pillRestore)

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

            mainWindow.Visible = true
            mainWindow.Size = UDim2.new(0, 0, 0, 0)
            mainWindow.Position = ORIGINAL_WINDOW_POS
            Utils.Tween(mainWindow, {Size = targetSize}, LouisHub.Motion.Modal, LouisHub.Motion.EasePop)

            task.spawn(function()
                task.wait(LouisHub.Motion.Expand)
                if isOpActive() then
                    pillRestore.Visible = false
                    pillRestore.Size = UDim2.new(0, pillWidth, 0, 28)
                end
                task.wait(math.max(0, LouisHub.Motion.Modal - LouisHub.Motion.Expand))
                if isOpActive() then
                    mainWindow.Size = targetSize
                    isWindowAnimating = false
                end
            end)
        else
            Utils.Tween(mainWindow, {Size = UDim2.new(0, 0, 0, 0)}, LouisHub.Motion.Expand, LouisHub.Motion.EaseExit)
            task.spawn(function()
                task.wait(LouisHub.Motion.Expand + 0.04)
                if not isOpActive() then return end
                mainWindow.Visible = false
                mainWindow.Size = UDim2.new(0, 0, 0, 0)
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
        Parent = mainWindow, Size = UDim2.new(1, 0, 0, 32),
        Color = Theme.Background, Radius = 10, Transparency = 0.35,
        Border = false,
    })
    titleBar.Active = true
    LouisHub:RegisterThemeObject(titleBar, "BackgroundColor3", "Background")

    local titleCover = Utils.Frame({
        Parent = titleBar, Size = UDim2.new(1, 0, 0, 8),
        Position = UDim2.new(0, 0, 1, -8),
        Color = Theme.Background, Radius = false, Border = false,
        Transparency = 0.35,
    })
    LouisHub:RegisterThemeObject(titleCover, "BackgroundColor3", "Background")

    local accentLine = Utils.Frame({
        Parent = mainWindow, Size = UDim2.new(1, -20, 0, 2),
        Position = UDim2.new(0, 10, 0, 31), Color = Theme.Accent, Radius = false,
        Border = false, Transparency = 0.1,
    })
    accentLine.ZIndex = titleBar.ZIndex + 2
    LouisHub:RegisterThemeObject(accentLine, "BackgroundColor3", "Accent")
    Utils.AccentGradient(accentLine)

    Utils.Draggable(titleBar, mainWindow, LouisHub.EventManager)

    local lblTitle = Utils.Text({
        Parent = titleBar, Text = title,
        Position = UDim2.new(0, 10, 0, 2), Size = UDim2.new(0.5, 0, 0, 16),
        Font = Enum.Font.GothamBold, TextSize = 13, Color = Theme.TextDark,
        Category = "title", Truncate = true,
    })
    LouisHub:RegisterThemeObject(lblTitle, "TextColor3", "TextDark")

    local lblSub = Utils.Text({
        Parent = titleBar, Text = subtitle,
        Position = UDim2.new(0, 10, 0, 17), Size = UDim2.new(0.5, 0, 0, 12),
        TextSize = 10, Color = Theme.TextDark, TextTransparency = 0.25,
        Category = "title", Truncate = true,
    })
    LouisHub:RegisterThemeObject(lblSub, "TextColor3", "TextDark")

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
            Title    = "Close Interface?",
            Content  = "Are you sure you want to destroy this interface? All active overlays and connections will be terminated.",
            Icon     = "warning",
            Buttons  = {
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
    sideBar.Parent              = mainWindow
    LouisHub:RegisterThemeObject(sideBar, "BackgroundColor3", "PanelLight")

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
    horizBar.Parent              = mainWindow
    LouisHub:RegisterThemeObject(horizBar, "BackgroundColor3", "PanelLight")

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
        Parent = mainWindow, Size = sizeP, Position = posP,
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

    -- ── HIERARCHY DATA STRUCTURES ───────────────────────────────
    local Window = {
        Categories   = {},
        Tabs         = {},
        _main        = mainWindow,
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

    local catOrder = 0
    local isFirstGlobalTab = true
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
            if cat.Header then
                cat.Header.Visible = (text == "") or catMatched
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
            LouisHub:RegisterThemeObject(box, "BackgroundColor3", "Input")
            LouisHub:RegisterThemeObject(box, "TextColor3", "Text")
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
        searchBoxHoriz.Parent   = mainWindow
        Window._searchBoxHoriz  = searchBoxHoriz
    end

    -- ── CREATE CATEGORY ENGINE ──────────────────────────────────
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
        LouisHub:RegisterThemeObject(arrowIcon, "ImageColor3", "TextDark")

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
        if not catCfg.Color then LouisHub:RegisterThemeObject(lblCat, "TextColor3", "AccentLight") end

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
            Header      = headerSide,
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
            LouisHub:RegisterThemeObject(btnSide, "BackgroundColor3", "Row")

            local indicatorSide = Utils.Frame({
                Parent = btnSide, Size = UDim2.new(0, 2.5, 1, -6),
                Position = UDim2.new(0, 0, 0, 3),
                Color = Theme.Accent, Radius = 2, Border = false,
            })
            indicatorSide.BackgroundTransparency = 1
            LouisHub:RegisterThemeObject(indicatorSide, "BackgroundColor3", "Accent")

            local icAsset = resolveIcon(tabIcon, "Material")
            local iconObj
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
                iconObj = img
            else
                local txtIco = Utils.Text({
                    Parent = btnSide, Text = tabIcon,
                    Size = UDim2.new(0, 18, 1, 0), Position = UDim2.new(0, 4, 0, 0),
                    Alignment = Enum.TextXAlignment.Center, TextSize = 11,
                })
                iconObj = txtIco
            end

            local lblTab = Utils.Text({
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
            LouisHub:RegisterThemeObject(indicatorHoriz, "BackgroundColor3", "Accent")

            local lblH = Utils.Text({
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
                LouisHub:RegisterThemeObject(tLbl, "TextColor3", "Highlight")
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
                ButtonSide      = btnSide,
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

            -- ── CREATE SUBTAB ENGINE ─────────────────────────────────
            function TabObj:CreateSubTab(subCfg)
                if type(subCfg) == "string" then subCfg = { Name = subCfg } end
                subCfg = subCfg or {}
                local subName = subCfg.Name or "Main"
                if self.SubTabs[subName] then return self.SubTabs[subName] end

                local subBtn = Utils.BaseButton({
                    Parent = self.SubTabBar, Size = UDim2.new(0, 70, 1, 0),
                    Color = Theme.Row, Transparency = 0.5, Radius = 5,
                })
                subBtn.AutomaticSize = Enum.AutomaticSize.X
                local sPad = Instance.new("UIPadding")
                sPad.PaddingLeft, sPad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
                sPad.Parent = subBtn

                local sLbl = Utils.Text({
                    Parent = subBtn, Text = subName,
                    Size = UDim2.new(1, 0, 1, 0), Alignment = Enum.TextXAlignment.Center,
                    TextSize = 10, Font = Enum.Font.GothamMedium,
                })

                local subPage = Instance.new("ScrollingFrame")
                subPage.Name = "SubPage_" .. subName
                subPage.Size = UDim2.new(1, 0, 1, 0)
                subPage.BackgroundTransparency = 1
                subPage.BorderSizePixel = 0
                subPage.ScrollBarThickness = 3
                subPage.ScrollBarImageColor3 = Theme.Accent
                subPage.CanvasSize = UDim2.new(0, 0, 0, 0)
                subPage.AutomaticCanvasSize = Enum.AutomaticSize.Y
                subPage.Visible = (#self.SubTabsOrder == 0)
                subPage.Parent = self.SubTabContainer

                local pLayout = Instance.new("UIListLayout")
                pLayout.Padding   = UDim.new(0, 10)
                pLayout.SortOrder = Enum.SortOrder.LayoutOrder
                pLayout.Parent    = subPage

                local pPad = Instance.new("UIPadding")
                pPad.PaddingTop, pPad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 10)
                pPad.PaddingLeft, pPad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
                pPad.Parent = subPage

                local SubTabObj = {
                    Name     = subName,
                    Button   = subBtn,
                    Page     = subPage,
                    Sections = {},
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
                    LouisHub.Events.SubTabChanged:Fire(TabObj.Category, TabObj.Name, self.Name)
                end

                Utils.ReliableClick(subBtn, function() SubTabObj:Select() end)

                table.insert(self.SubTabsOrder, SubTabObj)
                self.SubTabs[subName] = SubTabObj

                if #self.SubTabsOrder >= 2 then
                    self.SubTabBar.Visible = true
                    self.SubTabContainer.Position = UDim2.new(0, 0, 0, showTitle and 48 or 28)
                    self.SubTabContainer.Size = UDim2.new(1, 0, 1, showTitle and -48 or -28)
                else
                    self.SubTabBar.Visible = false
                    self.SubTabContainer.Position = UDim2.new(0, 0, 0, showTitle and 24 or 4)
                    self.SubTabContainer.Size = UDim2.new(1, 0, 1, showTitle and -24 or -4)
                end

                -- ── CREATE SECTION ENGINE (1 OR 2 COLUMNS) ───────────────
                function SubTabObj:CreateSection(secName, secCfg)
                    secCfg = secCfg or {}
                    local numColumns = secCfg.Columns or 1
                    local collapsible = (secCfg.Collapsible ~= false)
                    local collapsedByDefault = collapsible and (secCfg.CollapsedByDefault == true)

                    local frame = Utils.Frame({
                        Parent = subPage, Size = UDim2.new(1, 0, 0, 0),
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
                        LouisHub:RegisterThemeObject(arrow, "ImageColor3", "AccentLight")

                        lblSec = Utils.Text({
                            Parent = btnHeader, Text = secName or "Section",
                            Size = UDim2.new(1, -24, 1, 0), Position = UDim2.new(0, 20, 0, 0),
                            Font = Enum.Font.GothamBold, TextSize = 11, Color = Theme.AccentLight,
                        })
                        LouisHub:RegisterThemeObject(lblSec, "TextColor3", "AccentLight")
                    else
                        lblSec = Utils.Text({
                            Parent = frame, Text = secName or "Section",
                            Size = UDim2.new(1, -12, 0, 20), Position = UDim2.new(0, 8, 0, 2),
                            Font = Enum.Font.GothamBold, TextSize = 11, Color = Theme.AccentLight,
                        })
                        LouisHub:RegisterThemeObject(lblSec, "TextColor3", "AccentLight")
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

                    if LouisHub._ApplyControlMethods then
                        LouisHub._ApplyControlMethods(Section)
                    end

                    return Section
                end

                function TabObj:CreateSection(secName, secCfg)
                    local subMain = self.SubTabs["Main"] or self:CreateSubTab("Main")
                    return subMain:CreateSection(secName, secCfg)
                end

                return SubTabObj
            end

            table.insert(Window.Tabs, TabObj)
            self.Tabs[tabName] = TabObj

            -- ── LUNA ADAPTIVE DIRECT ATTACHMENT ─────────────────────────
            local currentSection = nil

            local function getTargetSec(selfTab)
                if not currentSection then
                    currentSection = selfTab:CreateSection("")
                end
                return currentSection
            end

            TabObj.CreateButton = function(selfTab, c)
                return getTargetSec(selfTab):Button(c)
            end

            TabObj.CreateToggle = function(selfTab, c, f)
                if f then c.Flag = f end
                local tog = getTargetSec(selfTab):Toggle(c)
                if tog then
                    tog.SetState = tog.Set
                    tog.SetValue = tog.Set
                end
                return tog
            end

            TabObj.CreateSlider = function(selfTab, c, f)
                if f then c.Flag = f end
                local sld = getTargetSec(selfTab):Slider(c)
                if sld then
                    sld.SetValue = sld.Set
                end
                return sld
            end

            TabObj.CreateInput = function(selfTab, c, f)
                if f then c.Flag = f end
                return getTargetSec(selfTab):Input(c)
            end

            TabObj.CreateDropdown = function(selfTab, c, f)
                if f then c.Flag = f end
                local drop = getTargetSec(selfTab):Dropdown(c)
                if drop then
                    drop.SetOptions = drop.Refresh
                    drop.SetOption  = drop.Set
                end
                return drop
            end

            TabObj.CreateColorPicker = function(selfTab, c, f)
                if f then c.Flag = f end
                return getTargetSec(selfTab):ColorPicker(c, f)
            end

            TabObj.CreateBind = function(selfTab, c, f)
                if f then c.Flag = f end
                return getTargetSec(selfTab):Keybind(c)
            end
            TabObj.CreateKeybind = TabObj.CreateBind

            TabObj.CreateLabel = function(selfTab, c)
                return getTargetSec(selfTab):Label(c)
            end

            TabObj.CreateParagraph = function(selfTab, c)
                return getTargetSec(selfTab):Paragraph(c)
            end

            TabObj.CreateDivider = function(selfTab)
                return getTargetSec(selfTab):Divider()
            end

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

        screenGui.Destroying:Connect(function()
            isAutosaveLoopActive = false
            pcall(function() LouisHub.SaveManager:SaveSilent(Window.ConfigName) end)
        end)
        startAutosaveLoop()
    end

    _G.LouisHub_Instance.Window = Window
    return Window
end

-- =====================================================================
-- SECTION 22: TOOLTIP ENGINE & DRAGGABLE SLIDER PRIMITIVES
-- =====================================================================
local overlayGui, helpPanel, lblHelp, globalCloseConnection

local function getTooltipOverlay()
    if overlayGui and overlayGui.Parent then return overlayGui end

    overlayGui = Instance.new("ScreenGui")
    overlayGui.Name = "LouisHub_TooltipOverlay"
    overlayGui.ResetOnSpawn = false
    overlayGui.IgnoreGuiInset = true
    overlayGui.DisplayOrder = 9999999
    pcall(function() overlayGui.Parent = getGuiContainer() end)
    protectGuiElement(overlayGui)
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
    LouisHub:RegisterThemeObject(helpPanel, "BackgroundColor3", "Panel")
    Utils.Corner(helpPanel, 6)
    local strokeTooltip = Utils.Stroke(helpPanel, Theme.Accent, 1, 0.3)
    LouisHub:RegisterThemeObject(strokeTooltip, "Color", "Accent")

    local blurTip = attachGlassShader(helpPanel)

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
    LouisHub:RegisterThemeObject(lblHelp, "TextColor3", "Text")

    return overlayGui
end

local function closeGlobalTooltip()
    if helpPanel then helpPanel.Visible = false end
    if globalCloseConnection then
        LouisHub:DisconnectConnection(globalCloseConnection)
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
    LouisHub:RegisterThemeObject(btnInfo, "BackgroundColor3", "AccentLight")

    local lblMark = Utils.Text({
        Parent = btnInfo, Text = "?",
        Alignment = Enum.TextXAlignment.Center,
        Font = Enum.Font.GothamBold, TextSize = 11,
        Color = Theme.TextDark,
    })
    LouisHub:RegisterThemeObject(lblMark, "TextColor3", "TextDark")

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

local function createDraggableBar(cfg)
    local minVal = cfg.Min or 0
    local maxVal = cfg.Max or 100
    local rangeDiff = math.max(maxVal - minVal, 0.0001)

    local background = Utils.Frame({
        Parent = cfg.Parent, Size = cfg.Size, Position = cfg.Position,
        Color = Theme.Input, Radius = 4, Transparency = 0.4,
    })
    LouisHub:RegisterThemeObject(background, "BackgroundColor3", "Input")

    local dragRing = Utils.Stroke(background, Theme.AccentLight, 1.5, 1)
    LouisHub:RegisterThemeObject(dragRing, "Color", "AccentLight")

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
    LouisHub:RegisterThemeObject(fill, "BackgroundColor3", "Accent")
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
                LouisHub:RegisterThemeObject(tickMark, "BackgroundColor3", "Border")
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
    LouisHub:RegisterThemeObject(background, "BackgroundColor3", "Input")

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
    LouisHub:RegisterThemeObject(fill, "BackgroundColor3", "Accent")
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
        LouisHub:RegisterThemeObject(h, "BackgroundColor3", "Highlight")
        local ring = Utils.Stroke(h, Theme.AccentLight, 1.5, 1)
        LouisHub:RegisterThemeObject(ring, "Color", "AccentLight")
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

-- =====================================================================
-- SECTION 23: INTERACTIVE CONTROLS INJECTOR (PART A - CORE CONTROLS)
-- =====================================================================
local function applyControlMethods(Section)
    local order = 0
    local function nextOrder() order = order + 1; return order end

    local function createHeader(height, text, labelWidth, offsetX, mode, targetContainer)
        local row = Utils.Row(targetContainer, height, nextOrder(), Theme.Row)
        LouisHub:RegisterThemeObject(row, "BackgroundColor3", "Row")
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
            local icData = resolveIcon(icoParam, "Material")
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
                    if ctrl and ctrl.Get() == true then ctrl.Set(false, true) end
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
            Set = function(v, fireCallback) updateVal(v, fireCallback or false) end,
            SetState = function(selfElem, v) updateVal(v, true) end,
            SetValue = function(selfElem, v) updateVal(v, true) end,
            UpdateState = function(selfElem, v) updateVal(v, true) end,
            Get = function() return value end,
            CurrentValue = value,
        }

        LouisHub.Elements[flag] = elemObj
        LouisHub.Options[flag]  = elemObj

        if cfg.Callback then executeWithFallback(cfg.Callback, cfg.Text or cfg.Name or "control", value) end
        return elemObj
    end

    function Section:Button(cfg)
        cfg = cfg or {}
        validateCallback("Button", cfg)
        local targetCont = self:_GetTargetContainer("Button", cfg)
        local row = Utils.BaseButton({
            Parent = targetCont, Size = UDim2.new(1, 0, 0, 26),
            Color = Theme.Row, Transparency = 0.5,
            Order = nextOrder(), Radius = 6,
        })
        LouisHub:RegisterThemeObject(row, "BackgroundColor3", "Row")
        Utils.Hover(row, row)

        local textWithIcon = cfg.Text or cfg.Name or "Button"
        local icoParam = cfg.Icon
        local icAsset = icoParam and resolveIcon(icoParam, "Material")
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
                LouisHub:RegisterThemeObject(spinner, "TextColor3", "AccentLight")
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

        return row
    end

    function Section:Toggle(cfg)
        return createBooleanControl("Toggle", cfg, function(row, getVal)
            local knob = Utils.BaseButton({
                Parent = row, Size = UDim2.new(0, 36, 0, 18),
                Position = UDim2.new(1, -42, 0.5, -9),
                Color = getVal() and Theme.Accent or Theme.Muted,
                Transparency = 0.2, Radius = 9,
            })
            LouisHub:RegisterThemeObject(knob, "BackgroundColor3", function()
                return getVal() and Theme.Accent or Theme.Muted
            end)

            local pGrad = Utils.AccentGradient(knob)
            pGrad.Enabled = getVal()

            local circle = Utils.Frame({
                Parent = knob, Size = UDim2.new(0, 14, 0, 14),
                Position = getVal() and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
                Color = Theme.Text, Radius = 7, Border = false, Transparency = 0,
            })
            LouisHub:RegisterThemeObject(circle, "BackgroundColor3", "Text")

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

    function Section:Checkbox(cfg)
        return createBooleanControl("Checkbox", cfg, function(row, getVal)
            local box = Utils.BaseButton({
                Parent = row, Size = UDim2.new(0, 18, 0, 18),
                Position = UDim2.new(1, -26, 0.5, -9),
                Color = getVal() and Theme.Accent or Theme.Input,
                Transparency = 0.3, Radius = 4,
            })
            LouisHub:RegisterThemeObject(box, "BackgroundColor3", function()
                return getVal() and Theme.Accent or Theme.Input
            end)
            local strokeBox = Utils.Stroke(box, Theme.Border, 1, 0.3)
            LouisHub:RegisterThemeObject(strokeBox, "Color", "Border")

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
            LouisHub:RegisterThemeObject(strokeShort, "BackgroundColor3", "Text")
            LouisHub:RegisterThemeObject(strokeLong, "BackgroundColor3", "Text")

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
        LouisHub:RegisterThemeObject(row, "BackgroundColor3", "Row")
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
        LouisHub:RegisterThemeObject(inputValBox, "BackgroundColor3", "Input")
        LouisHub:RegisterThemeObject(inputValBox, "TextColor3", "Highlight")

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
            Set = function(v, fireCallback)
                if typeof(v) ~= "number" then return end
                v = roundVal(v)
                lastProcessed = v
                value = v
                LouisHub.Flags[flag] = v
                animateDisplay(v, false)
                setVisual(v)
                if fireCallback and cfg.Callback then
                    executeWithFallback(cfg.Callback, cfg.Text or cfg.Name or "control", v)
                end
            end,
            SetValue = function(selfElem, v)
                if typeof(v) == "number" then selfElem.Set(v, true) end
            end,
            Get = function() return value end,
            CurrentValue = value,
        }
        LouisHub.Elements[flag] = elemObj
        LouisHub.Options[flag]  = elemObj

        return elemObj
    end

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
        LouisHub:RegisterThemeObject(row, "BackgroundColor3", "Row")
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
        LouisHub:RegisterThemeObject(lblValues, "TextColor3", "Highlight")

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
            Set = function(v, fireCallback)
                if type(v) ~= "table" or v.min == nil or v.max == nil then return end
                local vMin = roundVal(math.clamp(v.min, minVal, maxVal))
                local vMax = roundVal(math.clamp(v.max, minVal, maxVal))
                if vMin > vMax then vMin, vMax = vMax, vMin end
                lastMin, lastMax = vMin, vMax
                valMin, valMax = vMin, vMax
                LouisHub.Flags[flag] = currentRange()
                updateDisplay()
                setVisual(vMin, vMax)
                if fireCallback and cfg.Callback then
                    executeWithFallback(cfg.Callback, cfg.Text or "control", currentRange())
                end
            end,
            Get = function() return currentRange() end,
        }
        LouisHub.Elements[flag] = elemObj
        LouisHub.Options[flag]  = elemObj

        return elemObj
    end

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
        LouisHub:RegisterThemeObject(btnMinus, "BackgroundColor3", "Input")
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
        LouisHub:RegisterThemeObject(textBox, "BackgroundColor3", "Input")
        LouisHub:RegisterThemeObject(textBox, "TextColor3", "Highlight")

        local btnPlus = Utils.BaseButton({
            Parent = row, Color = Theme.Input, Transparency = 0.4, Radius = 4,
            Size = UDim2.new(0, BTN_WIDTH, 0, CTRL_HEIGHT),
            Position = UDim2.new(1, -(BTN_WIDTH + 6), 0.5, -CTRL_HEIGHT/2),
        })
        LouisHub:RegisterThemeObject(btnPlus, "BackgroundColor3", "Input")
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
            Set = function(v, fireCallback)
                if type(v) ~= "number" then return end
                value = roundVal(v)
                LouisHub.Flags[flag] = value
                textBox.Text = formatText(value)
                if fireCallback and cfg.Callback then
                    executeWithFallback(cfg.Callback, cfg.Text or "control", value)
                end
            end,
            Get = function() return value end,
        }
        LouisHub.Elements[flag] = elemObj
        LouisHub.Options[flag]  = elemObj

        return elemObj
    end

    function Section:Input(cfg)
        cfg = cfg or {}
        validateCallback("Input", cfg)
        local flag  = cfg.Flag or cfg.Text or cfg.Name or ("Input_" .. tostring(math.random(1e5, 1e6)))
        local value = cfg.CurrentValue or cfg.Default or ""
        LouisHub.Flags[flag] = value

        local isArea = (cfg.Type == "textarea")
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
        LouisHub:RegisterThemeObject(box, "BackgroundColor3", "Input")
        LouisHub:RegisterThemeObject(box, "TextColor3", "Highlight")

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
            Set = function(v, fireCallback)
                value = v
                box.Text = tostring(v)
                LouisHub.Flags[flag] = v
                if fireCallback and cfg.Callback then
                    executeWithFallback(cfg.Callback, cfg.Text or "Input", v)
                end
            end,
            Get = function() return value end,
            CurrentValue = value,
        }
        LouisHub.Elements[flag] = elemObj
        LouisHub.Options[flag]  = elemObj

        return elemObj
    end

    function Section:TagInput(cfg)
        cfg = cfg or {}
        validateCallback("TagInput", cfg)
        local flag     = cfg.Flag or cfg.Text or ("TagInput_" .. tostring(math.random(1e5, 1e6)))
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
        LouisHub:RegisterThemeObject(row, "BackgroundColor3", "Row")
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
        LouisHub:RegisterThemeObject(box, "BackgroundColor3", "Input")
        LouisHub:RegisterThemeObject(box, "TextColor3", "Highlight")

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
                LouisHub:RegisterThemeObject(chip, "BackgroundColor3", "Accent")
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
            Set = function(v, fireCallback)
                if type(v) ~= "table" then return end
                tags = {}
                tagsLower = {}
                for _, t in ipairs(v) do
                    if type(t) == "string" and not tagsLower[t:lower()] then
                        table.insert(tags, t)
                        tagsLower[t:lower()] = true
                    end
                end
                LouisHub.Flags[flag] = currentTags()
                drawChips()
                if fireCallback and cfg.Callback then
                    executeWithFallback(cfg.Callback, cfg.Text or "control", currentTags())
                end
            end,
            Get = function() return currentTags() end,
        }
        LouisHub.Elements[flag] = elemObj
        LouisHub.Options[flag]  = elemObj

        return elemObj
    end

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
            LouisHub:RegisterThemeObject(btn, "BackgroundColor3", function()
                return (opt == value) and Theme.Accent or Theme.Input
            end)
            local lblBtn = Utils.Text({
                Parent = btn, Text = tostring(opt), Size = UDim2.new(1, 0, 1, 0),
                Alignment = Enum.TextXAlignment.Center, TextSize = 10.5, Truncate = true,
                Color = isActive and Theme.Text or Theme.TextDark,
            })
            Utils.ReliableClick(btn, function() pickOption(opt) end)
            opButtons[opt] = btn
        end

        local elemObj = {
            Set = function(v, fireCallback)
                value = v
                LouisHub.Flags[flag] = v
                refreshVisual()
                if fireCallback and cfg.Callback then
                    executeWithFallback(cfg.Callback, cfg.Text or "RadioGroup", v)
                end
            end,
            Get = function() return value end,
        }
        LouisHub.Elements[flag] = elemObj
        LouisHub.Options[flag]  = elemObj

        return elemObj
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
                LouisHub:DisconnectConnection(conn)
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
        LouisHub:RegisterThemeObject(frame, "BackgroundColor3", "Row")
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
        LouisHub:RegisterThemeObject(arrow, "ImageColor3", "Text")

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
            LouisHub:RegisterThemeObject(searchBox, "BackgroundColor3", "Input")
            LouisHub:RegisterThemeObject(searchBox, "TextColor3", "Text")
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
                LouisHub:RegisterThemeObject(btn, "BackgroundColor3", function()
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

        local function updateOptionsExternal(newOpts)
            options = cloneTable(newOpts or {})
            buildOptionButtons()
            updateLabel()
        end

        local elemObj = {
            Set = function(v, fireCallback)
                if multi then
                    selection = {}
                    if type(v) == "table" then
                        if #v > 0 then
                            for _, item in ipairs(v) do selection[item] = true end
                        else
                            for item, val in pairs(v) do if val then selection[item] = true end end
                        end
                    elseif type(v) == "string" then
                        selection[v] = true
                    end
                else
                    selection = {[v] = true}
                end
                for opt, btn in pairs(opButtons) do
                    btn.BackgroundColor3 = selection[opt] and Theme.Accent or Theme.Input
                    btn.BackgroundTransparency = selection[opt] and 0.2 or 0.5
                end
                updateLabel()
                LouisHub.Flags[flag] = multi and cloneTable(selection) or v
                if fireCallback and cfg.Callback then
                    executeWithFallback(cfg.Callback, cfg.Text or cfg.Name or "Dropdown", LouisHub.Flags[flag])
                end
            end,
            SetOption     = function(selfElem, v) selfElem.Set(v, true) end,
            SetOptions    = updateOptionsExternal,
            Refresh       = updateOptionsExternal,
            Get           = getSelectedValue,
            CurrentOption = multi and cloneTable(selection) or (cfg.CurrentOption or cfg.Default),
        }
        LouisHub.Elements[flag] = elemObj
        LouisHub.Options[flag]  = elemObj

        return elemObj
    end

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
        LouisHub:RegisterThemeObject(frame, "BackgroundColor3", "Row")

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
        LouisHub:RegisterThemeObject(hexBox, "BackgroundColor3", "Input")
        LouisHub:RegisterThemeObject(hexBox, "TextColor3", "Text")

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

        elemObj.Set = function(v, fireCallback)
            if typeof(v) ~= "Color3" then return end
            currentColor = v
            r = v.R * 255; g = v.G * 255; b = v.B * 255
            swatch.BackgroundColor3 = v
            if hexBox then hexBox.Text = toHex(v) end
            LouisHub.Flags[flag] = v
            elemObj.Color = v
            setVisualR(r); setVisualG(g); setVisualB(b)
            if fireCallback then
                triggerColorCallback(v)
            end
        end
        elemObj.Get = function() return currentColor end
        elemObj.Color = currentColor
        elemObj.Callback = cfg.Callback

        LouisHub.Elements[flag] = elemObj
        LouisHub.Options[flag]  = elemObj

        return elemObj
    end

    function Section:Keybind(cfg)
        cfg = cfg or {}
        validateCallback("Keybind", cfg)
        local flag     = cfg.Flag or cfg.Text or cfg.Name or ("Keybind_" .. tostring(math.random(1e5, 1e6)))
        local withMods = (cfg.WithModifiers == true)
        local defaultK = cfg.CurrentBind or cfg.Default or (withMods and {KeyCode = Enum.KeyCode.Unknown} or Enum.KeyCode.Unknown)
        if withMods and typeof(defaultK) ~= "table" then
            defaultK = {KeyCode = defaultK, Ctrl = false, Shift = false, Alt = false}
        end
        local value = defaultK
        local isWaiting = false
        local connCapture = nil
        local assignedThisFrame = false
        local waitToken = 0
        LouisHub.Flags[flag] = value

        local conflictEntry = { flag = flag, text = cfg.Text or cfg.Name or "Keybind" }
        conflictEntry.GetValue = function() return value end
        table.insert(registeredKeybinds, conflictEntry)

        local function formatKey(v)
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
        LouisHub:RegisterThemeObject(btnKey, "BackgroundColor3", "Input")
        Utils.Hover(btnKey, btnKey)

        local lblKey = Utils.Text({
            Parent = btnKey, Text = formatKey(value),
            Alignment = Enum.TextXAlignment.Center,
            Color = Theme.Highlight, TextSize = 9.5, Truncate = true,
        })
        LouisHub:RegisterThemeObject(lblKey, "TextColor3", "Highlight")

        local function updateKey(keyVal, fire)
            value = keyVal
            LouisHub.Flags[flag] = keyVal
            lblKey.Text = formatKey(keyVal)
            if fire and cfg.Callback then
                executeWithFallback(cfg.Callback, cfg.Text or cfg.Name or "Keybind", keyVal)
            end
        end

        local function cancelListening()
            if not isWaiting then return end
            isWaiting = false
            btnKey.BackgroundColor3 = Theme.Input
            lblKey.Text = formatKey(value)
            if connCapture then
                connCapture:Disconnect()
                connCapture = nil
            end
        end

        LouisHub:RegisterConnection(UserInputService.InputBegan:Connect(function(input, processed)
            if processed or isWaiting or assignedThisFrame then return end
            local k, c, s, a = decomposeKey(value)
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

                    checkKeybindConflict(conflictEntry, newVal)
                    assignedThisFrame = true
                    task.defer(function() assignedThisFrame = false end)
                    updateKey(newVal, false)
                end
            end)
            LouisHub:RegisterConnection(connCapture)
        end)

        local elemObj = {
            Set = function(v, fireCallback) updateKey(v, fireCallback or false) end,
            Get = function() return value end,
            CurrentBind = value,
        }
        LouisHub.Elements[flag] = elemObj
        LouisHub.Options[flag]  = elemObj

        return elemObj
    end

    function Section:Label(cfg)
        cfg = cfg or {}
        local flag  = cfg.Flag or ("Label_" .. tostring(math.random(1e5, 1e6)))
        local isDirectLabel = (cfg.Value == nil)
        local valueStr = tostring(cfg.Value or "")
        nonPersistentFlags[flag] = true

        local targetCont = self:_GetTargetContainer("Label", cfg)
        local row, lbl = createHeader(26, cfg.Text or "Label", 1, isDirectLabel and -16 or -100, nil, targetCont)
        addTextTooltip(row, cfg.Text or "Label", cfg.Tooltip or cfg.Description, lbl)
        registerSearchable(row, cfg.Text or "Label", cfg.VisibleIf)

        local lblValue = nil
        if not isDirectLabel then
            lblValue = Utils.Text({
                Parent = row, Text = valueStr, Size = UDim2.new(0, 90, 1, 0),
                Position = UDim2.new(1, -96, 0, 0), Alignment = Enum.TextXAlignment.Right,
                Color = Theme.AccentLight, TextSize = 10.5, Truncate = true,
            })
            LouisHub:RegisterThemeObject(lblValue, "TextColor3", "AccentLight")
        end

        local function setVal(v)
            local txt = tostring(v)
            realFlags[flag] = v
            if isDirectLabel then
                lbl.Text = txt
            else
                valueStr = txt
                if lblValue then lblValue.Text = valueStr end
            end
        end

        realFlags[flag] = cfg.Value or cfg.Text
        local elemObj = {
            Set     = function(v) setVal(v) end,
            SetText = function(v) setVal(v) end,
            Get     = function() return isDirectLabel and lbl.Text or valueStr end,
            Row     = row,
        }
        LouisHub.Elements[flag] = elemObj

        local updateInterval = tonumber(cfg.Every)
        local updateFn = cfg.Update
        if updateInterval and updateFn and type(updateFn) == "function" and updateInterval >= 0.05 then
            autoUpdateLabels[lblValue or lbl] = {
                interval = updateInterval,
                fn = updateFn,
                apply = setVal,
                flag = flag,
                nextTime = os.clock() + updateInterval,
            }
        end

        return elemObj
    end

    function Section:Progress(cfg)
        cfg = cfg or {}
        local flag  = cfg.Flag or ("Progress_" .. tostring(math.random(1e5, 1e6)))
        local value = math.clamp(cfg.Default or 0, 0, 100)
        nonPersistentFlags[flag] = true
        realFlags[flag] = value

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
        LouisHub:RegisterThemeObject(lblVal, "TextColor3", "AccentLight")

        local bg = Utils.Frame({
            Parent = row, Size = UDim2.new(1, -12, 0, 5),
            Position = UDim2.new(0, 6, 0, 22), Color = Theme.Input,
            Radius = 3, Transparency = 0.4,
        })
        LouisHub:RegisterThemeObject(bg, "BackgroundColor3", "Input")

        local fill = Utils.Frame({
            Parent = bg, Size = UDim2.new(value / 100, 0, 1, 0),
            Color = Theme.Accent, Radius = 3, Transparency = 0, Border = false,
        })
        LouisHub:RegisterThemeObject(fill, "BackgroundColor3", "Accent")
        Utils.AccentGradient(fill)

        local function setProgress(v)
            if type(v) ~= "number" then return end
            value = math.clamp(v, 0, 100)
            Utils.Tween(fill, {Size = UDim2.new(value / 100, 0, 1, 0)}, LouisHub.Motion.Expand)
            lblVal.Text = math.floor(value + 0.5) .. "%"
            realFlags[flag] = value
        end

        local elemObj = {
            Set = function(v) setProgress(v) end,
            Get = function() return value end,
        }
        LouisHub.Elements[flag] = elemObj
        return elemObj
    end

    function Section:Paragraph(cfg)
        cfg = cfg or {}
        local targetCont = self:_GetTargetContainer("Paragraph", cfg)
        local frame = Utils.Frame({
            Parent = targetCont, Size = UDim2.new(1, 0, 0, 0),
            Color = Theme.Row, Order = nextOrder(), Radius = 6,
            Transparency = 0.5,
        })
        frame.AutomaticSize = Enum.AutomaticSize.Y
        LouisHub:RegisterThemeObject(frame, "BackgroundColor3", "Row")

        local pad = Instance.new("UIPadding")
        pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
        pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
        pad.Parent = frame

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 2)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = frame

        local titleParam = cfg.Title
        if titleParam then
            local lblTit = Utils.Text({
                Parent = frame, Text = titleParam,
                Size = UDim2.new(1, 0, 0, 0), Font = Enum.Font.GothamBold,
                TextSize = 11, Color = Theme.Highlight, Wrapped = true, Order = 1,
            })
            lblTit.AutomaticSize = Enum.AutomaticSize.Y
            LouisHub:RegisterThemeObject(lblTit, "TextColor3", "Highlight")
        end

        local bodyParam = cfg.Content or cfg.Text or ""
        local lblBody = Utils.Text({
            Parent = frame, Text = bodyParam,
            Size = UDim2.new(1, 0, 0, 0), TextSize = 10.5, Color = Theme.Text,
            Wrapped = true, Order = 2,
        })
        lblBody.AutomaticSize = Enum.AutomaticSize.Y
        LouisHub:RegisterThemeObject(lblBody, "TextColor3", "Text")

        return {
            Instance = frame,
            Set = function(...)
                local t = normalizeArgSet(...)
                lblBody.Text = tostring(t)
            end,
        }
    end

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
        LouisHub:RegisterThemeObject(line, "BackgroundColor3", "Accent")
        Utils.AccentGradient(line)
        return { Instance = row }
    end

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
        img.Image = type(cfg.Url) == "string" and cfg.Url or ""
        img.ScaleType = Enum.ScaleType.Fit
        img.Size = UDim2.new(1, 0, 1, 0)
        img.Parent = row
        Utils.Corner(img, 6)
        LouisHub:RegisterThemeObject(img, "BackgroundColor3", "Row")
        return {
            Set = function(...)
                local u = normalizeArgSet(...)
                if type(u) == "string" then img.Image = u end
            end,
            Get = function() return img.Image end,
            Instance = img,
        }
    end

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
        local groupObj = { Instance = rowG }
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

    for _, n in ipairs({
        "Button", "Toggle", "Checkbox", "Slider", "RangeSlider",
        "NumberStepper", "Input", "TagInput", "Dropdown", "RadioGroup", "ColorPicker", "Keybind",
    }) do
        Utils.WrapLockableControl(Section, Section.container, n)
    end
end

LouisHub._ApplyControlMethods = applyControlMethods

-- =====================================================================
-- SECTION 24: STACKABLE GLASS NOTIFICATIONS ENGINE
-- =====================================================================
local notifGuiRef = nil
local notifContainer = nil
local MAX_SIMULTANEOUS_NOTIFS = 4
local notifQueue = {}
local activeNotifCount = 0

local function ensureNotificationContainer()
    if notifContainer and notifContainer.Parent then return notifContainer end
    local parent = getGuiContainer()
    if not notifGuiRef or not notifGuiRef.Parent then
        notifGuiRef = (parent and parent:FindFirstChild("LouisHub_NotificationGui")) or Instance.new("ScreenGui")
        notifGuiRef.Name = "LouisHub_NotificationGui"
        notifGuiRef.ResetOnSpawn = false
        notifGuiRef.IgnoreGuiInset = true
        notifGuiRef.DisplayOrder = 10000000
        notifGuiRef.Parent = parent
        protectGuiElement(notifGuiRef)
        LouisHub:RegisterInstance(notifGuiRef)
    end

    notifContainer = notifGuiRef:FindFirstChild("LouisHub_Notifications")
    if not notifContainer then
        notifContainer = Instance.new("Frame")
        notifContainer.Name = "LouisHub_Notifications"
        notifContainer.BackgroundTransparency = 1
        notifContainer.Size = UDim2.new(0, 310, 1, -20)
        notifContainer.Position = UDim2.new(1, -320, 0, 10)
        notifContainer.ZIndex = 10000
        notifContainer.Parent = notifGuiRef

        local listLayout = Instance.new("UIListLayout")
        listLayout.Name = "UIListLayout"
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
        listLayout.Padding = UDim.new(0, 8)
        listLayout.Parent = notifContainer
    end
    return notifContainer
end

local NOTIF_TYPE_COLORS = {
    Success = Color3.fromRGB(46, 204, 113),
    Warning = Color3.fromRGB(241, 196, 15),
    Error   = Color3.fromRGB(231, 76, 60),
    Info    = Color3.fromRGB(90, 140, 210),
}

local function showNotificationCard(data)
    activeNotifCount = activeNotifCount + 1
    local container = ensureNotificationContainer()

    local title = data.Title or "Notification"
    local content = data.Content or ""
    local iconName = data.Icon or "info"
    local source = data.ImageSource or "Material"
    local duration = data.Duration or math.min(math.max((#content * 0.08) + 2.5, 3), 10)
    local nType = data.Type
    local accentCol = (nType and NOTIF_TYPE_COLORS[nType]) or Theme.Accent

    local card = Instance.new("Frame")
    card.Name = title
    card.BackgroundColor3 = Theme.Panel
    card.BackgroundTransparency = 1
    card.BorderSizePixel = 0
    card.ClipsDescendants = true
    card.Size = UDim2.new(1, 0, 0, 0)
    card.ZIndex = 10001
    card.Parent = container

    Utils.Corner(card, 8)
    local stroke = Utils.Stroke(card, accentCol, 1, 1)

    local blurData = attachGlassShader(card)

    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://1316045217"
    shadow.ImageColor3 = Color3.new(0, 0, 0)
    shadow.ImageTransparency = 1
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(10, 10, 118, 118)
    shadow.Size = UDim2.new(1, 14, 1, 14)
    shadow.Position = UDim2.new(0, -7, 0, -7)
    shadow.ZIndex = 10000
    shadow.Parent = card

    local iconImg = Instance.new("ImageLabel")
    iconImg.Name = "Icon"
    iconImg.BackgroundTransparency = 1
    iconImg.ImageTransparency = 1
    iconImg.Size = UDim2.new(0, 22, 0, 22)
    iconImg.Position = UDim2.new(0, 10, 0, 10)
    iconImg.ZIndex = 10002
    iconImg.Parent = card

    local iconData = resolveIcon(iconName, source)
    if type(iconData) == "table" then
        iconImg.Image = "rbxassetid://" .. tostring(iconData.id)
        iconImg.ImageRectSize = iconData.imageRectSize
        iconImg.ImageRectOffset = iconData.imageRectOffset
    elseif type(iconData) == "string" then
        iconImg.Image = iconData
    else
        iconImg.Visible = false
    end

    local offsetX = iconImg.Visible and 38 or 12
    local reduceWidth = iconImg.Visible and -44 or -24

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Name = "Title"
    titleLbl.BackgroundTransparency = 1
    titleLbl.TextTransparency = 1
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 13
    titleLbl.TextColor3 = Theme.Highlight
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Size = UDim2.new(1, reduceWidth, 0, 20)
    titleLbl.Position = UDim2.new(0, offsetX, 0, 10)
    titleLbl.Text = title
    titleLbl.ZIndex = 10002
    titleLbl.Parent = card

    local descLbl = Instance.new("TextLabel")
    descLbl.Name = "Description"
    descLbl.BackgroundTransparency = 1
    descLbl.TextTransparency = 1
    descLbl.Font = Enum.Font.Gotham
    descLbl.TextSize = 11
    descLbl.TextColor3 = Theme.Text
    descLbl.TextXAlignment = Enum.TextXAlignment.Left
    descLbl.TextWrapped = true
    descLbl.Size = UDim2.new(1, reduceWidth, 0, 0)
    descLbl.Position = UDim2.new(0, offsetX, 0, 30)
    descLbl.Text = content
    descLbl.ZIndex = 10002
    descLbl.Parent = card

    local boundsY = TextService:GetTextSize(content, 11, Enum.Font.Gotham, Vector2.new(250, 1000)).Y
    local totalHeight = math.max(48, boundsY + 42)
    descLbl.Size = UDim2.new(1, reduceWidth, 0, boundsY)

    Utils.Tween(card, {Size = UDim2.new(1, 0, 0, totalHeight)}, 0.45, LouisHub.Motion.EaseEnter)
    Utils.Tween(card, {BackgroundTransparency = 0.45}, 0.35, LouisHub.Motion.EaseEnter)
    Utils.Tween(titleLbl, {TextTransparency = 0}, 0.3, LouisHub.Motion.EaseEnter)
    if iconImg.Visible then Utils.Tween(iconImg, {ImageTransparency = 0}, 0.3, LouisHub.Motion.EaseEnter) end
    Utils.Tween(descLbl, {TextTransparency = 0.15}, 0.3, LouisHub.Motion.EaseEnter)
    Utils.Tween(stroke, {Transparency = 0.6}, 0.35, LouisHub.Motion.EaseEnter)
    Utils.Tween(shadow, {ImageTransparency = 0.8}, 0.35, LouisHub.Motion.EaseEnter)

    local function close()
        if not (card and card.Parent) then return end
        Utils.Tween(card, {BackgroundTransparency = 1}, 0.3, LouisHub.Motion.EaseExit)
        Utils.Tween(stroke, {Transparency = 1}, 0.3, LouisHub.Motion.EaseExit)
        Utils.Tween(titleLbl, {TextTransparency = 1}, 0.25, LouisHub.Motion.EaseExit)
        Utils.Tween(descLbl, {TextTransparency = 1}, 0.25, LouisHub.Motion.EaseExit)
        if iconImg.Visible then Utils.Tween(iconImg, {ImageTransparency = 1}, 0.25, LouisHub.Motion.EaseExit) end
        Utils.Tween(shadow, {ImageTransparency = 1}, 0.25, LouisHub.Motion.EaseExit)
        Utils.Tween(card, {Size = UDim2.new(1, 0, 0, 0)}, 0.35, LouisHub.Motion.EaseExit)

        task.delay(0.36, function()
            pcall(function() card:Destroy() end)
            activeNotifCount = math.max(0, activeNotifCount - 1)
            local nextCard = table.remove(notifQueue, 1)
            if nextCard then showNotificationCard(nextCard) end
        end)
    end

    task.delay(duration, close)
end

function LouisHub:Notify(data)
    data = data or {}
    if activeNotifCount >= MAX_SIMULTANEOUS_NOTIFS then
        local priority = data.Priority or 0
        local pos = #notifQueue + 1
        for i, queued in ipairs(notifQueue) do
            if (queued.Priority or 0) < priority then
                pos = i
                break
            end
        end
        table.insert(notifQueue, pos, data)
        return
    end
    showNotificationCard(data)
end
LouisHub.Notification = LouisHub.Notify

-- =====================================================================
-- SECTION 25: MODAL CONFIRMATION DIALOG ENGINE
-- =====================================================================
function LouisHub:Confirm(cfg)
    cfg = cfg or {}
    local parent = getGuiContainer()
    local gui = self._guiConfirm or (parent and (parent:FindFirstChild("LouisHub_ScreenGui") or parent:FindFirstChild("LouisHub_NotificationGui")))
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

    local blurData = attachGlassShader(backdrop)

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
    LouisHub:RegisterThemeObject(card, "BackgroundColor3", "Panel")

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
        local iconAsset = resolveIcon(iconParam, "Material")
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
        LouisHub:RegisterThemeObject(lblTitle, "TextColor3", "Highlight")
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
        if themeKey then LouisHub:RegisterThemeObject(btn, "BackgroundColor3", themeKey) end
        if hasBorder then
            local strokeBorder = Utils.Stroke(btn, Theme.Border, 1, 0)
            LouisHub:RegisterThemeObject(strokeBorder, "Color", "Border")
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

-- =====================================================================
-- SECTION 26: LUNA CONFIG & CUSTOM THEME BUILDERS
-- =====================================================================
local ClassParser = {
    ["Toggle"] = {
        Save = function(flag, data)
            return {
                type = "Toggle",
                flag = flag,
                state = data.CurrentValue or false
            }
        end,
        Load = function(flag, data)
            if LouisHub.Options[flag] then
                LouisHub.Options[flag]:Set(data.state)
            end
        end
    },
    ["Slider"] = {
        Save = function(flag, data)
            return {
                type = "Slider",
                flag = flag,
                value = (data.CurrentValue and tostring(data.CurrentValue)),
            }
        end,
        Load = function(flag, data)
            if LouisHub.Options[flag] and data.value then
                LouisHub.Options[flag]:Set(tonumber(data.value) or data.value)
            end
        end
    },
    ["Input"] = {
        Save = function(flag, data)
            return {
                type = "Input",
                flag = flag,
                text = data.CurrentValue
            }
        end,
        Load = function(flag, data)
            if LouisHub.Options[flag] and data.text and type(data.text) == "string" then
                LouisHub.Options[flag]:Set(data.text)
            end
        end
    },
    ["Dropdown"] = {
        Save = function(flag, data)
            return {
                type = "Dropdown",
                flag = flag,
                value = data.CurrentOption
            }
        end,
        Load = function(flag, data)
            if LouisHub.Options[flag] and data.value then
                LouisHub.Options[flag]:Set(data.value)
            end
        end
    },
    ["Colorpicker"] = {
        Save = function(flag, data)
            local function Color3ToHex(color)
                return string.format("#%02X%02X%02X", math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255))
            end

            return {
                type = "Colorpicker",
                flag = flag,
                color = Color3ToHex(data.Color) or nil,
                alpha = data.Alpha
            }
        end,
        Load = function(flag, data)
            local function HexToColor3(hex)
                local r = tonumber(hex:sub(2, 3), 16) / 255
                local g = tonumber(hex:sub(4, 5), 16) / 255
                local b = tonumber(hex:sub(6, 7), 16) / 255
                return Color3.new(r, g, b)
            end

            if LouisHub.Options[flag] and data.color then
                LouisHub.Options[flag]:Set(HexToColor3(data.color))
            end
        end
    }
}

local function registerAdvancedLunaMethods(TabObj)
    function TabObj:BuildConfigSection()
        if not isFilesystemAvailable() then
            local secErr = self:CreateSection("Configurations", { Columns = 1 })
            secErr:Label({ Text = "Config system unavailable (No filesystem support)." })
            return "Config system unavailable."
        end

        local inputPath = nil
        local selectedConfig = nil

        local secCreator = self:CreateSection("Config Creator", { Columns = 1 })

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
                        ImageSource = "Material",
                        Content = "Config name cannot be empty."
                    })
                    return
                end

                local success, returned = LouisHub.SaveManager:Save(inputPath)
                if not success then
                    LouisHub:Notify({
                        Title = "Interface",
                        Icon = "warning",
                        ImageSource = "Material",
                        Content = "Unable to save config, error: " .. tostring(returned)
                    })
                else
                    LouisHub:Notify({
                        Title = "Interface",
                        Icon = "info",
                        ImageSource = "Material",
                        Content = string.format("Created config %q", inputPath),
                    })
                end

                if configSelection and configSelection.Refresh then
                    configSelection:Refresh(LouisHub.SaveManager:List())
                end
            end
        })

        local secSettings = self:CreateSection("Config Load/Settings", { Columns = 1 })

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
                        ImageSource = "Material",
                        Content = "Unable to load config, error: " .. tostring(returned)
                    })
                    return
                end

                LouisHub:Notify({
                    Title = "Interface",
                    Icon = "info",
                    ImageSource = "Material",
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
                        ImageSource = "Material",
                        Content = "Unable to overwrite config, error: " .. tostring(returned)
                    })
                    return
                end

                LouisHub:Notify({
                    Title = "Interface",
                    Icon = "info",
                    ImageSource = "Material",
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
                    writefile(LouisHub.ConfigFolder .. "/autoload.txt", name)
                end)
                if loadLabel then
                    loadLabel:Set("Current autoload config: " .. name)
                end

                LouisHub:Notify({
                    Title = "Interface",
                    Icon = "info",
                    ImageSource = "Material",
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
                if isFilesystemAvailable() and type(isfile) == "function" and isfile(LouisHub.ConfigFolder .. "/autoload.txt") then
                    pcall(delfile, LouisHub.ConfigFolder .. "/autoload.txt")
                end
                if loadLabel then
                    loadLabel:Set("None")
                end

                LouisHub:Notify({
                    Title = "Interface",
                    Icon = "info",
                    ImageSource = "Material",
                    Content = "Deleted Autoload file.",
                })
            end,
        })

        if isFilesystemAvailable() and type(isfile) == "function" and isfile(LouisHub.ConfigFolder .. "/autoload.txt") then
            local successRead, name = pcall(readfile, LouisHub.ConfigFolder .. "/autoload.txt")
            if successRead and name and loadLabel then
                loadLabel:Set("Current autoload config: " .. name)
            end
        end
    end

    function TabObj:BuildThemeSection()
        local secEditor = self:CreateSection("Custom Editor", { Columns = 1 })

        local c1cp = secEditor:ColorPicker({
            Text = "Color 1",
            Color = Color3.fromRGB(117, 164, 206),
        }, "LunaInterfaceSuitePrebuiltCPC1")

        local c2cp = secEditor:ColorPicker({
            Text = "Color 2",
            Color = Color3.fromRGB(123, 201, 201),
        }, "LunaInterfaceSuitePrebuiltCPC2")

        local c3cp = secEditor:ColorPicker({
            Text = "Color 3",
            Color = Color3.fromRGB(224, 138, 184),
        }, "LunaInterfaceSuitePrebuiltCPC3")

        local function updateGradient()
            local c1 = (c1cp and c1cp:Get()) or Color3.fromRGB(255, 255, 255)
            local c2 = (c2cp and c2cp:Get()) or Color3.fromRGB(255, 255, 255)
            local c3 = (c3cp and c3cp:Get()) or Color3.fromRGB(255, 255, 255)

            LouisHub.Theme.Accent      = c1
            LouisHub.Theme.AccentLight = c2
            LouisHub.Theme.Highlight   = c3

            LouisHub.ThemeGradient = ColorSequence.new{
                ColorSequenceKeypoint.new(0.00, c1),
                ColorSequenceKeypoint.new(0.50, c2),
                ColorSequenceKeypoint.new(1.00, c3)
            }
            LouisHub.ThemeManager:ApplyTheme(LouisHub.Theme)
        end

        task.spawn(function()
            task.wait(0.2)
            if c1cp then c1cp.Callback = updateGradient end
            if c2cp then c2cp.Callback = updateGradient end
            if c3cp then c3cp.Callback = updateGradient end
        end)

        local secPresets = self:CreateSection("Preset Gradients", { Columns = 2 })

        for presetName, colors in pairs(PresetGradients) do
            secPresets:Button({
                Text = tostring(presetName),
                Callback = function()
                    if c1cp then c1cp:Set(colors[1], false) end
                    if c2cp then c2cp:Set(colors[2], false) end
                    if c3cp then c3cp:Set(colors[3], false) end
                    updateGradient()
                end,
            })
        end
    end
end
LouisHub._RegisterAdvancedLunaMethods = registerAdvancedLunaMethods

-- =====================================================================
-- SECTION 27: LUNA HOME DASHBOARD PORT (PLAYER PROFILE & STATS)
-- =====================================================================
local function createLunaHomeTab(Window, HomeTabSettings)
    HomeTabSettings = kwargify({
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

    local execName = detectExecutor()
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
        pcall(function() regionStr = LocalizationService:GetCountryRegionForPlayerAsync(LocalPlayer) end)
    end
    secClient:Label({ Text = "Region", Value = regionStr, Column = 2 })

    local secDiscord = homeTab:CreateSection("Discord Community", { Columns = 1 })
    secDiscord:Button({
        Text = "Join Official Discord Server",
        Icon = "chat",
        Callback = function()
            local link = "https://discord.gg/" .. tostring(HomeTabSettings.DiscordInvite)
            if setclipboard then setclipboard(link) end
            if executeRequest then
                pcall(function()
                    executeRequest({
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

-- =====================================================================
-- SECTION 28: PREINSTALLED SYSTEM & HARDWARE DIAGNOSTICS TAB
-- =====================================================================
local function addCompletePreinstalledTab(Window, cfg)
    cfg = cfg or {}

    local catSystem = Window:CreateCategory({ Name = "System", Icon = "settings" })
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
    local lblHealth = secInfo:Label({
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
    local capabilities = LouisHub.Capabilities
    secDiag:Label({ Text = "Device Type", Value = capabilities.Type .. " (" .. capabilities:PlatformName() .. ")", Column = 1 })
    secDiag:Label({ Text = "Screen Resolution", Value = math.floor(capabilities.ViewportSize.X) .. "x" .. math.floor(capabilities.ViewportSize.Y), Column = 1 })

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

    local secAppearance = sysTab:CreateSection("Appearance & Dimensions", { Columns = 2 })
    local themeNames = {}
    for n in pairs(LouisHub.ThemeManager.Themes) do table.insert(themeNames, n) end
    table.sort(themeNames)

    for n in pairs(PresetGradients) do
        table.insert(themeNames, "Gradient: " .. n)
    end

    secAppearance:Dropdown({
        Text = "Theme Palette",
        Flag = "sys_theme",
        Options = themeNames,
        Default = Themes.Default,
        Column = 1,
        Callback = function(v)
            LouisHub.ThemeManager:ApplyTheme(v)
            LouisHub:Notify({ Title = "Appearance", Content = "Theme " .. v .. " applied.", Duration = 2 })
            LouisHub.SaveManager:SaveUI("preinstalled")
        end
    })

    secAppearance:Slider({
        Text = "Interface Scale",
        Flag = "sys_scale",
        Min = 70, Max = 130, Increment = 5, Suffix = "%", Default = 100,
        Column = 1,
        Callback = function(v)
            if Window._main and Window._main:FindFirstChildOfClass("UIScale") then
                Window._main:FindFirstChildOfClass("UIScale").Scale = (v / 100)
            end
            LouisHub.SaveManager:SaveUI("preinstalled")
        end
    })

    secAppearance:Slider({
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

    secAppearance:Slider({
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

    LouisHub:MarkAsUI({"sys_theme", "sys_scale", "sys_width", "sys_height"})

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

-- =====================================================================
-- SECTION 29: WINDOW LIFECYCLE HOOKS & TERMINATION ENGINE
-- =====================================================================
local baseCreateWindow = LouisHub.CreateWindow
function LouisHub:CreateWindow(config)
    local Window = baseCreateWindow(self, config)

    local catSystem = Window:CreateCategory({ Name = "System", Icon = "settings" })

    local tabConfigLuna = catSystem:CreateTab({
        Name = "Config",
        Icon = "settings",
        ShowTitle = true
    })
    LouisHub._RegisterAdvancedLunaMethods(tabConfigLuna)
    tabConfigLuna:BuildConfigSection()
    tabConfigLuna:BuildThemeSection()

    if config.PreinstalledTab ~= false then
        addCompletePreinstalledTab(Window, config)
    end

    function Window:CreateHomeTab(hSettings)
        return createLunaHomeTab(Window, hSettings)
    end

    local originalCreateCategory = Window.CreateCategory
    function Window:CreateCategory(catCfg)
        local CatObj = originalCreateCategory(self, catCfg)
        local originalCreateTab = CatObj.CreateTab
        function CatObj:CreateTab(tabCfg, iconParamOverride)
            local TabObj = originalCreateTab(self, tabCfg, iconParamOverride)
            LouisHub._RegisterAdvancedLunaMethods(TabObj)
            return TabObj
        end
        return CatObj
    end

    return Window
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
        Title   = "Active Script Detected",
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

-- =====================================================================
-- SECTION 30: GLOBAL ENVIRONMENT EXPORT
-- =====================================================================
_G.LouisHub = LouisHub

if getgenv then
    getgenv().LouisHub = LouisHub
end

return LouisHub
