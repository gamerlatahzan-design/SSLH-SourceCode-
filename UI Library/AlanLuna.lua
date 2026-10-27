-- LOUIS HUB | PART 1A | continues in PART 1B

local LouisHub = {}
LouisHub.__index = LouisHub
LouisHub.Version = "5.0.0"
LouisHub.LogoAssetId = "rbxthumb://type=Asset&id=104436283956004&w=420&h=420"

-- =====================================================================
-- SECTION 1: SINGLE-INSTANCE ENFORCEMENT & AUTO-CLEANUP
-- =====================================================================
local GLOBAL_REGISTRY_KEY = "_LOUIS_HUB_V5_REGISTRY"
local environment = (type(getgenv) == "function" and getgenv()) or _G

-- Bersihkan instance script lama
if environment[GLOBAL_REGISTRY_KEY] then
    local oldLibrary = environment[GLOBAL_REGISTRY_KEY]
    if type(oldLibrary) == "table" and type(oldLibrary.Destroy) == "function" then
        pcall(function() oldLibrary:Destroy() end)
    end
    environment[GLOBAL_REGISTRY_KEY] = nil
end

-- Hancurkan SEMUA sisa ScreenGui lama yang masih nyangkut di layar
pcall(function()
    local container = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui")
    if container then
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("ScreenGui") and child.Name:find("LouisHub") then
                child.Enabled = false
                pcall(function() child:Destroy() end)
            end
        end
    end
end)

environment[GLOBAL_REGISTRY_KEY] = LouisHub

-- Set logo resmi pakai rbxthumb (DIJAMIN MUNCUL 100%)
LouisHub.LogoAssetId = "rbxthumb://type=Asset&id=104436283956004&w=420&h=420"

-- =====================================================================
-- SECTION 2: SERVICE CACHE & RUNTIME RESOLUTION
-- =====================================================================
local Services = setmetatable({}, {
    __index = function(self, serviceName)
        local success, service = pcall(function()
            return game:GetService(serviceName)
        end)
        if success and service then
            rawset(self, serviceName, service)
            return service
        end
        return nil
    end
})

local Players          = Services.Players
local UserInputService = Services.UserInputService
local TweenService     = Services.TweenService
local RunService       = Services.RunService
local HttpService      = Services.HttpService
local TextService      = Services.TextService
local CoreGui          = Services.CoreGui
local Lighting         = Services.Lighting
local TeleportService  = Services.TeleportService

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    pcall(function()
        LocalPlayer = Players.PlayerAdded:Wait()
    end)
end

-- =====================================================================
-- SECTION 3: CENTRAL JANITOR / LIFECYCLE RESOURCE COLLECTOR
-- =====================================================================
local Janitor = {}
Janitor.__index = Janitor

function Janitor.new()
    local self = setmetatable({}, Janitor)
    self._objects = {}
    self._isCleaned = false
    return self
end

function Janitor:Add(item, customCleanupMethod)
    if not item or self._isCleaned then return item end

    table.insert(self._objects, {
        Target = item,
        Method = customCleanupMethod
    })

    return item
end

function Janitor:Cleanup()
    if self._isCleaned then return end
    self._isCleaned = true

    for index = #self._objects, 1, -1 do
        local entry = self._objects[index]
        local target = entry.Target
        local method = entry.Method

        pcall(function()
            if type(method) == "string" and typeof(target) == "Instance" and type(target[method]) == "function" then
                target[method](target)
            elseif type(method) == "function" then
                method(target)
            elseif typeof(target) == "RBXScriptConnection" then
                target:Disconnect()
            elseif typeof(target) == "Instance" then
                target:Destroy()
            elseif type(target) == "thread" then
                if coroutine.status(target) ~= "dead" then
                    task.cancel(target)
                end
            elseif type(target) == "table" and type(target.Destroy) == "function" then
                target:Destroy()
            elseif type(target) == "table" and type(target.Remove) == "function" then
                target:Remove()
            end
        end)

        self._objects[index] = nil
    end
end

LouisHub.RootJanitor = Janitor.new()
LouisHub.Janitor = Janitor

-- =====================================================================
-- SECTION 4: ERROR LOGGING STREAM & RECOVERY
-- =====================================================================
LouisHub.Errors = {}
local MAX_ERROR_ENTRIES = 80

function LouisHub:Log(category, errorMessage)
    local record = {
        Timestamp = os.time(),
        Category = tostring(category or "General"),
        Message = tostring(errorMessage or "Unknown execution anomaly")
    }

    table.insert(self.Errors, record)
    if #self.Errors > MAX_ERROR_ENTRIES then
        table.remove(self.Errors, 1)
    end

    if self.DebugMode then
        warn(string.format("[Louis Hub V5] [%s]: %s", record.Category, record.Message))
    end
end

function LouisHub:GetErrors()
    local dump = {}
    for i, entry in ipairs(self.Errors) do
        dump[i] = {
            Timestamp = entry.Timestamp,
            Category = entry.Category,
            Message = entry.Message
        }
    end
    return dump
end

function LouisHub:ClearErrors()
    table.clear(self.Errors)
end

-- =====================================================================
-- SECTION 5: EXECUTOR DETECTION & CAPABILITIES PROFILER
-- =====================================================================
local function identifyExecutor()
    if type(identifyexecutor) == "function" then
        local success, result = pcall(identifyexecutor)
        if success and result and result ~= "" then
            return result
        end
    end
    if type(getexecutorname) == "function" then
        local success, result = pcall(getexecutorname)
        if success and result and result ~= "" then
            return result
        end
    end
    return "Standard Roblox Environment"
end

local Capabilities = {
    Executor = identifyExecutor(),
    HasFilesystem = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function",
    HasFolders = type(makefolder) == "function" and type(isfolder) == "function",
    HasFileDeletion = type(delfile) == "function",
    HasFileList = type(listfiles) == "function",
    HasClipboard = type(setclipboard) == "function",
    HasHttpRequest = (type(request) == "function") or (syn and type(syn.request) == "function") or (http and type(http.request) == "function") or (type(http_request) == "function"),
    HasProtectGui = (syn and type(syn.protect_gui) == "function") or (type(protectgui) == "function"),
    HasGetHui = type(gethui) == "function",
    IsStudio = RunService:IsStudio(),
    HasTouch = UserInputService.TouchEnabled,
    HasMouse = UserInputService.MouseEnabled,
    HasKeyboard = UserInputService.KeyboardEnabled,
    HasGamepad = UserInputService.GamepadEnabled,
    PlatformName = (function()
        local ok, platform = pcall(function() return UserInputService:GetPlatform() end)
        return (ok and platform and platform.Name) or "Unknown"
    end)()
}

function Capabilities:GetDeviceCategory()
    if self.IsStudio then return "Studio" end
    if self.PlatformName:find("Xbox") or self.PlatformName:find("PS") then return "Console" end
    if self.HasTouch and not self.HasMouse then return "Mobile" end
    if self.HasTouch and self.HasMouse then return "Tablet" end
    return "Desktop"
end

LouisHub.Capabilities = Capabilities

-- =====================================================================
-- SECTION 6: SAFE CONTAINER MOUNTING & PROTECTION
-- =====================================================================
function LouisHub:GetSafeContainer()
    if self.Capabilities.HasGetHui then
        local okHui, hui = pcall(gethui)
        if okHui and hui then return hui end
    end

    if self.Capabilities.HasProtectGui and CoreGui then
        return CoreGui
    end

    if CoreGui and not self.Capabilities.IsStudio then
        local okCore = pcall(function() local _ = CoreGui.Name end)
        if okCore then return CoreGui end
    end

    if LocalPlayer then
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if playerGui then return playerGui end
    end

    return CoreGui or game:GetService("StarterGui")
end

function LouisHub:ProtectContainer(screenGuiInstance)
    if not screenGuiInstance then return end

    pcall(function()
        if syn and type(syn.protect_gui) == "function" then
            syn.protect_gui(screenGuiInstance)
        elseif type(protectgui) == "function" then
            protectgui(screenGuiInstance)
        end
    end)
end

-- LOUIS HUB | PART 1B | continues in PART 1C

-- =====================================================================
-- SECTION 7: EXPANDED THEME PALETTES & EVENT PRESETS (18 THEMES)
-- =====================================================================
local BuiltInThemes = {
    -- ── OFFICIAL SIGNATURE THEME (BASED ON NEW LOGO) ─────────────────
    ["Louis Signature"] = {
        Background  = Color3.fromRGB(10, 14, 26),
        Surface     = Color3.fromRGB(16, 22, 40),
        SurfaceAlt  = Color3.fromRGB(24, 32, 58),
        Accent      = Color3.fromRGB(0, 230, 255),      -- Neon Cyan
        AccentAlt   = Color3.fromRGB(175, 45, 255),     -- Cyber Purple
        Highlight   = Color3.fromRGB(190, 245, 255),
        Text        = Color3.fromRGB(245, 250, 255),
        TextMuted   = Color3.fromRGB(135, 150, 185),
        Border      = Color3.fromRGB(36, 48, 88),
        Success     = Color3.fromRGB(52, 211, 153),
        Warning     = Color3.fromRGB(251, 191, 36),
        Error       = Color3.fromRGB(248, 113, 113),
        GradientA   = Color3.fromRGB(0, 230, 255),      -- Cyan
        GradientB   = Color3.fromRGB(80, 130, 255),     -- Deep Royal Blue
        GradientC   = Color3.fromRGB(175, 45, 255),     -- Vivid Violet Purple
        Rotation    = 45
    },

    -- ── SPECIAL EVENT THEMES ─────────────────────────────────────────
    ["Ramadhan"] = {
        Background  = Color3.fromRGB(10, 20, 16),
        Surface     = Color3.fromRGB(16, 32, 25),
        SurfaceAlt  = Color3.fromRGB(24, 46, 36),
        Accent      = Color3.fromRGB(16, 185, 129),     -- Islamic Emerald Green
        AccentAlt   = Color3.fromRGB(234, 179, 8),      -- Crescent Moon Gold
        Highlight   = Color3.fromRGB(254, 240, 138),
        Text        = Color3.fromRGB(240, 253, 244),
        TextMuted   = Color3.fromRGB(130, 168, 145),
        Border      = Color3.fromRGB(34, 68, 52),
        Success     = Color3.fromRGB(52, 211, 153),
        Warning     = Color3.fromRGB(250, 204, 21),
        Error       = Color3.fromRGB(239, 68, 68),
        GradientA   = Color3.fromRGB(16, 185, 129),     -- Emerald
        GradientB   = Color3.fromRGB(202, 138, 4),      -- Amber Gold
        GradientC   = Color3.fromRGB(250, 204, 21),     -- Divine Gold
        Rotation    = 45
    },
    ["Halloween"] = {
        Background  = Color3.fromRGB(18, 13, 24),
        Surface     = Color3.fromRGB(28, 20, 37),
        SurfaceAlt  = Color3.fromRGB(40, 28, 53),
        Accent      = Color3.fromRGB(249, 115, 22),     -- Spooky Pumpkin Orange
        AccentAlt   = Color3.fromRGB(168, 85, 247),     -- Witch Dark Violet
        Highlight   = Color3.fromRGB(254, 215, 170),
        Text        = Color3.fromRGB(250, 245, 255),
        TextMuted   = Color3.fromRGB(158, 136, 178),
        Border      = Color3.fromRGB(60, 42, 79),
        Success     = Color3.fromRGB(74, 222, 128),
        Warning     = Color3.fromRGB(250, 204, 21),
        Error       = Color3.fromRGB(239, 68, 68),
        GradientA   = Color3.fromRGB(249, 115, 22),     -- Pumpkin
        GradientB   = Color3.fromRGB(168, 85, 247),     -- Haunted Violet
        GradientC   = Color3.fromRGB(132, 204, 22),     -- Toxic Slime
        Rotation    = 45
    },
    ["Christmas"] = {
        Background  = Color3.fromRGB(20, 12, 14),
        Surface     = Color3.fromRGB(32, 18, 22),
        SurfaceAlt  = Color3.fromRGB(46, 26, 32),
        Accent      = Color3.fromRGB(225, 29, 72),      -- Santa Velvet Red
        AccentAlt   = Color3.fromRGB(34, 197, 94),      -- Pine Tree Green
        Highlight   = Color3.fromRGB(255, 255, 255),    -- Snow White
        Text        = Color3.fromRGB(255, 245, 245),
        TextMuted   = Color3.fromRGB(175, 140, 145),
        Border      = Color3.fromRGB(75, 38, 46),
        Success     = Color3.fromRGB(74, 222, 128),
        Warning     = Color3.fromRGB(250, 204, 21),
        Error       = Color3.fromRGB(225, 29, 72),
        GradientA   = Color3.fromRGB(225, 29, 72),      -- Velvet Red
        GradientB   = Color3.fromRGB(255, 255, 255),    -- Frost White
        GradientC   = Color3.fromRGB(34, 197, 94),      -- Pine Green
        Rotation    = 45
    },
    ["Lunar New Year"] = {
        Background  = Color3.fromRGB(24, 10, 12),
        Surface     = Color3.fromRGB(38, 16, 20),
        SurfaceAlt  = Color3.fromRGB(54, 24, 30),
        Accent      = Color3.fromRGB(239, 68, 68),      -- Imperial Red
        AccentAlt   = Color3.fromRGB(234, 179, 8),      -- Fortune Gold
        Highlight   = Color3.fromRGB(254, 240, 138),
        Text        = Color3.fromRGB(255, 245, 245),
        TextMuted   = Color3.fromRGB(180, 135, 140),
        Border      = Color3.fromRGB(80, 35, 45),
        Success     = Color3.fromRGB(52, 211, 153),
        Warning     = Color3.fromRGB(250, 204, 21),
        Error       = Color3.fromRGB(239, 68, 68),
        GradientA   = Color3.fromRGB(239, 68, 68),
        GradientB   = Color3.fromRGB(220, 38, 38),
        GradientC   = Color3.fromRGB(234, 179, 8),
        Rotation    = 45
    },
    ["Cyberpunk 2077"] = {
        Background  = Color3.fromRGB(12, 13, 18),
        Surface     = Color3.fromRGB(20, 22, 30),
        SurfaceAlt  = Color3.fromRGB(30, 32, 45),
        Accent      = Color3.fromRGB(254, 240, 138),    -- High-Voltage Yellow
        AccentAlt   = Color3.fromRGB(6, 182, 212),      -- Cyan Data
        Highlight   = Color3.fromRGB(255, 255, 255),
        Text        = Color3.fromRGB(255, 255, 240),
        TextMuted   = Color3.fromRGB(150, 155, 170),
        Border      = Color3.fromRGB(60, 65, 85),
        Success     = Color3.fromRGB(34, 197, 94),
        Warning     = Color3.fromRGB(250, 204, 21),
        Error       = Color3.fromRGB(239, 68, 68),
        GradientA   = Color3.fromRGB(250, 204, 21),     -- Cyber Yellow
        GradientB   = Color3.fromRGB(239, 68, 68),      -- Glitch Red
        GradientC   = Color3.fromRGB(6, 182, 212),      -- Neon Cyan
        Rotation    = 60
    },

    -- ── POPULAR HIGH-CONTRAST THEMES ─────────────────────────────────
    ["Midnight"] = {
        Background  = Color3.fromRGB(15, 17, 23),
        Surface     = Color3.fromRGB(22, 26, 35),
        SurfaceAlt  = Color3.fromRGB(30, 35, 48),
        Accent      = Color3.fromRGB(94, 129, 244),
        AccentAlt   = Color3.fromRGB(138, 165, 255),
        Highlight   = Color3.fromRGB(190, 208, 255),
        Text        = Color3.fromRGB(242, 245, 255),
        TextMuted   = Color3.fromRGB(130, 138, 160),
        Border      = Color3.fromRGB(40, 46, 64),
        Success     = Color3.fromRGB(52, 211, 153),
        Warning     = Color3.fromRGB(251, 191, 36),
        Error       = Color3.fromRGB(248, 113, 113),
        GradientA   = Color3.fromRGB(94, 129, 244),
        GradientB   = Color3.fromRGB(147, 105, 255),
        GradientC   = Color3.fromRGB(192, 132, 252),
        Rotation    = 45
    },
    ["Aurora"] = {
        Background  = Color3.fromRGB(11, 20, 24),
        Surface     = Color3.fromRGB(17, 31, 37),
        SurfaceAlt  = Color3.fromRGB(24, 44, 53),
        Accent      = Color3.fromRGB(45, 212, 191),
        AccentAlt   = Color3.fromRGB(56, 189, 248),
        Highlight   = Color3.fromRGB(165, 243, 252),
        Text        = Color3.fromRGB(240, 253, 250),
        TextMuted   = Color3.fromRGB(115, 148, 158),
        Border      = Color3.fromRGB(32, 60, 72),
        Success     = Color3.fromRGB(74, 222, 128),
        Warning     = Color3.fromRGB(250, 204, 21),
        Error       = Color3.fromRGB(251, 113, 133),
        GradientA   = Color3.fromRGB(45, 212, 191),
        GradientB   = Color3.fromRGB(56, 189, 248),
        GradientC   = Color3.fromRGB(129, 140, 248),
        Rotation    = 45
    },
    ["Sunset"] = {
        Background  = Color3.fromRGB(24, 16, 22),
        Surface     = Color3.fromRGB(36, 23, 33),
        SurfaceAlt  = Color3.fromRGB(50, 31, 46),
        Accent      = Color3.fromRGB(249, 115, 22),
        AccentAlt   = Color3.fromRGB(244, 63, 94),
        Highlight   = Color3.fromRGB(254, 215, 170),
        Text        = Color3.fromRGB(255, 247, 237),
        TextMuted   = Color3.fromRGB(168, 135, 156),
        Border      = Color3.fromRGB(70, 42, 64),
        Success     = Color3.fromRGB(52, 211, 153),
        Warning     = Color3.fromRGB(251, 191, 36),
        Error       = Color3.fromRGB(239, 68, 68),
        GradientA   = Color3.fromRGB(249, 115, 22),
        GradientB   = Color3.fromRGB(244, 63, 94),
        GradientC   = Color3.fromRGB(192, 38, 211),
        Rotation    = 45
    },
    ["Ocean"] = {
        Background  = Color3.fromRGB(10, 18, 30),
        Surface     = Color3.fromRGB(16, 28, 46),
        SurfaceAlt  = Color3.fromRGB(22, 39, 65),
        Accent      = Color3.fromRGB(14, 165, 233),
        AccentAlt   = Color3.fromRGB(56, 189, 248),
        Highlight   = Color3.fromRGB(186, 230, 253),
        Text        = Color3.fromRGB(240, 249, 255),
        TextMuted   = Color3.fromRGB(125, 149, 176),
        Border      = Color3.fromRGB(31, 55, 88),
        Success     = Color3.fromRGB(45, 212, 191),
        Warning     = Color3.fromRGB(251, 191, 36),
        Error       = Color3.fromRGB(244, 63, 94),
        GradientA   = Color3.fromRGB(14, 165, 233),
        GradientB   = Color3.fromRGB(37, 99, 235),
        GradientC   = Color3.fromRGB(99, 102, 241),
        Rotation    = 45
    },
    ["Neon Cyber"] = {
        Background  = Color3.fromRGB(13, 11, 24),
        Surface     = Color3.fromRGB(21, 18, 38),
        SurfaceAlt  = Color3.fromRGB(31, 26, 56),
        Accent      = Color3.fromRGB(236, 72, 153),
        AccentAlt   = Color3.fromRGB(34, 211, 238),
        Highlight   = Color3.fromRGB(251, 207, 232),
        Text        = Color3.fromRGB(253, 244, 255),
        TextMuted   = Color3.fromRGB(155, 138, 185),
        Border      = Color3.fromRGB(54, 44, 94),
        Success     = Color3.fromRGB(34, 197, 94),
        Warning     = Color3.fromRGB(234, 179, 8),
        Error       = Color3.fromRGB(239, 68, 68),
        GradientA   = Color3.fromRGB(236, 72, 153),
        GradientB   = Color3.fromRGB(168, 85, 247),
        GradientC   = Color3.fromRGB(34, 211, 238),
        Rotation    = 60
    },
    ["Sakura"] = {
        Background  = Color3.fromRGB(26, 18, 22),
        Surface     = Color3.fromRGB(38, 26, 33),
        SurfaceAlt  = Color3.fromRGB(52, 36, 45),
        Accent      = Color3.fromRGB(244, 114, 182),
        AccentAlt   = Color3.fromRGB(251, 168, 212),
        Highlight   = Color3.fromRGB(254, 205, 232),
        Text        = Color3.fromRGB(253, 242, 248),
        TextMuted   = Color3.fromRGB(175, 141, 159),
        Border      = Color3.fromRGB(74, 49, 64),
        Success     = Color3.fromRGB(74, 222, 128),
        Warning     = Color3.fromRGB(250, 204, 21),
        Error       = Color3.fromRGB(248, 113, 113),
        GradientA   = Color3.fromRGB(244, 114, 182),
        GradientB   = Color3.fromRGB(251, 113, 133),
        GradientC   = Color3.fromRGB(253, 164, 175),
        Rotation    = 45
    },
    ["Emerald"] = {
        Background  = Color3.fromRGB(12, 22, 17),
        Surface     = Color3.fromRGB(18, 34, 26),
        SurfaceAlt  = Color3.fromRGB(26, 48, 37),
        Accent      = Color3.fromRGB(16, 185, 129),
        AccentAlt   = Color3.fromRGB(52, 211, 153),
        Highlight   = Color3.fromRGB(167, 243, 208),
        Text        = Color3.fromRGB(236, 253, 245),
        TextMuted   = Color3.fromRGB(118, 156, 135),
        Border      = Color3.fromRGB(35, 68, 52),
        Success     = Color3.fromRGB(34, 197, 94),
        Warning     = Color3.fromRGB(234, 179, 8),
        Error       = Color3.fromRGB(239, 68, 68),
        GradientA   = Color3.fromRGB(16, 185, 129),
        GradientB   = Color3.fromRGB(5, 150, 105),
        GradientC   = Color3.fromRGB(45, 212, 191),
        Rotation    = 45
    },
    ["Royal Purple"] = {
        Background  = Color3.fromRGB(18, 13, 28),
        Surface     = Color3.fromRGB(27, 20, 42),
        SurfaceAlt  = Color3.fromRGB(39, 29, 60),
        Accent      = Color3.fromRGB(147, 51, 234),
        AccentAlt   = Color3.fromRGB(168, 85, 247),
        Highlight   = Color3.fromRGB(216, 180, 254),
        Text        = Color3.fromRGB(250, 245, 255),
        TextMuted   = Color3.fromRGB(152, 133, 179),
        Border      = Color3.fromRGB(58, 42, 88),
        Success     = Color3.fromRGB(52, 211, 153),
        Warning     = Color3.fromRGB(251, 191, 36),
        Error       = Color3.fromRGB(244, 63, 94),
        GradientA   = Color3.fromRGB(147, 51, 234),
        GradientB   = Color3.fromRGB(124, 58, 237),
        GradientC   = Color3.fromRGB(192, 132, 252),
        Rotation    = 45
    },
    ["Crimson"] = {
        Background  = Color3.fromRGB(24, 12, 14),
        Surface     = Color3.fromRGB(36, 18, 21),
        SurfaceAlt  = Color3.fromRGB(52, 25, 30),
        Accent      = Color3.fromRGB(225, 29, 72),
        AccentAlt   = Color3.fromRGB(244, 63, 94),
        Highlight   = Color3.fromRGB(254, 205, 211),
        Text        = Color3.fromRGB(255, 241, 242),
        TextMuted   = Color3.fromRGB(173, 130, 136),
        Border      = Color3.fromRGB(75, 35, 42),
        Success     = Color3.fromRGB(74, 222, 128),
        Warning     = Color3.fromRGB(250, 204, 21),
        Error       = Color3.fromRGB(225, 29, 72),
        GradientA   = Color3.fromRGB(225, 29, 72),
        GradientB   = Color3.fromRGB(190, 18, 60),
        GradientC   = Color3.fromRGB(244, 63, 94),
        Rotation    = 45
    },
    ["Monochrome"] = {
        Background  = Color3.fromRGB(16, 16, 16),
        Surface     = Color3.fromRGB(26, 26, 26),
        SurfaceAlt  = Color3.fromRGB(38, 38, 38),
        Accent      = Color3.fromRGB(220, 220, 220),
        AccentAlt   = Color3.fromRGB(180, 180, 180),
        Highlight   = Color3.fromRGB(255, 255, 255),
        Text        = Color3.fromRGB(245, 245, 245),
        TextMuted   = Color3.fromRGB(140, 140, 140),
        Border      = Color3.fromRGB(55, 55, 55),
        Success     = Color3.fromRGB(160, 220, 160),
        Warning     = Color3.fromRGB(240, 210, 120),
        Error       = Color3.fromRGB(240, 130, 130),
        GradientA   = Color3.fromRGB(240, 240, 240),
        GradientB   = Color3.fromRGB(180, 180, 180),
        GradientC   = Color3.fromRGB(120, 120, 120),
        Rotation    = 45
    },
    ["Cotton Candy"] = {
        Background  = Color3.fromRGB(18, 18, 28),
        Surface     = Color3.fromRGB(26, 26, 40),
        SurfaceAlt  = Color3.fromRGB(36, 36, 56),
        Accent      = Color3.fromRGB(244, 114, 182),
        AccentAlt   = Color3.fromRGB(96, 165, 250),
        Highlight   = Color3.fromRGB(254, 215, 240),
        Text        = Color3.fromRGB(248, 250, 252),
        TextMuted   = Color3.fromRGB(148, 152, 178),
        Border      = Color3.fromRGB(54, 54, 82),
        Success     = Color3.fromRGB(52, 211, 153),
        Warning     = Color3.fromRGB(251, 191, 36),
        Error       = Color3.fromRGB(244, 63, 94),
        GradientA   = Color3.fromRGB(244, 114, 182),
        GradientB   = Color3.fromRGB(167, 139, 250),
        GradientC   = Color3.fromRGB(96, 165, 250),
        Rotation    = 45
    },
    ["Gold Luxe"] = {
        Background  = Color3.fromRGB(20, 18, 14),
        Surface     = Color3.fromRGB(31, 27, 21),
        SurfaceAlt  = Color3.fromRGB(45, 39, 30),
        Accent      = Color3.fromRGB(234, 179, 8),
        AccentAlt   = Color3.fromRGB(250, 204, 21),
        Highlight   = Color3.fromRGB(254, 240, 138),
        Text        = Color3.fromRGB(254, 252, 232),
        TextMuted   = Color3.fromRGB(168, 153, 125),
        Border      = Color3.fromRGB(68, 58, 44),
        Success     = Color3.fromRGB(74, 222, 128),
        Warning     = Color3.fromRGB(234, 179, 8),
        Error       = Color3.fromRGB(239, 68, 68),
        GradientA   = Color3.fromRGB(202, 138, 4),
        GradientB   = Color3.fromRGB(234, 179, 8),
        GradientC   = Color3.fromRGB(253, 224, 71),
        Rotation    = 45
    }
}

LouisHub.BuiltInThemes = BuiltInThemes
LouisHub.Themes = BuiltInThemes
LouisHub.ActiveThemeName = "Louis Signature"
LouisHub.CurrentTheme = BuiltInThemes["Louis Signature"]

-- =====================================================================
-- SECTION 8: DYNAMIC THEME ENGINE & LIVE SKINNING PIPELINE
-- =====================================================================
local ThemedElements = {}
local AnimatedGradients = {}

local function deepCopyTable(source)
    local target = {}
    for k, v in pairs(source) do
        if type(v) == "table" then
            target[k] = deepCopyTable(v)
        else
            target[k] = v
        end
    end
    return target
end

function LouisHub:RegisterThemeProperty(guiInstance, propertyName, themeColorKey)
    if not guiInstance or not propertyName or not themeColorKey then return end

    local entry = {
        Instance = guiInstance,
        Property = propertyName,
        Key = themeColorKey
    }

    table.insert(ThemedElements, entry)

    guiInstance.Destroying:Connect(function()
        local idx = table.find(ThemedElements, entry)
        if idx then
            table.remove(ThemedElements, idx)
        end
    end)

    if self.CurrentTheme and self.CurrentTheme[themeColorKey] then
        pcall(function()
            guiInstance[propertyName] = self.CurrentTheme[themeColorKey]
        end)
    end
end

function LouisHub:RegisterGradient(gradientInstance, customStops)
    if not gradientInstance or not gradientInstance:IsA("UIGradient") then return end

    local entry = {
        Instance = gradientInstance,
        Stops = customStops or nil
    }

    table.insert(AnimatedGradients, entry)

    gradientInstance.Destroying:Connect(function()
        local idx = table.find(AnimatedGradients, entry)
        if idx then
            table.remove(AnimatedGradients, idx)
        end
    end)

    self:RefreshGradientInstance(gradientInstance, customStops)
end

function LouisHub:RefreshGradientInstance(gradientInstance, customStops)
    if not gradientInstance or not gradientInstance.Parent then return end

    local theme = self.CurrentTheme
    local colA = (customStops and customStops[1]) or theme.GradientA
    local colB = (customStops and customStops[2]) or theme.GradientB
    local colC = (customStops and customStops[3]) or theme.GradientC

    pcall(function()
        gradientInstance.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.0, colA),
            ColorSequenceKeypoint.new(0.5, colB),
            ColorSequenceKeypoint.new(1.0, colC)
        })
    end)
end

function LouisHub:SetTheme(themeNameOrTable, animateTransition)
    local newTheme = nil
    local themeKey = nil

    if type(themeNameOrTable) == "string" then
        themeKey = themeNameOrTable
        newTheme = self.Themes[themeNameOrTable]
    elseif type(themeNameOrTable) == "table" then
        themeKey = "Custom"
        newTheme = themeNameOrTable
    end

    if not newTheme then return false, "Theme not found" end

    self.ActiveThemeName = themeKey
    self.CurrentTheme = newTheme

    local shouldAnimate = (animateTransition ~= false) and not self.ReduceMotion

    for index = #ThemedElements, 1, -1 do
        local entry = ThemedElements[index]
        local inst = entry.Instance
        local prop = entry.Property
        local key = entry.Key

        if inst and inst.Parent then
            local targetColor = newTheme[key]
            if targetColor and typeof(targetColor) == "Color3" then
                if shouldAnimate and typeof(inst[prop]) == "Color3" then
                    pcall(function()
                        TweenService:Create(inst, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                            [prop] = targetColor
                        }):Play()
                    end)
                else
                    pcall(function()
                        inst[prop] = targetColor
                    end)
                end
            end
        else
            table.remove(ThemedElements, index)
        end
    end

    for index = #AnimatedGradients, 1, -1 do
        local entry = AnimatedGradients[index]
        local grad = entry.Instance
        if grad and grad.Parent then
            self:RefreshGradientInstance(grad, entry.Stops)
        else
            table.remove(AnimatedGradients, index)
        end
    end

    if self.OnThemeChanged then
        pcall(self.OnThemeChanged, themeKey, newTheme)
    end

    return true
end

function LouisHub:GetThemes()
    local names = {}
    for name in pairs(self.Themes) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function LouisHub:GetTheme()
    return self.CurrentTheme, self.ActiveThemeName
end

function LouisHub:AddTheme(name, themeData)
    if type(name) ~= "string" or type(themeData) ~= "table" then return false end
    self.Themes[name] = deepCopyTable(themeData)
    return true
end

-- =====================================================================
-- SECTION 9: GLOBAL TRAVELING GRADIENT TICKER (SMOOTH PING-PONG LOOP)
-- =====================================================================
LouisHub.GradientSettings = {
    Enabled = true,
    Speed = 1.0,
    Direction = 1,
    CurrentOffset = 0,
    Elapsed = 0
}

local function startGradientTicker()
    local connection = RunService.Heartbeat:Connect(function(deltaTime)
        local settings = LouisHub.GradientSettings
        if not settings.Enabled or #AnimatedGradients == 0 or LouisHub.ReduceMotion then
            return
        end

        -- Akumulasi waktu kontinu
        settings.Elapsed = settings.Elapsed + (deltaTime * 1.5 * settings.Speed)

        -- Osilasi halus bolak-balik menggunakan gelombang sinus (bebas patah/snapping)
        local xOffset = math.sin(settings.Elapsed * settings.Direction) * 0.45

        for i = 1, #AnimatedGradients do
            local item = AnimatedGradients[i]
            local grad = item and item.Instance
            if grad and grad.Parent then
                grad.Offset = Vector2.new(xOffset, 0)
            end
        end
    end)

    LouisHub.RootJanitor:Add(connection)
end

startGradientTicker()

function LouisHub:SetGradientAnimation(enabled, speed, direction)
    if enabled ~= nil then self.GradientSettings.Enabled = (enabled == true) end
    if speed and type(speed) == "number" then self.GradientSettings.Speed = math.clamp(speed, 0.1, 5.0) end
    if direction and (direction == 1 or direction == -1) then self.GradientSettings.Direction = direction end
end

-- LOUIS HUB | PART 1C | continues in PART 1D

-- =====================================================================
-- SECTION 10: ADVANCED MOTION ENGINE & SPRING PROFILES
-- =====================================================================
LouisHub.ReduceMotion = false

LouisHub.Easing = {
    Smooth = {
        Style = Enum.EasingStyle.Exponential,
        Direction = Enum.EasingDirection.Out,
        Duration = 0.30
    },
    Snappy = {
        Style = Enum.EasingStyle.Quart,
        Direction = Enum.EasingDirection.Out,
        Duration = 0.20
    },
    Bounce = {
        Style = Enum.EasingStyle.Back,
        Direction = Enum.EasingDirection.Out,
        Duration = 0.35
    },
    Elastic = {
        Style = Enum.EasingStyle.Elastic,
        Direction = Enum.EasingDirection.Out,
        Duration = 0.50
    },
    Linear = {
        Style = Enum.EasingStyle.Linear,
        Direction = Enum.EasingDirection.InOut,
        Duration = 0.18
    }
}

local ActiveObjectTweens = setmetatable({}, { __mode = "k" })

local function generatePropertyToken(propertyTable)
    local sortedKeys = {}
    for key in pairs(propertyTable) do
        table.insert(sortedKeys, key)
    end
    table.sort(sortedKeys)
    return table.concat(sortedKeys, ":")
end

function LouisHub:Tween(guiObject, properties, duration, style, direction, onComplete)
    if not guiObject or not guiObject.Parent then return nil end

    local token = generatePropertyToken(properties)
    ActiveObjectTweens[guiObject] = ActiveObjectTweens[guiObject] or {}

    local existingTween = ActiveObjectTweens[guiObject][token]
    if existingTween then
        pcall(function()
            existingTween:Cancel()
        end)
        ActiveObjectTweens[guiObject][token] = nil
    end

    if self.ReduceMotion or duration == 0 then
        for prop, value in pairs(properties) do
            pcall(function()
                guiObject[prop] = value
            end)
        end
        if onComplete then
            task.spawn(onComplete)
        end
        return nil
    end

    local tweenDuration = duration or self.Easing.Smooth.Duration
    local tweenStyle = style or self.Easing.Smooth.Style
    local tweenDirection = direction or self.Easing.Smooth.Direction

    local tweenInfo = TweenInfo.new(tweenDuration, tweenStyle, tweenDirection)
    local success, tween = pcall(function()
        return TweenService:Create(guiObject, tweenInfo, properties)
    end)

    if success and tween then
        ActiveObjectTweens[guiObject][token] = tween

        local completeConnection
        completeConnection = tween.Completed:Connect(function()
            if completeConnection then
                completeConnection:Disconnect()
            end
            if ActiveObjectTweens[guiObject] and ActiveObjectTweens[guiObject][token] == tween then
                ActiveObjectTweens[guiObject][token] = nil
            end
            if onComplete then
                pcall(onComplete)
            end
        end)

        tween:Play()
        return tween
    end

    return nil
end

function LouisHub:ApplyPressAnimation(clickableObject, customIntensity)
    if not clickableObject or not clickableObject.Parent then return end

    local scaleModifier = clickableObject:FindFirstChild("_PressScaleModifier")
    if not scaleModifier then
        scaleModifier = Instance.new("UIScale")
        scaleModifier.Name = "_PressScaleModifier"
        scaleModifier.Scale = 1.0
        scaleModifier.Parent = clickableObject
    end

    local pressedScale = customIntensity or 0.92
    scaleModifier.Scale = pressedScale
    self:Tween(scaleModifier, { Scale = 1.0 }, 0.28, self.Easing.Bounce.Style, self.Easing.Bounce.Direction)
end

function LouisHub:ApplyHoverHighlight(triggerTarget, targetSurface, baseColor, hoverColor)
    if not triggerTarget or not targetSurface then return end

    triggerTarget.MouseEnter:Connect(function()
        local activeHover = hoverColor or self.CurrentTheme.SurfaceAlt
        LouisHub:Tween(targetSurface, { BackgroundColor3 = activeHover }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end)

    triggerTarget.MouseLeave:Connect(function()
        local activeRest = baseColor or self.CurrentTheme.Surface
        LouisHub:Tween(targetSurface, { BackgroundColor3 = activeRest }, 0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end)
end

function LouisHub:ApplyFlashFeedback(targetInstance, isSuccess)
    if not targetInstance or not targetInstance.Parent then return end

    local flashColor = isSuccess and self.CurrentTheme.Success or self.CurrentTheme.Error
    local originalColor = targetInstance.BackgroundColor3

    self:Tween(targetInstance, { BackgroundColor3 = flashColor }, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function()
        task.delay(0.08, function()
            if targetInstance and targetInstance.Parent then
                LouisHub:Tween(targetInstance, { BackgroundColor3 = originalColor }, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
        end)
    end)
end

-- =====================================================================
-- SECTION 11: CAMERA-SHIELDED UNIFIED DRAG PIPELINE (FREE DRAG MODE)
-- =====================================================================
local InputPipeline = {}
InputPipeline.__index = InputPipeline

function InputPipeline.GetViewportSize()
    local camera = workspace.CurrentCamera
    return (camera and camera.ViewportSize) or Vector2.new(1920, 1080)
end

-- Toleransi bebas: Menyisakan sedikit area (32px) agar jendela tidak hilang total dari layar
function InputPipeline.ClampPositionToViewport(targetPosition, frameSize)
    local viewport = InputPipeline.GetViewportSize()
    local minVisible = 32

    local minX = -(frameSize.X - minVisible)
    local maxX = viewport.X - minVisible
    local minY = 0
    local maxY = viewport.Y - minVisible

    local clampedX = math.clamp(targetPosition.X, minX, maxX)
    local clampedY = math.clamp(targetPosition.Y, minY, maxY)

    return Vector2.new(clampedX, clampedY)
end

function LouisHub:MakeDraggable(triggerObject, frameToMove, onDragStep, onDragEnd)
    if not triggerObject or not frameToMove then return end

    local isDragging = false
    local dragStart = Vector2.zero
    local frameStart = Vector2.zero

    triggerObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            -- Jangan seret jika objek atau target terkunci
            if triggerObject:GetAttribute("DragLocked") or frameToMove:GetAttribute("DragLocked") then
                return
            end

            isDragging = true
            dragStart = Vector2.new(input.Position.X, input.Position.Y)
            frameStart = Vector2.new(frameToMove.AbsolutePosition.X, frameToMove.AbsolutePosition.Y)

            local moveConn, endConn

            moveConn = UserInputService.InputChanged:Connect(function(moveInput)
                if not isDragging then return end
                if moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch then
                    local currentPos = Vector2.new(moveInput.Position.X, moveInput.Position.Y)
                    local delta = currentPos - dragStart
                    local targetPos = frameStart + delta
                    
                    -- Dragging bebas responsif
                    local clamped = InputPipeline.ClampPositionToViewport(targetPos, frameToMove.AbsoluteSize)
                    frameToMove.Position = UDim2.fromOffset(clamped.X, clamped.Y)

                    if onDragStep then pcall(onDragStep, clamped) end
                end
            end)

            endConn = UserInputService.InputEnded:Connect(function(endInput)
                if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then
                    isDragging = false
                    if moveConn then moveConn:Disconnect() end
                    if endConn then endConn:Disconnect() end
                    if onDragEnd then pcall(onDragEnd, frameToMove.Position) end
                end
            end)
        end
    end)
end

-- =====================================================================
-- SECTION 12: HOLD-TO-REPEAT & OUTSIDE CLICK HANDLERS
-- =====================================================================
function LouisHub:RegisterHoldAction(triggerButton, onStepCallback, initialDelay, repeatInterval)
    if not triggerButton then return end

    local delayTime = initialDelay or 0.32
    local intervalTime = repeatInterval or 0.07
    local activeToken = 0

    local function cancelHold()
        activeToken = activeToken + 1
    end

    triggerButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local currentToken = activeToken + 1
            activeToken = currentToken

            pcall(onStepCallback)

            task.delay(delayTime, function()
                while activeToken == currentToken and triggerButton.Parent do
                    pcall(onStepCallback)
                    task.wait(intervalTime)
                end
            end)
        end
    end)

    triggerButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            cancelHold()
        end
    end)

    triggerButton.MouseLeave:Connect(cancelHold)
end

local ActiveOutsideClickDetectors = {}

function LouisHub:ListenForOutsideClick(targetFrame, onCloseCallback)
    if not targetFrame then return end

    local entry = {
        Frame = targetFrame,
        Callback = onCloseCallback
    }

    table.insert(ActiveOutsideClickDetectors, entry)

    targetFrame.Destroying:Connect(function()
        local idx = table.find(ActiveOutsideClickDetectors, entry)
        if idx then table.remove(ActiveOutsideClickDetectors, idx) end
    end)
end

local outsideClickConnection = UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    local clickPos = Vector2.new(input.Position.X, input.Position.Y)

    for i = #ActiveOutsideClickDetectors, 1, -1 do
        local detector = ActiveOutsideClickDetectors[i]
        local frame = detector and detector.Frame

        if frame and frame.Parent and frame.Visible then
            local absPos = frame.AbsolutePosition
            local absSize = frame.AbsoluteSize

            local isInside = (clickPos.X >= absPos.X and clickPos.X <= absPos.X + absSize.X) and
                             (clickPos.Y >= absPos.Y and clickPos.Y <= absPos.Y + absSize.Y)

            if not isInside then
                pcall(detector.Callback)
            end
        else
            table.remove(ActiveOutsideClickDetectors, i)
        end
    end
end)

LouisHub.RootJanitor:Add(outsideClickConnection)

-- =====================================================================
-- SECTION 13: RESPONSIVE VIEWPORT ADAPTATION & MOBILE AUTO-FIT
-- =====================================================================
LouisHub.AutoScaling = {
    Enabled = true,
    MinScale = 0.85,
    MaxScale = 1.25,
    ReferenceResolution = Vector2.new(1920, 1080)
}

function LouisHub:CalculateViewportScale()
    local viewport = InputPipeline.GetViewportSize()
    if viewport.X <= 0 or viewport.Y <= 0 then return 1.0 end

    -- Enhanced Mobile / Tablet thumb-friendly scaling
    if self.Capabilities.HasTouch and (viewport.X < 900 or viewport.Y < 550) then
        local mobileScale = math.clamp(viewport.Y / 440, self.AutoScaling.MinScale, self.AutoScaling.MaxScale)
        return mobileScale
    end

    return math.clamp(viewport.Y / 950, 0.90, 1.15)
end

function LouisHub:BindViewportScaler(uiScaleInstance)
    if not uiScaleInstance or not uiScaleInstance:IsA("UIScale") then return end

    local function refreshScale()
        local newScale = self:CalculateViewportScale()
        self:Tween(uiScaleInstance, { Scale = newScale }, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end

    refreshScale()

    local camera = workspace.CurrentCamera
    if camera then
        local camConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScale)
        self.RootJanitor:Add(camConnection)
    end

    local camSwitchConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        local newCam = workspace.CurrentCamera
        if newCam then
            local conn = newCam:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScale)
            self.RootJanitor:Add(conn)
            refreshScale()
        end
    end)

    self.RootJanitor:Add(camSwitchConnection)
end

-- LOUIS HUB | PART 1D | continues in PART 2A

-- =====================================================================
-- SECTION 13B: FUTURISTIC LOADING SCREEN ENGINE (SPLASH & GLOW)
-- =====================================================================
function LouisHub:ShowLoadingScreen(loadConfig, onLoadedCallback)
    loadConfig = loadConfig or {}
    local duration = tonumber(loadConfig.Duration) or 2.8
    local appTitle = tostring(loadConfig.Title or "LOUIS HUB")
    local subtitle = tostring(loadConfig.Subtitle or "Master Interface Suite • V5.0")
    local customLogo = loadConfig.Logo or self.LogoAssetId

    local safeContainer = self:GetSafeContainer()
    local splashGui = Instance.new("ScreenGui")
    splashGui.Name = "LouisHub_LoadingSplash"
    splashGui.ResetOnSpawn = false
    splashGui.IgnoreGuiInset = true
    splashGui.DisplayOrder = 999999
    splashGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    splashGui.Parent = safeContainer
    self:ProtectContainer(splashGui)

    -- Fullscreen Dark Backdrop
    local backdrop = Instance.new("Frame")
    backdrop.Name = "SplashBackdrop"
    backdrop.BackgroundColor3 = Color3.fromRGB(8, 10, 18)
    backdrop.BackgroundTransparency = 0
    backdrop.BorderSizePixel = 0
    backdrop.Size = UDim2.new(1, 0, 1, 0)
    backdrop.Parent = splashGui

    -- Ambient Neon Glow Behind Logo
    local ambientGlow = Instance.new("ImageLabel")
    ambientGlow.Name = "AmbientGlow"
    ambientGlow.BackgroundTransparency = 1
    ambientGlow.Size = UDim2.fromOffset(260, 260)
    ambientGlow.AnchorPoint = Vector2.new(0.5, 0.5)
    ambientGlow.Position = UDim2.new(0.5, 0, 0.42, 0)
    ambientGlow.Image = "rbxassetid://6014261993" -- Smooth Radial Glow
    ambientGlow.ImageColor3 = Color3.fromRGB(0, 230, 255)
    ambientGlow.ImageTransparency = 0.45
    ambientGlow.Parent = backdrop

    -- Central Card Holder
    local centerCard = Instance.new("Frame")
    centerCard.Name = "CenterCard"
    centerCard.BackgroundTransparency = 1
    centerCard.Size = UDim2.fromOffset(360, 320)
    centerCard.AnchorPoint = Vector2.new(0.5, 0.5)
    centerCard.Position = UDim2.new(0.5, 0, 0.5, 0)
    centerCard.Parent = backdrop

    local cardScale = Instance.new("UIScale")
    cardScale.Scale = 0.90
    cardScale.Parent = centerCard

    -- Circular Logo Frame with Cyan/Purple Glow Ring
    local logoRing = Instance.new("Frame")
    logoRing.Name = "LogoRing"
    logoRing.BackgroundColor3 = Color3.fromRGB(16, 22, 40)
    logoRing.Size = UDim2.fromOffset(110, 110)
    logoRing.AnchorPoint = Vector2.new(0.5, 0)
    logoRing.Position = UDim2.new(0.5, 0, 0, 10)
    logoRing.Parent = centerCard

    local ringCorner = Instance.new("UICorner")
    ringCorner.CornerRadius = UDim.new(0, 55)
    ringCorner.Parent = logoRing

    local ringStroke = Instance.new("UIStroke")
    ringStroke.Thickness = 2.5
    ringStroke.Color = Color3.fromRGB(0, 230, 255)
    ringStroke.Parent = logoRing

    local ringGradient = Instance.new("UIGradient")
    ringGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(0, 230, 255)),
        ColorSequenceKeypoint.new(0.50, Color3.fromRGB(120, 80, 255)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(175, 45, 255))
    })
    ringGradient.Rotation = 45
    ringGradient.Parent = ringStroke

    -- Official Logo Image (Asset ID: 104436283956004)
    local logoImage = Instance.new("ImageLabel")
    logoImage.Name = "OfficialLogo"
    logoImage.BackgroundTransparency = 1
    logoImage.Size = UDim2.new(1, -12, 1, -12)
    logoImage.AnchorPoint = Vector2.new(0.5, 0.5)
    logoImage.Position = UDim2.new(0.5, 0, 0.5, 0)
    logoImage.Image = customLogo
    logoImage.ScaleType = Enum.ScaleType.Fit
    logoImage.Parent = logoRing

    local imgCorner = Instance.new("UICorner")
    imgCorner.CornerRadius = UDim.new(0, 50)
    imgCorner.Parent = logoImage

    -- App Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "AppTitle"
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 20
    titleLabel.TextColor3 = Color3.fromRGB(245, 250, 255)
    titleLabel.Text = appTitle
    titleLabel.Position = UDim2.new(0, 0, 0, 136)
    titleLabel.Size = UDim2.new(1, 0, 0, 24)
    titleLabel.Parent = centerCard

    local titleGrad = Instance.new("UIGradient")
    titleGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(0, 230, 255)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(175, 45, 255))
    })
    titleGrad.Parent = titleLabel

    -- Subtitle
    local subLabel = Instance.new("TextLabel")
    subLabel.Name = "Subtitle"
    subLabel.BackgroundTransparency = 1
    subLabel.Font = Enum.Font.GothamMedium
    subLabel.TextSize = 11
    subLabel.TextColor3 = Color3.fromRGB(135, 150, 185)
    subLabel.Text = subtitle
    subLabel.Position = UDim2.new(0, 0, 0, 162)
    subLabel.Size = UDim2.new(1, 0, 0, 16)
    subLabel.Parent = centerCard

    -- Status Text (Dynamic Boot Messages)
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "BootStatus"
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.GothamMedium
    statusLabel.TextSize = 10.5
    statusLabel.TextColor3 = Color3.fromRGB(0, 230, 255)
    statusLabel.Text = "Initializing runtime..."
    statusLabel.Position = UDim2.new(0, 0, 0, 210)
    statusLabel.Size = UDim2.new(1, 0, 0, 16)
    statusLabel.Parent = centerCard

    -- Progress Bar Track
    local progressTrack = Instance.new("Frame")
    progressTrack.Name = "ProgressTrack"
    progressTrack.BackgroundColor3 = Color3.fromRGB(20, 26, 46)
    progressTrack.BorderSizePixel = 0
    progressTrack.Size = UDim2.new(0, 260, 0, 6)
    progressTrack.AnchorPoint = Vector2.new(0.5, 0)
    progressTrack.Position = UDim2.new(0.5, 0, 0, 232)
    progressTrack.Parent = centerCard

    local ptCorner = Instance.new("UICorner")
    ptCorner.CornerRadius = UDim.new(0, 3)
    ptCorner.Parent = progressTrack

    local ptStroke = Instance.new("UIStroke")
    ptStroke.Thickness = 1
    ptStroke.Color = Color3.fromRGB(36, 48, 88)
    ptStroke.Transparency = 0.5
    ptStroke.Parent = progressTrack

    -- Progress Fill Bar with Gradient
    local progressFill = Instance.new("Frame")
    progressFill.Name = "ProgressFill"
    progressFill.BackgroundColor3 = Color3.fromRGB(0, 230, 255)
    progressFill.BorderSizePixel = 0
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.Parent = progressTrack

    local pfCorner = Instance.new("UICorner")
    pfCorner.CornerRadius = UDim.new(0, 3)
    pfCorner.Parent = progressFill

    local pfGrad = Instance.new("UIGradient")
    pfGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(0, 230, 255)),
        ColorSequenceKeypoint.new(0.50, Color3.fromRGB(120, 80, 255)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(175, 45, 255))
    })
    pfGrad.Parent = progressFill

    -- Entrance Pop-In Animation
    self:Tween(cardScale, { Scale = 1.0 }, 0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

    -- Ambient Glow Breathing Routine
    local breathingTween = TweenService:Create(
        ambientGlow,
        TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { ImageTransparency = 0.70, Size = UDim2.fromOffset(290, 290) }
    )
    breathingTween:Play()

    -- Rotating Ring Gradient
    local rotateConnection
    rotateConnection = RunService.RenderStepped:Connect(function()
        if ringGradient and ringGradient.Parent then
            ringGradient.Rotation = (ringGradient.Rotation + 1.8) % 360
        else
            if rotateConnection then rotateConnection:Disconnect() end
        end
    end)

    -- Staged Boot Progression Sequence
    task.spawn(function()
        local bootSteps = {
            { Pct = 0.25, Text = "Verifying environment & capabilities..." },
            { Pct = 0.55, Text = "Mounting theme palettes & icons..." },
            { Pct = 0.82, Text = "Preparing user interface components..." },
            { Pct = 1.00, Text = "Boot successful. Welcome to Louis Hub!" }
        }

        local stepInterval = duration / #bootSteps

        for _, step in ipairs(bootSteps) do
            statusLabel.Text = step.Text
            self:Tween(progressFill, { Size = UDim2.new(step.Pct, 0, 1, 0) }, stepInterval * 0.90, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            task.wait(stepInterval)
        end

        task.wait(0.25)

        -- Matikan animasi putaran
        if rotateConnection then rotateConnection:Disconnect() end
        breathingTween:Cancel()

        self:Tween(cardScale, { Scale = 0.90 }, 0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        self:Tween(backdrop, { BackgroundTransparency = 1 }, 0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

        task.wait(0.22)

        -- KUNCI UTAMA: Matikan total splash screen & buang dari memori!
        splashGui.Enabled = false
        backdrop.Visible = false
        backdrop.Size = UDim2.fromOffset(0, 0)
        pcall(function() splashGui:Destroy() end)

        -- Panggil callback untuk memunculkan Window
        if onLoadedCallback then
            task.spawn(onLoadedCallback)
        end
    end)
end

-- LOUIS HUB | PART 2A | continues in PART 2B

-- =====================================================================
-- SECTION 14: REACTIVE STATE, FLAGS & CONDITIONAL LOGIC
-- =====================================================================
LouisHub.Flags = {}
LouisHub.Elements = {}
LouisHub.StateListeners = {}
LouisHub.Conditionals = {}

local RealFlagStorage = {}
local SuppressHistoryRecord = false

local function deepClone(value)
    if type(value) ~= "table" then return value end
    local cloned = {}
    for k, v in pairs(value) do
        cloned[k] = deepClone(v)
    end
    return cloned
end

setmetatable(LouisHub.Flags, {
    __index = function(_, key)
        return RealFlagStorage[key]
    end,
    __newindex = function(_, key, newValue)
        local previousValue = RealFlagStorage[key]
        if type(newValue) ~= "table" and previousValue == newValue then
            return
        end

        RealFlagStorage[key] = newValue

        if not SuppressHistoryRecord then
            LouisHub:RecordHistoryStep(key, previousValue, newValue)
        end

        if LouisHub.StateListeners[key] then
            for _, listener in ipairs(LouisHub.StateListeners[key]) do
                pcall(listener, newValue, previousValue)
            end
        end

        LouisHub:EvaluateConditionals()
    end
})

function LouisHub:OnFlagChanged(flagName, callbackFunction)
    if not flagName or type(callbackFunction) ~= "function" then return end
    self.StateListeners[flagName] = self.StateListeners[flagName] or {}
    table.insert(self.StateListeners[flagName], callbackFunction)

    return function()
        local list = self.StateListeners[flagName]
        if list then
            local idx = table.find(list, callbackFunction)
            if idx then table.remove(list, idx) end
        end
    end
end

function LouisHub:RegisterConditional(targetElement, conditionFunction, evaluationMode)
    if not targetElement or type(conditionFunction) ~= "function" then return end

    local entry = {
        Element = targetElement,
        Condition = conditionFunction,
        Mode = evaluationMode or "Visible"
    }

    table.insert(self.Conditionals, entry)

    if typeof(targetElement) == "Instance" then
        targetElement.Destroying:Connect(function()
            local idx = table.find(self.Conditionals, entry)
            if idx then table.remove(self.Conditionals, idx) end
        end)
    end

    self:EvaluateSingleConditional(entry)
end

function LouisHub:EvaluateSingleConditional(entry)
    local success, result = pcall(entry.Condition)
    if not success then return end

    local isMet = (result == true)
    local target = entry.Element

    if entry.Mode == "Visible" then
        if typeof(target) == "Instance" and target:IsA("GuiObject") then
            target.Visible = isMet
        elseif type(target) == "table" and type(target.SetVisible) == "function" then
            target:SetVisible(isMet)
        end
    elseif entry.Mode == "Enabled" then
        if type(target) == "table" and type(target.SetDisabled) == "function" then
            target:SetDisabled(not isMet)
        end
    end
end

function LouisHub:EvaluateConditionals()
    for i = #self.Conditionals, 1, -1 do
        local entry = self.Conditionals[i]
        if entry.Element then
            self:EvaluateSingleConditional(entry)
        else
            table.remove(self.Conditionals, i)
        end
    end
end

-- =====================================================================
-- SECTION 15: UNDO / REDO HISTORY ENGINE
-- =====================================================================
local HistoryUndoStack = {}
local HistoryRedoStack = {}
local MAX_HISTORY_STEPS = 50

function LouisHub:RecordHistoryStep(flagKey, oldValue, newValue)
    if not flagKey or oldValue == nil then return end

    local lastEntry = HistoryUndoStack[#HistoryUndoStack]
    local currentTime = os.clock()

    if lastEntry and lastEntry.Key == flagKey and (currentTime - lastEntry.Time) < 0.35 then
        lastEntry.After = deepClone(newValue)
        lastEntry.Time = currentTime
        return
    end

    table.insert(HistoryUndoStack, {
        Key = flagKey,
        Before = deepClone(oldValue),
        After = deepClone(newValue),
        Time = currentTime
    })

    if #HistoryUndoStack > MAX_HISTORY_STEPS then
        table.remove(HistoryUndoStack, 1)
    end

    table.clear(HistoryRedoStack)
end

function LouisHub:Undo()
    if #HistoryUndoStack == 0 then return false end

    local step = table.remove(HistoryUndoStack)
    table.insert(HistoryRedoStack, step)

    SuppressHistoryRecord = true
    local element = self.Elements[step.Key]
    if element and type(element.Set) == "function" then
        pcall(element.Set, element, step.Before, false)
    else
        self.Flags[step.Key] = step.Before
    end
    SuppressHistoryRecord = false

    return true, step.Key
end

function LouisHub:Redo()
    if #HistoryRedoStack == 0 then return false end

    local step = table.remove(HistoryRedoStack)
    table.insert(HistoryUndoStack, step)

    SuppressHistoryRecord = true
    local element = self.Elements[step.Key]
    if element and type(element.Set) == "function" then
        pcall(element.Set, element, step.After, false)
    else
        self.Flags[step.Key] = step.After
    end
    SuppressHistoryRecord = false

    return true, step.Key
end

function LouisHub:CanUndo()
    return #HistoryUndoStack > 0
end

function LouisHub:CanRedo()
    return #HistoryRedoStack > 0
end

function LouisHub:ClearHistory()
    table.clear(HistoryUndoStack)
    table.clear(HistoryRedoStack)
end

-- =====================================================================
-- SECTION 16: ROBUST CONFIG SERIALIZER & STORAGE MANAGER
-- =====================================================================
local ConfigManager = {}
ConfigManager.__index = ConfigManager
ConfigManager.Folder = "LouisHub/Configs"
ConfigManager.AutoloadPointerFile = "LouisHub/Configs/_autoload.txt"

local function serializeValue(val)
    if typeof(val) == "Color3" then
        return {
            __type = "Color3",
            R = math.round(val.R * 255),
            G = math.round(val.G * 255),
            B = math.round(val.B * 255)
        }
    elseif typeof(val) == "EnumItem" then
        return {
            __type = "EnumItem",
            EnumType = tostring(val.EnumType),
            Name = val.Name
        }
    elseif type(val) == "table" and val.KeyCode and typeof(val.KeyCode) == "EnumItem" then
        return {
            __type = "KeyCombo",
            KeyCode = val.KeyCode.Name,
            Ctrl = val.Ctrl == true,
            Shift = val.Shift == true,
            Alt = val.Alt == true
        }
    end
    return val
end

local function deserializeValue(val)
    if type(val) == "table" and val.__type then
        if val.__type == "Color3" then
            return Color3.fromRGB(val.R or 255, val.G or 255, val.B or 255)
        elseif val.__type == "EnumItem" then
            local ok, item = pcall(function()
                return Enum[val.EnumType][val.Name]
            end)
            return (ok and item) or Enum.KeyCode.Unknown
        elseif val.__type == "KeyCombo" then
            local ok, item = pcall(function()
                return Enum.KeyCode[val.KeyCode]
            end)
            return {
                KeyCode = (ok and item) or Enum.KeyCode.Unknown,
                Ctrl = val.Ctrl == true,
                Shift = val.Shift == true,
                Alt = val.Alt == true
            }
        end
    end
    return val
end

function ConfigManager:EnsureDirectory()
    if not (LouisHub.Capabilities.HasFilesystem and LouisHub.Capabilities.HasFolders) then return false end

    local currentPath = ""
    for segment in self.Folder:gmatch("[^/]+") do
        currentPath = (currentPath == "") and segment or (currentPath .. "/" .. segment)
        if not isfolder(currentPath) then
            pcall(makefolder, currentPath)
        end
    end
    return true
end

function ConfigManager:Save(configName)
    if not LouisHub.Capabilities.HasFilesystem then
        return false, "Filesystem API unavailable in this environment"
    end

    self:EnsureDirectory()
    local cleanName = tostring(configName or "default"):gsub("[^%w_%-]", "")
    local filePath = self.Folder .. "/" .. cleanName .. ".json"

    local packet = {
        _version = LouisHub.Version,
        _timestamp = os.time(),
        _theme = LouisHub.ActiveThemeName,
        Data = {}
    }

    for key, val in pairs(RealFlagStorage) do
        packet.Data[key] = serializeValue(val)
    end

    local success, encoded = pcall(function()
        return HttpService:JSONEncode(packet)
    end)

    if not success then
        return false, "JSON serialization error"
    end

    local writeSuccess, writeError = pcall(writefile, filePath, encoded)
    if not writeSuccess then
        return false, tostring(writeError)
    end

    return true, cleanName
end

function ConfigManager:Load(configName, silent)
    if not LouisHub.Capabilities.HasFilesystem then
        return false, "Filesystem API unavailable"
    end

    local cleanName = tostring(configName or "default"):gsub("[^%w_%-]", "")
    local filePath = self.Folder .. "/" .. cleanName .. ".json"

    if not isfile(filePath) then
        return false, "Configuration file does not exist"
    end

    local readOk, content = pcall(readfile, filePath)
    if not readOk then return false, "Unable to read config file" end

    local decodeOk, packet = pcall(function()
        return HttpService:JSONDecode(content)
    end)
    if not decodeOk or type(packet) ~= "table" or not packet.Data then
        return false, "Invalid JSON data structure"
    end

    SuppressHistoryRecord = true

    if packet._theme and LouisHub.Themes[packet._theme] then
        LouisHub:SetTheme(packet._theme, true)
    end

    for flagKey, rawValue in pairs(packet.Data) do
        local decodedValue = deserializeValue(rawValue)
        local element = LouisHub.Elements[flagKey]

        if element and type(element.Set) == "function" then
            pcall(element.Set, element, decodedValue, not silent)
        else
            LouisHub.Flags[flagKey] = decodedValue
        end
    end

    SuppressHistoryRecord = false
    return true, cleanName
end

function ConfigManager:Delete(configName)
    if not (LouisHub.Capabilities.HasFilesystem and LouisHub.Capabilities.HasFileDeletion) then
        return false, "File deletion unsupported"
    end

    local cleanName = tostring(configName):gsub("[^%w_%-]", "")
    local filePath = self.Folder .. "/" .. cleanName .. ".json"

    if isfile(filePath) then
        local success, err = pcall(delfile, filePath)
        return success, err
    end
    return false, "File not found"
end

function ConfigManager:List()
    if not (LouisHub.Capabilities.HasFilesystem and LouisHub.Capabilities.HasFileList) then
        return {}
    end

    self:EnsureDirectory()
    local configs = {}
    local success, files = pcall(listfiles, self.Folder)

    if success and type(files) == "table" then
        for _, fullPath in ipairs(files) do
            local fileName = fullPath:match("([^/\\]+)%.json$")
            if fileName and not fileName:match("^_") then
                table.insert(configs, fileName)
            end
        end
    end
    table.sort(configs)
    return configs
end

function ConfigManager:ExportToClipboard(configName)
    local cleanName = tostring(configName or "default"):gsub("[^%w_%-]", "")
    local filePath = self.Folder .. "/" .. cleanName .. ".json"

    if not isfile(filePath) then return false, "File not found" end
    local ok, content = pcall(readfile, filePath)
    if not ok then return false, "Read error" end

    if LouisHub.Capabilities.HasClipboard then
        pcall(setclipboard, content)
        return true, content
    end
    return false, "Clipboard function not available"
end

function ConfigManager:ImportFromRaw(configName, rawJson)
    if type(rawJson) ~= "string" or rawJson == "" then return false, "Empty data" end

    local decodeOk, packet = pcall(function()
        return HttpService:JSONDecode(rawJson)
    end)
    if not decodeOk or type(packet) ~= "table" then return false, "Malformed JSON" end

    self:EnsureDirectory()
    local cleanName = tostring(configName):gsub("[^%w_%-]", "")
    local filePath = self.Folder .. "/" .. cleanName .. ".json"

    local writeOk, err = pcall(writefile, filePath, rawJson)
    return writeOk, err
end

function ConfigManager:SetAutoload(configName)
    if not LouisHub.Capabilities.HasFilesystem then return false end
    self:EnsureDirectory()
    return pcall(writefile, self.AutoloadPointerFile, tostring(configName))
end

function ConfigManager:GetAutoload()
    if not (LouisHub.Capabilities.HasFilesystem and isfile(self.AutoloadPointerFile)) then
        return nil
    end
    local ok, name = pcall(readfile, self.AutoloadPointerFile)
    return ok and name or nil
end

function ConfigManager:ClearAutoload()
    if LouisHub.Capabilities.HasFilesystem and isfile(self.AutoloadPointerFile) then
        pcall(delfile, self.AutoloadPointerFile)
    end
end

LouisHub.ConfigManager = ConfigManager

-- LOUIS HUB | PART 2B | continues in PART 2C

-- =====================================================================
-- SECTION 17: COMPLETE 640+ MATERIAL ICON DATABASE (PACKED NUMBER IDS)
-- =====================================================================
local RawIconDatabase = {
    ["perm_media"] = 6031215982, ["sticky_note_2"] = 6031265972, ["gavel"] = 6023565902, ["table_view"] = 6031233835,
    ["home"] = 6026568195, ["list"] = 6026568229, ["alarm_add"] = 6023426898, ["speaker_notes"] = 6031266001,
    ["check_circle_outline"] = 6023426909, ["extension"] = 6023565892, ["pending"] = 6031084745, ["pageview"] = 6031216007,
    ["group_work"] = 6023565910, ["zoom_in"] = 6031075573, ["aspect_ratio"] = 6022668895, ["code"] = 6022668955,
    ["3d_rotation"] = 6022668893, ["translate"] = 6031225812, ["star_rate"] = 6031265978, ["system_update_alt"] = 6031251515,
    ["open_with"] = 6026568265, ["build_circle"] = 6023426952, ["toc"] = 6031229341, ["settings_phone"] = 6031289445,
    ["open_in_full"] = 6026568245, ["history"] = 6026568197, ["accessibility_new"] = 6022668945, ["hourglass_disabled"] = 6026568193,
    ["line_style"] = 6026568276, ["account_circle"] = 6022668898, ["settings_cell"] = 6031280890, ["search_off"] = 6031260783,
    ["shop"] = 6031265983, ["anchor"] = 6023426906, ["language"] = 6026568213, ["settings_brightness"] = 6031280902,
    ["restore_page"] = 6031154877, ["chrome_reader_mode"] = 6023426912, ["sync_alt"] = 6031233840, ["book"] = 6022860343,
    ["smart_button"] = 6031265962, ["request_page"] = 6031154873, ["lock_clock"] = 6026568260, ["android"] = 6022668966,
    ["outgoing_mail"] = 6026568242, ["dynamic_form"] = 6023426970, ["track_changes"] = 6031225814, ["source"] = 6031289451,
    ["thumb_down"] = 6031229336, ["integration_instructions"] = 6026568214, ["opacity"] = 6026568295, ["perm_identity"] = 6031215978,
    ["view_module"] = 6031079152, ["perm_data_setting"] = 6031215991, ["assignment_turned_in"] = 6023426904, ["change_history"] = 6023426914,
    ["thumb_down_off_alt"] = 6031229354, ["text_rotation_angledown"] = 6031251513, ["bookmark"] = 6022852108, ["view_stream"] = 6031079164,
    ["remove_done"] = 6031086169, ["markunread_mailbox"] = 6031082531, ["store"] = 6031265968, ["text_rotation_angleup"] = 6031229337,
    ["eco"] = 6023426988, ["find_in_page"] = 6023426986, ["api"] = 6022668911, ["launch"] = 6026568211,
    ["text_rotation_down"] = 6031229334, ["flip_to_back"] = 6023565896, ["contact_page"] = 6022668881, ["preview"] = 6031260793,
    ["restore"] = 6031260800, ["favorite_border"] = 6023565882, ["assignment_late"] = 6022668880, ["youtube_searched_for"] = 6031075934,
    ["hourglass_full"] = 6026568190, ["timeline"] = 6031229350, ["turned_in"] = 6031225808, ["info"] = 6026568227,
    ["restore_from_trash"] = 6031154869, ["arrow_circle_down"] = 6022668877, ["flaky"] = 6031082523, ["alarm_on"] = 6023426920,
    ["swap_vertical_circle"] = 6031233839, ["open_in_new"] = 6026568256, ["watch_later"] = 6031075924, ["alarm_off"] = 6023426901,
    ["maximize"] = 6026568267, ["lock_outline"] = 6031082533, ["outbond"] = 6026568244, ["view_carousel"] = 6031251507,
    ["published_with_changes"] = 6031243328, ["verified_user"] = 6031225819, ["drag_indicator"] = 6023426962, ["lightbulb_outline"] = 6026568254,
    ["segment"] = 6031260773, ["assignment"] = 6022668882, ["work_outline"] = 6031075930, ["line_weight"] = 6026568226,
    ["dangerous"] = 6022668916, ["assessment"] = 6022668897, ["view_day"] = 6031079153, ["help_center"] = 6026568192,
    ["logout"] = 6031082522, ["event"] = 6023426959, ["get_app"] = 6023565889, ["tab"] = 6031233851,
    ["label"] = 6031082525, ["g_translate"] = 6031082526, ["view_week"] = 6031079154, ["view_in_ar"] = 6031079158,
    ["card_travel"] = 6023426925, ["lock_open"] = 6026568220, ["voice_over_off"] = 6031075927, ["app_blocking"] = 6022668952,
    ["settings_ethernet"] = 6031280883, ["supervised_user_circle"] = 6031289449, ["done_all"] = 6023426929, ["lightbulb"] = 6026568247,
    ["find_replace"] = 6023426979, ["bookmarks"] = 6023426924, ["today"] = 6031229352, ["class"] = 6022668949,
    ["supervisor_account"] = 6031251516, ["support"] = 6031251532, ["done_outline"] = 6023426936, ["reorder"] = 6031154868,
    ["fact_check"] = 6023426951, ["thumb_up"] = 6031229347, ["assignment_returned"] = 6023426899, ["card_giftcard"] = 6023426978,
    ["trending_down"] = 6031225811, ["settings_backup_restore"] = 6031280886, ["settings_voice"] = 6031265966, ["dns"] = 6023426958,
    ["perm_scan_wifi"] = 6031215985, ["plagiarism"] = 6031243320, ["commute"] = 6022668901, ["gif"] = 6031082540,
    ["work"] = 6031075939, ["picture_in_picture_alt"] = 6031215979, ["query_builder"] = 6031086183, ["label_off"] = 6026568209,
    ["all_out"] = 6022668876, ["article"] = 6022668907, ["shopping_basket"] = 6031265997, ["mark_as_unread"] = 6026568223,
    ["work_off"] = 6031075937, ["delete_outline"] = 6022668962, ["account_box"] = 6023426915, ["home_filled"] = 9080449299,
    ["lock"] = 6026568224, ["perm_device_information"] = 6031215996, ["add_task"] = 6022668912, ["text_rotate_up"] = 6031251526,
    ["swipe"] = 6031233863, ["eject"] = 6023426930, ["mediation"] = 6026568249, ["label_important_outline"] = 6026568199,
    ["settings_remote"] = 6031289442, ["history_toggle_off"] = 6026568196, ["invert_colors"] = 6026568253, ["visibility_off"] = 6031075929,
    ["addchart"] = 6023426905, ["cancel_schedule_send"] = 6022668963, ["loyalty"] = 6026568237, ["speaker_notes_off"] = 6031265965,
    ["online_prediction"] = 6026568239, ["remove_shopping_cart"] = 6031260778, ["text_rotate_vertical"] = 6031251518, ["visibility"] = 6031075931,
    ["add_to_drive"] = 6022860335, ["accessible"] = 6022668902, ["bookmark_border"] = 6022860339, ["tour"] = 6031229362,
    ["compare_arrows"] = 6022668951, ["view_sidebar"] = 6031079160, ["face"] = 6023426944, ["wysiwyg"] = 6031075938,
    ["camera_enhance"] = 6023426935, ["perm_camera_mic"] = 6031215983, ["model_training"] = 6026568222, ["arrow_circle_up"] = 6022668934,
    ["euro_symbol"] = 6023426954, ["pending_actions"] = 6031260777, ["not_accessible"] = 6026568269, ["explore_off"] = 6023426953,
    ["build"] = 6023426938, ["backup"] = 6023426911, ["settings_input_antenna"] = 6031280891, ["disabled_by_default"] = 6023426939,
    ["upgrade"] = 6031225815, ["contactless"] = 6022668886, ["trending_flat"] = 6031225818, ["schedule"] = 6031260808,
    ["offline_pin"] = 6031084770, ["date_range"] = 6022668894, ["flight_land"] = 6023565897, ["view_headline"] = 6031079151,
    ["cached"] = 6023426921, ["unpublished"] = 6031225817, ["outlet"] = 6031084748, ["favorite"] = 6023426974,
    ["vertical_split"] = 6031225820, ["report_problem"] = 6031086176, ["fingerprint"] = 6023565895, ["important_devices"] = 6026568202,
    ["outbox"] = 6026568263, ["all_inbox"] = 6022668909, ["label_important"] = 6026568215, ["print"] = 6031243324,
    ["settings_bluetooth"] = 6031280905, ["power_settings_new"] = 6031260781, ["zoom_out"] = 6031075577, ["stars"] = 6031265971,
    ["offline_bolt"] = 6031084742, ["feedback"] = 6023426957, ["accessibility"] = 6022668887, ["announcement"] = 6022668946,
    ["settings_input_hdmi"] = 6031280970, ["leaderboard"] = 6026568216, ["view_quilt"] = 6031079155, ["note_add"] = 6031084749,
    ["theaters"] = 6031229335, ["alarm"] = 6023426910, ["settings_input_composite"] = 6031280896, ["grade"] = 6026568189,
    ["tab_unselected"] = 6031251505, ["swap_vert"] = 6031233847, ["assignment_return"] = 6023426931, ["highlight_alt"] = 6023565913,
    ["shopping_bag"] = 6031265970, ["contact_support"] = 6022668879, ["flip_to_front"] = 6023565894, ["touch_app"] = 6031229361,
    ["room"] = 6031154875, ["send_and_archive"] = 6031280889, ["view_array"] = 6031225842, ["settings_power"] = 6031289446,
    ["admin_panel_settings"] = 6022668961, ["open_in_browser"] = 6026568266, ["card_membership"] = 6023426942, ["rule"] = 6031154859,
    ["schedule_send"] = 6031154866, ["calendar_today"] = 6022668917, ["info_outline"] = 6026568210, ["description"] = 6022668888,
    ["dashboard_customize"] = 6022668899, ["rowing"] = 6031154857, ["swap_horizontal_circle"] = 6031233833, ["account_balance_wallet"] = 6022668892,
    ["view_agenda"] = 6031225831, ["shop_two"] = 6031289461, ["done"] = 6023426926, ["circle_notifications"] = 6023426923,
    ["compress"] = 6022668878, ["calendar_view_day"] = 6023426946, ["thumbs_up_down"] = 6031229373, ["account_balance"] = 6022668900,
    ["play_for_work"] = 6031260776, ["pets"] = 6031260782, ["view_column"] = 6031079172, ["search"] = 6031154871,
    ["autorenew"] = 6023565901, ["copyright"] = 6023565898, ["privacy_tip"] = 6031260784, ["arrow_right_alt"] = 6022668890,
    ["delete"] = 6022668885, ["nightlight_round"] = 6031084743, ["batch_prediction"] = 6022860334, ["shopping_cart"] = 6031265976,
    ["login"] = 6031082527, ["settings_input_svideo"] = 6031289444, ["payment"] = 6031084751, ["update"] = 6031225810,
    ["text_rotation_none"] = 6031229344, ["perm_contact_calendar"] = 6031215990, ["explore"] = 6023426941, ["delete_forever"] = 6022668939,
    ["rounded_corner"] = 6031154861, ["book_online"] = 6022860332, ["quickreply"] = 6031243319, ["bug_report"] = 6022852107,
    ["subtitles_off"] = 6031289466, ["close_fullscreen"] = 6023426928, ["horizontal_split"] = 6026568194, ["minimize"] = 6026568240,
    ["filter_list_alt"] = 6023426955, ["add_shopping_cart"] = 6022668875, ["next_plan"] = 6026568231, ["view_list"] = 6031079156,
    ["receipt"] = 6031086173, ["polymer"] = 6031260785, ["spellcheck"] = 6031289450, ["wifi_protected_setup"] = 6031075926,
    ["label_outline"] = 6026568207, ["highlight_off"] = 6023565916, ["turned_in_not"] = 6031225806, ["edit_off"] = 6023426983,
    ["question_answer"] = 6031086172, ["settings_overscan"] = 6031289459, ["trending_up"] = 6031225816, ["verified"] = 6031225809,
    ["flight_takeoff"] = 6023565891, ["grading"] = 6026568191, ["dashboard"] = 6022668883, ["expand"] = 6022668891,
    ["backup_table"] = 6022860338, ["analytics"] = 6022668884, ["picture_in_picture"] = 6031215994, ["settings"] = 6031280882,
    ["accessible_forward"] = 6022668906, ["pan_tool"] = 6031084771, ["https"] = 6026568200, ["filter_alt"] = 6023426984,
    ["thumb_up_off_alt"] = 6031229342, ["record_voice_over"] = 6031243318, ["help_outline"] = 6026568201, ["check_circle"] = 6023426945,
    ["comment_bank"] = 6023426937, ["perm_phone_msg"] = 6031215986, ["settings_applications"] = 6031280894, ["exit_to_app"] = 6023426922,
    ["saved_search"] = 6031154867, ["toll"] = 6031229343, ["not_started"] = 6026568232, ["subject"] = 6031289452,
    ["redeem"] = 6031086170, ["input"] = 6026568225, ["settings_input_component"] = 6031280884, ["assignment_ind"] = 6022668935,
    ["swap_horiz"] = 6031233841, ["fullscreen"] = 6031094681, ["cancel"] = 6031094677, ["subdirectory_arrow_left"] = 6031104654,
    ["close"] = 6031094678, ["arrow_back_ios"] = 6031091003, ["east"] = 6031094675, ["unfold_more"] = 6031104644,
    ["south"] = 6031104646, ["arrow_drop_up"] = 6031090990, ["arrow_back"] = 6031091000, ["arrow_downward"] = 6031090991,
    ["west"] = 6031104677, ["legend_toggle"] = 6031097233, ["fullscreen_exit"] = 6031094691, ["last_page"] = 6031094686,
    ["switch_right"] = 6031104649, ["check"] = 6031094667, ["home_work"] = 6031094683, ["north_east"] = 6031097228,
    ["double_arrow"] = 6031094674, ["more_vert"] = 6031104648, ["chevron_left"] = 6031094670, ["more_horiz"] = 6031104650,
    ["unfold_less"] = 6031104681, ["first_page"] = 6031094682, ["payments"] = 6031097227, ["arrow_right"] = 6031090994,
    ["offline_share"] = 6031097267, ["south_west"] = 6031104652, ["expand_less"] = 6031094679, ["south_east"] = 6031104642,
    ["assistant_navigation"] = 6031091006, ["apps"] = 6031090999, ["arrow_upward"] = 6031090997, ["app_settings_alt"] = 6031090998,
    ["subdirectory_arrow_right"] = 6031104647, ["north_west"] = 6031104630, ["switch_left"] = 6031104651, ["chevron_right"] = 6031094680,
    ["arrow_forward"] = 6031090995, ["arrow_forward_ios"] = 6031091008, ["arrow_drop_down"] = 6031091004, ["refresh"] = 6031097226,
    ["pivot_table_chart"] = 6031097234, ["expand_more"] = 6031094687, ["campaign"] = 6031094666, ["arrow_left"] = 6031091002,
    ["arrow_drop_down_circle"] = 6031091001, ["menu_open"] = 6031097229, ["waterfall_chart"] = 6031104632, ["assistant_direction"] = 6031091005,
    ["menu"] = 6031097225, ["personal_video"] = 6034457070, ["power_off"] = 6034457087, ["wifi_off"] = 6034461625,
    ["adb"] = 6034418515, ["airline_seat_recline_normal"] = 6034418512, ["sync_problem"] = 6034452653, ["network_check"] = 6034461631,
    ["event_busy"] = 6034439634, ["airline_seat_flat"] = 6034418511, ["disc_full"] = 6034418518, ["sd_card"] = 6034457089,
    ["time_to_leave"] = 6034452660, ["phone_bluetooth_speaker"] = 6034457057, ["phone_paused"] = 6034457066, ["phone_locked"] = 6034457058,
    ["more"] = 6034461627, ["add_call"] = 6034418524, ["account_tree"] = 6034418507, ["do_not_disturb_on"] = 6034439649,
    ["event_note"] = 6034439637, ["sync_disabled"] = 6034452649, ["mms"] = 6034461621, ["airline_seat_flat_angled"] = 6034418513,
    ["bluetooth_audio"] = 6034418522, ["vibration"] = 6034452651, ["system_update"] = 6034452663, ["enhanced_encryption"] = 6034439652,
    ["wc"] = 6034452643, ["live_tv"] = 6034439648, ["folder_special"] = 6034439639, ["phone_missed"] = 6034457056,
    ["airline_seat_recline_extra"] = 6034418528, ["sms"] = 6034452645, ["tap_and_play"] = 6034452650, ["confirmation_number"] = 6034418519,
    ["event_available"] = 6034439643, ["sms_failed"] = 6034452676, ["do_not_disturb_alt"] = 6034461619, ["do_not_disturb"] = 6034439645,
    ["ondemand_video"] = 6034457065, ["no_encryption"] = 6034457059, ["airline_seat_legroom_extra"] = 6034418508, ["tv_off"] = 6034452646,
    ["sim_card_alert"] = 6034452641, ["airline_seat_legroom_normal"] = 6034418532, ["wifi"] = 6034461626, ["do_not_disturb_off"] = 6034439642,
    ["imagesearch_roller"] = 6034439635, ["power"] = 6034457105, ["airline_seat_legroom_reduced"] = 6034418520, ["phone_in_talk"] = 6034457067,
    ["airline_seat_individual_suite"] = 6034418514, ["priority_high"] = 6034457092, ["phone_callback"] = 6034457104, ["phone_forwarded"] = 6034457106,
    ["sync"] = 6034452662, ["vpn_lock"] = 6034452648, ["support_agent"] = 6034452656, ["network_locked"] = 6034457064,
    ["directions_off"] = 6034418517, ["drive_eta"] = 6034464371, ["sensor_window"] = 6031067242, ["sensor_door"] = 6031067241,
    ["keyboard_return"] = 6034818370, ["monitor"] = 6034837803, ["device_hub"] = 6034789877, ["keyboard"] = 6034818398,
    ["keyboard_voice"] = 6034818360, ["cast"] = 6034789876, ["developer_board"] = 6034789883, ["tablet"] = 6034848733,
    ["keyboard_hide"] = 6034818386, ["dock"] = 6034789888, ["phonelink"] = 6034837801, ["device_unknown"] = 6034789884,
    ["speaker_group"] = 6034848732, ["desktop_mac"] = 6034789898, ["point_of_sale"] = 6034837798, ["memory"] = 6034837807,
    ["keyboard_tab"] = 6034818363, ["router"] = 6034837806, ["sim_card"] = 6034837800, ["headset"] = 6034789880,
    ["gamepad"] = 6034789879, ["speaker"] = 6034848746, ["devices_other"] = 6034789873, ["laptop"] = 6034818367,
    ["scanner"] = 6034837799, ["tv"] = 6034848740, ["headset_mic"] = 6034818383, ["browser_not_supported"] = 6034789875,
    ["computer"] = 6034789874, ["connected_tv"] = 6034789870, ["phonelink_off"] = 6034837804, ["headset_off"] = 6034818402,
    ["cast_connected"] = 6034789895, ["watch"] = 6034848747, ["keyboard_arrow_up"] = 6034818379, ["keyboard_backspace"] = 6034818381,
    ["laptop_chromebook"] = 6034818364, ["phone_iphone"] = 6034837811, ["smartphone"] = 6034848731, ["power_input"] = 6034837794,
    ["videogame_asset"] = 6034848748, ["desktop_windows"] = 6034789893, ["keyboard_arrow_down"] = 6034818372, ["laptop_mac"] = 6034837808,
    ["laptop_windows"] = 6034837796, ["keyboard_arrow_right"] = 6034818365, ["cast_for_education"] = 6034789872, ["keyboard_capslock"] = 6034818403,
    ["toys"] = 6034848752, ["tablet_android"] = 6034848734, ["mouse"] = 6034837797, ["phone_android"] = 6034837793,
    ["keyboard_arrow_left"] = 6034818375, ["security"] = 6034837802, ["dry_cleaning"] = 6034754456, ["bakery_dining"] = 6034767610,
    ["place"] = 6034503372, ["run_circle"] = 6034503367, ["local_post_office"] = 6034513883, ["takeout_dining"] = 6034467808,
    ["nightlife"] = 6034510003, ["design_services"] = 6034754453, ["celebration"] = 6034767613, ["near_me_disabled"] = 6034509988,
    ["add_location_alt"] = 6034483678, ["directions_run"] = 6034754445, ["local_fire_department"] = 6034684949, ["add_road"] = 6034483677,
    ["my_location"] = 6034509987, ["dinner_dining"] = 6034754457, ["local_airport"] = 6034687951, ["zoom_out_map"] = 6035229856,
    ["pin_drop"] = 6034470807, ["subway"] = 6034467790, ["electric_moped"] = 6034744027, ["restaurant_menu"] = 6034503378,
    ["local_gas_station"] = 6034684935, ["local_cafe"] = 6034687954, ["theater_comedy"] = 6034467796, ["directions_bus"] = 6034754434,
    ["hail"] = 6034744033, ["satellite"] = 6034503370, ["local_phone"] = 6034513884, ["electric_bike"] = 6034744032,
    ["local_see"] = 6034513887, ["transit_enterexit"] = 6034467805, ["local_convenience_store"] = 6034687956, ["local_offer"] = 6034513891,
    ["electric_car"] = 6034744029, ["beenhere"] = 6034483675, ["miscellaneous_services"] = 6034509993, ["maps_ugc"] = 6034509992,
    ["moped"] = 6034509999, ["medical_services"] = 6034510001, ["money"] = 6034509997, ["transfer_within_a_station"] = 6034467809,
    ["electrical_services"] = 6034744038, ["museum"] = 6034510005, ["add_location"] = 6034483672, ["layers"] = 6034687957,
    ["handyman"] = 6034744057, ["local_pharmacy"] = 6034513903, ["electric_rickshaw"] = 6034744043, ["alt_route"] = 6034483670,
    ["no_transfer"] = 6034503363, ["pedal_bike"] = 6034503374, ["directions_transit"] = 6034754436, ["railway_alert"] = 6034470823,
    ["local_police"] = 6034513895, ["directions_car"] = 6034754441, ["category"] = 6034767621, ["attractions"] = 6034767620,
    ["person_pin_circle"] = 6034503375, ["cleaning_services"] = 6034767619, ["terrain"] = 6034467794, ["no_meals"] = 6034510024,
    ["train"] = 6034467803, ["delivery_dining"] = 6034767644, ["pest_control"] = 6034470809, ["directions"] = 6034754449,
    ["atm"] = 6034767614, ["rate_review"] = 6034503385, ["local_bar"] = 6034687950, ["local_drink"] = 6034687965,
    ["directions_railway"] = 6034754433, ["person_pin"] = 6034503364, ["ev_station"] = 6034744037, ["home_repair_service"] = 6034744064,
    ["bus_alert"] = 6034767618, ["agriculture"] = 6034483674, ["volunteer_activism"] = 6034467799, ["breakfast_dining"] = 6034483671,
    ["layers_clear"] = 6034687975, ["plumbing"] = 6034470800, ["taxi_alert"] = 6034467792, ["add_business"] = 6034483666,
    ["badge"] = 6034767607, ["edit_attributes"] = 6034754443, ["directions_walk"] = 6034754448, ["local_play"] = 6034513889,
    ["bike_scooter"] = 6034483669, ["two_wheeler"] = 6034467795, ["local_florist"] = 6034684940, ["local_hotel"] = 6034684939,
    ["no_meals_ouline"] = 6034510025, ["festival"] = 6034744031, ["local_shipping"] = 6034684926, ["directions_boat"] = 6034754442,
    ["wrong_location"] = 6034467801, ["restaurant"] = 6034503366, ["directions_subway"] = 6034754440, ["not_listed_location"] = 6034503380,
    ["electric_scooter"] = 6034744041, ["ramen_dining"] = 6034503377, ["edit_road"] = 6034744035, ["local_printshop"] = 6034513897,
    ["map"] = 6034684930, ["car_rental"] = 6034767641, ["multiple_stop"] = 6034510026, ["brunch_dining"] = 6034767611,
    ["local_laundry_service"] = 6034684943, ["set_meal"] = 6034503368, ["local_car_wash"] = 6034687976, ["pest_control_rodent"] = 6034470803,
    ["local_pizza"] = 6034513885, ["local_grocery_store"] = 6034684933, ["traffic"] = 6034467797, ["departure_board"] = 6034767615,
    ["icecream"] = 6034687967, ["navigation"] = 6034509984, ["near_me"] = 6034509996, ["fastfood"] = 6034744034,
    ["local_library"] = 6034684931, ["local_activity"] = 6034687955, ["local_hospital"] = 6034684956, ["menu_book"] = 6034509994,
    ["directions_bike"] = 6034754459, ["store_mall_directory"] = 6034470811, ["trip_origin"] = 6034467804, ["tram"] = 6034467806,
    ["edit_location"] = 6034754439, ["streetview"] = 6034470805, ["hvac"] = 6034687960, ["lunch_dining"] = 6034684928,
    ["car_repair"] = 6034767617, ["compass_calibration"] = 6034767623, ["360"] = 6034767608, ["flight"] = 6034744030,
    ["local_mall"] = 6034684934, ["hotel"] = 6034687977, ["local_parking"] = 6034513893, ["hardware"] = 6034744036,
    ["local_dining"] = 6034687963, ["park"] = 6034503369, ["location_pin"] = 6034684937, ["local_movies"] = 6034684936,
    ["local_atm"] = 6034687953, ["local_taxi"] = 6034684927, ["brightness_low"] = 6034989542, ["screen_lock_landscape"] = 6034996700,
    ["graphic_eq"] = 6034989551, ["screen_lock_rotation"] = 6034996710, ["signal_cellular_4_bar"] = 6035030076, ["airplanemode_inactive"] = 6034983848,
    ["signal_wifi_0_bar"] = 6035030067, ["battery_full"] = 6034983854, ["gps_fixed"] = 6034989550, ["brightness_high"] = 6034989541,
    ["ad_units"] = 6034983845, ["signal_cellular_alt"] = 6035030079, ["bluetooth_connected"] = 6034983855, ["wifi_tethering"] = 6035039430,
    ["dvr"] = 6034989561, ["screen_search_desktop"] = 6034996711, ["network_wifi"] = 6034996712, ["access_alarms"] = 6034983853,
    ["nfc"] = 6034996698, ["location_disabled"] = 6034996694, ["signal_wifi_4_bar"] = 6035030077, ["access_time"] = 6034983856,
    ["mobile_off"] = 6034996702, ["battery_unknown"] = 6034983842, ["signal_cellular_null"] = 6035030075, ["bluetooth_disabled"] = 6034989562,
    ["developer_mode"] = 6034989549, ["network_cell"] = 6034996709, ["sd_storage"] = 6034996719, ["signal_cellular_no_sim"] = 6035030078,
    ["devices"] = 6034989540, ["screen_rotation"] = 6034996701, ["device_thermostat"] = 6034989544, ["signal_wifi_off"] = 6035030074,
    ["widgets"] = 6035039429, ["bluetooth"] = 6034983880, ["battery_charging_full"] = 6034983849, ["mobile_friendly"] = 6034996699,
    ["signal_cellular_0_bar"] = 6035030072, ["storage"] = 6035030083, ["send_to_mobile"] = 6034996697, ["location_searching"] = 6034996695,
    ["brightness_auto"] = 6034989545, ["wifi_lock"] = 6035039428, ["gps_not_fixed"] = 6034989547, ["access_alarm"] = 6034983844,
    ["battery_alert"] = 6034983843, ["signal_cellular_off"] = 6035030084, ["signal_cellular_connected_no_internet_4"] = 6035229858, ["gps_off"] = 6034989548,
    ["add_alarm"] = 6034983850, ["brightness_medium"] = 6034989543, ["usb"] = 6035030080, ["airplanemode_active"] = 6034983864,
    ["reset_tv"] = 6034996696, ["wallpaper"] = 6035030102, ["settings_system_daydream"] = 6035030081, ["bluetooth_searching"] = 6034989553,
    ["add_to_home_screen"] = 6034983858, ["screen_lock_portrait"] = 6034996706, ["data_usage"] = 6034989568, ["_auto_delete"] = 6031071068,
    ["_error"] = 6031071057, ["_notification_important"] = 6031071056, ["_add_alert"] = 6031071067, ["_warning"] = 6031071053,
    ["_error_outline"] = 6031071050, ["check_box_outline_blank"] = 6031068420, ["toggle_off"] = 6031068429, ["indeterminate_check_box"] = 6031068445,
    ["radio_button_checked"] = 6031068426, ["toggle_on"] = 6031068430, ["check_box"] = 6031068421, ["radio_button_unchecked"] = 6031068433,
    ["star"] = 6031068423, ["star_border"] = 6031068425, ["star_half"] = 6031068427, ["star_outline"] = 6031068428,
    ["multiline_chart"] = 6034941721, ["pie_chart"] = 6034973076, ["format_line_spacing"] = 6034910905, ["format_align_left"] = 6034900727,
    ["linear_scale"] = 6034941707, ["insert_photo"] = 6034941703, ["scatter_plot"] = 6034973094, ["post_add"] = 6034973083,
    ["format_textdirection_r_to_l"] = 6034925623, ["format_size"] = 6034910908, ["format_color_fill"] = 6034910903, ["format_paint"] = 6034925618,
    ["format_underlined"] = 6034925627, ["format_shapes"] = 6034910909, ["title"] = 6034934042, ["highlight"] = 6034925617,
    ["bar_chart"] = 6034898096, ["format_indent_increase"] = 6034900724, ["merge_type"] = 6034941705, ["bubble_chart"] = 6034925612,
    ["publish"] = 6034973085, ["format_indent_decrease"] = 6034900733, ["margin"] = 6034941701, ["table_rows"] = 6034934025,
    ["stacked_line_chart"] = 6034934039, ["border_clear"] = 6034898135, ["border_color"] = 6034898100, ["border_inner"] = 6034898131,
    ["insert_chart"] = 6034925628, ["border_top"] = 6034900726, ["padding"] = 6034973078, ["border_vertical"] = 6034900725,
    ["score"] = 6034934041, ["border_right"] = 6034898120, ["add_chart"] = 6034898093, ["space_bar"] = 6034934037,
    ["border_outer"] = 6034898104, ["mode_comment"] = 6034941700, ["attach_money"] = 6034898098, ["drag_handle"] = 6034910907,
    ["format_align_right"] = 6034900723, ["pie_chart_outlined"] = 6034973077, ["horizontal_rule"] = 6034925610, ["border_all"] = 6034898101,
    ["border_style"] = 6034898097, ["insert_comment"] = 6034925609, ["vertical_align_top"] = 6034973080, ["vertical_align_center"] = 6034934051,
    ["format_color_text"] = 6034910910, ["format_quote"] = 6034925629, ["height"] = 6034925613, ["add_comment"] = 6034898128,
    ["format_strikethrough"] = 6034910904, ["strikethrough_s"] = 6034934030, ["border_left"] = 6034898099, ["format_list_bulleted"] = 6034925620,
    ["format_italic"] = 6034910912, ["format_list_numbered"] = 6034925622, ["attach_file"] = 6034898102, ["wrap_text"] = 6034973118,
    ["insert_invitation"] = 6034973091, ["format_list_numbered_rtl"] = 6034910906, ["border_horizontal"] = 6034898105, ["format_align_center"] = 6034900718,
    ["format_textdirection_l_to_r"] = 6034925619, ["show_chart"] = 6034934032, ["insert_chart_outlined"] = 6034925606, ["vertical_align_bottom"] = 6034934023,
    ["subscript"] = 6034934059, ["format_align_justify"] = 6034900721, ["format_clear"] = 6034910902, ["notes"] = 6034973084,
    ["insert_drive_file"] = 6034941697, ["functions"] = 6034925614, ["insert_emoticon"] = 6034973079, ["insert_link"] = 6034973074,
    ["format_color_reset"] = 6034900743, ["monetization_on"] = 6034973115, ["short_text"] = 6034934035, ["mode_edit"] = 6034941708,
    ["superscript"] = 6034934034, ["table_chart"] = 6034973081, ["format_bold"] = 6034900732, ["money_off"] = 6034973088,
    ["border_bottom"] = 6034898094, ["text_fields"] = 6034934040, ["note"] = 6026663734, ["shuffle"] = 6026667003,
    ["library_books"] = 6026660085, ["library_music"] = 6026660075, ["surround_sound"] = 6026671209, ["forward_30"] = 6026660088,
    ["music_video"] = 6026663704, ["videocam_off"] = 6026671212, ["control_camera"] = 6026647916, ["explicit"] = 6026647913,
    ["3k_plus"] = 6026681598, ["fiber_pin"] = 6026660064, ["skip_previous"] = 6026667011, ["pause_circle_filled"] = 6026663718,
    ["video_settings"] = 6026671211, ["movie"] = 6026660081, ["add_to_queue"] = 6026647903, ["6k"] = 6026681579,
    ["web_asset"] = 6026671239, ["play_circle_outline"] = 6026663726, ["volume_off"] = 6026671224, ["mic_off"] = 6026660076,
    ["featured_play_list"] = 6026647932, ["pause_circle_outline"] = 6026663701, ["slow_motion_video"] = 6026681583, ["7k"] = 6026681584,
    ["playlist_add"] = 6026663728, ["fiber_smart_record"] = 6026660080, ["8k"] = 6026643014, ["hd"] = 6026660065,
    ["repeat_one_on"] = 6026666992, ["recent_actors"] = 6026663773, ["fiber_new"] = 6026647930, ["fiber_dvr"] = 6026647912,
    ["hearing_disabled"] = 6026660068, ["forward_10"] = 6026660062, ["4k_plus"] = 6026643005, ["repeat_one"] = 6026681590,
    ["equalizer"] = 6026647906, ["stop"] = 6026681576, ["2k"] = 6026643032, ["playlist_add_check"] = 6026663727,
    ["not_interested"] = 6026663743, ["videocam"] = 6026671213, ["sort_by_alpha"] = 6026667009, ["library_add"] = 6026660063,
    ["stop_circle"] = 6026681577, ["pause"] = 6026663719, ["new_releases"] = 6026663730, ["album"] = 6026647905,
    ["sd"] = 6026681582, ["volume_up"] = 6026671215, ["replay_5"] = 6026666993, ["high_quality"] = 6026660059,
    ["shuffle_on"] = 6026666996, ["play_arrow"] = 6026663699, ["snooze"] = 6026667006, ["closed_caption_disabled"] = 6026647900,
    ["subscriptions"] = 6026671207, ["skip_next"] = 6026667005, ["branding_watermark"] = 6026647911, ["speed"] = 6026681578,
    ["art_track"] = 6026647908, ["3k"] = 6026681574, ["4k"] = 6026643017, ["volume_mute"] = 6026671214,
    ["playlist_play"] = 6026663723, ["remove_from_queue"] = 6026663771, ["fast_forward"] = 6026647902, ["play_disabled"] = 6026663702,
    ["fast_rewind"] = 6026647942, ["5k"] = 6026681575, ["replay_10"] = 6026667007, ["video_library"] = 6026671208,
    ["loop"] = 6026660087, ["replay_circle_filled"] = 6026667002, ["5g"] = 6026643007, ["library_add_check"] = 6026660083,
    ["repeat"] = 6026666998, ["queue_play_next"] = 6026663700, ["forward_5"] = 6026660067, ["web"] = 6026671234,
    ["mic_none"] = 6026660066, ["queue"] = 6026663724, ["closed_caption_off"] = 6026647943, ["hearing"] = 6026660060,
    ["queue_music"] = 6026663725, ["airplay"] = 6026647929, ["9k"] = 6026643013, ["video_label"] = 6026671204,
    ["8k_plus"] = 6026643003, ["play_circle_filled"] = 6026663705, ["1k"] = 6026643002, ["fiber_manual_record"] = 6026647909,
    ["closed_caption"] = 6026647896, ["subtitles"] = 6026671203, ["featured_video"] = 6026647910, ["replay_30"] = 6026667010,
    ["10k"] = 6026643035, ["5k_plus"] = 6026643028, ["6k_plus"] = 6026643019, ["replay"] = 6026666999,
    ["repeat_on"] = 6026666994, ["1k_plus"] = 6026681580, ["2k_plus"] = 6026681588, ["games"] = 6026660074,
    ["volume_down"] = 6026671206, ["mic"] = 6026660078, ["call_to_action"] = 6026647898, ["7k_plus"] = 6026643012,
    ["av_timer"] = 6026647934, ["9k_plus"] = 6026681585, ["radio"] = 6026663698, ["10mp"] = 6031328149,
    ["20mp"] = 6031488940, ["wb_twighlight"] = 6034412760, ["movie_creation"] = 6034323681, ["crop_portrait"] = 6031630198,
    ["filter_5"] = 6031597518, ["broken_image"] = 6031471480, ["flip_camera_android"] = 6034333280, ["flip_camera_ios"] = 6034333267,
    ["circle"] = 6031625146, ["photo_camera_front"] = 6031771000, ["assistant"] = 6031360356, ["face_retouching_natural"] = 6034333274,
    ["palette"] = 6034316009, ["nature_people"] = 6034323711, ["14mp"] = 6031328161, ["gradient"] = 6034333261,
    ["filter_4"] = 6031597512, ["panorama_wide_angle_select"] = 6031770990, ["photo"] = 6031770993, ["grid_off"] = 6034333286,
    ["leak_add"] = 6034407074, ["landscape"] = 6034407069, ["exposure_plus_1"] = 6034328970, ["slideshow"] = 6031754546,
    ["camera_alt"] = 6031572307, ["audiotrack"] = 6031471489, ["filter_none"] = 6031600815, ["blur_off"] = 6031371055,
    ["crop_16_9"] = 6031630205, ["blur_on"] = 6031371068, ["brightness_4"] = 6031471483, ["details"] = 6034328968,
    ["panorama_horizontal"] = 6034315966, ["camera_rear"] = 6031572316, ["hdr_weak"] = 6034407083, ["collections"] = 6031625145,
    ["hdr_enhanced_select"] = 6034333281, ["adjust"] = 6031339048, ["burst_mode"] = 6031572306, ["nature"] = 6034323695,
    ["brightness_6"] = 6031572309, ["19mp"] = 6031339054, ["grain"] = 6034333288, ["receipt_long"] = 6031763428,
    ["photo_filter"] = 6031770992, ["edit"] = 6034328955, ["healing"] = 6034407071, ["exposure_neg_1"] = 6034328957,
    ["exposure"] = 6034328962, ["wb_shade"] = 6034315974, ["compare"] = 6031625151, ["cases"] = 6031572324,
    ["timer_3"] = 6031754540, ["exposure_plus_2"] = 6034328961, ["12mp"] = 6031328140, ["22mp"] = 6031360353,
    ["timer_off"] = 6031734881, ["auto_stories"] = 6031360360, ["rotate_left"] = 6031763427, ["wb_iridescent"] = 6034315972,
    ["shutter_speed"] = 6031763443, ["switch_video"] = 6031754536, ["23mp"] = 6031339045, ["euro"] = 6034328963,
    ["15mp"] = 6031328158, ["filter_center_focus"] = 6031600817, ["photo_library"] = 6031770998, ["mp"] = 6034323674,
    ["looks_4"] = 6034407089, ["filter_2"] = 6031597521, ["crop_3_2"] = 6034328956, ["auto_fix_normal"] = 6031371074,
    ["auto_fix_off"] = 6031360381, ["wb_auto"] = 6031734875, ["switch_camera"] = 6031754550, ["filter_vintage"] = 6031600811,
    ["photo_size_select_small"] = 6031763457, ["blur_linear"] = 6031488930, ["hdr_on"] = 6034333279, ["tag_faces"] = 6031754560,
    ["21mp"] = 6031339065, ["camera"] = 6031572312, ["image_aspect_ratio"] = 6034407073, ["filter_b_and_w"] = 6031600824,
    ["crop_landscape"] = 6031630202, ["13mp"] = 6031328137, ["grid_on"] = 6034333276, ["motion_photos_pause"] = 6034323668,
    ["filter_6"] = 6031597524, ["linked_camera"] = 6034407082, ["panorama_fish_eye"] = 6034315969, ["panorama"] = 6034315955,
    ["color_lens"] = 6031625148, ["lens"] = 6034407081, ["crop_din"] = 6031630208, ["exposure_neg_2"] = 6034328973,
    ["mic_external_off"] = 6034323672, ["crop_free"] = 6031630212, ["crop_original"] = 6031630204, ["panorama_photosphere_select"] = 6034315975,
    ["photo_size_select_actual"] = 6031771012, ["leak_remove"] = 6034407080, ["collections_bookmark"] = 6034328965, ["straighten"] = 6031754545,
    ["timelapse"] = 6031754541, ["picture_as_pdf"] = 6031763425, ["crop_rotate"] = 6031630203, ["control_point_duplicate"] = 6034328959,
    ["photo_camera_back"] = 6031771007, ["looks_3"] = 6034407088, ["motion_photos_off"] = 6034323670, ["rotate_right"] = 6031763429,
    ["view_compact"] = 6031734878, ["crop_7_5"] = 6031630197, ["style"] = 6031754538, ["exposure_zero"] = 6034329000,
    ["camera_front"] = 6031572318, ["hdr_strong"] = 6034333272, ["view_comfy"] = 6031734876, ["panorama_vertical"] = 6034315963,
    ["panorama_vertical_select"] = 6034315961, ["looks_two"] = 6034412757, ["filter_drama"] = 6031600813, ["center_focus_strong"] = 6031625147,
    ["18mp"] = 6031339064, ["7mp"] = 6031328139, ["wb_sunny"] = 6034412758, ["filter_9_plus"] = 6031600812,
    ["crop"] = 6034328964, ["vignette"] = 6031734905, ["brightness_2"] = 6031488938, ["crop_square"] = 6031630222,
    ["looks_5"] = 6034412764, ["flip"] = 6034333275, ["looks_one"] = 6034412761, ["flash_off"] = 6034333270,
    ["hdr_off"] = 6034333266, ["photo_album"] = 6031770989, ["motion_photos_paused"] = 6034323675, ["photo_camera"] = 6031770997,
    ["2mp"] = 6031328138, ["3mp"] = 6031328136, ["24mp"] = 6031360352, ["filter_9"] = 6031597534,
    ["6mp"] = 6031328131, ["remove_red_eye"] = 6031763426, ["4mp"] = 6031328152, ["add_a_photo"] = 6031339049,
    ["filter_3"] = 6031597513, ["crop_5_4"] = 6034328960, ["8mp"] = 6031328133, ["camera_roll"] = 6031572314,
    ["panorama_wide_angle"] = 6031770995, ["transform"] = 6031734873, ["flare"] = 6031600816, ["image_search"] = 6034407084,
    ["auto_awesome"] = 6031360365, ["motion_photos_on"] = 6034323669, ["rotate_90_degrees_ccw"] = 6031763456, ["filter_1"] = 6031597511,
    ["filter_tilt_shift"] = 6031600814, ["image"] = 6034407078, ["center_focus_weak"] = 6031625144, ["blur_circular"] = 6031488945,
    ["bedtime"] = 6031371054, ["auto_fix_high"] = 6031360355, ["monochrome_photos"] = 6034323678, ["flash_auto"] = 6034333287,
    ["5mp"] = 6031328144, ["photo_size_select_large"] = 6031763423, ["assistant_photo"] = 6031339052, ["animation"] = 6031625150,
    ["looks"] = 6034407096, ["17mp"] = 6031339055, ["panorama_horizontal_select"] = 6034315965, ["flash_on"] = 6034333271,
    ["iso"] = 6034407106, ["music_note"] = 6034323673, ["music_off"] = 6034323679, ["navigate_next"] = 6034315956,
    ["timer"] = 6031754564, ["loupe"] = 6034412770, ["navigate_before"] = 6034323696, ["brightness_1"] = 6031471488,
    ["brightness_7"] = 6031471491, ["tonality"] = 6031734891, ["brush"] = 6031572320, ["colorize"] = 6031625161,
    ["filter_7"] = 6031597515, ["16mp"] = 6031328168, ["timer_10"] = 6031734880, ["portrait"] = 6031763434,
    ["tune"] = 6031734877, ["image_not_supported"] = 6034407076, ["wb_cloudy"] = 6031734907, ["auto_awesome_motion"] = 6031360370,
    ["filter_8"] = 6031597532, ["brightness_5"] = 6031471479, ["movie_filter"] = 6034323687, ["add_photo_alternate"] = 6031471484,
    ["add_to_photos"] = 6031371075, ["texture"] = 6031754553, ["11mp"] = 6031328141, ["mic_external_on"] = 6034323671,
    ["looks_6"] = 6034412759, ["dehaze"] = 6031630200, ["control_point"] = 6031625131, ["panorama_photosphere"] = 6034412763,
    ["filter_frames"] = 6031600833, ["auto_awesome_mosaic"] = 6031371053, ["9mp"] = 6031328146, ["filter"] = 6031597514,
    ["brightness_3"] = 6031572317, ["dirty_lens"] = 6034328967, ["wb_incandescent"] = 6034316010, ["filter_hdr"] = 6031600819,
    ["textsms"] = 6035202006, ["comment"] = 6035181871, ["call_end"] = 6035173845, ["qr_code_scanner"] = 6035202022,
    ["phonelink_setup"] = 6035202025, ["call_merge"] = 6035173843, ["phonelink_erase"] = 6035202085, ["contact_mail"] = 6035181868,
    ["contact_phone"] = 6035181861, ["screen_share"] = 6035202008, ["present_to_all"] = 6035202020, ["stay_primary_portrait"] = 6035202009,
    ["message"] = 6035202033, ["sentiment_satisfied_alt"] = 6035202069, ["stay_current_portrait"] = 6035202004, ["voicemail"] = 6035202019,
    ["business"] = 6035173853, ["mail_outline"] = 6035190844, ["vpn_key"] = 6035202034, ["forward_to_inbox"] = 6035190840,
    ["contacts"] = 6035181864, ["phonelink_ring"] = 6035202066, ["domain_disabled"] = 6035181862, ["person_add_disabled"] = 6035202007,
    ["stay_primary_landscape"] = 6035202026, ["alternate_email"] = 6035173865, ["phone_disabled"] = 6035202028, ["email"] = 6035181866,
    ["mobile_screen_share"] = 6035202021, ["live_help"] = 6035190836, ["chat_bubble"] = 6035181858, ["stop_screen_share"] = 6035202042,
    ["location_on"] = 6035190846, ["chat_bubble_outline"] = 6035181869, ["dialer_sip"] = 6035181865, ["no_sim"] = 6035202030,
    ["list_alt"] = 6035190838, ["call"] = 6035173859, ["pause_presentation"] = 6035202015, ["invert_colors_off"] = 6035190842,
    ["call_missed_outgoing"] = 6035173847, ["stay_current_landscape"] = 6035202011, ["import_export"] = 6035202040, ["add_ic_call"] = 6035173839,
    ["dialpad"] = 6035181892, ["nat"] = 6035202082, ["unsubscribe"] = 6035202044, ["mark_chat_unread"] = 6035190841,
    ["portable_wifi_off"] = 6035202091, ["location_off"] = 6035202049, ["person_search"] = 6035202013, ["phonelink_lock"] = 6035202064,
    ["desktop_access_disabled"] = 6035181863, ["import_contacts"] = 6035190854, ["rss_feed"] = 6035202016, ["chat"] = 6035173838,
    ["print_disabled"] = 6035202041, ["mark_email_read"] = 6035202038, ["hourglass_top"] = 6035190886, ["clear_all"] = 6035181870,
    ["forum"] = 6035202002, ["qr_code"] = 6035202012, ["speaker_phone"] = 6035202018, ["rtt"] = 6035202010,
    ["domain_verification"] = 6035181867, ["app_registration"] = 6035173870, ["call_split"] = 6035173861, ["cell_wifi"] = 6035173852,
    ["phone_enabled"] = 6035202089, ["call_made"] = 6035173858, ["call_received"] = 6035173844, ["phone"] = 6035202017,
    ["ring_volume"] = 6035202032, ["mark_email_unread"] = 6035202027, ["hourglass_bottom"] = 6035202043, ["read_more"] = 6035202014,
    ["duo"] = 6035181860, ["more_time"] = 6035202036, ["wifi_calling"] = 6035202065, ["swap_calls"] = 6035202037,
    ["cancel_presentation"] = 6035173837, ["call_missed"] = 6035173850, ["mark_chat_read"] = 6035202031, ["text_snippet"] = 6031302995,
    ["snippet_folder"] = 6031302947, ["workspaces_outline"] = 6031302952, ["file_download"] = 6031302931, ["request_quote"] = 6031302941,
    ["approval"] = 6031302928, ["drive_folder_upload"] = 6031302929, ["rule_folder"] = 6031302940, ["attach_email"] = 6031302935,
    ["topic"] = 6031302976, ["upload_file"] = 6031302959, ["attachment"] = 6031302921, ["file_download_done"] = 6031302926,
    ["drive_file_move_outline"] = 6031302924, ["cloud_upload"] = 6031302992, ["cloud_circle"] = 6031302919, ["folder_shared"] = 6031302945,
    ["cloud_download"] = 6031302917, ["file_upload"] = 6031302996, ["workspaces_filled"] = 6031302961, ["cloud_queue"] = 6031302916,
    ["cloud"] = 6031302918, ["folder_open"] = 6031302934, ["grid_view"] = 6031302950, ["cloud_off"] = 6031302993,
    ["create_new_folder"] = 6031302933, ["cloud_done"] = 6031302927, ["folder"] = 6031302932, ["drive_file_move"] = 6031302922,
    ["drive_file_rename_outline"] = 6031302994, ["notifications_active"] = 6034304908, ["sentiment_neutral"] = 6034230636, ["sick"] = 6034230642,
    ["poll"] = 6034267991, ["emoji_events"] = 6034275726, ["groups"] = 6034281935, ["sports_soccer"] = 6034227075,
    ["person_add"] = 6034287514, ["mood_bad"] = 6034295706, ["person_remove_alt_1"] = 6034287515, ["king_bed"] = 6034281948,
    ["architecture"] = 6034275730, ["deck"] = 6034295703, ["group_add"] = 6034281909, ["sports_basketball"] = 6034230649,
    ["emoji_symbols"] = 6034281899, ["switch_account"] = 6034227138, ["remove_moderator"] = 6034267998, ["coronavirus"] = 6034275724,
    ["people"] = 6034287513, ["person"] = 6034287594, ["elderly"] = 6034295698, ["clean_hands"] = 6034275729,
    ["emoji_flags"] = 6034304898, ["psychology"] = 6034287516, ["person_add_alt"] = 6034267994, ["sports_volleyball"] = 6034227139,
    ["domain"] = 6034275722, ["emoji_objects"] = 6034281900, ["ios_share"] = 6034281941, ["history_edu"] = 6034281934,
    ["share"] = 6034230648, ["military_tech"] = 6034295711, ["sports_kabaddi"] = 6034227141, ["cake"] = 6034295702,
    ["engineering"] = 6034281908, ["emoji_food_beverage"] = 6034304883, ["notifications_none"] = 6034308947, ["emoji_people"] = 6034281904,
    ["thumb_down_alt"] = 6034227069, ["sentiment_very_satisfied"] = 6034230650, ["nights_stay"] = 6034304881, ["reduce_capacity"] = 6034268013,
    ["add_moderator"] = 6034295699, ["science"] = 6034230640, ["pages"] = 6034304892, ["sentiment_satisfied"] = 6034230668,
    ["plus_one"] = 6034268012, ["party_mode"] = 6034287521, ["person_remove"] = 6034267996, ["single_bed"] = 6034230651,
    ["mood"] = 6034295704, ["public"] = 6034287522, ["sports_rugby"] = 6034227073, ["sports_handball"] = 6034227074,
    ["person_add_alt_1"] = 6034287519, ["people_alt"] = 6034287518, ["notifications_off"] = 6034304894, ["whatshot"] = 6034287525,
    ["emoji_transportation"] = 6034281894, ["outdoor_grill"] = 6034304900, ["sentiment_very_dissatisfied"] = 6034230659, ["masks"] = 6034295710,
    ["luggage"] = 6034295708, ["sports_motorsports"] = 6034227071, ["sports_esports"] = 6034227061, ["location_city"] = 6034304889,
    ["sports_golf"] = 6034227060, ["sentiment_dissatisfied"] = 6034230637, ["no_luggage"] = 6034304891, ["fireplace"] = 6034281910,
    ["emoji_nature"] = 6034281896, ["group"] = 6034281901, ["thumb_up_alt"] = 6034227076, ["sports_tennis"] = 6034227068,
    ["facebook"] = 6034281898, ["sports_mma"] = 6034227072, ["person_outline"] = 6034268008, ["sports_baseball"] = 6034230652,
    ["sports_cricket"] = 6034230660, ["people_outline"] = 6034287528, ["notifications_paused"] = 6034304896, ["emoji_emotions"] = 6034275731,
    ["follow_the_signs"] = 6034281911, ["sanitizer"] = 6034287586, ["self_improvement"] = 6034230634, ["notifications"] = 6034308946,
    ["public_off"] = 6034287538, ["recommend"] = 6034287524, ["sports_football"] = 6034227067, ["sports_hockey"] = 6034227064,
    ["school"] = 6034230641, ["connect_without_contact"] = 6034275800, ["sports"] = 6034230647, ["construction"] = 6034275725,
    ["inventory"] = 6035056487, ["add_box"] = 6035047375, ["how_to_reg"] = 6035053288, ["unarchive"] = 6035078921,
    ["block_flipped"] = 6035047378, ["file_copy"] = 6035053293, ["bolt"] = 6035047381, ["remove_circle_outline"] = 6035067843,
    ["move_to_inbox"] = 6035067838, ["save_alt"] = 6035067842, ["weekend"] = 6035078894, ["where_to_vote"] = 6035078913,
    ["biotech"] = 6035047385, ["report_off"] = 6035067830, ["clear"] = 6035047409, ["redo"] = 6035056483,
    ["link"] = 6035056475, ["drafts"] = 6035053297, ["push_pin"] = 6035056481, ["reply"] = 6035067844,
    ["undo"] = 6035078896, ["archive"] = 6035047379, ["add"] = 6035047377, ["insights"] = 6035067839,
    ["flag"] = 6035053279, ["save"] = 6035067857, ["text_format"] = 6035078890, ["content_cut"] = 6035053280,
    ["ballot"] = 6035047386, ["remove"] = 6035067836, ["calculate"] = 6035047384, ["report"] = 6035067826,
    ["markunread"] = 6035056476, ["delete_sweep"] = 6035053301, ["gesture"] = 6035053287, ["link_off"] = 6035056484,
    ["forward"] = 6035053298, ["reply_all"] = 6035067824, ["how_to_vote"] = 6035053295, ["square_foot"] = 6035078918,
    ["outlined_flag"] = 6035056486, ["add_circle"] = 6035047380, ["stacked_bar_chart"] = 6035078892, ["policy"] = 6035056512,
    ["backspace"] = 6035047397, ["sort"] = 6035078888, ["content_paste"] = 6035053285, ["low_priority"] = 6035056491,
    ["font_download"] = 6035053275, ["shield"] = 6035078889, ["waves"] = 6035078898, ["select_all"] = 6035067834,
    ["dynamic_feed"] = 6035053289, ["mail"] = 6035056477, ["amp_stories"] = 6035047382, ["filter_list"] = 6035053294,
    ["send"] = 6035067832, ["create"] = 6035053304, ["stream"] = 6035078897, ["next_week"] = 6035067835,
    ["inbox"] = 6035067831, ["add_link"] = 6035047374, ["content_copy"] = 6035053278, ["remove_circle"] = 6035067837,
    ["add_circle_outline"] = 6035047391, ["block"] = 6035047387, ["tag"] = 6035078895, ["beach_access"] = 6035107923,
    ["stroller"] = 6035161535, ["family_restroom"] = 6035121916, ["corporate_fare"] = 6035121908, ["no_meeting_room"] = 6035153649,
    ["do_not_touch"] = 6035121915, ["ac_unit"] = 6035107929, ["business_center"] = 6035107933, ["spa"] = 6035153639,
    ["no_flash"] = 6035145424, ["no_cell"] = 6035145376, ["room_service"] = 6035153648, ["tapas"] = 6035161533,
    ["microwave"] = 6035145367, ["meeting_room"] = 6035145361, ["wash"] = 6035161540, ["escalator"] = 6035121939,
    ["house_siding"] = 6035145393, ["food_bank"] = 6035121921, ["foundation"] = 6035121918, ["elevator"] = 6035121912,
    ["room_preferences"] = 6035153642, ["do_not_step"] = 6035121910, ["free_breakfast"] = 6035145363, ["house"] = 6035145364,
    ["child_care"] = 6035107927, ["night_shelter"] = 6035145378, ["child_friendly"] = 6035121942, ["checkroom"] = 6035107931,
    ["hot_tub"] = 6035145382, ["dry"] = 6035121909, ["charging_station"] = 6035107925, ["all_inclusive"] = 6035107920,
    ["bento"] = 6035107924, ["no_backpack"] = 6035145368, ["storefront"] = 6035161534, ["no_food"] = 6035145372,
    ["backpack"] = 6035107928, ["stairs"] = 6035153637, ["carpenter"] = 6035107955, ["no_stroller"] = 6035153661,
    ["roofing"] = 6035153656, ["umbrella"] = 6035161550, ["sports_bar"] = 6035153638, ["apartment"] = 6035107922,
    ["smoke_free"] = 6035153647, ["pool"] = 6035153655, ["bathtub"] = 6035107939, ["no_drinks"] = 6035145390,
    ["escalator_warning"] = 6035121930, ["wheelchair_pickup"] = 6035161536, ["smoking_rooms"] = 6035153636, ["rice_bowl"] = 6035153662,
    ["tty"] = 6035161541, ["no_photography"] = 6035153664, ["casino"] = 6035107936, ["fence"] = 6035121923,
    ["grass"] = 6035145359, ["countertops"] = 6035121914, ["kitchen"] = 6035145362, ["golf_course"] = 6035145423,
    ["soap"] = 6035153645, ["water_damage"] = 6035161563, ["airport_shuttle"] = 6035107921, ["fitness_center"] = 6035121907,
    ["baby_changing_station"] = 6035107930, ["fire_extinguisher"] = 6035121913, ["sparkle"] = 4483362748
}

LouisHub.RawIcons = RawIconDatabase
LouisHub.CustomIcons = {}

-- =====================================================================
-- SECTION 18: HIGH-PERFORMANCE ICON RESOLVER ENGINE
-- =====================================================================
local CommonIconAliases = {
    ["warning"]     = "_warning",
    ["error"]       = "_error",
    ["alert"]       = "report_problem",
    ["danger"]      = "dangerous",
    ["help"]        = "info",
    ["success"]     = "check_circle",
    ["crosshair"]   = "my_location",
    ["user"]        = "person",
    ["profile"]     = "account_circle",
    ["sword"]       = "sports_kabaddi",
    ["aim"]         = "my_location",
    ["trash"]       = "delete",
    ["gear"]        = "settings"
}

function LouisHub:AddIcon(customName, robloxAssetId)
    if type(customName) ~= "string" then return false end
    local cleanId = tostring(robloxAssetId):gsub("[^%d]", "")
    local num = tonumber(cleanId)
    if num then
        self.CustomIcons[customName:lower()] = num
        return true
    end
    return false
end

function LouisHub:GetIcon(iconKey)
    if not iconKey then return nil end

    local str = tostring(iconKey):gsub("^%s+", ""):gsub("%s+$", "")
    if str == "" then return nil end

    if str:find("^rbxassetid://") then
        return str
    end

    local cleanNumeric = str:match("^%d+$")
    if cleanNumeric then
        return "rbxassetid://" .. cleanNumeric
    end

    local normalized = str:lower()
    local resolvedKey = CommonIconAliases[normalized] or normalized

    if self.CustomIcons[resolvedKey] then
        return "rbxassetid://" .. tostring(self.CustomIcons[resolvedKey])
    end

    if self.RawIcons[resolvedKey] then
        return "rbxassetid://" .. tostring(self.RawIcons[resolvedKey])
    end

    return nil
end

function LouisHub:MountIcon(parentInstance, iconKey, sizePixels, iconColor)
    local assetUrl = self:GetIcon(iconKey)
    local px = sizePixels or 16

    if assetUrl then
        local iconImage = Instance.new("ImageLabel")
        iconImage.Name = "Icon_" .. tostring(iconKey)
        iconImage.BackgroundTransparency = 1
        iconImage.Size = UDim2.fromOffset(px, px)
        iconImage.Image = assetUrl
        iconImage.ImageColor3 = iconColor or self.CurrentTheme.Text
        iconImage.ScaleType = Enum.ScaleType.Fit
        iconImage.Parent = parentInstance

        if not iconColor then
            self:RegisterThemeProperty(iconImage, "ImageColor3", "Text")
        end

        return iconImage, true
    else
        local glyphLabel = Instance.new("TextLabel")
        glyphLabel.Name = "Glyph_" .. tostring(iconKey)
        glyphLabel.BackgroundTransparency = 1
        glyphLabel.Size = UDim2.fromOffset(px, px)
        glyphLabel.Text = "▪"
        glyphLabel.Font = Enum.Font.GothamBold
        glyphLabel.TextSize = math.clamp(px, 10, 18)
        glyphLabel.TextColor3 = iconColor or self.CurrentTheme.Accent
        glyphLabel.Parent = parentInstance

        if not iconColor then
            self:RegisterThemeProperty(glyphLabel, "TextColor3", "Accent")
        end

        return glyphLabel, false
    end
end

-- LOUIS HUB | PART 2C | continues in PART 3A

-- =====================================================================
-- SECTION 19: SCREEN-CLAMPED RESPONSIVE TOOLTIP SYSTEM
-- =====================================================================
local TooltipOverlayGui = nil
local ActiveTooltipFrame = nil
local ActiveTooltipLabel = nil
local CurrentTooltipOwner = nil
local TooltipHoverToken = 0

local function ensureTooltipOverlay()
    if TooltipOverlayGui and TooltipOverlayGui.Parent then return TooltipOverlayGui end

    local safeParent = LouisHub:GetSafeContainer()
    TooltipOverlayGui = Instance.new("ScreenGui")
    TooltipOverlayGui.Name = "LouisHub_TooltipOverlay"
    TooltipOverlayGui.ResetOnSpawn = false
    TooltipOverlayGui.IgnoreGuiInset = true
    TooltipOverlayGui.DisplayOrder = 999999
    TooltipOverlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    TooltipOverlayGui.Parent = safeParent

    LouisHub:ProtectContainer(TooltipOverlayGui)
    LouisHub.RootJanitor:Add(TooltipOverlayGui)

    ActiveTooltipFrame = Instance.new("Frame")
    ActiveTooltipFrame.Name = "TooltipCard"
    ActiveTooltipFrame.BackgroundColor3 = LouisHub.CurrentTheme.Surface
    ActiveTooltipFrame.BackgroundTransparency = 0.15
    ActiveTooltipFrame.BorderSizePixel = 0
    ActiveTooltipFrame.Visible = false
    ActiveTooltipFrame.ZIndex = 1000000
    ActiveTooltipFrame.Size = UDim2.fromOffset(0, 0)
    ActiveTooltipFrame.AutomaticSize = Enum.AutomaticSize.XY
    ActiveTooltipFrame.Parent = TooltipOverlayGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = ActiveTooltipFrame

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Color = LouisHub.CurrentTheme.Border
    stroke.Transparency = 0.3
    stroke.Parent = ActiveTooltipFrame
    LouisHub:RegisterThemeProperty(stroke, "Color", "Border")

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)
    padding.PaddingTop = UDim.new(0, 6)
    padding.PaddingBottom = UDim.new(0, 6)
    padding.Parent = ActiveTooltipFrame

    ActiveTooltipLabel = Instance.new("TextLabel")
    ActiveTooltipLabel.Name = "TooltipText"
    ActiveTooltipLabel.BackgroundTransparency = 1
    ActiveTooltipLabel.Font = Enum.Font.GothamMedium
    ActiveTooltipLabel.TextSize = 11
    ActiveTooltipLabel.TextColor3 = LouisHub.CurrentTheme.Text
    ActiveTooltipLabel.TextWrapped = true
    ActiveTooltipLabel.Size = UDim2.fromOffset(0, 0)
    ActiveTooltipLabel.AutomaticSize = Enum.AutomaticSize.XY
    ActiveTooltipLabel.ZIndex = 1000001
    ActiveTooltipLabel.Parent = ActiveTooltipFrame
    LouisHub:RegisterThemeProperty(ActiveTooltipLabel, "TextColor3", "Text")

    return TooltipOverlayGui
end

function LouisHub:HideTooltip()
    TooltipHoverToken = TooltipHoverToken + 1
    CurrentTooltipOwner = nil

    if ActiveTooltipFrame and ActiveTooltipFrame.Visible then
        LouisHub:Tween(ActiveTooltipFrame, { BackgroundTransparency = 1 }, 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function()
            if not CurrentTooltipOwner then
                ActiveTooltipFrame.Visible = false
            end
        end)
    end
end

function LouisHub:ShowTooltip(ownerInstance, textString)
    if not ownerInstance or not ownerInstance.Parent or not textString or textString == "" then
        self:HideTooltip()
        return
    end

    ensureTooltipOverlay()
    CurrentTooltipOwner = ownerInstance

    ActiveTooltipLabel.Text = textString
    ActiveTooltipFrame.Visible = true
    ActiveTooltipFrame.BackgroundTransparency = 1

    local scaleModifier = ActiveTooltipFrame:FindFirstChild("_TipScale")
    if not scaleModifier then
        scaleModifier = Instance.new("UIScale")
        scaleModifier.Name = "_TipScale"
        scaleModifier.Parent = ActiveTooltipFrame
    end

    scaleModifier.Scale = 0.92

    task.defer(function()
        if CurrentTooltipOwner ~= ownerInstance then return end

        local ownerPos = ownerInstance.AbsolutePosition
        local ownerSize = ownerInstance.AbsoluteSize
        local tipSize = ActiveTooltipFrame.AbsoluteSize

        local targetX = ownerPos.X + (ownerSize.X / 2) - (tipSize.X / 2)
        local targetY = ownerPos.Y + ownerSize.Y + 8

        local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
        if targetY + tipSize.Y > viewport.Y - 12 then
            targetY = ownerPos.Y - tipSize.Y - 8
        end

        local clampedX = math.clamp(targetX, 10, math.max(10, viewport.X - tipSize.X - 10))
        local clampedY = math.clamp(targetY, 10, math.max(10, viewport.Y - tipSize.Y - 10))

        ActiveTooltipFrame.Position = UDim2.fromOffset(clampedX, clampedY)

        LouisHub:Tween(ActiveTooltipFrame, { BackgroundTransparency = 0.15 }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        LouisHub:Tween(scaleModifier, { Scale = 1.0 }, 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    end)
end

function LouisHub:BindTooltip(targetInteractiveObject, tooltipContent)
    if not targetInteractiveObject or not tooltipContent or tooltipContent == "" then return end

    local longPressThread = nil

    targetInteractiveObject.MouseEnter:Connect(function()
        local myToken = TooltipHoverToken + 1
        TooltipHoverToken = myToken

        task.delay(0.35, function()
            if TooltipHoverToken == myToken and targetInteractiveObject.Parent then
                LouisHub:ShowTooltip(targetInteractiveObject, tooltipContent)
            end
        end)
    end)

    targetInteractiveObject.MouseLeave:Connect(function()
        LouisHub:HideTooltip()
    end)

    targetInteractiveObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            local myToken = TooltipHoverToken + 1
            TooltipHoverToken = myToken

            longPressThread = task.delay(0.48, function()
                if TooltipHoverToken == myToken and targetInteractiveObject.Parent then
                    LouisHub:ShowTooltip(targetInteractiveObject, tooltipContent)
                end
            end)
        end
    end)

    targetInteractiveObject.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            if longPressThread then
                task.cancel(longPressThread)
                longPressThread = nil
            end
            task.delay(1.5, function()
                if CurrentTooltipOwner == targetInteractiveObject then
                    LouisHub:HideTooltip()
                end
            end)
        end
    end)
end

-- =====================================================================
-- SECTION 20: STACKING NOTIFICATION ENGINE (QUEUE & COUNTDOWN)
-- =====================================================================
local NotificationGui = nil
local NotificationContainer = nil
local ActiveNotificationCount = 0
local NotificationQueue = {}
local MAX_CONCURRENT_NOTIFICATIONS = 4

local NotificationTypeStyles = {
    ["Info"] = {
        ColorKey = "Accent",
        FallbackColor = Color3.fromRGB(0, 230, 255),
        DefaultIcon = "info"
    },
    ["Success"] = {
        ColorKey = "Success",
        FallbackColor = Color3.fromRGB(52, 211, 153),
        DefaultIcon = "success"
    },
    ["Warning"] = {
        ColorKey = "Warning",
        FallbackColor = Color3.fromRGB(251, 191, 36),
        DefaultIcon = "warning"
    },
    ["Error"] = {
        ColorKey = "Error",
        FallbackColor = Color3.fromRGB(248, 113, 113),
        DefaultIcon = "error"
    }
}

local function ensureNotificationDisplay()
    if NotificationContainer and NotificationContainer.Parent then return NotificationContainer end

    local safeParent = LouisHub:GetSafeContainer()
    NotificationGui = Instance.new("ScreenGui")
    NotificationGui.Name = "LouisHub_NotificationDisplay"
    NotificationGui.ResetOnSpawn = false
    NotificationGui.IgnoreGuiInset = true
    NotificationGui.DisplayOrder = 900000
    NotificationGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    NotificationGui.Parent = safeParent

    LouisHub:ProtectContainer(NotificationGui)
    LouisHub.RootJanitor:Add(NotificationGui)

    NotificationContainer = Instance.new("Frame")
    NotificationContainer.Name = "NotificationQueueFrame"
    NotificationContainer.BackgroundTransparency = 1
    NotificationContainer.Size = UDim2.new(0, 310, 1, -24)
    NotificationContainer.Position = UDim2.new(1, -322, 0, 12)
    NotificationContainer.Parent = NotificationGui

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    layout.Padding = UDim.new(0, 8)
    layout.Parent = NotificationContainer

    return NotificationContainer
end

local function processNotificationCard(data)
    ActiveNotificationCount = ActiveNotificationCount + 1
    local container = ensureNotificationDisplay()

    local titleText = tostring(data.Title or "Notification")
    local bodyContent = tostring(data.Content or data.Text or "")
    local nType = tostring(data.Type or "Info")
    local duration = tonumber(data.Duration) or 4.5
    local style = NotificationTypeStyles[nType] or NotificationTypeStyles["Info"]
    local iconIdentifier = data.Icon or style.DefaultIcon

    local card = Instance.new("Frame")
    card.Name = "Notif_" .. titleText:gsub("%s+", "")
    card.BackgroundColor3 = LouisHub.CurrentTheme.Surface
    card.BackgroundTransparency = 1
    card.BorderSizePixel = 0
    card.ClipsDescendants = true
    card.Size = UDim2.new(1, 0, 0, 0)
    card.Position = UDim2.new(1, 50, 0, 0)
    card.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Thickness = 1
    cardStroke.Color = LouisHub.CurrentTheme[style.ColorKey] or style.FallbackColor
    cardStroke.Transparency = 1
    cardStroke.Parent = card

    local accentStripe = Instance.new("Frame")
    accentStripe.Name = "AccentStripe"
    accentStripe.Size = UDim2.new(0, 4, 1, 0)
    accentStripe.Position = UDim2.new(0, 0, 0, 0)
    accentStripe.BackgroundColor3 = LouisHub.CurrentTheme[style.ColorKey] or style.FallbackColor
    accentStripe.BorderSizePixel = 0
    accentStripe.Parent = card

    local iconHolder = Instance.new("Frame")
    iconHolder.Name = "IconHolder"
    iconHolder.BackgroundTransparency = 1
    iconHolder.Size = UDim2.fromOffset(20, 20)
    iconHolder.Position = UDim2.fromOffset(12, 10)
    iconHolder.Parent = card

    LouisHub:MountIcon(iconHolder, iconIdentifier, 18, LouisHub.CurrentTheme[style.ColorKey] or style.FallbackColor)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 13
    titleLabel.TextColor3 = LouisHub.CurrentTheme.Highlight
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = titleText
    titleLabel.Size = UDim2.new(1, -64, 0, 18)
    titleLabel.Position = UDim2.fromOffset(38, 10)
    titleLabel.Parent = card
    LouisHub:RegisterThemeProperty(titleLabel, "TextColor3", "Highlight")

    local dismissButton = Instance.new("TextButton")
    dismissButton.Name = "DismissBtn"
    dismissButton.BackgroundTransparency = 1
    dismissButton.Font = Enum.Font.GothamBold
    dismissButton.TextSize = 13
    dismissButton.TextColor3 = LouisHub.CurrentTheme.TextMuted
    dismissButton.Text = "✕"
    dismissButton.Size = UDim2.fromOffset(20, 20)
    dismissButton.Position = UDim2.new(1, -26, 0, 8)
    dismissButton.Parent = card

    local bodyLabel = Instance.new("TextLabel")
    bodyLabel.Name = "BodyLabel"
    bodyLabel.BackgroundTransparency = 1
    bodyLabel.Font = Enum.Font.Gotham
    bodyLabel.TextSize = 11
    bodyLabel.TextColor3 = LouisHub.CurrentTheme.Text
    bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
    bodyLabel.TextWrapped = true
    bodyLabel.Text = bodyContent
    bodyLabel.Position = UDim2.fromOffset(38, 30)
    bodyLabel.Size = UDim2.new(1, -50, 0, 0)
    bodyLabel.AutomaticSize = Enum.AutomaticSize.Y
    bodyLabel.Parent = card
    LouisHub:RegisterThemeProperty(bodyLabel, "TextColor3", "Text")

    local actionButtonContainer = nil
    local hasButtons = type(data.Buttons) == "table" and #data.Buttons > 0

    if hasButtons then
        actionButtonContainer = Instance.new("Frame")
        actionButtonContainer.Name = "ActionsFrame"
        actionButtonContainer.BackgroundTransparency = 1
        actionButtonContainer.Size = UDim2.new(1, -50, 0, 24)
        actionButtonContainer.Parent = card

        local bLayout = Instance.new("UIListLayout")
        bLayout.FillDirection = Enum.FillDirection.Horizontal
        bLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
        bLayout.Padding = UDim.new(0, 6)
        bLayout.Parent = actionButtonContainer
    end

    local progressTrack = Instance.new("Frame")
    progressTrack.Name = "ProgressBarTrack"
    progressTrack.BackgroundColor3 = LouisHub.CurrentTheme.SurfaceAlt
    progressTrack.BorderSizePixel = 0
    progressTrack.Size = UDim2.new(1, 0, 0, 2)
    progressTrack.Position = UDim2.new(0, 0, 1, -2)
    progressTrack.Parent = card

    local progressFill = Instance.new("Frame")
    progressFill.Name = "ProgressBarFill"
    progressFill.BackgroundColor3 = LouisHub.CurrentTheme[style.ColorKey] or style.FallbackColor
    progressFill.BorderSizePixel = 0
    progressFill.Size = UDim2.new(1, 0, 1, 0)
    progressFill.Parent = progressTrack

    local isDismissed = false
    local function dismissNotification()
        if isDismissed then return end
        isDismissed = true

        LouisHub:Tween(card, { BackgroundTransparency = 1, Position = UDim2.new(1, 80, 0, card.Position.Y.Offset) }, 0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        LouisHub:Tween(cardStroke, { Transparency = 1 }, 0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        LouisHub:Tween(card, { Size = UDim2.new(1, 0, 0, 0) }, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function()
            pcall(function() card:Destroy() end)
            ActiveNotificationCount = math.max(0, ActiveNotificationCount - 1)

            local nextInQueue = table.remove(NotificationQueue, 1)
            if nextInQueue then
                processNotificationCard(nextInQueue)
            end
        end)
    end

    dismissButton.MouseButton1Click:Connect(dismissNotification)
    card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if not hasButtons then
                dismissNotification()
            end
        end
    end)

    task.defer(function()
        local bodyY = bodyLabel.AbsoluteSize.Y
        local targetCardHeight = math.max(54, bodyY + 44)

        if hasButtons and actionButtonContainer then
            targetCardHeight = targetCardHeight + 30
            actionButtonContainer.Position = UDim2.fromOffset(38, bodyY + 36)

            for _, btnDef in ipairs(data.Buttons) do
                local b = Instance.new("TextButton")
                b.BackgroundColor3 = LouisHub.CurrentTheme.SurfaceAlt
                b.Size = UDim2.new(0, 68, 1, 0)
                b.Font = Enum.Font.GothamMedium
                b.TextSize = 10.5
                b.TextColor3 = LouisHub.CurrentTheme.Text
                b.Text = tostring(btnDef.Text or "Action")
                b.Parent = actionButtonContainer

                local bCorner = Instance.new("UICorner")
                bCorner.CornerRadius = UDim.new(0, 4)
                bCorner.Parent = b

                b.MouseButton1Click:Connect(function()
                    if btnDef.Callback then
                        pcall(btnDef.Callback)
                    end
                    dismissNotification()
                end)
            end
        end

        card.Position = UDim2.new(1, 50, 0, 0)
        card.Size = UDim2.new(1, 0, 0, targetCardHeight)

        LouisHub:Tween(card, { BackgroundTransparency = 0.08, Position = UDim2.new(0, 0, 0, 0) }, 0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        LouisHub:Tween(cardStroke, { Transparency = 0.4 }, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

        LouisHub:Tween(progressFill, { Size = UDim2.new(0, 0, 1, 0) }, duration, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, function()
            dismissNotification()
        end)
    end)
end

function LouisHub:Notify(notificationConfig)
    if type(notificationConfig) == "string" then
        notificationConfig = { Title = "Notification", Content = notificationConfig }
    end
    notificationConfig = notificationConfig or {}

    if ActiveNotificationCount >= MAX_CONCURRENT_NOTIFICATIONS then
        local priority = notificationConfig.Priority or 0
        local inserted = false

        for idx, queued in ipairs(NotificationQueue) do
            if (queued.Priority or 0) < priority then
                table.insert(NotificationQueue, idx, notificationConfig)
                inserted = true
                break
            end
        end

        if not inserted then
            table.insert(NotificationQueue, notificationConfig)
        end
        return
    end

    processNotificationCard(notificationConfig)
end

-- LOUIS HUB | PART 3A | continues in PART 3B

-- =====================================================================
-- SECTION 21: AUTHENTIC GLASS BLUR FRUSTUM RAYCASTING ENGINE
-- =====================================================================
local Lighting = Services.Lighting
local ActiveBlurConsumers = 0
local SingletonDepthOfField = nil

local BlurController = {}

function BlurController.Request()
    ActiveBlurConsumers = ActiveBlurConsumers + 1
    if SingletonDepthOfField and SingletonDepthOfField.Parent then return SingletonDepthOfField end

    if Lighting then
        local success, dof = pcall(function()
            local inst = Instance.new("DepthOfFieldEffect")
            inst.Name = "LouisHub_GlobalBlur"
            inst.FarIntensity = 0
            inst.FocusDistance = 50
            inst.InFocusRadius = 45
            inst.NearIntensity = 3.5
            inst.Parent = Lighting
            return inst
        end)

        if success and dof then
            SingletonDepthOfField = dof
            LouisHub.RootJanitor:Add(dof)
            return dof
        end
    end
    return nil
end

function BlurController.Release()
    ActiveBlurConsumers = math.max(0, ActiveBlurConsumers - 1)
    if ActiveBlurConsumers <= 0 and SingletonDepthOfField then
        pcall(function()
            SingletonDepthOfField:Destroy()
        end)
        SingletonDepthOfField = nil
    end
end

LouisHub.Blur = BlurController

function LouisHub:ApplyGlassBlur(targetFrame)
    local camera = workspace.CurrentCamera
    if not camera then return nil end

    local blurFolder = Instance.new("Folder")
    blurFolder.Name = "LouisHub_GlassBlurMesh"
    blurFolder.Parent = camera
    self.RootJanitor:Add(blurFolder)

    self.Blur.Request()

    local function createWedgePart()
        local part = Instance.new("Part")
        part.Material = Enum.Material.Glass
        part.Transparency = 0.98
        part.Color = Color3.fromRGB(240, 240, 245)
        part.Anchored = true
        part.CanCollide = false
        part.CastShadow = false
        part.Size = Vector3.new(0.2, 0.2, 0.2)

        local mesh = Instance.new("SpecialMesh", part)
        mesh.MeshType = Enum.MeshType.Wedge
        mesh.Scale = Vector3.new(0, 0, 0)
        part.Parent = blurFolder
        return part, mesh
    end

    local p1, m1 = createWedgePart()
    local p2, m2 = createWedgePart()

    local function updateGlassOrientation()
        if not (targetFrame and targetFrame.Parent and targetFrame.Visible) then
            p1.CFrame = CFrame.new(0, 10000, 0)
            p2.CFrame = CFrame.new(0, 10000, 0)
            return
        end

        local absPos = targetFrame.AbsolutePosition
        local absSize = targetFrame.AbsoluteSize
        if absSize.X <= 0 or absSize.Y <= 0 then return end

        local depthPlane = 0.99
        local tl = camera:ViewportPointToRay(absPos.X, absPos.Y, depthPlane).Origin
        local tr = camera:ViewportPointToRay(absPos.X + absSize.X, absPos.Y, depthPlane).Origin
        local bl = camera:ViewportPointToRay(absPos.X, absPos.Y + absSize.Y, depthPlane).Origin
        local br = camera:ViewportPointToRay(absPos.X + absSize.X, absPos.Y + absSize.Y, depthPlane).Origin

        local mid1 = (tl + tr + bl) / 3
        p1.Size = Vector3.new(0.2, (tr - tl).Magnitude, (bl - tl).Magnitude)
        p1.CFrame = CFrame.new(mid1, tr) * CFrame.Angles(0, math.pi / 2, 0)
        m1.Scale = Vector3.new(0.01, (tr - tl).Magnitude / 0.2, (bl - tl).Magnitude / 0.2)

        local mid2 = (tr + br + bl) / 3
        p2.Size = Vector3.new(0.2, (br - tr).Magnitude, (bl - br).Magnitude)
        p2.CFrame = CFrame.new(mid2, br) * CFrame.Angles(0, math.pi / 2, 0)
        m2.Scale = Vector3.new(0.01, (br - tr).Magnitude / 0.2, (bl - br).Magnitude / 0.2)
    end

    local renderConn = RunService.RenderStepped:Connect(updateGlassOrientation)
    self.RootJanitor:Add(renderConn)

    targetFrame.Destroying:Connect(function()
        pcall(function() renderConn:Disconnect() end)
        pcall(function() blurFolder:Destroy() end)
        self.Blur.Release()
    end)
end

-- =====================================================================
-- SECTION 22: MODAL CONFIRMATION DIALOG SUBSYSTEM
-- =====================================================================
local OpenModalLayerCount = 0

function LouisHub:Confirm(dialogConfig)
    dialogConfig = dialogConfig or {}
    local titleText = tostring(dialogConfig.Title or "Confirm Action")
    local messageContent = tostring(dialogConfig.Content or dialogConfig.Message or "Are you sure you want to proceed?")
    local iconIdentifier = dialogConfig.Icon or "warning"
    local allowBackdropDismiss = dialogConfig.BackdropClose == true

    local safeParent = self:GetSafeContainer()
    local modalGui = Instance.new("ScreenGui")
    modalGui.Name = "LouisHub_ConfirmModal"
    modalGui.ResetOnSpawn = false
    modalGui.IgnoreGuiInset = true

    OpenModalLayerCount = OpenModalLayerCount + 1
    local currentZ = 950000 + (OpenModalLayerCount * 20)
    modalGui.DisplayOrder = currentZ
    modalGui.Parent = safeParent
    self:ProtectContainer(modalGui)

    local blurInstance = BlurController.Request()

    local backdrop = Instance.new("TextButton")
    backdrop.Name = "Backdrop"
    backdrop.AutoButtonColor = false
    backdrop.Text = ""
    backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    backdrop.BackgroundTransparency = 1
    backdrop.Size = UDim2.new(1, 0, 1, 0)
    backdrop.Parent = modalGui

    local card = Instance.new("Frame")
    card.Name = "ConfirmCard"
    card.BackgroundColor3 = self.CurrentTheme.Surface
    card.BackgroundTransparency = 1
    card.Size = UDim2.fromOffset(340, 0)
    card.Position = UDim2.new(0.5, 0, 0.5, 0)
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.ClipsDescendants = true
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.Parent = backdrop

    self:ApplyGlassBlur(card)

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 10)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Thickness = 1.2
    cardStroke.Color = self.CurrentTheme.Border
    cardStroke.Transparency = 1
    cardStroke.Parent = card
    self:RegisterThemeProperty(cardStroke, "Color", "Border")

    local cardPadding = Instance.new("UIPadding")
    cardPadding.PaddingLeft = UDim.new(0, 16)
    cardPadding.PaddingRight = UDim.new(0, 16)
    cardPadding.PaddingTop = UDim.new(0, 16)
    cardPadding.PaddingBottom = UDim.new(0, 16)
    cardPadding.Parent = card

    local cardLayout = Instance.new("UIListLayout")
    cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
    cardLayout.Padding = UDim.new(0, 10)
    cardLayout.Parent = card

    local headerContainer = Instance.new("Frame")
    headerContainer.Name = "Header"
    headerContainer.BackgroundTransparency = 1
    headerContainer.Size = UDim2.new(1, 0, 0, 24)
    headerContainer.LayoutOrder = 1
    headerContainer.Parent = card

    local iconHolder = Instance.new("Frame")
    iconHolder.Name = "IconHolder"
    iconHolder.BackgroundTransparency = 1
    iconHolder.Size = UDim2.fromOffset(22, 22)
    iconHolder.Position = UDim2.new(0, 0, 0.5, -11)
    iconHolder.Parent = headerContainer

    self:MountIcon(iconHolder, iconIdentifier, 20, self.CurrentTheme.Accent)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 14
    titleLabel.TextColor3 = self.CurrentTheme.Highlight
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = titleText
    titleLabel.Position = UDim2.fromOffset(28, 0)
    titleLabel.Size = UDim2.new(1, -28, 1, 0)
    titleLabel.Parent = headerContainer
    self:RegisterThemeProperty(titleLabel, "TextColor3", "Highlight")

    local bodyLabel = Instance.new("TextLabel")
    bodyLabel.Name = "MessageBody"
    bodyLabel.BackgroundTransparency = 1
    bodyLabel.Font = Enum.Font.Gotham
    bodyLabel.TextSize = 11.5
    bodyLabel.TextColor3 = self.CurrentTheme.Text
    bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
    bodyLabel.TextWrapped = true
    bodyLabel.Text = messageContent
    bodyLabel.Size = UDim2.new(1, 0, 0, 0)
    bodyLabel.AutomaticSize = Enum.AutomaticSize.Y
    bodyLabel.LayoutOrder = 2
    bodyLabel.Parent = card
    self:RegisterThemeProperty(bodyLabel, "TextColor3", "Text")

    local buttonsRow = Instance.new("Frame")
    buttonsRow.Name = "ButtonsContainer"
    buttonsRow.BackgroundTransparency = 1
    buttonsRow.Size = UDim2.new(1, 0, 0, 28)
    buttonsRow.LayoutOrder = 3
    buttonsRow.Parent = card

    local bLayout = Instance.new("UIListLayout")
    bLayout.FillDirection = Enum.FillDirection.Horizontal
    bLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    bLayout.Padding = UDim.new(0, 8)
    bLayout.Parent = buttonsRow

    local rawButtons = dialogConfig.Buttons or {
        { Text = "Cancel", Variant = "neutral", Value = false },
        { Text = "Confirm", Variant = "primary", Value = true }
    }

    local activeThread = coroutine.running()
    local isYielding = (type(dialogConfig.Callback) ~= "function")
    local dialogResult = nil
    local isResolved = false

    local function finalizeDialog(resultValue)
        if isResolved then return end
        isResolved = true
        dialogResult = resultValue

        OpenModalLayerCount = math.max(0, OpenModalLayerCount - 1)
        BlurController.Release()

        LouisHub:Tween(backdrop, { BackgroundTransparency = 1 }, 0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local cardScale = card:FindFirstChild("_CardScale")
        if cardScale then
            LouisHub:Tween(cardScale, { Scale = 0.90 }, 0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        LouisHub:Tween(card, { BackgroundTransparency = 1 }, 0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function()
            pcall(function() modalGui:Destroy() end)
        end)

        if type(dialogConfig.Callback) == "function" then
            pcall(dialogConfig.Callback, resultValue)
        elseif isYielding and coroutine.status(activeThread) == "suspended" then
            task.spawn(activeThread, resultValue)
        end
    end

    for _, bDef in ipairs(rawButtons) do
        local btn = Instance.new("TextButton")
        btn.Name = "Btn_" .. tostring(bDef.Text or "Option")
        btn.AutoButtonColor = false
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 11
        btn.Size = UDim2.new(0, 75, 1, 0)
        btn.Text = tostring(bDef.Text or "Button")
        btn.Parent = buttonsRow

        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 6)
        bCorner.Parent = btn

        local variant = bDef.Variant or "neutral"
        if variant == "primary" then
            btn.BackgroundColor3 = self.CurrentTheme.Accent
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            self:RegisterThemeProperty(btn, "BackgroundColor3", "Accent")
        elseif variant == "danger" then
            btn.BackgroundColor3 = self.CurrentTheme.Error
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            self:RegisterThemeProperty(btn, "BackgroundColor3", "Error")
        else
            btn.BackgroundColor3 = self.CurrentTheme.SurfaceAlt
            btn.TextColor3 = self.CurrentTheme.Text
            self:RegisterThemeProperty(btn, "BackgroundColor3", "SurfaceAlt")
            self:RegisterThemeProperty(btn, "TextColor3", "Text")
        end

        btn.MouseButton1Click:Connect(function()
            if bDef.Callback then
                pcall(bDef.Callback)
            end
            finalizeDialog(bDef.Value ~= nil and bDef.Value or bDef.Text)
        end)
    end

    if allowBackdropDismiss then
        backdrop.MouseButton1Click:Connect(function()
            finalizeDialog(false)
        end)
    end

    local cardScale = Instance.new("UIScale")
    cardScale.Name = "_CardScale"
    cardScale.Scale = 0.90
    cardScale.Parent = card

    LouisHub:Tween(backdrop, { BackgroundTransparency = 0.45 }, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    LouisHub:Tween(card, { BackgroundTransparency = 0.05 }, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    LouisHub:Tween(cardStroke, { Transparency = 0.3 }, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    LouisHub:Tween(cardScale, { Scale = 1.0 }, 0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

    if isYielding then
        return coroutine.yield()
    end

    return {
        Close = function() finalizeDialog(false) end
    }
end

-- =====================================================================
-- SECTION 23: STACKABLE GENERIC POPUP WINDOWS
-- =====================================================================
function LouisHub:Popup(popupConfig)
    popupConfig = popupConfig or {}
    local titleText = tostring(popupConfig.Title or "Details")
    local initialWidth = tonumber(popupConfig.Width) or 360
    local isDraggable = popupConfig.Draggable ~= false
    local isClosable = popupConfig.Closable ~= false

    local safeParent = self:GetSafeContainer()
    local popupGui = Instance.new("ScreenGui")
    popupGui.Name = "LouisHub_PopupModal"
    popupGui.ResetOnSpawn = false
    popupGui.IgnoreGuiInset = true

    OpenModalLayerCount = OpenModalLayerCount + 1
    local currentZ = 950000 + (OpenModalLayerCount * 20)
    popupGui.DisplayOrder = currentZ
    popupGui.Parent = safeParent
    self:ProtectContainer(popupGui)

    local blurInstance = BlurController.Request()

    local backdrop = Instance.new("TextButton")
    backdrop.Name = "Backdrop"
    backdrop.AutoButtonColor = false
    backdrop.Text = ""
    backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    backdrop.BackgroundTransparency = 1
    backdrop.Size = UDim2.new(1, 0, 1, 0)
    backdrop.Parent = popupGui

    local card = Instance.new("Frame")
    card.Name = "PopupContainerCard"
    card.BackgroundColor3 = self.CurrentTheme.Surface
    card.BackgroundTransparency = 1
    card.Size = UDim2.fromOffset(initialWidth, 0)
    card.Position = UDim2.new(0.5, 0, 0.5, 0)
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.ClipsDescendants = true
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.Parent = backdrop

    self:ApplyGlassBlur(card)

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 10)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Thickness = 1.2
    cardStroke.Color = self.CurrentTheme.Accent
    cardStroke.Transparency = 1
    cardStroke.Parent = card
    self:RegisterThemeProperty(cardStroke, "Color", "Accent")

    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.BackgroundColor3 = self.CurrentTheme.SurfaceAlt
    titleBar.BackgroundTransparency = 0.3
    titleBar.Size = UDim2.new(1, 0, 0, 32)
    titleBar.Parent = card
    self:RegisterThemeProperty(titleBar, "BackgroundColor3", "SurfaceAlt")

    local tbCorner = Instance.new("UICorner")
    tbCorner.CornerRadius = UDim.new(0, 10)
    tbCorner.Parent = titleBar

    local tbCover = Instance.new("Frame")
    tbCover.Name = "CornerCover"
    tbCover.BackgroundColor3 = self.CurrentTheme.SurfaceAlt
    tbCover.BackgroundTransparency = 0.3
    tbCover.BorderSizePixel = 0
    tbCover.Size = UDim2.new(1, 0, 0, 8)
    tbCover.Position = UDim2.new(0, 0, 1, -8)
    tbCover.Parent = titleBar
    self:RegisterThemeProperty(tbCover, "BackgroundColor3", "SurfaceAlt")

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 13
    titleLabel.TextColor3 = self.CurrentTheme.Highlight
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = titleText
    titleLabel.Position = UDim2.fromOffset(12, 0)
    titleLabel.Size = UDim2.new(1, -44, 1, 0)
    titleLabel.Parent = titleBar
    self:RegisterThemeProperty(titleLabel, "TextColor3", "Highlight")

    if isDraggable then
        self:MakeDraggable(titleBar, card)
    end

    local isClosed = false
    local function closePopup()
        if isClosed then return end
        isClosed = true

        OpenModalLayerCount = math.max(0, OpenModalLayerCount - 1)
        BlurController.Release()

        LouisHub:Tween(backdrop, { BackgroundTransparency = 1 }, 0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local cardScale = card:FindFirstChild("_PopupScale")
        if cardScale then
            LouisHub:Tween(cardScale, { Scale = 0.90 }, 0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
        LouisHub:Tween(card, { BackgroundTransparency = 1 }, 0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function()
            pcall(function() popupGui:Destroy() end)
            if popupConfig.OnClose then
                pcall(popupConfig.OnClose)
            end
        end)
    end

    if isClosable then
        local closeBtn = Instance.new("TextButton")
        closeBtn.Name = "CloseBtn"
        closeBtn.BackgroundTransparency = 1
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 13
        closeBtn.TextColor3 = self.CurrentTheme.TextMuted
        closeBtn.Text = "✕"
        closeBtn.Size = UDim2.fromOffset(24, 24)
        closeBtn.Position = UDim2.new(1, -28, 0.5, -12)
        closeBtn.Parent = titleBar

        closeBtn.MouseButton1Click:Connect(closePopup)

        backdrop.MouseButton1Click:Connect(function()
            if popupConfig.BackdropClose ~= false then
                closePopup()
            end
        end)
    end

    local bodyHost = Instance.new("Frame")
    bodyHost.Name = "BodyHost"
    bodyHost.BackgroundTransparency = 1
    bodyHost.Size = UDim2.new(1, 0, 0, 0)
    bodyHost.Position = UDim2.fromOffset(0, 32)
    bodyHost.AutomaticSize = Enum.AutomaticSize.Y
    bodyHost.Parent = card

    local bodyPad = Instance.new("UIPadding")
    bodyPad.PaddingLeft = UDim.new(0, 14)
    bodyPad.PaddingRight = UDim.new(0, 14)
    bodyPad.PaddingTop = UDim.new(0, 12)
    bodyPad.PaddingBottom = UDim.new(0, 14)
    bodyPad.Parent = bodyHost

    if type(popupConfig.Content) == "function" then
        pcall(popupConfig.Content, bodyHost)
    elseif type(popupConfig.Content) == "string" then
        local contentLabel = Instance.new("TextLabel")
        contentLabel.Name = "TextContent"
        contentLabel.BackgroundTransparency = 1
        contentLabel.Font = Enum.Font.Gotham
        contentLabel.TextSize = 11.5
        contentLabel.TextColor3 = self.CurrentTheme.Text
        contentLabel.TextXAlignment = Enum.TextXAlignment.Left
        contentLabel.TextWrapped = true
        contentLabel.Text = popupConfig.Content
        contentLabel.Size = UDim2.new(1, 0, 0, 0)
        contentLabel.AutomaticSize = Enum.AutomaticSize.Y
        contentLabel.Parent = bodyHost
        self:RegisterThemeProperty(contentLabel, "TextColor3", "Text")
    end

    local cardScale = Instance.new("UIScale")
    cardScale.Name = "_PopupScale"
    cardScale.Scale = 0.90
    cardScale.Parent = card

    LouisHub:Tween(backdrop, { BackgroundTransparency = 0.50 }, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    LouisHub:Tween(card, { BackgroundTransparency = 0.04 }, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    LouisHub:Tween(cardStroke, { Transparency = 0.4 }, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    LouisHub:Tween(cardScale, { Scale = 1.0 }, 0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

    return {
        Close = closePopup,
        SetTitle = function(_, newTitle)
            titleLabel.Text = tostring(newTitle)
        end,
        GetContainer = function()
            return bodyHost
        end,
        Card = card
    }
end

-- LOUIS HUB | PART 3B | continues in PART 3C

-- =====================================================================
-- SECTION 24: MODERN WINDOW SHELL, OFFICIAL LOGO & GLASS FRAME
-- =====================================================================
local ActiveMainWindow = nil

function LouisHub:CreateWindow(windowConfig)
    windowConfig = windowConfig or {}

    local titleText = tostring(windowConfig.Title or "Louis Hub")
    local subtitleText = tostring(windowConfig.Subtitle or "Master Interface Suite")
    local logoAsset = windowConfig.Logo or self.LogoAssetId
    local versionTag = tostring(windowConfig.VersionTag or ("v" .. self.Version))
    local initialWidth = tonumber(windowConfig.Width or (windowConfig.Size and windowConfig.Size.X)) or 640
    local initialHeight = tonumber(windowConfig.Height or (windowConfig.Size and windowConfig.Size.Y)) or 400
    local toggleKey = windowConfig.ToggleKey or Enum.KeyCode.RightControl
    local isHorizontal = (windowConfig.Orientation == "Horizontal")
    local isResizable = windowConfig.Resizable ~= false

    if windowConfig.Theme and self.Themes[windowConfig.Theme] then
        self:SetTheme(windowConfig.Theme, false)
    end

    local safeParent = self:GetSafeContainer()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LouisHub_MainWindowHost"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 100000
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = safeParent

    self:ProtectContainer(screenGui)
    self.RootJanitor:Add(screenGui)

    local uiScale = Instance.new("UIScale")
    uiScale.Scale = 1.0
    uiScale.Parent = screenGui
    self:BindViewportScaler(uiScale)

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.BackgroundColor3 = self.CurrentTheme.Background
    mainFrame.BackgroundTransparency = 0.12
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Size = UDim2.fromOffset(initialWidth, initialHeight)
    mainFrame.Position = UDim2.new(0.5, -initialWidth / 2, 0.5, -initialHeight / 2)
    mainFrame.Parent = screenGui
    self:RegisterThemeProperty(mainFrame, "BackgroundColor3", "Background")

    -- Mount Authentic Frosted Glass Blur
    self:ApplyGlassBlur(mainFrame)

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = mainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Thickness = 1.5
    mainStroke.Color = self.CurrentTheme.Accent
    mainStroke.Transparency = 0.35
    mainStroke.Parent = mainFrame
    self:RegisterThemeProperty(mainStroke, "Color", "Accent")

    local strokeGrad = Instance.new("UIGradient")
    strokeGrad.Parent = mainStroke
    self:RegisterGradient(strokeGrad)

    -- ── TITLE BAR ────────────────────────────────────────────────────────
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.BackgroundColor3 = self.CurrentTheme.Surface
    titleBar.BackgroundTransparency = 0.20
    titleBar.BorderSizePixel = 0
    titleBar.Size = UDim2.new(1, 0, 0, 38)
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.Parent = mainFrame
    self:RegisterThemeProperty(titleBar, "BackgroundColor3", "Surface")

    local tbCorner = Instance.new("UICorner")
    tbCorner.CornerRadius = UDim.new(0, 10)
    tbCorner.Parent = titleBar

    local tbCover = Instance.new("Frame")
    tbCover.Name = "CornerCover"
    tbCover.BackgroundColor3 = self.CurrentTheme.Surface
    tbCover.BackgroundTransparency = 0.20
    tbCover.BorderSizePixel = 0
    tbCover.Size = UDim2.new(1, 0, 0, 8)
    tbCover.Position = UDim2.new(0, 0, 1, -8)
    tbCover.Parent = titleBar
    self:RegisterThemeProperty(tbCover, "BackgroundColor3", "Surface")

    local titleAccentStripe = Instance.new("Frame")
    titleAccentStripe.Name = "AccentStripe"
    titleAccentStripe.BackgroundColor3 = self.CurrentTheme.Accent
    titleAccentStripe.BorderSizePixel = 0
    titleAccentStripe.Size = UDim2.new(1, 0, 0, 2)
    titleAccentStripe.Position = UDim2.new(0, 0, 1, -2)
    titleAccentStripe.Parent = titleBar
    self:RegisterThemeProperty(titleAccentStripe, "BackgroundColor3", "Accent")

    local stripeGradient = Instance.new("UIGradient")
    stripeGradient.Parent = titleAccentStripe
    self:RegisterGradient(stripeGradient)

    -- Official Louis Hub Logo Frame (Asset ID: 104436283956004)
    local logoHolder = Instance.new("Frame")
    logoHolder.Name = "OfficialLogoHolder"
    logoHolder.BackgroundColor3 = self.CurrentTheme.SurfaceAlt
    logoHolder.Size = UDim2.fromOffset(26, 26)
    logoHolder.Position = UDim2.fromOffset(8, 6)
    logoHolder.Parent = titleBar
    self:RegisterThemeProperty(logoHolder, "BackgroundColor3", "SurfaceAlt")

    local lhCorner = Instance.new("UICorner")
    lhCorner.CornerRadius = UDim.new(0, 13)
    lhCorner.Parent = logoHolder

    local lhStroke = Instance.new("UIStroke")
    lhStroke.Thickness = 1
    lhStroke.Color = self.CurrentTheme.Accent
    lhStroke.Parent = logoHolder
    self:RegisterThemeProperty(lhStroke, "Color", "Accent")

    local officialLogoImage = Instance.new("ImageLabel")
    officialLogoImage.Name = "LogoImage"
    officialLogoImage.BackgroundTransparency = 1
    officialLogoImage.Size = UDim2.new(1, -4, 1, -4)
    officialLogoImage.AnchorPoint = Vector2.new(0.5, 0.5)
    officialLogoImage.Position = UDim2.new(0.5, 0, 0.5, 0)
    officialLogoImage.Image = logoAsset
    officialLogoImage.ScaleType = Enum.ScaleType.Fit
    officialLogoImage.Parent = logoHolder

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 13.5
    titleLabel.TextColor3 = self.CurrentTheme.Highlight
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = titleText
    titleLabel.Position = UDim2.fromOffset(40, 4)
    titleLabel.Size = UDim2.new(0, 180, 0, 16)
    titleLabel.Parent = titleBar
    self:RegisterThemeProperty(titleLabel, "TextColor3", "Highlight")

    local subtitleLabel = Instance.new("TextLabel")
    subtitleLabel.Name = "SubtitleLabel"
    subtitleLabel.BackgroundTransparency = 1
    subtitleLabel.Font = Enum.Font.GothamMedium
    subtitleLabel.TextSize = 9.5
    subtitleLabel.TextColor3 = self.CurrentTheme.TextMuted
    subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    subtitleLabel.Text = subtitleText
    subtitleLabel.Position = UDim2.fromOffset(40, 20)
    subtitleLabel.Size = UDim2.new(0, 220, 0, 12)
    subtitleLabel.Parent = titleBar
    self:RegisterThemeProperty(subtitleLabel, "TextColor3", "TextMuted")

    local versionBadge = Instance.new("Frame")
    versionBadge.Name = "VersionBadge"
    versionBadge.BackgroundColor3 = self.CurrentTheme.SurfaceAlt
    versionBadge.BorderSizePixel = 0
    versionBadge.Size = UDim2.fromOffset(48, 16)
    versionBadge.Position = UDim2.new(0, 268, 0.5, -8)
    versionBadge.Parent = titleBar
    self:RegisterThemeProperty(versionBadge, "BackgroundColor3", "SurfaceAlt")

    local vbCorner = Instance.new("UICorner")
    vbCorner.CornerRadius = UDim.new(0, 4)
    vbCorner.Parent = versionBadge

    local versionText = Instance.new("TextLabel")
    versionText.BackgroundTransparency = 1
    versionText.Font = Enum.Font.GothamBold
    versionText.TextSize = 9
    versionText.TextColor3 = self.CurrentTheme.Accent
    versionText.Text = versionTag
    versionText.Size = UDim2.new(1, 0, 1, 0)
    versionText.Parent = versionBadge
    self:RegisterThemeProperty(versionText, "TextColor3", "Accent")

    -- ── WINDOW ACTION BUTTONS (MINIMIZE & CLOSE) ─────────────────────────
    local windowActionsFrame = Instance.new("Frame")
    windowActionsFrame.Name = "WindowActions"
    windowActionsFrame.BackgroundTransparency = 1
    windowActionsFrame.Size = UDim2.new(0, 56, 1, 0)
    windowActionsFrame.Position = UDim2.new(1, -62, 0, 0)
    windowActionsFrame.ZIndex = titleBar.ZIndex + 15
    windowActionsFrame.Parent = titleBar

    local actionLayout = Instance.new("UIListLayout")
    actionLayout.FillDirection = Enum.FillDirection.Horizontal
    actionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    actionLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    actionLayout.Padding = UDim.new(0, 4)
    actionLayout.Parent = windowActionsFrame

    local minButton = Instance.new("TextButton")
    minButton.Name = "MinimizeButton"
    minButton.AutoButtonColor = false
    minButton.BackgroundColor3 = self.CurrentTheme.SurfaceAlt
    minButton.BackgroundTransparency = 0.4
    minButton.Size = UDim2.fromOffset(24, 22)
    minButton.Font = Enum.Font.GothamBold
    minButton.TextSize = 12
    minButton.TextColor3 = self.CurrentTheme.TextMuted
    minButton.Text = "—"
    minButton.Parent = windowActionsFrame

    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 5)
    minCorner.Parent = minButton

    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.AutoButtonColor = false
    closeButton.BackgroundColor3 = self.CurrentTheme.SurfaceAlt
    closeButton.BackgroundTransparency = 0.4
    closeButton.Size = UDim2.fromOffset(24, 22)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 12
    closeButton.TextColor3 = self.CurrentTheme.TextMuted
    closeButton.Text = "✕"
    closeButton.Parent = windowActionsFrame

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 5)
    closeCorner.Parent = closeButton

    self:ApplyHoverHighlight(minButton, minButton, self.CurrentTheme.SurfaceAlt, self.CurrentTheme.Surface)
    self:ApplyHoverHighlight(closeButton, closeButton, self.CurrentTheme.SurfaceAlt, Color3.fromRGB(220, 60, 60))

    -- ── RESTORE PILL (MINIMIZED STATE) ───────────────────────────────────
    local restorePill = Instance.new("TextButton")
    restorePill.Name = "RestorePill"
    restorePill.AutoButtonColor = false
    restorePill.BackgroundColor3 = self.CurrentTheme.Surface
    restorePill.BackgroundTransparency = 0.15
    restorePill.BorderSizePixel = 0
    restorePill.Size = UDim2.fromOffset(145, 34)
    restorePill.Position = UDim2.new(0.5, -72, 0, 20)
    restorePill.Visible = false
    restorePill.ZIndex = 50000
    restorePill.Parent = screenGui
    self:RegisterThemeProperty(restorePill, "BackgroundColor3", "Surface")

    local pillCorner = Instance.new("UICorner")
    pillCorner.CornerRadius = UDim.new(0, 17)
    pillCorner.Parent = restorePill

    local pillStroke = Instance.new("UIStroke")
    pillStroke.Thickness = 1.5
    pillStroke.Color = self.CurrentTheme.Accent
    pillStroke.Transparency = 0.3
    pillStroke.Parent = restorePill
    self:RegisterThemeProperty(pillStroke, "Color", "Accent")

    local pillLogoHolder = Instance.new("Frame")
    pillLogoHolder.Name = "PillLogo"
    pillLogoHolder.BackgroundTransparency = 1
    pillLogoHolder.Size = UDim2.fromOffset(22, 22)
    pillLogoHolder.Position = UDim2.fromOffset(8, 6)
    pillLogoHolder.Parent = restorePill

    local pillLogoImg = Instance.new("ImageLabel")
    pillLogoImg.BackgroundTransparency = 1
    pillLogoImg.Size = UDim2.new(1, 0, 1, 0)
    pillLogoImg.Image = logoAsset
    pillLogoImg.ScaleType = Enum.ScaleType.Fit
    pillLogoImg.Parent = pillLogoHolder

    local pillText = Instance.new("TextLabel")
    pillText.BackgroundTransparency = 1
    pillText.Font = Enum.Font.GothamBold
    pillText.TextSize = 11.5
    pillText.TextColor3 = self.CurrentTheme.Highlight
    pillText.Text = titleText
    pillText.Position = UDim2.fromOffset(36, 0)
    pillText.Size = UDim2.new(1, -42, 1, 0)
    pillText.Parent = restorePill
    self:RegisterThemeProperty(pillText, "TextColor3", "Highlight")

    self:MakeDraggable(restorePill, restorePill)

    -- ── NAVIGATION & CONTENT HOSTS ───────────────────────────────────────
    local navigationHost = nil
    local contentContainer = nil

    if isHorizontal then
        navigationHost = Instance.new("ScrollingFrame")
        navigationHost.Name = "HorizontalNavigationBar"
        navigationHost.BackgroundColor3 = self.CurrentTheme.SurfaceAlt
        navigationHost.BackgroundTransparency = 0.45
        navigationHost.BorderSizePixel = 0
        navigationHost.ScrollBarThickness = 2
        navigationHost.ScrollBarImageColor3 = self.CurrentTheme.Accent
        navigationHost.ScrollingDirection = Enum.ScrollingDirection.X
        navigationHost.Size = UDim2.new(1, 0, 0, 36)
        navigationHost.Position = UDim2.new(0, 0, 0, 38)
        navigationHost.AutomaticCanvasSize = Enum.AutomaticSize.X
        navigationHost.CanvasSize = UDim2.fromOffset(0, 0)
        navigationHost.Parent = mainFrame
        self:RegisterThemeProperty(navigationHost, "BackgroundColor3", "SurfaceAlt")

        local navLayout = Instance.new("UIListLayout")
        navLayout.FillDirection = Enum.FillDirection.Horizontal
        navLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        navLayout.Padding = UDim.new(0, 6)
        navLayout.Parent = navigationHost

        local navPad = Instance.new("UIPadding")
        navPad.PaddingLeft = UDim.new(0, 8)
        navPad.PaddingRight = UDim.new(0, 8)
        navPad.Parent = navigationHost

        contentContainer = Instance.new("Frame")
        contentContainer.Name = "ContentContainer"
        contentContainer.BackgroundTransparency = 1
        contentContainer.Size = UDim2.new(1, 0, 1, -74)
        contentContainer.Position = UDim2.new(0, 0, 0, 74)
        contentContainer.Parent = mainFrame
    else
        navigationHost = Instance.new("ScrollingFrame")
        navigationHost.Name = "SidebarNavigationBar"
        navigationHost.BackgroundColor3 = self.CurrentTheme.SurfaceAlt
        navigationHost.BackgroundTransparency = 0.45
        navigationHost.BorderSizePixel = 0
        navigationHost.ScrollBarThickness = 2
        navigationHost.ScrollBarImageColor3 = self.CurrentTheme.Accent
        navigationHost.ScrollingDirection = Enum.ScrollingDirection.Y
        navigationHost.Size = UDim2.new(0, 160, 1, -38)
        navigationHost.Position = UDim2.new(0, 0, 0, 38)
        navigationHost.AutomaticCanvasSize = Enum.AutomaticSize.Y
        navigationHost.CanvasSize = UDim2.fromOffset(0, 0)
        navigationHost.Parent = mainFrame
        self:RegisterThemeProperty(navigationHost, "BackgroundColor3", "SurfaceAlt")

        local navLayout = Instance.new("UIListLayout")
        navLayout.FillDirection = Enum.FillDirection.Vertical
        navLayout.SortOrder = Enum.SortOrder.LayoutOrder
        navLayout.Padding = UDim.new(0, 4)
        navLayout.Parent = navigationHost

        local navPad = Instance.new("UIPadding")
        navPad.PaddingLeft = UDim.new(0, 6)
        navPad.PaddingRight = UDim.new(0, 6)
        navPad.PaddingTop = UDim.new(0, 6)
        navPad.PaddingBottom = UDim.new(0, 6)
        navPad.Parent = navigationHost

        contentContainer = Instance.new("Frame")
        contentContainer.Name = "ContentContainer"
        contentContainer.BackgroundTransparency = 1
        contentContainer.Size = UDim2.new(1, -160, 1, -38)
        contentContainer.Position = UDim2.new(0, 160, 0, 38)
        contentContainer.Parent = mainFrame
    end

    -- ── BREADCRUMB BAR ───────────────────────────────────────────────────
    local breadcrumbFrame = Instance.new("Frame")
    breadcrumbFrame.Name = "BreadcrumbHeader"
    breadcrumbFrame.BackgroundTransparency = 1
    breadcrumbFrame.Size = UDim2.new(1, -16, 0, 20)
    breadcrumbFrame.Position = UDim2.fromOffset(8, 4)
    breadcrumbFrame.Parent = contentContainer

    local breadcrumbLabel = Instance.new("TextLabel")
    breadcrumbLabel.Name = "PathLabel"
    breadcrumbLabel.BackgroundTransparency = 1
    breadcrumbLabel.Font = Enum.Font.GothamMedium
    breadcrumbLabel.TextSize = 10
    breadcrumbLabel.TextColor3 = self.CurrentTheme.TextMuted
    breadcrumbLabel.TextXAlignment = Enum.TextXAlignment.Left
    breadcrumbLabel.Text = "Dashboard"
    breadcrumbLabel.Size = UDim2.new(1, 0, 1, 0)
    breadcrumbLabel.Parent = breadcrumbFrame
    self:RegisterThemeProperty(breadcrumbLabel, "TextColor3", "TextMuted")

    local pageViewport = Instance.new("Frame")
    pageViewport.Name = "PageViewport"
    pageViewport.BackgroundTransparency = 1
    pageViewport.Size = UDim2.new(1, 0, 1, -24)
    pageViewport.Position = UDim2.fromOffset(0, 24)
    pageViewport.Parent = contentContainer

    -- Attach Camera-Shielded Dragging
    self:MakeDraggable(titleBar, mainFrame)

    -- ── CORNER RESIZE GRIP HANDLE (FIXED UISCALE JUMP BUG) ───────────────
    if isResizable then
        local resizeHandle = Instance.new("ImageButton")
        resizeHandle.Name = "ResizeGrip"
        resizeHandle.BackgroundTransparency = 1
        resizeHandle.Size = UDim2.fromOffset(16, 16)
        resizeHandle.Position = UDim2.new(1, -18, 1, -18)
        resizeHandle.Image = "rbxassetid://6031225818"
        resizeHandle.ImageColor3 = self.CurrentTheme.TextMuted
        resizeHandle.Rotation = 45
        resizeHandle.ZIndex = mainFrame.ZIndex + 20
        resizeHandle.Parent = mainFrame

        local isResizing = false
        local initialSizeOffset = Vector2.zero
        local startMousePos = Vector2.zero

        resizeHandle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                isResizing = true
                -- Baca murni dari offset frame sebelum terdistorsi UIScale
                initialSizeOffset = Vector2.new(mainFrame.Size.X.Offset, mainFrame.Size.Y.Offset)
                startMousePos = Vector2.new(input.Position.X, input.Position.Y)

                local moveConn, endConn
                moveConn = UserInputService.InputChanged:Connect(function(moveInput)
                    if not isResizing then return end
                    if moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch then
                        local activeScale = (uiScale and uiScale.Scale > 0) and uiScale.Scale or 1.0
                        -- Kompensasikan delta mouse dengan faktor UIScale
                        local delta = (Vector2.new(moveInput.Position.X, moveInput.Position.Y) - startMousePos) / activeScale
                        
                        -- Cek threshold pergerakan minimal agar tidak resize saat sekadar diklik biasa
                        if delta.Magnitude > 1 then
                            local targetW = math.clamp(initialSizeOffset.X + delta.X, 420, 1100)
                            local targetH = math.clamp(initialSizeOffset.Y + delta.Y, 280, 800)
                            mainFrame.Size = UDim2.fromOffset(targetW, targetH)
                        end
                    end
                end)

                endConn = UserInputService.InputEnded:Connect(function(endInput)
                    if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then
                        isResizing = false
                        if moveConn then moveConn:Disconnect() end
                        if endConn then endConn:Disconnect() end
                    end
                end)
            end
        end)
    end
    
    -- ── WINDOW CONTROLLER OBJECT & SMOOTH FADE-IN ────────────────────────
    local Window = {
        MainFrame = mainFrame,
        ScreenGui = screenGui,
        NavigationHost = navigationHost,
        ContentContainer = contentContainer,
        PageViewport = pageViewport,
        BreadcrumbLabel = breadcrumbLabel,
        IsHorizontal = isHorizontal,
        Categories = {},
        Tabs = {},
        ActiveTab = nil,
        IsOpen = true,
        IsMinimized = false
    }

    local isAnimatingState = false

    local winScale = Instance.new("UIScale")
    winScale.Name = "_WinScale"
    winScale.Scale = 0.88
    winScale.Parent = mainFrame

    -- Smooth Modal Fade-in & Spring Pop on Open
    mainFrame.BackgroundTransparency = 1
    self:Tween(winScale, { Scale = 1.0 }, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    self:Tween(mainFrame, { BackgroundTransparency = 0.12 }, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    function Window:SetState(openState)
        if isAnimatingState or openState == self.IsOpen then return end
        isAnimatingState = true
        self.IsOpen = openState

        if openState then
            restorePill.Visible = false
            mainFrame.Visible = true
            mainFrame.BackgroundTransparency = 1
            winScale.Scale = 0.88

            LouisHub:Tween(winScale, { Scale = 1.0 }, 0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            LouisHub:Tween(mainFrame, { BackgroundTransparency = 0.12 }, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function()
                isAnimatingState = false
            end)
        else
            LouisHub:Tween(winScale, { Scale = 0.88 }, 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            LouisHub:Tween(mainFrame, { BackgroundTransparency = 1 }, 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function()
                mainFrame.Visible = false
                restorePill.Visible = true
                restorePill.Size = UDim2.fromOffset(0, 0)

                LouisHub:Tween(restorePill, {
                    Size = UDim2.fromOffset(145, 34)
                }, 0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out, function()
                    isAnimatingState = false
                end)
            end)
        end
    end

    function Window:Toggle()
        self:SetState(not self.IsOpen)
    end

    function Window:UpdateBreadcrumb(categoryName, tabName, subTabName)
        local str = tostring(tabName or "Main")
        if categoryName and categoryName ~= "" and categoryName ~= "General" then
            str = categoryName .. " › " .. str
        end
        if subTabName and subTabName ~= "" and subTabName ~= "Default" then
            str = str .. " › " .. subTabName
        end
        breadcrumbLabel.Text = str
    end

    function Window:Destroy()
        pcall(function()
            screenGui:Destroy()
        end)
        if ActiveMainWindow == self then
            ActiveMainWindow = nil
        end
    end

    minButton.MouseButton1Click:Connect(function()
        Window:SetState(false)
    end)

    restorePill.MouseButton1Click:Connect(function()
        Window:SetState(true)
    end)

    closeButton.MouseButton1Click:Connect(function()
        LouisHub:Confirm({
            Title = "Unload Interface?",
            Content = "Are you sure you want to terminate and close Louis Hub? All active tasks and connections will be destroyed.",
            Icon = "warning",
            Buttons = {
                { Text = "Cancel", Variant = "neutral", Value = false },
                { Text = "Unload", Variant = "danger", Value = true, Callback = function()
                    Window:Destroy()
                end }
            }
        })
    end)

    local toggleConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == toggleKey then
            Window:Toggle()
        end
    end)
    self.RootJanitor:Add(toggleConnection)

    ActiveMainWindow = Window
    return Window
end

-- LOUIS HUB | PART 3C | continues in PART 4A

-- =====================================================================
-- SECTION 25: FONT MANAGER & HIERARCHY NAVIGATION ROUTER
-- =====================================================================
local RegisteredFontElements = {}

local FontPresets = {
    ["Gotham"]      = { Regular = Enum.Font.Gotham, Bold = Enum.Font.GothamBold, Medium = Enum.Font.GothamMedium },
    ["Montserrat"]  = { Regular = Enum.Font.Montserrat, Bold = Enum.Font.Montserrat, Medium = Enum.Font.Montserrat },
    ["Ubuntu"]      = { Regular = Enum.Font.Ubuntu, Bold = Enum.Font.Ubuntu, Medium = Enum.Font.Ubuntu },
    ["Roboto"]      = { Regular = Enum.Font.Roboto, Bold = Enum.Font.RobotoCondensed, Medium = Enum.Font.Roboto },
    ["SourceSans"]  = { Regular = Enum.Font.SourceSans, Bold = Enum.Font.SourceSansBold, Medium = Enum.Font.SourceSansSemibold },
    ["Highway"]     = { Regular = Enum.Font.Highway, Bold = Enum.Font.Highway, Medium = Enum.Font.Highway },
    ["SciFi"]       = { Regular = Enum.Font.SciFi, Bold = Enum.Font.SciFi, Medium = Enum.Font.SciFi },
    ["Oswald"]      = { Regular = Enum.Font.Oswald, Bold = Enum.Font.Oswald, Medium = Enum.Font.Oswald },
    ["Code"]        = { Regular = Enum.Font.Code, Bold = Enum.Font.Code, Medium = Enum.Font.Code },
    ["FredokaOne"]  = { Regular = Enum.Font.FredokaOne, Bold = Enum.Font.FredokaOne, Medium = Enum.Font.FredokaOne },
    ["Arial"]       = { Regular = Enum.Font.Arial, Bold = Enum.Font.ArialBold, Medium = Enum.Font.Arial }
}

LouisHub.FontPresets = FontPresets
LouisHub.ActiveFontName = "Gotham"
LouisHub.CurrentFont = FontPresets["Gotham"]

function LouisHub:RegisterFontElement(textInstance, weightCategory)
    if not textInstance or not (textInstance:IsA("TextLabel") or textInstance:IsA("TextButton") or textInstance:IsA("TextBox")) then
        return
    end

    local weight = weightCategory or "Regular"
    local entry = { Instance = textInstance, Weight = weight }
    table.insert(RegisteredFontElements, entry)

    textInstance.Destroying:Connect(function()
        local idx = table.find(RegisteredFontElements, entry)
        if idx then table.remove(RegisteredFontElements, idx) end
    end)

    if self.CurrentFont and self.CurrentFont[weight] then
        pcall(function()
            textInstance.Font = self.CurrentFont[weight]
        end)
    end
end

function LouisHub:SetFont(fontNameOrTable)
    local targetFont = nil
    local fontKey = nil

    if type(fontNameOrTable) == "string" and FontPresets[fontNameOrTable] then
        fontKey = fontNameOrTable
        targetFont = FontPresets[fontNameOrTable]
    elseif type(fontNameOrTable) == "table" and fontNameOrTable.Regular then
        fontKey = "Custom"
        targetFont = fontNameOrTable
    end

    if not targetFont then return false, "Font preset not found" end

    self.ActiveFontName = fontKey
    self.CurrentFont = targetFont

    for idx = #RegisteredFontElements, 1, -1 do
        local entry = RegisteredFontElements[idx]
        local inst = entry.Instance
        local weight = entry.Weight

        if inst and inst.Parent then
            local resolvedFont = targetFont[weight] or targetFont.Regular
            pcall(function()
                inst.Font = resolvedFont
            end)
        else
            table.remove(RegisteredFontElements, idx)
        end
    end

    return true
end

function LouisHub:GetFonts()
    local names = {}
    for name in pairs(FontPresets) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

-- Hook Window Creation for Navigation Hierarchy
local OriginalCreateWindow_3C = LouisHub.CreateWindow

function LouisHub:CreateWindow(windowConfig)
    local Window = OriginalCreateWindow_3C(self, windowConfig)

    local isHorizontal = Window.IsHorizontal
    local navigationHost = Window.NavigationHost
    local pageViewport = Window.PageViewport
    local allTabsList = {}
    local defaultCategory = nil

    local function deselectAllTabs()
        for _, tab in ipairs(allTabsList) do
            tab.PageFrame.Visible = false
            if tab.Indicator then
                LouisHub:Tween(tab.Indicator, { BackgroundTransparency = 1 }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
            if tab.Button then
                LouisHub:Tween(tab.Button, { BackgroundColor3 = LouisHub.CurrentTheme.SurfaceAlt }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
            if tab.TitleLabel then
                tab.TitleLabel.TextColor3 = LouisHub.CurrentTheme.TextMuted
            end
        end
    end

    -- ── SECTION CONSTRUCTOR ──────────────────────────────────────────────
    local function createSectionInstance(parentContainer, sectionConfig)
        sectionConfig = sectionConfig or {}
        local sectionTitle = tostring(sectionConfig.Title or sectionConfig.Name or "Section")
        local numColumns = tonumber(sectionConfig.Columns) or 1
        local isCollapsible = sectionConfig.Collapsible ~= false
        local isCollapsed = sectionConfig.Collapsed == true and isCollapsible

        local sectionCard = Instance.new("Frame")
        sectionCard.Name = "Section_" .. sectionTitle:gsub("%s+", "")
        sectionCard.BackgroundColor3 = LouisHub.CurrentTheme.Surface
        sectionCard.BackgroundTransparency = 0.35
        sectionCard.BorderSizePixel = 0
        sectionCard.ClipsDescendants = true
        sectionCard.Size = UDim2.new(1, 0, 0, 0)
        sectionCard.AutomaticSize = Enum.AutomaticSize.Y
        sectionCard.Parent = parentContainer
        LouisHub:RegisterThemeProperty(sectionCard, "BackgroundColor3", "Surface")

        local secCorner = Instance.new("UICorner")
        secCorner.CornerRadius = UDim.new(0, 8)
        secCorner.Parent = sectionCard

        local secStroke = Instance.new("UIStroke")
        secStroke.Thickness = 1
        secStroke.Color = LouisHub.CurrentTheme.Border
        secStroke.Transparency = 0.35
        secStroke.Parent = sectionCard
        LouisHub:RegisterThemeProperty(secStroke, "Color", "Border")

        local secLayout = Instance.new("UIListLayout")
        secLayout.SortOrder = Enum.SortOrder.LayoutOrder
        secLayout.Padding = UDim.new(0, 6)
        secLayout.Parent = sectionCard

        local secPadding = Instance.new("UIPadding")
        secPadding.PaddingLeft = UDim.new(0, 10)
        secPadding.PaddingRight = UDim.new(0, 10)
        secPadding.PaddingTop = UDim.new(0, 8)
        secPadding.PaddingBottom = UDim.new(0, 10)
        secPadding.Parent = sectionCard

        local headerButton = Instance.new("TextButton")
        headerButton.Name = "SectionHeader"
        headerButton.AutoButtonColor = false
        headerButton.BackgroundTransparency = 1
        headerButton.Size = UDim2.new(1, 0, 0, 20)
        headerButton.Text = ""
        headerButton.LayoutOrder = 1
        headerButton.Parent = sectionCard

        local headerIcon = nil
        local textOffsetX = 0

        if isCollapsible then
            headerIcon = Instance.new("ImageLabel")
            headerIcon.Name = "ArrowIcon"
            headerIcon.BackgroundTransparency = 1
            headerIcon.Size = UDim2.fromOffset(10, 10)
            headerIcon.Position = UDim2.new(0, 2, 0.5, -5)
            headerIcon.Image = "rbxassetid://6031090990"
            headerIcon.ImageColor3 = LouisHub.CurrentTheme.AccentAlt
            headerIcon.Rotation = isCollapsed and -90 or 0
            headerIcon.Parent = headerButton
            LouisHub:RegisterThemeProperty(headerIcon, "ImageColor3", "AccentAlt")
            textOffsetX = 16
        end

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "SectionTitle"
        titleLabel.BackgroundTransparency = 1
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextSize = 12
        titleLabel.TextColor3 = LouisHub.CurrentTheme.Highlight
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.Text = sectionTitle
        titleLabel.Position = UDim2.fromOffset(textOffsetX, 0)
        titleLabel.Size = UDim2.new(1, -textOffsetX, 1, 0)
        titleLabel.Parent = headerButton
        LouisHub:RegisterThemeProperty(titleLabel, "TextColor3", "Highlight")
        LouisHub:RegisterFontElement(titleLabel, "Bold")

        local bodyContainer = Instance.new("Frame")
        bodyContainer.Name = "SectionBody"
        bodyContainer.BackgroundTransparency = 1
        bodyContainer.Size = UDim2.new(1, 0, 0, 0)
        bodyContainer.AutomaticSize = Enum.AutomaticSize.Y
        bodyContainer.LayoutOrder = 2
        bodyContainer.Visible = not isCollapsed
        bodyContainer.Parent = sectionCard

        local col1Frame = nil
        local col2Frame = nil

        if numColumns == 2 then
            local colLayoutHost = Instance.new("Frame")
            colLayoutHost.Name = "ColumnHost"
            colLayoutHost.BackgroundTransparency = 1
            colLayoutHost.Size = UDim2.new(1, 0, 0, 0)
            colLayoutHost.AutomaticSize = Enum.AutomaticSize.Y
            colLayoutHost.Parent = bodyContainer

            col1Frame = Instance.new("Frame")
            col1Frame.Name = "Col1"
            col1Frame.BackgroundTransparency = 1
            col1Frame.Size = UDim2.new(0.5, -4, 0, 0)
            col1Frame.Position = UDim2.new(0, 0, 0, 0)
            col1Frame.AutomaticSize = Enum.AutomaticSize.Y
            col1Frame.Parent = colLayoutHost

            local l1 = Instance.new("UIListLayout")
            l1.SortOrder = Enum.SortOrder.LayoutOrder
            l1.Padding = UDim.new(0, 6)
            l1.Parent = col1Frame

            col2Frame = Instance.new("Frame")
            col2Frame.Name = "Col2"
            col2Frame.BackgroundTransparency = 1
            col2Frame.Size = UDim2.new(0.5, -4, 0, 0)
            col2Frame.Position = UDim2.new(0.5, 4, 0, 0)
            col2Frame.AutomaticSize = Enum.AutomaticSize.Y
            col2Frame.Parent = colLayoutHost

            local l2 = Instance.new("UIListLayout")
            l2.SortOrder = Enum.SortOrder.LayoutOrder
            l2.Padding = UDim.new(0, 6)
            l2.Parent = col2Frame
        else
            local singleLayout = Instance.new("UIListLayout")
            singleLayout.SortOrder = Enum.SortOrder.LayoutOrder
            singleLayout.Padding = UDim.new(0, 6)
            singleLayout.Parent = bodyContainer
        end

        local Section = {
            Card = sectionCard,
            Body = bodyContainer,
            Col1 = col1Frame,
            Col2 = col2Frame,
            NumColumns = numColumns,
            IsCollapsed = isCollapsed,
            _elementIndex = 0
        }

        function Section:ToggleCollapse(forceState)
            if not isCollapsible then return end
            if forceState ~= nil then
                self.IsCollapsed = (forceState == true)
            else
                self.IsCollapsed = not self.IsCollapsed
            end

            bodyContainer.Visible = not self.IsCollapsed
            if headerIcon then
                LouisHub:Tween(headerIcon, { Rotation = self.IsCollapsed and -90 or 0 }, 0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
        end

        if isCollapsible then
            headerButton.MouseButton1Click:Connect(function()
                Section:ToggleCollapse()
            end)
        end

        function Section:_GetTargetContainer(controlType, controlConfig)
            if self.NumColumns ~= 2 then return self.Body end

            if controlConfig and (controlConfig.Column == 1 or controlConfig.Col == 1) then
                return self.Col1
            elseif controlConfig and (controlConfig.Column == 2 or controlConfig.Col == 2) then
                return self.Col2
            end

            local wideTypes = {
                Slider = true, RangeSlider = true, Dropdown = true,
                ColorPicker = true, TagInput = true, Paragraph = true
            }

            if wideTypes[controlType] and not (controlConfig and (controlConfig.Column or controlConfig.Col)) then
                return self.Body
            end

            self._elementIndex = self._elementIndex + 1
            return (self._elementIndex % 2 == 1) and self.Col1 or self.Col2
        end

        return Section
    end

    -- ── SUB-TAB CONSTRUCTOR ──────────────────────────────────────────────
    local function createSubTabInstance(parentTab, subTabConfig)
        subTabConfig = subTabConfig or {}
        local subTabName = tostring(subTabConfig.Name or subTabConfig.Title or "Main")

        local subTabButton = Instance.new("TextButton")
        subTabButton.Name = "SubTabBtn_" .. subTabName:gsub("%s+", "")
        subTabButton.AutoButtonColor = false
        subTabButton.BackgroundColor3 = LouisHub.CurrentTheme.SurfaceAlt
        subTabButton.Size = UDim2.new(0, 72, 1, 0)
        subTabButton.AutomaticSize = Enum.AutomaticSize.X
        subTabButton.Font = Enum.Font.GothamMedium
        subTabButton.TextSize = 10.5
        subTabButton.TextColor3 = LouisHub.CurrentTheme.TextMuted
        subTabButton.Text = subTabName
        subTabButton.Parent = parentTab.SubTabBar
        LouisHub:RegisterFontElement(subTabButton, "Medium")

        local stbCorner = Instance.new("UICorner")
        stbCorner.CornerRadius = UDim.new(0, 5)
        stbCorner.Parent = subTabButton

        local stbPad = Instance.new("UIPadding")
        stbPad.PaddingLeft = UDim.new(0, 10)
        stbPad.PaddingRight = UDim.new(0, 10)
        stbPad.Parent = subTabButton

        local subPageScroll = Instance.new("ScrollingFrame")
        subPageScroll.Name = "SubPage_" .. subTabName:gsub("%s+", "")
        subPageScroll.BackgroundTransparency = 1
        subPageScroll.BorderSizePixel = 0
        subPageScroll.ScrollBarThickness = 2
        subPageScroll.ScrollBarImageColor3 = LouisHub.CurrentTheme.Accent
        subPageScroll.Size = UDim2.new(1, 0, 1, 0)
        subPageScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        subPageScroll.CanvasSize = UDim2.fromOffset(0, 0)
        subPageScroll.Visible = (#parentTab.SubTabsList == 0)
        subPageScroll.Parent = parentTab.SubPageContainer

        local subLayout = Instance.new("UIListLayout")
        subLayout.SortOrder = Enum.SortOrder.LayoutOrder
        subLayout.Padding = UDim.new(0, 8)
        subLayout.Parent = subPageScroll

        local subPadding = Instance.new("UIPadding")
        subPadding.PaddingLeft = UDim.new(0, 8)
        subPadding.PaddingRight = UDim.new(0, 8)
        subPadding.PaddingTop = UDim.new(0, 6)
        subPadding.PaddingBottom = UDim.new(0, 12)
        subPadding.Parent = subPageScroll

        local SubTab = {
            Name = subTabName,
            Button = subTabButton,
            Page = subPageScroll,
            Sections = {},
            ParentTab = parentTab
        }

        function SubTab:Select()
            for _, s in ipairs(parentTab.SubTabsList) do
                s.Page.Visible = false
                LouisHub:Tween(s.Button, { BackgroundColor3 = LouisHub.CurrentTheme.SurfaceAlt }, 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                s.Button.TextColor3 = LouisHub.CurrentTheme.TextMuted
            end

            self.Page.Visible = true
            LouisHub:Tween(self.Button, { BackgroundColor3 = LouisHub.CurrentTheme.Accent }, 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            self.Button.TextColor3 = Color3.fromRGB(255, 255, 255)

            Window:UpdateBreadcrumb(parentTab.CategoryName, parentTab.Name, self.Name)
        end

        subTabButton.MouseButton1Click:Connect(function()
            SubTab:Select()
        end)

        function SubTab:AddSection(secCfg)
            local sec = createSectionInstance(subPageScroll, secCfg)
            table.insert(self.Sections, sec)
            return sec
        end
        SubTab.CreateSection = SubTab.AddSection

        table.insert(parentTab.SubTabsList, SubTab)

        if #parentTab.SubTabsList >= 2 then
            parentTab.SubTabBar.Visible = true
            parentTab.SubPageContainer.Position = UDim2.new(0, 0, 0, 32)
            parentTab.SubPageContainer.Size = UDim2.new(1, 0, 1, -32)
        else
            parentTab.SubTabBar.Visible = false
            parentTab.SubPageContainer.Position = UDim2.new(0, 0, 0, 0)
            parentTab.SubPageContainer.Size = UDim2.new(1, 0, 1, 0)
        end

        return SubTab
    end

    -- ── TAB CONSTRUCTOR ──────────────────────────────────────────────────
    local function createTabInstance(targetNavContainer, tabConfig, categoryName)
        tabConfig = tabConfig or {}
        local tabName = tostring(tabConfig.Name or tabConfig.Title or "Tab")
        local tabIcon = tabConfig.Icon or "list"

        local tabButton = Instance.new("TextButton")
        tabButton.Name = "TabBtn_" .. tabName:gsub("%s+", "")
        tabButton.AutoButtonColor = false
        tabButton.BackgroundColor3 = LouisHub.CurrentTheme.SurfaceAlt
        tabButton.BackgroundTransparency = 0.5
        tabButton.Size = isHorizontal and UDim2.new(0, 80, 0, 26) or UDim2.new(1, 0, 0, 28)
        tabButton.AutomaticSize = isHorizontal and Enum.AutomaticSize.X or Enum.AutomaticSize.None
        tabButton.Text = ""
        tabButton.Parent = targetNavContainer

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = tabButton

        local iconHolder = Instance.new("Frame")
        iconHolder.Name = "IconHolder"
        iconHolder.BackgroundTransparency = 1
        iconHolder.Size = UDim2.fromOffset(16, 16)
        iconHolder.Position = UDim2.new(0, 8, 0.5, -8)
        iconHolder.Parent = tabButton

        LouisHub:MountIcon(iconHolder, tabIcon, 14, LouisHub.CurrentTheme.TextMuted)

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "TabLabel"
        titleLabel.BackgroundTransparency = 1
        titleLabel.Font = Enum.Font.GothamMedium
        titleLabel.TextSize = 11
        titleLabel.TextColor3 = LouisHub.CurrentTheme.TextMuted
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.Text = tabName
        titleLabel.Position = UDim2.fromOffset(28, 0)
        titleLabel.Size = isHorizontal and UDim2.new(0, 0, 1, 0) or UDim2.new(1, -32, 1, 0)
        titleLabel.AutomaticSize = isHorizontal and Enum.AutomaticSize.X or Enum.AutomaticSize.None
        titleLabel.Parent = tabButton
        LouisHub:RegisterFontElement(titleLabel, "Medium")

        if isHorizontal then
            local padH = Instance.new("UIPadding")
            padH.PaddingLeft = UDim.new(0, 6)
            padH.PaddingRight = UDim.new(0, 10)
            padH.Parent = tabButton
        end

        local activeIndicator = Instance.new("Frame")
        activeIndicator.Name = "ActiveIndicator"
        activeIndicator.BackgroundColor3 = LouisHub.CurrentTheme.Accent
        activeIndicator.BorderSizePixel = 0
        activeIndicator.BackgroundTransparency = 1
        activeIndicator.Parent = tabButton
        LouisHub:RegisterThemeProperty(activeIndicator, "BackgroundColor3", "Accent")

        local indGrad = Instance.new("UIGradient")
        indGrad.Parent = activeIndicator
        LouisHub:RegisterGradient(indGrad)

        if isHorizontal then
            activeIndicator.Size = UDim2.new(1, -12, 0, 2)
            activeIndicator.Position = UDim2.new(0, 6, 1, -2)
        else
            activeIndicator.Size = UDim2.new(0, 3, 1, -8)
            activeIndicator.Position = UDim2.new(0, 2, 0, 4)
            local indCorner = Instance.new("UICorner")
            indCorner.CornerRadius = UDim.new(0, 2)
            indCorner.Parent = activeIndicator
        end

        local pageFrame = Instance.new("Frame")
        pageFrame.Name = "Page_" .. tabName:gsub("%s+", "")
        pageFrame.BackgroundTransparency = 1
        pageFrame.Size = UDim2.new(1, 0, 1, 0)
        pageFrame.Visible = false
        pageFrame.Parent = pageViewport

        local subTabBar = Instance.new("Frame")
        subTabBar.Name = "SubTabBar"
        subTabBar.BackgroundTransparency = 1
        subTabBar.Size = UDim2.new(1, -16, 0, 26)
        subTabBar.Position = UDim2.fromOffset(8, 2)
        subTabBar.Visible = false
        subTabBar.Parent = pageFrame

        local stbLayout = Instance.new("UIListLayout")
        stbLayout.FillDirection = Enum.FillDirection.Horizontal
        stbLayout.Padding = UDim.new(0, 6)
        stbLayout.Parent = subTabBar

        local subPageContainer = Instance.new("Frame")
        subPageContainer.Name = "SubPageContainer"
        subPageContainer.BackgroundTransparency = 1
        subPageContainer.Size = UDim2.new(1, 0, 1, 0)
        subPageContainer.Position = UDim2.fromOffset(0, 0)
        subPageContainer.Parent = pageFrame

        local Tab = {
            Name = tabName,
            CategoryName = categoryName or "General",
            Button = tabButton,
            Indicator = activeIndicator,
            TitleLabel = titleLabel,
            PageFrame = pageFrame,
            SubTabBar = subTabBar,
            SubPageContainer = subPageContainer,
            SubTabsList = {}
        }

        function Tab:Select()
            deselectAllTabs()
            Window.ActiveTab = self

            self.PageFrame.Visible = true
            self.TitleLabel.TextColor3 = LouisHub.CurrentTheme.Highlight

            if not isHorizontal then
                LouisHub:Tween(self.Button, { BackgroundColor3 = LouisHub.CurrentTheme.Surface }, 0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
            LouisHub:Tween(self.Indicator, { BackgroundTransparency = 0 }, 0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

            if #self.SubTabsList > 0 then
                self.SubTabsList[1]:Select()
            else
                Window:UpdateBreadcrumb(self.CategoryName, self.Name, nil)
            end
        end

        tabButton.MouseButton1Click:Connect(function()
            Tab:Select()
        end)

        function Tab:AddSubTab(subCfg)
            return createSubTabInstance(self, subCfg)
        end
        Tab.CreateSubTab = Tab.AddSubTab

        function Tab:AddSection(secCfg)
            local defaultSub = self.SubTabsList[1]
            if not defaultSub then
                defaultSub = self:AddSubTab({ Name = "Main" })
            end
            return defaultSub:AddSection(secCfg)
        end
        Tab.CreateSection = Tab.AddSection

        table.insert(allTabsList, Tab)
        table.insert(Window.Tabs, Tab)

        if #allTabsList == 1 then
            Tab:Select()
        end

        return Tab
    end

    -- ── CATEGORY CONSTRUCTOR ─────────────────────────────────────────────
    function Window:AddCategory(categoryConfig)
        if type(categoryConfig) == "string" then
            categoryConfig = { Name = categoryConfig }
        end
        categoryConfig = categoryConfig or {}

        local catName = tostring(categoryConfig.Name or "General")
        local isCollapsible = categoryConfig.Collapsible ~= false
        local isCollapsed = categoryConfig.Collapsed == true and isCollapsible

        if isHorizontal then
            return {
                Name = catName,
                AddTab = function(_, tabCfg)
                    return createTabInstance(navigationHost, tabCfg, catName)
                end,
                CreateTab = function(selfCat, tabCfg)
                    return selfCat:AddTab(tabCfg)
                end
            }
        end

        local catFrame = Instance.new("Frame")
        catFrame.Name = "Category_" .. catName:gsub("%s+", "")
        catFrame.BackgroundTransparency = 1
        catFrame.Size = UDim2.new(1, 0, 0, 0)
        catFrame.AutomaticSize = Enum.AutomaticSize.Y
        catFrame.Parent = navigationHost

        local catLayout = Instance.new("UIListLayout")
        catLayout.SortOrder = Enum.SortOrder.LayoutOrder
        catLayout.Padding = UDim.new(0, 3)
        catLayout.Parent = catFrame

        local catHeaderBtn = Instance.new("TextButton")
        catHeaderBtn.Name = "CategoryHeader"
        catHeaderBtn.AutoButtonColor = false
        catHeaderBtn.BackgroundTransparency = 1
        catHeaderBtn.Size = UDim2.new(1, 0, 0, 20)
        catHeaderBtn.Text = ""
        catHeaderBtn.LayoutOrder = 1
        catHeaderBtn.Parent = catFrame

        local catArrow = nil
        if isCollapsible then
            catArrow = Instance.new("ImageLabel")
            catArrow.Name = "CatArrow"
            catArrow.BackgroundTransparency = 1
            catArrow.Size = UDim2.fromOffset(8, 8)
            catArrow.Position = UDim2.new(0, 4, 0.5, -4)
            catArrow.Image = "rbxassetid://6031090990"
            catArrow.ImageColor3 = LouisHub.CurrentTheme.TextMuted
            catArrow.Rotation = isCollapsed and -90 or 0
            catArrow.Parent = catHeaderBtn
        end

        local catLabel = Instance.new("TextLabel")
        catLabel.Name = "CatTitle"
        catLabel.BackgroundTransparency = 1
        catLabel.Font = Enum.Font.GothamBold
        catLabel.TextSize = 9.5
        catLabel.TextColor3 = LouisHub.CurrentTheme.AccentAlt
        catLabel.TextXAlignment = Enum.TextXAlignment.Left
        catLabel.Text = string.upper(catName)
        catLabel.Position = UDim2.fromOffset(isCollapsible and 16 or 4, 0)
        catLabel.Size = UDim2.new(1, -20, 1, 0)
        catLabel.Parent = catHeaderBtn
        LouisHub:RegisterThemeProperty(catLabel, "TextColor3", "AccentAlt")
        LouisHub:RegisterFontElement(catLabel, "Bold")

        local tabsContainer = Instance.new("Frame")
        tabsContainer.Name = "TabsHolder"
        tabsContainer.BackgroundTransparency = 1
        tabsContainer.Size = UDim2.new(1, 0, 0, 0)
        tabsContainer.AutomaticSize = Enum.AutomaticSize.Y
        tabsContainer.LayoutOrder = 2
        tabsContainer.Visible = not isCollapsed
        tabsContainer.Parent = catFrame

        local tcLayout = Instance.new("UIListLayout")
        tcLayout.SortOrder = Enum.SortOrder.LayoutOrder
        tcLayout.Padding = UDim.new(0, 3)
        tcLayout.Parent = tabsContainer

        local Category = {
            Name = catName,
            IsCollapsed = isCollapsed,
            Container = tabsContainer
        }

        function Category:ToggleCollapse(forceState)
            if not isCollapsible then return end
            if forceState ~= nil then
                self.IsCollapsed = (forceState == true)
            else
                self.IsCollapsed = not self.IsCollapsed
            end

            tabsContainer.Visible = not self.IsCollapsed
            if catArrow then
                LouisHub:Tween(catArrow, { Rotation = self.IsCollapsed and -90 or 0 }, 0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
        end

        if isCollapsible then
            catHeaderBtn.MouseButton1Click:Connect(function()
                Category:ToggleCollapse()
            end)
        end

        function Category:AddTab(tabCfg)
            return createTabInstance(tabsContainer, tabCfg, catName)
        end
        Category.CreateTab = Category.AddTab

        table.insert(Window.Categories, Category)
        return Category
    end
    Window.CreateCategory = Window.AddCategory

    function Window:AddTab(tabConfig)
        if not defaultCategory then
            defaultCategory = self:AddCategory({ Name = "General", Collapsible = false })
        end
        return defaultCategory:AddTab(tabConfig)
    end
    Window.CreateTab = Window.AddTab

    return Window
end

-- LOUIS HUB | PART 4A | continues in PART 4B

-- =====================================================================
-- SECTION 26: INTERACTIVE CONTROLS (BUTTONS, TOGGLES, SLIDERS)
-- =====================================================================
local SectionControls = {}

local function createBaseRow(parentContainer, titleText, descText, tooltipText, iconIdentifier, heightPixels, controlWidth)
    local rowHeight = heightPixels or 32
    local rightReserved = (controlWidth or 50) + 16
    local hasDesc = type(descText) == "string" and descText ~= ""

    local row = Instance.new("Frame")
    row.Name = "Row_" .. tostring(titleText):gsub("%s+", "")
    row.BackgroundColor3 = LouisHub.CurrentTheme.SurfaceAlt
    row.BackgroundTransparency = 0.45
    row.BorderSizePixel = 0
    row.Size = UDim2.new(1, 0, 0, hasDesc and (rowHeight + 14) or rowHeight)
    row.Parent = parentContainer
    LouisHub:RegisterThemeProperty(row, "BackgroundColor3", "SurfaceAlt")

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 7)
    rowCorner.Parent = row

    local rowStroke = Instance.new("UIStroke")
    rowStroke.Thickness = 1
    rowStroke.Color = LouisHub.CurrentTheme.Border
    rowStroke.Transparency = 0.35
    rowStroke.Parent = row
    LouisHub:RegisterThemeProperty(rowStroke, "Color", "Border")

    local textOffsetLeft = 8
    if iconIdentifier then
        local iconFrame = Instance.new("Frame")
        iconFrame.BackgroundTransparency = 1
        iconFrame.Size = UDim2.fromOffset(16, 16)
        iconFrame.Position = UDim2.new(0, 8, 0, hasDesc and 8 or math.floor((rowHeight - 16) / 2))
        iconFrame.Parent = row
        LouisHub:MountIcon(iconFrame, iconIdentifier, 14, LouisHub.CurrentTheme.Accent)
        textOffsetLeft = 28
    end

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamMedium
    titleLabel.TextSize = 11.5
    titleLabel.TextColor3 = LouisHub.CurrentTheme.Text
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    titleLabel.Text = tostring(titleText or "")
    titleLabel.Position = UDim2.new(0, textOffsetLeft, 0, hasDesc and 4 or 0)
    titleLabel.Size = UDim2.new(1, -textOffsetLeft - rightReserved, 0, hasDesc and 16 or rowHeight)
    titleLabel.Parent = row
    LouisHub:RegisterThemeProperty(titleLabel, "TextColor3", "Text")
    LouisHub:RegisterFontElement(titleLabel, "Medium")

    if hasDesc then
        local descLabel = Instance.new("TextLabel")
        descLabel.Name = "DescriptionLabel"
        descLabel.BackgroundTransparency = 1
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextSize = 9.5
        descLabel.TextColor3 = LouisHub.CurrentTheme.TextMuted
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextTruncate = Enum.TextTruncate.AtEnd
        descLabel.Text = descText
        descLabel.Position = UDim2.new(0, textOffsetLeft, 0, 20)
        descLabel.Size = UDim2.new(1, -textOffsetLeft - rightReserved, 0, 14)
        descLabel.Parent = row
        LouisHub:RegisterThemeProperty(descLabel, "TextColor3", "TextMuted")
        LouisHub:RegisterFontElement(descLabel, "Regular")
    end

    if tooltipText and tooltipText ~= "" then
        LouisHub:BindTooltip(row, tooltipText)
    end

    return row, titleLabel
end

-- ── 1. BUTTON CONTROL ────────────────────────────────────────────────
function SectionControls:AddButton(config)
    config = config or {}
    local btnName = tostring(config.Name or config.Title or "Button")
    local variant = config.Variant or "secondary"
    local callback = config.Callback
    local targetContainer = self:_GetTargetContainer("Button", config)

    local btnFrame = Instance.new("TextButton")
    btnFrame.Name = "Button_" .. btnName:gsub("%s+", "")
    btnFrame.AutoButtonColor = false
    btnFrame.Size = UDim2.new(1, 0, 0, 32)
    btnFrame.Text = ""
    btnFrame.Parent = targetContainer

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 6)
    bCorner.Parent = btnFrame

    local bStroke = Instance.new("UIStroke")
    bStroke.Thickness = 1
    bStroke.Transparency = 0.35
    bStroke.Parent = btnFrame

    local bGradient = nil
    if variant == "primary" then
        btnFrame.BackgroundColor3 = LouisHub.CurrentTheme.Accent
        bStroke.Color = LouisHub.CurrentTheme.AccentAlt
        bGradient = Instance.new("UIGradient")
        bGradient.Parent = btnFrame
        LouisHub:RegisterGradient(bGradient)
    elseif variant == "danger" then
        btnFrame.BackgroundColor3 = LouisHub.CurrentTheme.Error
        bStroke.Color = LouisHub.CurrentTheme.Error
    else
        btnFrame.BackgroundColor3 = LouisHub.CurrentTheme.SurfaceAlt
        btnFrame.BackgroundTransparency = 0.4
        bStroke.Color = LouisHub.CurrentTheme.Border
        LouisHub:RegisterThemeProperty(btnFrame, "BackgroundColor3", "SurfaceAlt")
        LouisHub:RegisterThemeProperty(bStroke, "Color", "Border")
    end

    local contentHolder = Instance.new("Frame")
    contentHolder.Name = "CenterContent"
    contentHolder.BackgroundTransparency = 1
    contentHolder.Size = UDim2.new(1, -16, 1, 0)
    contentHolder.Position = UDim2.fromOffset(8, 0)
    contentHolder.Parent = btnFrame

    local cLayout = Instance.new("UIListLayout")
    cLayout.FillDirection = Enum.FillDirection.Horizontal
    cLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    cLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    cLayout.Padding = UDim.new(0, 6)
    cLayout.Parent = contentHolder

    if config.Icon then
        local icoHolder = Instance.new("Frame")
        icoHolder.BackgroundTransparency = 1
        icoHolder.Size = UDim2.fromOffset(16, 16)
        icoHolder.Parent = contentHolder
        LouisHub:MountIcon(icoHolder, config.Icon, 14, Color3.fromRGB(255, 255, 255))
    end

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "BtnText"
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamMedium
    titleLabel.TextSize = 11.5
    titleLabel.TextColor3 = (variant == "secondary") and LouisHub.CurrentTheme.Text or Color3.fromRGB(255, 255, 255)
    titleLabel.Text = btnName
    titleLabel.AutomaticSize = Enum.AutomaticSize.X
    titleLabel.Size = UDim2.new(0, 0, 1, 0)
    titleLabel.Parent = contentHolder
    LouisHub:RegisterFontElement(titleLabel, "Medium")

    if config.Tooltip then
        LouisHub:BindTooltip(btnFrame, config.Tooltip)
    end

    local isLoading = false
    local isDisabled = config.Disabled == true

    local function triggerClick()
        if isDisabled or isLoading then return end
        LouisHub:ApplyPressAnimation(btnFrame, 0.92)

        if type(callback) == "function" then
            local success, err = pcall(callback)
            if not success then
                LouisHub:Log("ButtonCallback", err)
            end
        end
    end

    btnFrame.MouseButton1Click:Connect(triggerClick)
    LouisHub:ApplyHoverHighlight(btnFrame, btnFrame, btnFrame.BackgroundColor3, LouisHub.CurrentTheme.Surface)

    local ButtonControl = {
        Instance = btnFrame,
        SetText = function(_, newText)
            titleLabel.Text = tostring(newText)
        end,
        SetDisabled = function(_, disabled)
            isDisabled = (disabled == true)
            btnFrame.Active = not isDisabled
            btnFrame.AutoButtonColor = not isDisabled
            btnFrame.BackgroundTransparency = isDisabled and 0.75 or 0.4
        end,
        SetLoading = function(_, loading)
            isLoading = (loading == true)
            titleLabel.Text = isLoading and "Loading..." or btnName
        end,
        SetVisible = function(_, visible)
            btnFrame.Visible = (visible == true)
        end,
        Destroy = function()
            pcall(function() btnFrame:Destroy() end)
        end
    }

    if config.VisibleIf then
        LouisHub:RegisterConditional(ButtonControl, config.VisibleIf, "Visible")
    end
    if config.EnabledIf then
        LouisHub:RegisterConditional(ButtonControl, config.EnabledIf, "Enabled")
    end

    return ButtonControl
end
SectionControls.CreateButton = SectionControls.AddButton

-- ── 2. TOGGLE CONTROL ────────────────────────────────────────────────
function SectionControls:AddToggle(config)
    config = config or {}
    local toggleName = tostring(config.Name or config.Title or "Toggle")
    local flagKey = config.Flag or ("Toggle_" .. toggleName:gsub("%s+", ""))
    local currentValue = config.Default == true
    local callback = config.Callback
    local isDisabled = config.Disabled == true

    local targetContainer = self:_GetTargetContainer("Toggle", config)
    local row = createBaseRow(targetContainer, toggleName, config.Description, config.Tooltip, config.Icon, 32, 40)

    local switchTrack = Instance.new("TextButton")
    switchTrack.Name = "SwitchTrack"
    switchTrack.AutoButtonColor = false
    switchTrack.BackgroundColor3 = currentValue and LouisHub.CurrentTheme.Accent or LouisHub.CurrentTheme.Surface
    switchTrack.BorderSizePixel = 0
    switchTrack.Size = UDim2.fromOffset(38, 20)
    switchTrack.Position = UDim2.new(1, -46, 0.5, -10)
    switchTrack.Text = ""
    switchTrack.Parent = row

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(0, 10)
    trackCorner.Parent = switchTrack

    local trackGradient = Instance.new("UIGradient")
    trackGradient.Enabled = currentValue
    trackGradient.Parent = switchTrack
    LouisHub:RegisterGradient(trackGradient)

    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Size = UDim2.fromOffset(16, 16)
    knob.Position = currentValue and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2)
    knob.Parent = switchTrack

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(0, 8)
    knobCorner.Parent = knob

    local function applyVisual(state)
        trackGradient.Enabled = state
        local targetColor = state and LouisHub.CurrentTheme.Accent or LouisHub.CurrentTheme.Surface
        local targetKnobPos = state and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2)

        LouisHub:Tween(switchTrack, { BackgroundColor3 = targetColor }, 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        LouisHub:Tween(knob, { Position = targetKnobPos }, 0.26, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
    end

    local function setToggleState(newState, silent)
        if isDisabled and newState ~= currentValue then return end
        currentValue = (newState == true)
        applyVisual(currentValue)
        LouisHub.Flags[flagKey] = currentValue

        if not silent and type(callback) == "function" then
            local success, err = pcall(callback, currentValue)
            if not success then LouisHub:Log("ToggleCallback", err) end
        end
    end

    local function toggleAction()
        if isDisabled then return end
        LouisHub:ApplyPressAnimation(knob, 0.88)
        setToggleState(not currentValue, false)
    end

    switchTrack.MouseButton1Click:Connect(toggleAction)
    row.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            toggleAction()
        end
    end)

    LouisHub.Flags[flagKey] = currentValue

    local ToggleControl = {
        Instance = row,
        Get = function()
            return currentValue
        end,
        Set = function(_, val, silent)
            setToggleState(val, silent)
        end,
        SetDisabled = function(_, disabled)
            isDisabled = (disabled == true)
            row.BackgroundTransparency = isDisabled and 0.8 or 0.45
            switchTrack.Active = not isDisabled
        end,
        SetVisible = function(_, visible)
            row.Visible = (visible == true)
        end,
        Destroy = function()
            LouisHub.Elements[flagKey] = nil
            pcall(function() row:Destroy() end)
        end
    }

    LouisHub.Elements[flagKey] = ToggleControl

    if config.VisibleIf then
        LouisHub:RegisterConditional(ToggleControl, config.VisibleIf, "Visible")
    end
    if config.EnabledIf then
        LouisHub:RegisterConditional(ToggleControl, config.EnabledIf, "Enabled")
    end

    return ToggleControl
end
SectionControls.CreateToggle = SectionControls.AddToggle

-- ── 3. CHECKBOX CONTROL ──────────────────────────────────────────────
function SectionControls:AddCheckbox(config)
    config = config or {}
    local boxName = tostring(config.Name or config.Title or "Checkbox")
    local flagKey = config.Flag or ("Checkbox_" .. boxName:gsub("%s+", ""))
    local currentValue = config.Default == true
    local callback = config.Callback
    local isDisabled = config.Disabled == true

    local targetContainer = self:_GetTargetContainer("Checkbox", config)
    local row = createBaseRow(targetContainer, boxName, config.Description, config.Tooltip, config.Icon, 32, 24)

    local boxButton = Instance.new("TextButton")
    boxButton.Name = "BoxButton"
    boxButton.AutoButtonColor = false
    boxButton.BackgroundColor3 = currentValue and LouisHub.CurrentTheme.Accent or LouisHub.CurrentTheme.Surface
    boxButton.BorderSizePixel = 0
    boxButton.Size = UDim2.fromOffset(20, 20)
    boxButton.Position = UDim2.new(1, -28, 0.5, -10)
    boxButton.Text = ""
    boxButton.Parent = row

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 5)
    bCorner.Parent = boxButton

    local bStroke = Instance.new("UIStroke")
    bStroke.Thickness = 1
    bStroke.Color = LouisHub.CurrentTheme.Border
    bStroke.Transparency = 0.3
    bStroke.Parent = boxButton
    LouisHub:RegisterThemeProperty(bStroke, "Color", "Border")

    local checkmark = Instance.new("ImageLabel")
    checkmark.Name = "Checkmark"
    checkmark.BackgroundTransparency = 1
    checkmark.Size = UDim2.fromOffset(14, 14)
    checkmark.Position = UDim2.fromOffset(3, 3)
    checkmark.Image = "rbxassetid://6031094667"
    checkmark.ImageColor3 = Color3.fromRGB(255, 255, 255)
    checkmark.ImageTransparency = currentValue and 0 or 1
    checkmark.Parent = boxButton

    local function applyVisual(state)
        local targetColor = state and LouisHub.CurrentTheme.Accent or LouisHub.CurrentTheme.Surface
        LouisHub:Tween(boxButton, { BackgroundColor3 = targetColor }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        LouisHub:Tween(checkmark, { ImageTransparency = state and 0 or 1 }, 0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    end

    local function setCheckboxState(newState, silent)
        if isDisabled and newState ~= currentValue then return end
        currentValue = (newState == true)
        applyVisual(currentValue)
        LouisHub.Flags[flagKey] = currentValue

        if not silent and type(callback) == "function" then
            local success, err = pcall(callback, currentValue)
            if not success then LouisHub:Log("CheckboxCallback", err) end
        end
    end

    local function toggleAction()
        if isDisabled then return end
        LouisHub:ApplyPressAnimation(boxButton, 0.90)
        setCheckboxState(not currentValue, false)
    end

    boxButton.MouseButton1Click:Connect(toggleAction)
    row.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            toggleAction()
        end
    end)

    LouisHub.Flags[flagKey] = currentValue

    local CheckboxControl = {
        Instance = row,
        Get = function()
            return currentValue
        end,
        Set = function(_, val, silent)
            setCheckboxState(val, silent)
        end,
        SetDisabled = function(_, disabled)
            isDisabled = (disabled == true)
            row.BackgroundTransparency = isDisabled and 0.8 or 0.45
            boxButton.Active = not isDisabled
        end,
        SetVisible = function(_, visible)
            row.Visible = (visible == true)
        end,
        Destroy = function()
            LouisHub.Elements[flagKey] = nil
            pcall(function() row:Destroy() end)
        end
    }

    LouisHub.Elements[flagKey] = CheckboxControl

    if config.VisibleIf then
        LouisHub:RegisterConditional(CheckboxControl, config.VisibleIf, "Visible")
    end
    if config.EnabledIf then
        LouisHub:RegisterConditional(CheckboxControl, config.EnabledIf, "Enabled")
    end

    return CheckboxControl
end
SectionControls.CreateCheckbox = SectionControls.AddCheckbox

-- ── 4. PRECISION SLIDER CONTROL ──────────────────────────────────────
function SectionControls:AddSlider(config)
    config = config or {}
    local sliderName = tostring(config.Name or config.Title or "Slider")
    local flagKey = config.Flag or ("Slider_" .. sliderName:gsub("%s+", ""))
    local minVal = tonumber(config.Min) or 0
    local maxVal = tonumber(config.Max) or 100
    if minVal >= maxVal then maxVal = minVal + 1 end

    local stepVal = tonumber(config.Step or config.Increment) or 1
    local suffixStr = tostring(config.Suffix or "")
    local rawDefault = tonumber(config.Default) or minVal
    local currentValue = math.clamp(rawDefault, minVal, maxVal)
    local callback = config.Callback
    local isDisabled = config.Disabled == true

    local targetContainer = self:_GetTargetContainer("Slider", config)

    local row = Instance.new("Frame")
    row.Name = "SliderRow_" .. sliderName:gsub("%s+", "")
    row.BackgroundColor3 = LouisHub.CurrentTheme.SurfaceAlt
    row.BackgroundTransparency = 0.45
    row.BorderSizePixel = 0
    row.Size = UDim2.new(1, 0, 0, 46)
    row.Parent = targetContainer
    LouisHub:RegisterThemeProperty(row, "BackgroundColor3", "SurfaceAlt")

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 7)
    rowCorner.Parent = row

    local rowStroke = Instance.new("UIStroke")
    rowStroke.Thickness = 1
    rowStroke.Color = LouisHub.CurrentTheme.Border
    rowStroke.Transparency = 0.35
    rowStroke.Parent = row
    LouisHub:RegisterThemeProperty(rowStroke, "Color", "Border")

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "SliderTitle"
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamMedium
    titleLabel.TextSize = 11.5
    titleLabel.TextColor3 = LouisHub.CurrentTheme.Text
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = sliderName
    titleLabel.Position = UDim2.fromOffset(8, 4)
    titleLabel.Size = UDim2.new(1, -94, 0, 16)
    titleLabel.Parent = row
    LouisHub:RegisterThemeProperty(titleLabel, "TextColor3", "Text")
    LouisHub:RegisterFontElement(titleLabel, "Medium")

    local valueInputBox = Instance.new("TextBox")
    valueInputBox.Name = "ValueInputBox"
    valueInputBox.BackgroundColor3 = LouisHub.CurrentTheme.Surface
    valueInputBox.BackgroundTransparency = 0.4
    valueInputBox.BorderSizePixel = 0
    valueInputBox.Font = Enum.Font.GothamBold
    valueInputBox.TextSize = 10.5
    valueInputBox.TextColor3 = LouisHub.CurrentTheme.Highlight
    valueInputBox.TextXAlignment = Enum.TextXAlignment.Right
    valueInputBox.Size = UDim2.fromOffset(72, 18)
    valueInputBox.Position = UDim2.new(1, -80, 0, 4)
    valueInputBox.ClearTextOnFocus = false
    valueInputBox.Parent = row
    LouisHub:RegisterThemeProperty(valueInputBox, "BackgroundColor3", "Surface")
    LouisHub:RegisterThemeProperty(valueInputBox, "TextColor3", "Highlight")
    LouisHub:RegisterFontElement(valueInputBox, "Bold")

    local vibCorner = Instance.new("UICorner")
    vibCorner.CornerRadius = UDim.new(0, 4)
    vibCorner.Parent = valueInputBox

    local vibPad = Instance.new("UIPadding")
    vibPad.PaddingRight = UDim.new(0, 6)
    vibPad.Parent = valueInputBox

    local trackFrame = Instance.new("Frame")
    trackFrame.Name = "Track"
    trackFrame.BackgroundColor3 = LouisHub.CurrentTheme.Surface
    trackFrame.BorderSizePixel = 0
    trackFrame.Size = UDim2.new(1, -16, 0, 6)
    trackFrame.Position = UDim2.fromOffset(8, 30)
    trackFrame.Parent = row
    LouisHub:RegisterThemeProperty(trackFrame, "BackgroundColor3", "Surface")

    local trCorner = Instance.new("UICorner")
    trCorner.CornerRadius = UDim.new(0, 3)
    trCorner.Parent = trackFrame

    local fillBar = Instance.new("Frame")
    fillBar.Name = "Fill"
    fillBar.BackgroundColor3 = LouisHub.CurrentTheme.Accent
    fillBar.BorderSizePixel = 0
    fillBar.Size = UDim2.new(0, 0, 1, 0)
    fillBar.Parent = trackFrame
    LouisHub:RegisterThemeProperty(fillBar, "BackgroundColor3", "Accent")

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 3)
    fillCorner.Parent = fillBar

    local fillGrad = Instance.new("UIGradient")
    fillGrad.Parent = fillBar
    LouisHub:RegisterGradient(fillGrad)

    local handleThumb = Instance.new("Frame")
    handleThumb.Name = "Handle"
    handleThumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    handleThumb.BorderSizePixel = 0
    handleThumb.Size = UDim2.fromOffset(13, 13)
    handleThumb.AnchorPoint = Vector2.new(0.5, 0.5)
    handleThumb.Position = UDim2.new(0, 0, 0.5, 0)
    handleThumb.Parent = trackFrame

    local htCorner = Instance.new("UICorner")
    htCorner.CornerRadius = UDim.new(0, 7)
    htCorner.Parent = handleThumb

    local function roundToStep(val)
        local factor = 1 / stepVal
        return math.clamp(math.floor((val - minVal) * factor + 0.5) / factor + minVal, minVal, maxVal)
    end

    local function updateVisual(val)
        local rel = math.clamp((val - minVal) / (maxVal - minVal), 0, 1)
        fillBar.Size = UDim2.new(rel, 0, 1, 0)
        handleThumb.Position = UDim2.new(rel, 0, 0.5, 0)
        valueInputBox.Text = tostring(val) .. suffixStr
    end

    local function setValue(newVal, silent)
        if isDisabled then return end
        local rounded = roundToStep(newVal)
        currentValue = rounded
        updateVisual(rounded)
        LouisHub.Flags[flagKey] = rounded

        if not silent and type(callback) == "function" then
            local success, err = pcall(callback, rounded)
            if not success then LouisHub:Log("SliderCallback", err) end
        end
    end

    local isDragging = false
    local function calculateInputRatio(inputX)
        local absPos = trackFrame.AbsolutePosition.X
        local absSize = trackFrame.AbsoluteSize.X
        local ratio = math.clamp((inputX - absPos) / absSize, 0, 1)
        local targetVal = minVal + (ratio * (maxVal - minVal))
        setValue(targetVal, false)
    end

    trackFrame.InputBegan:Connect(function(input)
        if isDisabled then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            LouisHub:Tween(handleThumb, { Size = UDim2.fromOffset(16, 16) }, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            calculateInputRatio(input.Position.X)

            local moveConn, endConn
            moveConn = UserInputService.InputChanged:Connect(function(moveInput)
                if not isDragging then return end
                if moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch then
                    calculateInputRatio(moveInput.Position.X)
                end
            end)

            endConn = UserInputService.InputEnded:Connect(function(endInput)
                if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then
                    isDragging = false
                    LouisHub:Tween(handleThumb, { Size = UDim2.fromOffset(13, 13) }, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                    if moveConn then moveConn:Disconnect() end
                    if endConn then endConn:Disconnect() end
                end
            end)
        end
    end)

    valueInputBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            local cleanStr = valueInputBox.Text:gsub("[^%d%.%-]", "")
            local parsed = tonumber(cleanStr)
            if parsed then
                setValue(parsed, false)
                LouisHub:ApplyFlashFeedback(valueInputBox, true)
            else
                updateVisual(currentValue)
                LouisHub:ApplyFlashFeedback(valueInputBox, false)
            end
        else
            updateVisual(currentValue)
        end
    end)

    if config.Tooltip then
        LouisHub:BindTooltip(row, config.Tooltip)
    end

    setValue(currentValue, true)

    local SliderControl = {
        Instance = row,
        Get = function()
            return currentValue
        end,
        Set = function(_, val, silent)
            setValue(tonumber(val) or minVal, silent)
        end,
        SetDisabled = function(_, disabled)
            isDisabled = (disabled == true)
            row.BackgroundTransparency = isDisabled and 0.8 or 0.45
            valueInputBox.Active = not isDisabled
        end,
        SetVisible = function(_, visible)
            row.Visible = (visible == true)
        end,
        Destroy = function()
            LouisHub.Elements[flagKey] = nil
            pcall(function() row:Destroy() end)
        end
    }

    LouisHub.Elements[flagKey] = SliderControl

    if config.VisibleIf then
        LouisHub:RegisterConditional(SliderControl, config.VisibleIf, "Visible")
    end
    if config.EnabledIf then
        LouisHub:RegisterConditional(SliderControl, config.EnabledIf, "Enabled")
    end

    return SliderControl
end
SectionControls.CreateSlider = SectionControls.AddSlider

-- ── 5. DUAL-HANDLE RANGE SLIDER ──────────────────────────────────────
function SectionControls:AddRangeSlider(config)
    config = config or {}
    local sliderName = tostring(config.Name or config.Title or "Range Slider")
    local flagKey = config.Flag or ("RangeSlider_" .. sliderName:gsub("%s+", ""))
    local minBound = tonumber(config.Min) or 0
    local maxBound = tonumber(config.Max) or 100
    if minBound >= maxBound then maxBound = minBound + 1 end

    local stepVal = tonumber(config.Step or config.Increment) or 1
    local suffixStr = tostring(config.Suffix or "")

    local defaultRange = config.Default or { Min = minBound, Max = maxBound }
    local currentMin = math.clamp(tonumber(defaultRange.Min) or minBound, minBound, maxBound)
    local currentMax = math.clamp(tonumber(defaultRange.Max) or maxBound, minBound, maxBound)
    if currentMin > currentMax then currentMin, currentMax = currentMax, currentMin end

    local callback = config.Callback
    local isDisabled = config.Disabled == true

    local targetContainer = self:_GetTargetContainer("RangeSlider", config)

    local row = Instance.new("Frame")
    row.Name = "RangeRow_" .. sliderName:gsub("%s+", "")
    row.BackgroundColor3 = LouisHub.CurrentTheme.SurfaceAlt
    row.BackgroundTransparency = 0.45
    row.BorderSizePixel = 0
    row.Size = UDim2.new(1, 0, 0, 46)
    row.Parent = targetContainer
    LouisHub:RegisterThemeProperty(row, "BackgroundColor3", "SurfaceAlt")

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 7)
    rowCorner.Parent = row

    local rowStroke = Instance.new("UIStroke")
    rowStroke.Thickness = 1
    rowStroke.Color = LouisHub.CurrentTheme.Border
    rowStroke.Transparency = 0.35
    rowStroke.Parent = row
    LouisHub:RegisterThemeProperty(rowStroke, "Color", "Border")

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamMedium
    titleLabel.TextSize = 11.5
    titleLabel.TextColor3 = LouisHub.CurrentTheme.Text
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = sliderName
    titleLabel.Position = UDim2.fromOffset(8, 4)
    titleLabel.Size = UDim2.new(1, -120, 0, 16)
    titleLabel.Parent = row
    LouisHub:RegisterThemeProperty(titleLabel, "TextColor3", "Text")
    LouisHub:RegisterFontElement(titleLabel, "Medium")

    local displayLabel = Instance.new("TextLabel")
    displayLabel.Name = "RangeDisplay"
    displayLabel.BackgroundTransparency = 1
    displayLabel.Font = Enum.Font.GothamBold
    displayLabel.TextSize = 10.5
    displayLabel.TextColor3 = LouisHub.CurrentTheme.Highlight
    displayLabel.TextXAlignment = Enum.TextXAlignment.Right
    displayLabel.Size = UDim2.fromOffset(106, 16)
    displayLabel.Position = UDim2.new(1, -114, 0, 4)
    displayLabel.Parent = row
    LouisHub:RegisterThemeProperty(displayLabel, "TextColor3", "Highlight")
    LouisHub:RegisterFontElement(displayLabel, "Bold")

    local trackFrame = Instance.new("Frame")
    trackFrame.Name = "Track"
    trackFrame.BackgroundColor3 = LouisHub.CurrentTheme.Surface
    trackFrame.BorderSizePixel = 0
    trackFrame.Size = UDim2.new(1, -16, 0, 6)
    trackFrame.Position = UDim2.fromOffset(8, 30)
    trackFrame.Parent = row
    LouisHub:RegisterThemeProperty(trackFrame, "BackgroundColor3", "Surface")

    local trCorner = Instance.new("UICorner")
    trCorner.CornerRadius = UDim.new(0, 3)
    trCorner.Parent = trackFrame

    local fillSpan = Instance.new("Frame")
    fillSpan.Name = "SpanFill"
    fillSpan.BackgroundColor3 = LouisHub.CurrentTheme.Accent
    fillSpan.BorderSizePixel = 0
    fillSpan.Parent = trackFrame
    LouisHub:RegisterThemeProperty(fillSpan, "BackgroundColor3", "Accent")

    local fsGrad = Instance.new("UIGradient")
    fsGrad.Parent = fillSpan
    LouisHub:RegisterGradient(fsGrad)

    local handleMin = Instance.new("Frame")
    handleMin.Name = "HandleMin"
    handleMin.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    handleMin.BorderSizePixel = 0
    handleMin.Size = UDim2.fromOffset(13, 13)
    handleMin.AnchorPoint = Vector2.new(0.5, 0.5)
    handleMin.Position = UDim2.new(0, 0, 0.5, 0)
    handleMin.Parent = trackFrame

    local hmCorner = Instance.new("UICorner")
    hmCorner.CornerRadius = UDim.new(0, 7)
    hmCorner.Parent = handleMin

    local handleMax = Instance.new("Frame")
    handleMax.Name = "HandleMax"
    handleMax.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    handleMax.BorderSizePixel = 0
    handleMax.Size = UDim2.fromOffset(13, 13)
    handleMax.AnchorPoint = Vector2.new(0.5, 0.5)
    handleMax.Position = UDim2.new(1, 0, 0.5, 0)
    handleMax.Parent = trackFrame

    local hmxCorner = Instance.new("UICorner")
    hmxCorner.CornerRadius = UDim.new(0, 7)
    hmxCorner.Parent = handleMax

    local function roundToStep(val)
        local factor = 1 / stepVal
        return math.clamp(math.floor((val - minBound) * factor + 0.5) / factor + minBound, minBound, maxBound)
    end

    local function updateVisual(lo, hi)
        local rangeDiff = maxBound - minBound
        local relLo = math.clamp((lo - minBound) / rangeDiff, 0, 1)
        local relHi = math.clamp((hi - minBound) / rangeDiff, 0, 1)

        fillSpan.Position = UDim2.new(relLo, 0, 0, 0)
        fillSpan.Size = UDim2.new(relHi - relLo, 0, 1, 0)

        handleMin.Position = UDim2.new(relLo, 0, 0.5, 0)
        handleMax.Position = UDim2.new(relHi, 0, 0.5, 0)

        displayLabel.Text = tostring(lo) .. suffixStr .. " - " .. tostring(hi) .. suffixStr
    end

    local function setRange(lo, hi, silent)
        if isDisabled then return end
        local rLo = roundToStep(lo)
        local rHi = roundToStep(hi)
        if rLo > rHi then rLo, rHi = rHi, rLo end

        currentMin = rLo
        currentMax = rHi
        updateVisual(rLo, rHi)

        local resultTable = { Min = rLo, Max = rHi }
        LouisHub.Flags[flagKey] = resultTable

        if not silent and type(callback) == "function" then
            local success, err = pcall(callback, resultTable)
            if not success then LouisHub:Log("RangeSliderCallback", err) end
        end
    end

    local activeHandle = nil
    local function calculateRatio(inputX)
        local absPos = trackFrame.AbsolutePosition.X
        local absSize = trackFrame.AbsoluteSize.X
        local ratio = math.clamp((inputX - absPos) / absSize, 0, 1)
        local val = minBound + (ratio * (maxBound - minBound))

        if activeHandle == "Min" then
            setRange(math.min(val, currentMax), currentMax, false)
        elseif activeHandle == "Max" then
            setRange(currentMin, math.max(val, currentMin), false)
        end
    end

    trackFrame.InputBegan:Connect(function(input)
        if isDisabled then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local absPos = trackFrame.AbsolutePosition.X
            local absSize = trackFrame.AbsoluteSize.X
            local ratio = math.clamp((input.Position.X - absPos) / absSize, 0, 1)
            local tapVal = minBound + (ratio * (maxBound - minBound))

            local distMin = math.abs(tapVal - currentMin)
            local distMax = math.abs(tapVal - currentMax)
            activeHandle = (distMin <= distMax) and "Min" or "Max"

            calculateRatio(input.Position.X)

            local moveConn, endConn
            moveConn = UserInputService.InputChanged:Connect(function(moveInput)
                if not activeHandle then return end
                if moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch then
                    calculateRatio(moveInput.Position.X)
                end
            end)

            endConn = UserInputService.InputEnded:Connect(function(endInput)
                if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then
                    activeHandle = nil
                    if moveConn then moveConn:Disconnect() end
                    if endConn then endConn:Disconnect() end
                end
            end)
        end
    end)

    if config.Tooltip then
        LouisHub:BindTooltip(row, config.Tooltip)
    end

    setRange(currentMin, currentMax, true)

    local RangeControl = {
        Instance = row,
        Get = function()
            return { Min = currentMin, Max = currentMax }
        end,
        Set = function(_, rangeTable, silent)
            if type(rangeTable) == "table" then
                setRange(rangeTable.Min or minBound, rangeTable.Max or maxBound, silent)
            end
        end,
        SetDisabled = function(_, disabled)
            isDisabled = (disabled == true)
            row.BackgroundTransparency = isDisabled and 0.8 or 0.45
        end,
        SetVisible = function(_, visible)
            row.Visible = (visible == true)
        end,
        Destroy = function()
            LouisHub.Elements[flagKey] = nil
            pcall(function() row:Destroy() end)
        end
    }

    LouisHub.Elements[flagKey] = RangeControl

    if config.VisibleIf then
        LouisHub:RegisterConditional(RangeControl, config.VisibleIf, "Visible")
    end
    if config.EnabledIf then
        LouisHub:RegisterConditional(RangeControl, config.EnabledIf, "Enabled")
    end

    return RangeControl
end
SectionControls.CreateRangeSlider = SectionControls.AddRangeSlider

-- ── SECTION CONTROLS REGISTRATION HOOK ────────────────────────────────
function LouisHub:ApplySectionControls(Section)
    for name, method in pairs(SectionControls) do
        Section[name] = function(selfSec, cfg)
            return method(selfSec, cfg)
        end
    end
end

-- Hook Window creation to automatically attach Section controls
local PreviousCreateWindow_4A = LouisHub.CreateWindow
function LouisHub:CreateWindow(windowConfig)
    local Window = PreviousCreateWindow_4A(self, windowConfig)

    local function hookSubTab(subTab)
        local rawAddSection = subTab.AddSection
        subTab.AddSection = function(selfSub, secCfg)
            local sec = rawAddSection(selfSub, secCfg)
            LouisHub:ApplySectionControls(sec)
            return sec
        end
        subTab.CreateSection = subTab.AddSection
    end

    local function hookTab(tab)
        local rawAddSubTab = tab.AddSubTab
        tab.AddSubTab = function(selfTab, subCfg)
            local sub = rawAddSubTab(selfTab, subCfg)
            hookSubTab(sub)
            return sub
        end
        tab.CreateSubTab = tab.AddSubTab

        local rawAddSection = tab.AddSection
        tab.AddSection = function(selfTab, secCfg)
            local sec = rawAddSection(selfTab, secCfg)
            LouisHub:ApplySectionControls(sec)
            return sec
        end
        tab.CreateSection = tab.AddSection

        for _, sub in ipairs(tab.SubTabsList) do
            hookSubTab(sub)
        end
    end

    local rawAddCategory = Window.AddCategory
    Window.AddCategory = function(selfWin, catCfg)
        local cat = rawAddCategory(selfWin, catCfg)
        local rawAddTab = cat.AddTab
        cat.AddTab = function(selfCat, tabCfg)
            local tab = rawAddTab(selfCat, tabCfg)
            hookTab(tab)
            return tab
        end
        cat.CreateTab = cat.AddTab
        return cat
    end
    Window.CreateCategory = Window.AddCategory

    local rawAddTab = Window.AddTab
    Window.AddTab = function(selfWin, tabCfg)
        local tab = rawAddTab(selfWin, tabCfg)
        hookTab(tab)
        return tab
    end
    Window.CreateTab = Window.AddTab

    for _, tab in ipairs(Window.Tabs) do
        hookTab(tab)
    end

    return Window
end

-- LOUIS HUB | PART 4B | continues in PART 4C

-- =====================================================================
-- SECTION 27: DATA ENTRY CONTROLS (STEPPERS, INPUTS, TAGS, RADIOS)
-- =====================================================================
local PreviousApplySectionControls = LouisHub.ApplySectionControls

function LouisHub:ApplySectionControls(Section)
    if PreviousApplySectionControls then
        PreviousApplySectionControls(self, Section)
    end

    -- ── 1. NUMBER STEPPER CONTROL ────────────────────────────────────
    function Section:AddStepper(config)
        config = config or {}
        local stepperName = tostring(config.Name or config.Title or "Stepper")
        local flagKey = config.Flag or ("Stepper_" .. stepperName:gsub("%s+", ""))
        local minVal = tonumber(config.Min) or 0
        local maxVal = tonumber(config.Max) or 100
        if minVal >= maxVal then maxVal = minVal + 1 end

        local stepVal = tonumber(config.Step or config.Increment) or 1
        local decimals = tonumber(config.Decimals) or 0
        local prefixStr = tostring(config.Prefix or "")
        local suffixStr = tostring(config.Suffix or "")

        local rawDefault = tonumber(config.Default) or minVal
        local currentValue = math.clamp(rawDefault, minVal, maxVal)
        local callback = config.Callback
        local isDisabled = config.Disabled == true

        local targetContainer = self:_GetTargetContainer("Stepper", config)

        local row = Instance.new("Frame")
        row.Name = "StepperRow_" .. stepperName:gsub("%s+", "")
        row.BackgroundColor3 = LouisHub.CurrentTheme.SurfaceAlt
        row.BackgroundTransparency = 0.45
        row.BorderSizePixel = 0
        row.Size = UDim2.new(1, 0, 0, 32)
        row.Parent = targetContainer
        LouisHub:RegisterThemeProperty(row, "BackgroundColor3", "SurfaceAlt")

        local rCorner = Instance.new("UICorner")
        rCorner.CornerRadius = UDim.new(0, 7)
        rCorner.Parent = row

        local rStroke = Instance.new("UIStroke")
        rStroke.Thickness = 1
        rStroke.Color = LouisHub.CurrentTheme.Border
        rStroke.Transparency = 0.35
        rStroke.Parent = row
        LouisHub:RegisterThemeProperty(rStroke, "Color", "Border")

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "TitleLabel"
        titleLabel.BackgroundTransparency = 1
        titleLabel.Font = Enum.Font.GothamMedium
        titleLabel.TextSize = 11.5
        titleLabel.TextColor3 = LouisHub.CurrentTheme.Text
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
        titleLabel.Text = stepperName
        titleLabel.Position = UDim2.fromOffset(8, 0)
        titleLabel.Size = UDim2.new(1, -125, 1, 0)
        titleLabel.Parent = row
        LouisHub:RegisterThemeProperty(titleLabel, "TextColor3", "Text")
        LouisHub:RegisterFontElement(titleLabel, "Medium")

        local stepperHost = Instance.new("Frame")
        stepperHost.Name = "ControlsHost"
        stepperHost.BackgroundTransparency = 1
        stepperHost.Size = UDim2.fromOffset(108, 22)
        stepperHost.Position = UDim2.new(1, -116, 0.5, -11)
        stepperHost.Parent = row

        local shLayout = Instance.new("UIListLayout")
        shLayout.FillDirection = Enum.FillDirection.Horizontal
        shLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
        shLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        shLayout.Padding = UDim.new(0, 3)
        shLayout.Parent = stepperHost

        local minusBtn = Instance.new("TextButton")
        minusBtn.Name = "MinusBtn"
        minusBtn.AutoButtonColor = false
        minusBtn.BackgroundColor3 = LouisHub.CurrentTheme.Surface
        minusBtn.Size = UDim2.fromOffset(22, 22)
        minusBtn.Font = Enum.Font.GothamBold
        minusBtn.TextSize = 13
        minusBtn.TextColor3 = LouisHub.CurrentTheme.Highlight
        minusBtn.Text = "−"
        minusBtn.Parent = stepperHost
        LouisHub:RegisterThemeProperty(minusBtn, "BackgroundColor3", "Surface")
        LouisHub:RegisterThemeProperty(minusBtn, "TextColor3", "Highlight")
        LouisHub:RegisterFontElement(minusBtn, "Bold")

        local mbCorner = Instance.new("UICorner")
        mbCorner.CornerRadius = UDim.new(0, 4)
        mbCorner.Parent = minusBtn

        local valueBox = Instance.new("TextBox")
        valueBox.Name = "ValueBox"
        valueBox.BackgroundColor3 = LouisHub.CurrentTheme.Surface
        valueBox.BackgroundTransparency = 0.4
        valueBox.BorderSizePixel = 0
        valueBox.Font = Enum.Font.GothamBold
        valueBox.TextSize = 10.5
        valueBox.TextColor3 = LouisHub.CurrentTheme.Highlight
        valueBox.TextXAlignment = Enum.TextXAlignment.Center
        valueBox.Size = UDim2.fromOffset(58, 22)
        valueBox.ClearTextOnFocus = false
        valueBox.Parent = stepperHost
        LouisHub:RegisterThemeProperty(valueBox, "BackgroundColor3", "Surface")
        LouisHub:RegisterThemeProperty(valueBox, "TextColor3", "Highlight")
        LouisHub:RegisterFontElement(valueBox, "Bold")

        local vbCorner = Instance.new("UICorner")
        vbCorner.CornerRadius = UDim.new(0, 4)
        vbCorner.Parent = valueBox

        local plusBtn = Instance.new("TextButton")
        plusBtn.Name = "PlusBtn"
        plusBtn.AutoButtonColor = false
        plusBtn.BackgroundColor3 = LouisHub.CurrentTheme.Surface
        plusBtn.Size = UDim2.fromOffset(22, 22)
        plusBtn.Font = Enum.Font.GothamBold
        plusBtn.TextSize = 13
        plusBtn.TextColor3 = LouisHub.CurrentTheme.Highlight
        plusBtn.Text = "+"
        plusBtn.Parent = stepperHost
        LouisHub:RegisterThemeProperty(plusBtn, "BackgroundColor3", "Surface")
        LouisHub:RegisterThemeProperty(plusBtn, "TextColor3", "Highlight")
        LouisHub:RegisterFontElement(plusBtn, "Bold")

        local pbCorner = Instance.new("UICorner")
        pbCorner.CornerRadius = UDim.new(0, 4)
        pbCorner.Parent = plusBtn

        local function formatValue(val)
            local formatted = (decimals > 0) and string.format("%." .. decimals .. "f", val) or tostring(math.floor(val + 0.5))
            return prefixStr .. formatted .. suffixStr
        end

        local function roundToStep(val)
            local factor = 1 / stepVal
            return math.clamp(math.floor((val - minVal) * factor + 0.5) / factor + minVal, minVal, maxVal)
        end

        local function setValue(newVal, silent)
            if isDisabled then return end
            local rounded = roundToStep(newVal)
            currentValue = rounded
            valueBox.Text = formatValue(rounded)
            LouisHub.Flags[flagKey] = rounded

            if not silent and type(callback) == "function" then
                local success, err = pcall(callback, rounded)
                if not success then LouisHub:Log("StepperCallback", err) end
            end
        end

        LouisHub:RegisterHoldAction(minusBtn, function()
            if not isDisabled then
                setValue(currentValue - stepVal, false)
                LouisHub:ApplyPressAnimation(minusBtn, 0.92)
            end
        end, 0.35, 0.08)

        LouisHub:RegisterHoldAction(plusBtn, function()
            if not isDisabled then
                setValue(currentValue + stepVal, false)
                LouisHub:ApplyPressAnimation(plusBtn, 0.92)
            end
        end, 0.35, 0.08)

        valueBox.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                local cleanStr = valueBox.Text:gsub("[^%d%.%-]", "")
                local parsed = tonumber(cleanStr)
                if parsed then
                    setValue(parsed, false)
                    LouisHub:ApplyFlashFeedback(valueBox, true)
                else
                    valueBox.Text = formatValue(currentValue)
                    LouisHub:ApplyFlashFeedback(valueBox, false)
                end
            else
                valueBox.Text = formatValue(currentValue)
            end
        end)

        if config.Tooltip then
            LouisHub:BindTooltip(row, config.Tooltip)
        end

        setValue(currentValue, true)

        local StepperControl = {
            Instance = row,
            Get = function()
                return currentValue
            end,
            Set = function(_, val, silent)
                setValue(tonumber(val) or minVal, silent)
            end,
            SetDisabled = function(_, disabled)
                isDisabled = (disabled == true)
                row.BackgroundTransparency = isDisabled and 0.8 or 0.45
                minusBtn.Active = not isDisabled
                plusBtn.Active = not isDisabled
                valueBox.Active = not isDisabled
            end,
            SetVisible = function(_, visible)
                row.Visible = (visible == true)
            end,
            Destroy = function()
                LouisHub.Elements[flagKey] = nil
                pcall(function() row:Destroy() end)
            end
        }

        LouisHub.Elements[flagKey] = StepperControl

        if config.VisibleIf then
            LouisHub:RegisterConditional(StepperControl, config.VisibleIf, "Visible")
        end
        if config.EnabledIf then
            LouisHub:RegisterConditional(StepperControl, config.EnabledIf, "Enabled")
        end

        return StepperControl
    end
    Section.CreateStepper = Section.AddStepper

    -- ── 2. TEXT INPUT & TEXTAREA CONTROL ─────────────────────────────
    function Section:AddInput(config)
        config = config or {}
        local inputName = tostring(config.Name or config.Title or "Input")
        local flagKey = config.Flag or ("Input_" .. inputName:gsub("%s+", ""))
        local placeholder = tostring(config.Placeholder or "Enter text...")
        local currentValue = tostring(config.Default or "")
        local isNumeric = config.NumericOnly == true
        local isTextArea = config.Type == "TextArea" or config.Type == "textarea"
        local areaHeight = tonumber(config.Height) or 64
        local maxLength = tonumber(config.MaxLength) or (isTextArea and 1000 or 150)
        local triggerOnEnterOnly = config.OnEnter == true or isTextArea
        local callback = config.Callback
        local isDisabled = config.Disabled == true

        local targetContainer = self:_GetTargetContainer("Input", config)

        local row = Instance.new("Frame")
        row.Name = "InputRow_" .. inputName:gsub("%s+", "")
        row.BackgroundColor3 = LouisHub.CurrentTheme.SurfaceAlt
        row.BackgroundTransparency = 0.45
        row.BorderSizePixel = 0
        row.Size = UDim2.new(1, 0, 0, isTextArea and (areaHeight + 34) or 32)
        row.Parent = targetContainer
        LouisHub:RegisterThemeProperty(row, "BackgroundColor3", "SurfaceAlt")

        local rCorner = Instance.new("UICorner")
        rCorner.CornerRadius = UDim.new(0, 7)
        rCorner.Parent = row

        local rStroke = Instance.new("UIStroke")
        rStroke.Thickness = 1
        rStroke.Color = LouisHub.CurrentTheme.Border
        rStroke.Transparency = 0.35
        rStroke.Parent = row
        LouisHub:RegisterThemeProperty(rStroke, "Color", "Border")

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "TitleLabel"
        titleLabel.BackgroundTransparency = 1
        titleLabel.Font = Enum.Font.GothamMedium
        titleLabel.TextSize = 11.5
        titleLabel.TextColor3 = LouisHub.CurrentTheme.Text
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.Text = inputName
        titleLabel.Position = UDim2.fromOffset(8, isTextArea and 6 or 0)
        titleLabel.Size = isTextArea and UDim2.new(1, -16, 0, 16) or UDim2.new(0.40, -8, 1, 0)
        titleLabel.Parent = row
        LouisHub:RegisterThemeProperty(titleLabel, "TextColor3", "Text")
        LouisHub:RegisterFontElement(titleLabel, "Medium")

        local boxFrame = Instance.new("Frame")
        boxFrame.Name = "BoxContainer"
        boxFrame.BackgroundColor3 = LouisHub.CurrentTheme.Surface
        boxFrame.BackgroundTransparency = 0.3
        boxFrame.BorderSizePixel = 0
        boxFrame.Parent = row
        LouisHub:RegisterThemeProperty(boxFrame, "BackgroundColor3", "Surface")

        local bfCorner = Instance.new("UICorner")
        bfCorner.CornerRadius = UDim.new(0, 5)
        bfCorner.Parent = boxFrame

        local bfStroke = Instance.new("UIStroke")
        bfStroke.Thickness = 1
        bfStroke.Color = LouisHub.CurrentTheme.Border
        bfStroke.Transparency = 0.5
        bfStroke.Parent = boxFrame
        LouisHub:RegisterThemeProperty(bfStroke, "Color", "Border")

        if isTextArea then
            boxFrame.Size = UDim2.new(1, -16, 0, areaHeight)
            boxFrame.Position = UDim2.fromOffset(8, 26)
        else
            boxFrame.Size = UDim2.new(0.60, -8, 0, 22)
            boxFrame.Position = UDim2.new(0.40, 0, 0.5, -11)
        end

        local textBox = Instance.new("TextBox")
        textBox.Name = "InputBox"
        textBox.BackgroundTransparency = 1
        textBox.Font = Enum.Font.Gotham
        textBox.TextSize = 10.5
        textBox.TextColor3 = LouisHub.CurrentTheme.Highlight
        textBox.PlaceholderColor3 = LouisHub.CurrentTheme.TextMuted
        textBox.PlaceholderText = placeholder
        textBox.Text = currentValue
        textBox.ClearTextOnFocus = config.ClearOnFocus == true
        textBox.MultiLine = isTextArea
        textBox.TextWrapped = isTextArea
        textBox.TextXAlignment = Enum.TextXAlignment.Left
        textBox.TextYAlignment = isTextArea and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
        textBox.Size = UDim2.new(1, -24, 1, 0)
        textBox.Position = UDim2.fromOffset(6, isTextArea and 4 or 0)
        textBox.Parent = boxFrame
        LouisHub:RegisterThemeProperty(textBox, "TextColor3", "Highlight")
        LouisHub:RegisterFontElement(textBox, "Regular")

        local clearBtn = Instance.new("TextButton")
        clearBtn.Name = "ClearBtn"
        clearBtn.BackgroundTransparency = 1
        clearBtn.Font = Enum.Font.GothamBold
        clearBtn.TextSize = 11
        clearBtn.TextColor3 = LouisHub.CurrentTheme.TextMuted
        clearBtn.Text = "✕"
        clearBtn.Size = UDim2.fromOffset(16, 16)
        clearBtn.Position = UDim2.new(1, -20, 0, isTextArea and 4 or 3)
        clearBtn.Visible = currentValue ~= ""
        clearBtn.Parent = boxFrame

        clearBtn.MouseButton1Click:Connect(function()
            if isDisabled then return end
            textBox.Text = ""
            clearBtn.Visible = false
            currentValue = ""
            LouisHub.Flags[flagKey] = ""
            if type(callback) == "function" then
                pcall(callback, "")
            end
        end)

        textBox:GetPropertyChangedSignal("Text"):Connect(function()
            local text = textBox.Text
            if isNumeric then
                local filtered = text:gsub("[^%d%.%-]", "")
                if filtered ~= text then
                    textBox.Text = filtered
                    text = filtered
                end
            end

            if #text > maxLength then
                text = text:sub(1, maxLength)
                textBox.Text = text
            end

            clearBtn.Visible = (text ~= "")

            if not triggerOnEnterOnly then
                currentValue = text
                LouisHub.Flags[flagKey] = text
                if type(callback) == "function" then
                    pcall(callback, text)
                end
            end
        end)

        textBox.FocusLost:Connect(function(enterPressed)
            local finalText = textBox.Text
            currentValue = finalText
            LouisHub.Flags[flagKey] = finalText

            if triggerOnEnterOnly and (enterPressed or not isTextArea) then
                if type(callback) == "function" then
                    local success, err = pcall(callback, finalText)
                    if not success then LouisHub:Log("InputCallback", err) end
                end
            end
        end)

        if config.Tooltip then
            LouisHub:BindTooltip(row, config.Tooltip)
        end

        LouisHub.Flags[flagKey] = currentValue

        local InputControl = {
            Instance = row,
            Get = function()
                return currentValue
            end,
            Set = function(_, val, silent)
                local str = tostring(val or "")
                currentValue = str
                textBox.Text = str
                clearBtn.Visible = (str ~= "")
                LouisHub.Flags[flagKey] = str

                if not silent and type(callback) == "function" then
                    pcall(callback, str)
                end
            end,
            SetDisabled = function(_, disabled)
                isDisabled = (disabled == true)
                row.BackgroundTransparency = isDisabled and 0.8 or 0.45
                textBox.Active = not isDisabled
            end,
            SetVisible = function(_, visible)
                row.Visible = (visible == true)
            end,
            Destroy = function()
                LouisHub.Elements[flagKey] = nil
                pcall(function() row:Destroy() end)
            end
        }

        LouisHub.Elements[flagKey] = InputControl

        if config.VisibleIf then
            LouisHub:RegisterConditional(InputControl, config.VisibleIf, "Visible")
        end
        if config.EnabledIf then
            LouisHub:RegisterConditional(InputControl, config.EnabledIf, "Enabled")
        end

        return InputControl
    end
    Section.CreateInput = Section.AddInput

    -- ── 3. CHIP TAG INPUT CONTROL ────────────────────────────────────
    function Section:AddTagInput(config)
        config = config or {}
        local tagTitle = tostring(config.Name or config.Title or "Tags")
        local flagKey = config.Flag or ("TagInput_" .. tagTitle:gsub("%s+", ""))
        local placeholder = tostring(config.Placeholder or "Type & Enter...")
        local maxTags = tonumber(config.MaxTags) or 20
        local callback = config.Callback
        local isDisabled = config.Disabled == true

        local tagsList = {}
        if type(config.Default) == "table" then
            for _, t in ipairs(config.Default) do
                table.insert(tagsList, tostring(t))
            end
        end

        local targetContainer = self:_GetTargetContainer("TagInput", config)

        local row = Instance.new("Frame")
        row.Name = "TagInputRow_" .. tagTitle:gsub("%s+", "")
        row.BackgroundColor3 = LouisHub.CurrentTheme.SurfaceAlt
        row.BackgroundTransparency = 0.45
        row.BorderSizePixel = 0
        row.Size = UDim2.new(1, 0, 0, 56)
        row.AutomaticSize = Enum.AutomaticSize.Y
        row.Parent = targetContainer
        LouisHub:RegisterThemeProperty(row, "BackgroundColor3", "SurfaceAlt")

        local rCorner = Instance.new("UICorner")
        rCorner.CornerRadius = UDim.new(0, 7)
        rCorner.Parent = row

        local rStroke = Instance.new("UIStroke")
        rStroke.Thickness = 1
        rStroke.Color = LouisHub.CurrentTheme.Border
        rStroke.Transparency = 0.35
        rStroke.Parent = row
        LouisHub:RegisterThemeProperty(rStroke, "Color", "Border")

        local rPad = Instance.new("UIPadding")
        rPad.PaddingLeft = UDim.new(0, 8)
        rPad.PaddingRight = UDim.new(0, 8)
        rPad.PaddingTop = UDim.new(0, 6)
        rPad.PaddingBottom = UDim.new(0, 8)
        rPad.Parent = row

        local rLayout = Instance.new("UIListLayout")
        rLayout.SortOrder = Enum.SortOrder.LayoutOrder
        rLayout.Padding = UDim.new(0, 6)
        rLayout.Parent = row

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "TitleLabel"
        titleLabel.BackgroundTransparency = 1
        titleLabel.Font = Enum.Font.GothamMedium
        titleLabel.TextSize = 11.5
        titleLabel.TextColor3 = LouisHub.CurrentTheme.Text
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.Text = tagTitle
        titleLabel.Size = UDim2.new(1, 0, 0, 14)
        titleLabel.LayoutOrder = 1
        titleLabel.Parent = row
        LouisHub:RegisterThemeProperty(titleLabel, "TextColor3", "Text")
        LouisHub:RegisterFontElement(titleLabel, "Medium")

        local chipsContainer = Instance.new("Frame")
        chipsContainer.Name = "ChipsContainer"
        chipsContainer.BackgroundTransparency = 1
        chipsContainer.Size = UDim2.new(1, 0, 0, 0)
        chipsContainer.AutomaticSize = Enum.AutomaticSize.Y
        chipsContainer.LayoutOrder = 2
        chipsContainer.Parent = row

        local cLayout = Instance.new("UIListLayout")
        cLayout.FillDirection = Enum.FillDirection.Horizontal
        cLayout.SortOrder = Enum.SortOrder.LayoutOrder
        cLayout.Padding = UDim.new(0, 4)
        cLayout.Wraps = true
        cLayout.Parent = chipsContainer

        local entryBox = Instance.new("TextBox")
        entryBox.Name = "EntryBox"
        entryBox.BackgroundColor3 = LouisHub.CurrentTheme.Surface
        entryBox.BackgroundTransparency = 0.3
        entryBox.BorderSizePixel = 0
        entryBox.Font = Enum.Font.Gotham
        entryBox.TextSize = 10.5
        entryBox.TextColor3 = LouisHub.CurrentTheme.Highlight
        entryBox.PlaceholderColor3 = LouisHub.CurrentTheme.TextMuted
        entryBox.PlaceholderText = placeholder
        entryBox.Text = ""
        entryBox.ClearTextOnFocus = false
        entryBox.Size = UDim2.new(1, 0, 0, 22)
        entryBox.LayoutOrder = 3
        entryBox.Parent = row
        LouisHub:RegisterThemeProperty(entryBox, "BackgroundColor3", "Surface")
        LouisHub:RegisterThemeProperty(entryBox, "TextColor3", "Highlight")
        LouisHub:RegisterFontElement(entryBox, "Regular")

        local ebCorner = Instance.new("UICorner")
        ebCorner.CornerRadius = UDim.new(0, 4)
        ebCorner.Parent = entryBox

        local ebPad = Instance.new("UIPadding")
        ebPad.PaddingLeft = UDim.new(0, 6)
        ebPad.PaddingRight = UDim.new(0, 6)
        ebPad.Parent = entryBox

        local function renderChips()
            for _, child in ipairs(chipsContainer:GetChildren()) do
                if child:IsA("Frame") then
                    child:Destroy()
                end
            end

            for idx, tagText in ipairs(tagsList) do
                local chip = Instance.new("Frame")
                chip.Name = "Chip_" .. tostring(idx)
                chip.BackgroundColor3 = LouisHub.CurrentTheme.Accent
                chip.BackgroundTransparency = 0.2
                chip.BorderSizePixel = 0
                chip.Size = UDim2.fromOffset(0, 18)
                chip.AutomaticSize = Enum.AutomaticSize.X
                chip.Parent = chipsContainer
                LouisHub:RegisterThemeProperty(chip, "BackgroundColor3", "Accent")

                local chCorner = Instance.new("UICorner")
                chCorner.CornerRadius = UDim.new(0, 9)
                chCorner.Parent = chip

                local chLayout = Instance.new("UIListLayout")
                chLayout.FillDirection = Enum.FillDirection.Horizontal
                chLayout.VerticalAlignment = Enum.VerticalAlignment.Center
                chLayout.Padding = UDim.new(0, 4)
                chLayout.Parent = chip

                local chPad = Instance.new("UIPadding")
                chPad.PaddingLeft = UDim.new(0, 8)
                chPad.PaddingRight = UDim.new(0, 6)
                chPad.Parent = chip

                local tLabel = Instance.new("TextLabel")
                tLabel.BackgroundTransparency = 1
                tLabel.Font = Enum.Font.GothamMedium
                tLabel.TextSize = 10
                tLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                tLabel.Text = tagText
                tLabel.Size = UDim2.fromOffset(0, 0)
                tLabel.AutomaticSize = Enum.AutomaticSize.XY
                tLabel.Parent = chip
                LouisHub:RegisterFontElement(tLabel, "Medium")

                local delBtn = Instance.new("TextButton")
                delBtn.BackgroundTransparency = 1
                delBtn.Font = Enum.Font.GothamBold
                delBtn.TextSize = 11
                delBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                delBtn.Text = "×"
                delBtn.Size = UDim2.fromOffset(12, 12)
                delBtn.Parent = chip

                delBtn.MouseButton1Click:Connect(function()
                    if isDisabled then return end
                    table.remove(tagsList, idx)
                    renderChips()
                    LouisHub.Flags[flagKey] = tagsList
                    if type(callback) == "function" then
                        pcall(callback, tagsList)
                    end
                end)
            end
        end

        local function commitTag(rawText)
            local clean = rawText:gsub("^%s+", ""):gsub("%s+$", "")
            if clean == "" then return end

            for _, existing in ipairs(tagsList) do
                if existing:lower() == clean:lower() then
                    entryBox.Text = ""
                    LouisHub:ApplyFlashFeedback(entryBox, false)
                    return
                end
            end

            if #tagsList >= maxTags then
                entryBox.Text = ""
                LouisHub:ApplyFlashFeedback(entryBox, false)
                return
            end

            table.insert(tagsList, clean)
            entryBox.Text = ""
            renderChips()
            LouisHub.Flags[flagKey] = tagsList

            if type(callback) == "function" then
                local success, err = pcall(callback, tagsList)
                if not success then LouisHub:Log("TagInputCallback", err) end
            end
        end

        entryBox.FocusLost:Connect(function(enterPressed)
            if enterPressed and entryBox.Text ~= "" then
                commitTag(entryBox.Text)
            end
        end)

        entryBox:GetPropertyChangedSignal("Text"):Connect(function()
            if entryBox.Text:find(",") then
                local parts = entryBox.Text:split(",")
                for _, part in ipairs(parts) do
                    commitTag(part)
                end
            end
        end)

        renderChips()
        LouisHub.Flags[flagKey] = tagsList

        local TagControl = {
            Instance = row,
            Get = function()
                return tagsList
            end,
            Set = function(_, newTags, silent)
                if type(newTags) == "table" then
                    tagsList = {}
                    for _, t in ipairs(newTags) do
                        table.insert(tagsList, tostring(t))
                    end
                    renderChips()
                    LouisHub.Flags[flagKey] = tagsList
                    if not silent and type(callback) == "function" then
                        pcall(callback, tagsList)
                    end
                end
            end,
            AddTag = function(_, tag)
                commitTag(tostring(tag))
            end,
            RemoveTag = function(_, tag)
                for i = #tagsList, 1, -1 do
                    if tagsList[i] == tag then
                        table.remove(tagsList, i)
                    end
                end
                renderChips()
            end,
            SetDisabled = function(_, disabled)
                isDisabled = (disabled == true)
                row.BackgroundTransparency = isDisabled and 0.8 or 0.45
                entryBox.Active = not isDisabled
            end,
            SetVisible = function(_, visible)
                row.Visible = (visible == true)
            end,
            Destroy = function()
                LouisHub.Elements[flagKey] = nil
                pcall(function() row:Destroy() end)
            end
        }

        LouisHub.Elements[flagKey] = TagControl

        if config.VisibleIf then
            LouisHub:RegisterConditional(TagControl, config.VisibleIf, "Visible")
        end
        if config.EnabledIf then
            LouisHub:RegisterConditional(TagControl, config.EnabledIf, "Enabled")
        end

        return TagControl
    end
    Section.CreateTagInput = Section.AddTagInput

    -- ── 4. RADIO GROUP CONTROL ───────────────────────────────────────
    function Section:AddRadioGroup(config)
        config = config or {}
        local radioTitle = tostring(config.Name or config.Title or "Options")
        local flagKey = config.Flag or ("Radio_" .. radioTitle:gsub("%s+", ""))
        local rawOptions = config.Options or { "Option 1", "Option 2" }
        local currentValue = tostring(config.Default or rawOptions[1] or "")
        local callback = config.Callback
        local isDisabled = config.Disabled == true

        local targetContainer = self:_GetTargetContainer("RadioGroup", config)

        local row = Instance.new("Frame")
        row.Name = "RadioRow_" .. radioTitle:gsub("%s+", "")
        row.BackgroundColor3 = LouisHub.CurrentTheme.SurfaceAlt
        row.BackgroundTransparency = 0.45
        row.BorderSizePixel = 0
        row.Size = UDim2.new(1, 0, 0, 54)
        row.AutomaticSize = Enum.AutomaticSize.Y
        row.Parent = targetContainer
        LouisHub:RegisterThemeProperty(row, "BackgroundColor3", "SurfaceAlt")

        local rCorner = Instance.new("UICorner")
        rCorner.CornerRadius = UDim.new(0, 7)
        rCorner.Parent = row

        local rStroke = Instance.new("UIStroke")
        rStroke.Thickness = 1
        rStroke.Color = LouisHub.CurrentTheme.Border
        rStroke.Transparency = 0.35
        rStroke.Parent = row
        LouisHub:RegisterThemeProperty(rStroke, "Color", "Border")

        local rPad = Instance.new("UIPadding")
        rPad.PaddingLeft = UDim.new(0, 8)
        rPad.PaddingRight = UDim.new(0, 8)
        rPad.PaddingTop = UDim.new(0, 6)
        rPad.PaddingBottom = UDim.new(0, 8)
        rPad.Parent = row

        local rLayout = Instance.new("UIListLayout")
        rLayout.SortOrder = Enum.SortOrder.LayoutOrder
        rLayout.Padding = UDim.new(0, 6)
        rLayout.Parent = row

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "TitleLabel"
        titleLabel.BackgroundTransparency = 1
        titleLabel.Font = Enum.Font.GothamMedium
        titleLabel.TextSize = 11.5
        titleLabel.TextColor3 = LouisHub.CurrentTheme.Text
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.Text = radioTitle
        titleLabel.Size = UDim2.new(1, 0, 0, 14)
        titleLabel.LayoutOrder = 1
        titleLabel.Parent = row
        LouisHub:RegisterThemeProperty(titleLabel, "TextColor3", "Text")
        LouisHub:RegisterFontElement(titleLabel, "Medium")

        local pillContainer = Instance.new("Frame")
        pillContainer.Name = "PillContainer"
        pillContainer.BackgroundTransparency = 1
        pillContainer.Size = UDim2.new(1, 0, 0, 24)
        pillContainer.LayoutOrder = 2
        pillContainer.Parent = row

        local pLayout = Instance.new("UIListLayout")
        pLayout.FillDirection = Enum.FillDirection.Horizontal
        pLayout.SortOrder = Enum.SortOrder.LayoutOrder
        pLayout.Padding = UDim.new(0, 4)
        pLayout.Parent = pillContainer

        local pillButtons = {}

        local function refreshPills()
            for optName, btn in pairs(pillButtons) do
                local isSelected = (optName == currentValue)
                local targetColor = isSelected and LouisHub.CurrentTheme.Accent or LouisHub.CurrentTheme.Surface
                local targetTextColor = isSelected and Color3.fromRGB(255, 255, 255) or LouisHub.CurrentTheme.TextMuted

                LouisHub:Tween(btn, { BackgroundColor3 = targetColor }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                local txt = btn:FindFirstChildOfClass("TextLabel")
                if txt then
                    txt.TextColor3 = targetTextColor
                end
            end
        end

        local function selectOption(optName, silent)
            if isDisabled then return end
            currentValue = optName
            LouisHub.Flags[flagKey] = optName
            refreshPills()

            if not silent and type(callback) == "function" then
                local success, err = pcall(callback, optName)
                if not success then LouisHub:Log("RadioCallback", err) end
            end
        end

        local function buildPills()
            for _, child in ipairs(pillContainer:GetChildren()) do
                if child:IsA("TextButton") then child:Destroy() end
            end
            pillButtons = {}

            local totalOptions = #rawOptions
            for idx, optName in ipairs(rawOptions) do
                local optStr = tostring(optName)
                local btn = Instance.new("TextButton")
                btn.Name = "RadioBtn_" .. optStr:gsub("%s+", "")
                btn.AutoButtonColor = false
                btn.BackgroundColor3 = (optStr == currentValue) and LouisHub.CurrentTheme.Accent or LouisHub.CurrentTheme.Surface
                btn.Size = UDim2.new(1 / totalOptions, -math.floor(4 * (totalOptions - 1) / totalOptions), 1, 0)
                btn.Text = ""
                btn.Parent = pillContainer

                local bCorner = Instance.new("UICorner")
                bCorner.CornerRadius = UDim.new(0, 5)
                bCorner.Parent = btn

                local bStroke = Instance.new("UIStroke")
                bStroke.Thickness = 1
                bStroke.Color = LouisHub.CurrentTheme.Border
                bStroke.Transparency = 0.5
                bStroke.Parent = btn

                local lbl = Instance.new("TextLabel")
                lbl.BackgroundTransparency = 1
                lbl.Font = Enum.Font.GothamMedium
                lbl.TextSize = 10
                lbl.TextColor3 = (optStr == currentValue) and Color3.fromRGB(255, 255, 255) or LouisHub.CurrentTheme.TextMuted
                lbl.TextTruncate = Enum.TextTruncate.AtEnd
                lbl.Text = optStr
                lbl.Size = UDim2.new(1, 0, 1, 0)
                lbl.Parent = btn
                LouisHub:RegisterFontElement(lbl, "Medium")

                btn.MouseButton1Click:Connect(function()
                    selectOption(optStr, false)
                end)

                pillButtons[optStr] = btn
            end
        end

        buildPills()
        LouisHub.Flags[flagKey] = currentValue

        local RadioControl = {
            Instance = row,
            Get = function()
                return currentValue
            end,
            Set = function(_, val, silent)
                selectOption(tostring(val), silent)
            end,
            SetOptions = function(_, newOptions)
                if type(newOptions) == "table" then
                    rawOptions = newOptions
                    buildPills()
                end
            end,
            SetDisabled = function(_, disabled)
                isDisabled = (disabled == true)
                row.BackgroundTransparency = isDisabled and 0.8 or 0.45
                for _, b in pairs(pillButtons) do
                    b.Active = not isDisabled
                end
            end,
            SetVisible = function(_, visible)
                row.Visible = (visible == true)
            end,
            Destroy = function()
                LouisHub.Elements[flagKey] = nil
                pcall(function() row:Destroy() end)
            end
        }

        LouisHub.Elements[flagKey] = RadioControl

        if config.VisibleIf then
            LouisHub:RegisterConditional(RadioControl, config.VisibleIf, "Visible")
        end
        if config.EnabledIf then
            LouisHub:RegisterConditional(RadioControl, config.EnabledIf, "Enabled")
        end

        return RadioControl
    end
    Section.CreateRadioGroup = Section.AddRadioGroup
end

-- LOUIS HUB | PART 4C | continues in PART 5A

-- =====================================================================
-- SECTION 28: ADVANCED PICKERS (DROPDOWNS, COLORPICKERS, KEYBINDS)
-- =====================================================================
local PreviousApplySectionControls_4C = LouisHub.ApplySectionControls

function LouisHub:ApplySectionControls(Section)
    if PreviousApplySectionControls_4C then
        PreviousApplySectionControls_4C(self, Section)
    end

    -- ── 1. SEARCHABLE SINGLE & MULTI DROPDOWN ────────────────────────
    function Section:AddDropdown(config)
        config = config or {}
        local dropName = tostring(config.Name or config.Title or "Dropdown")
        local flagKey = config.Flag or ("Dropdown_" .. dropName:gsub("%s+", ""))
        local rawOptions = config.Options or {}
        local isMulti = (config.Multi == true) or (config.MultipleOptions == true)
        local callback = config.Callback
        local isDisabled = config.Disabled == true

        local currentSelection = {}
        if isMulti then
            if type(config.Default) == "table" then
                for _, item in ipairs(config.Default) do
                    currentSelection[tostring(item)] = true
                end
            elseif config.Default then
                currentSelection[tostring(config.Default)] = true
            end
        else
            local def = config.Default or rawOptions[1]
            if def ~= nil then
                currentSelection[tostring(def)] = true
            end
        end

        local targetContainer = self:_GetTargetContainer("Dropdown", config)

        local row = Instance.new("Frame")
        row.Name = "DropdownRow_" .. dropName:gsub("%s+", "")
        row.BackgroundColor3 = LouisHub.CurrentTheme.SurfaceAlt
        row.BackgroundTransparency = 0.45
        row.BorderSizePixel = 0
        row.ClipsDescendants = false
        row.Size = UDim2.new(1, 0, 0, 32)
        row.ZIndex = 50
        row.Parent = targetContainer
        LouisHub:RegisterThemeProperty(row, "BackgroundColor3", "SurfaceAlt")

        local rCorner = Instance.new("UICorner")
        rCorner.CornerRadius = UDim.new(0, 7)
        rCorner.Parent = row

        local rStroke = Instance.new("UIStroke")
        rStroke.Thickness = 1
        rStroke.Color = LouisHub.CurrentTheme.Border
        rStroke.Transparency = 0.35
        rStroke.Parent = row
        LouisHub:RegisterThemeProperty(rStroke, "Color", "Border")

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "TitleLabel"
        titleLabel.BackgroundTransparency = 1
        titleLabel.Font = Enum.Font.GothamMedium
        titleLabel.TextSize = 11.5
        titleLabel.TextColor3 = LouisHub.CurrentTheme.Text
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
        titleLabel.Text = dropName
        titleLabel.Position = UDim2.fromOffset(8, 0)
        titleLabel.Size = UDim2.new(0.40, -8, 1, 0)
        titleLabel.ZIndex = 51
        titleLabel.Parent = row
        LouisHub:RegisterThemeProperty(titleLabel, "TextColor3", "Text")
        LouisHub:RegisterFontElement(titleLabel, "Medium")

        local selectorButton = Instance.new("TextButton")
        selectorButton.Name = "SelectorButton"
        selectorButton.AutoButtonColor = false
        selectorButton.BackgroundColor3 = LouisHub.CurrentTheme.Surface
        selectorButton.BackgroundTransparency = 0.3
        selectorButton.Size = UDim2.new(0.60, -8, 0, 22)
        selectorButton.Position = UDim2.new(0.40, 0, 0.5, -11)
        selectorButton.Text = ""
        selectorButton.ZIndex = 51
        selectorButton.Parent = row
        LouisHub:RegisterThemeProperty(selectorButton, "BackgroundColor3", "Surface")

        local sbCorner = Instance.new("UICorner")
        sbCorner.CornerRadius = UDim.new(0, 5)
        sbCorner.Parent = selectorButton

        local sbStroke = Instance.new("UIStroke")
        sbStroke.Thickness = 1
        sbStroke.Color = LouisHub.CurrentTheme.Border
        sbStroke.Transparency = 0.5
        sbStroke.Parent = selectorButton
        LouisHub:RegisterThemeProperty(sbStroke, "Color", "Border")

        local displayLabel = Instance.new("TextLabel")
        displayLabel.Name = "DisplayLabel"
        displayLabel.BackgroundTransparency = 1
        displayLabel.Font = Enum.Font.GothamMedium
        displayLabel.TextSize = 10.5
        displayLabel.TextColor3 = LouisHub.CurrentTheme.Highlight
        displayLabel.TextXAlignment = Enum.TextXAlignment.Left
        displayLabel.TextTruncate = Enum.TextTruncate.AtEnd
        displayLabel.Position = UDim2.fromOffset(6, 0)
        displayLabel.Size = UDim2.new(1, -24, 1, 0)
        displayLabel.ZIndex = 52
        displayLabel.Parent = selectorButton
        LouisHub:RegisterThemeProperty(displayLabel, "TextColor3", "Highlight")
        LouisHub:RegisterFontElement(displayLabel, "Medium")

        local arrowIcon = Instance.new("ImageLabel")
        arrowIcon.Name = "ArrowIcon"
        arrowIcon.BackgroundTransparency = 1
        arrowIcon.Size = UDim2.fromOffset(10, 10)
        arrowIcon.Position = UDim2.new(1, -16, 0.5, -5)
        arrowIcon.Image = "rbxassetid://6031090990"
        arrowIcon.ImageColor3 = LouisHub.CurrentTheme.TextMuted
        arrowIcon.Rotation = 0
        arrowIcon.ZIndex = 52
        arrowIcon.Parent = selectorButton

        local popoutMenu = Instance.new("Frame")
        popoutMenu.Name = "PopoutMenu"
        popoutMenu.BackgroundColor3 = LouisHub.CurrentTheme.Surface
        popoutMenu.BackgroundTransparency = 0.05
        popoutMenu.BorderSizePixel = 0
        popoutMenu.ClipsDescendants = true
        popoutMenu.Visible = false
        popoutMenu.Size = UDim2.new(0.60, -8, 0, 0)
        popoutMenu.Position = UDim2.new(0.40, 0, 1, 4)
        popoutMenu.ZIndex = 2500
        popoutMenu.Parent = row
        LouisHub:RegisterThemeProperty(popoutMenu, "BackgroundColor3", "Surface")

        local pmCorner = Instance.new("UICorner")
        pmCorner.CornerRadius = UDim.new(0, 6)
        pmCorner.Parent = popoutMenu

        local pmStroke = Instance.new("UIStroke")
        pmStroke.Thickness = 1
        pmStroke.Color = LouisHub.CurrentTheme.Accent
        pmStroke.Transparency = 0.4
        pmStroke.Parent = popoutMenu
        LouisHub:RegisterThemeProperty(pmStroke, "Color", "Accent")

        local searchBox = nil
        local needsSearch = #rawOptions > 6

        if needsSearch then
            searchBox = Instance.new("TextBox")
            searchBox.Name = "SearchBox"
            searchBox.BackgroundColor3 = LouisHub.CurrentTheme.SurfaceAlt
            searchBox.BackgroundTransparency = 0.3
            searchBox.BorderSizePixel = 0
            searchBox.Font = Enum.Font.Gotham
            searchBox.TextSize = 10
            searchBox.TextColor3 = LouisHub.CurrentTheme.Text
            searchBox.PlaceholderColor3 = LouisHub.CurrentTheme.TextMuted
            searchBox.PlaceholderText = "Search..."
            searchBox.Text = ""
            searchBox.ClearTextOnFocus = false
            searchBox.Size = UDim2.new(1, -12, 0, 20)
            searchBox.Position = UDim2.fromOffset(6, 6)
            searchBox.ZIndex = 2501
            searchBox.Parent = popoutMenu
            LouisHub:RegisterThemeProperty(searchBox, "BackgroundColor3", "SurfaceAlt")
            LouisHub:RegisterThemeProperty(searchBox, "TextColor3", "Text")
            LouisHub:RegisterFontElement(searchBox, "Regular")

            local sCorner = Instance.new("UICorner")
            sCorner.CornerRadius = UDim.new(0, 4)
            sCorner.Parent = searchBox

            local sPad = Instance.new("UIPadding")
            sPad.PaddingLeft = UDim.new(0, 6)
            sPad.Parent = searchBox
        end

        local optionsScroll = Instance.new("ScrollingFrame")
        optionsScroll.Name = "OptionsScroll"
        optionsScroll.BackgroundTransparency = 1
        optionsScroll.BorderSizePixel = 0
        optionsScroll.ScrollBarThickness = 2
        optionsScroll.ScrollBarImageColor3 = LouisHub.CurrentTheme.Accent
        optionsScroll.Size = UDim2.new(1, -8, 1, needsSearch and -32 or -8)
        optionsScroll.Position = UDim2.fromOffset(4, needsSearch and 30 or 4)
        optionsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        optionsScroll.CanvasSize = UDim2.fromOffset(0, 0)
        optionsScroll.ZIndex = 2501
        optionsScroll.Parent = popoutMenu

        local osLayout = Instance.new("UIListLayout")
        osLayout.SortOrder = Enum.SortOrder.LayoutOrder
        osLayout.Padding = UDim.new(0, 2)
        osLayout.Parent = optionsScroll

        local function updateDisplayLabel()
            if isMulti then
                local selectedList = {}
                for opt in pairs(currentSelection) do
                    table.insert(selectedList, opt)
                end
                table.sort(selectedList)
                if #selectedList == 0 then
                    displayLabel.Text = "None selected"
                else
                    displayLabel.Text = table.concat(selectedList, ", ")
                end
            else
                local picked = nil
                for opt in pairs(currentSelection) do
                    picked = opt
                    break
                end
                displayLabel.Text = picked or "None"
            end
        end

        local isOpen = false
        local optionButtonsMap = {}

        local function closeMenu()
            if not isOpen then return end
            isOpen = false
            row.ZIndex = 50
            LouisHub:Tween(arrowIcon, { Rotation = 0 }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            LouisHub:Tween(popoutMenu, { Size = UDim2.new(0.60, -8, 0, 0) }, 0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function()
                if not isOpen then popoutMenu.Visible = false end
            end)
        end

        local function openMenu()
            if isOpen or isDisabled then return end
            isOpen = true
            row.ZIndex = 2500
            popoutMenu.Visible = true

            local totalItemsHeight = math.min(#rawOptions * 22, 120)
            local targetHeight = totalItemsHeight + (needsSearch and 36 or 10)

            LouisHub:Tween(arrowIcon, { Rotation = 180 }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            LouisHub:Tween(popoutMenu, { Size = UDim2.new(0.60, -8, 0, targetHeight) }, 0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        end

        local function pickOption(optName, silent)
            if isMulti then
                if currentSelection[optName] then
                    currentSelection[optName] = nil
                else
                    currentSelection[optName] = true
                end
            else
                currentSelection = { [optName] = true }
                closeMenu()
            end

            for nameStr, btn in pairs(optionButtonsMap) do
                local isPicked = currentSelection[nameStr] == true
                btn.BackgroundColor3 = isPicked and LouisHub.CurrentTheme.Accent or LouisHub.CurrentTheme.SurfaceAlt
                btn.BackgroundTransparency = isPicked and 0.2 or 0.6
                local lbl = btn:FindFirstChildOfClass("TextLabel")
                if lbl then
                    lbl.TextColor3 = isPicked and Color3.fromRGB(255, 255, 255) or LouisHub.CurrentTheme.Text
                end
            end

            updateDisplayLabel()

            local resultValue = isMulti and currentSelection or optName
            LouisHub.Flags[flagKey] = resultValue

            if not silent and type(callback) == "function" then
                local success, err = pcall(callback, resultValue)
                if not success then LouisHub:Log("DropdownCallback", err) end
            end
        end

        local function rebuildOptions()
            for _, child in ipairs(optionsScroll:GetChildren()) do
                if child:IsA("TextButton") then child:Destroy() end
            end
            optionButtonsMap = {}

            for idx, opt in ipairs(rawOptions) do
                local optStr = tostring(opt)
                local isPicked = currentSelection[optStr] == true

                local btn = Instance.new("TextButton")
                btn.Name = "Opt_" .. optStr:gsub("%s+", "")
                btn.AutoButtonColor = false
                btn.BackgroundColor3 = isPicked and LouisHub.CurrentTheme.Accent or LouisHub.CurrentTheme.SurfaceAlt
                btn.BackgroundTransparency = isPicked and 0.2 or 0.6
                btn.Size = UDim2.new(1, 0, 0, 20)
                btn.Text = ""
                btn.ZIndex = 2502
                btn.Parent = optionsScroll

                local bCorner = Instance.new("UICorner")
                bCorner.CornerRadius = UDim.new(0, 4)
                bCorner.Parent = btn

                local lbl = Instance.new("TextLabel")
                lbl.BackgroundTransparency = 1
                lbl.Font = Enum.Font.GothamMedium
                lbl.TextSize = 10
                lbl.TextColor3 = isPicked and Color3.fromRGB(255, 255, 255) or LouisHub.CurrentTheme.Text
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.TextTruncate = Enum.TextTruncate.AtEnd
                lbl.Position = UDim2.fromOffset(6, 0)
                lbl.Size = UDim2.new(1, -12, 1, 0)
                lbl.Text = optStr
                lbl.ZIndex = 2503
                lbl.Parent = btn
                LouisHub:RegisterFontElement(lbl, "Medium")

                btn.MouseButton1Click:Connect(function()
                    pickOption(optStr, false)
                end)

                optionButtonsMap[optStr] = btn
            end
            updateDisplayLabel()
        end

        rebuildOptions()

        if searchBox then
            searchBox:GetPropertyChangedSignal("Text"):Connect(function()
                local query = searchBox.Text:lower()
                for nameStr, btn in pairs(optionButtonsMap) do
                    btn.Visible = (query == "") or (nameStr:lower():find(query, 1, true) ~= nil)
                end
            end)
        end

        selectorButton.MouseButton1Click:Connect(function()
            if isOpen then closeMenu() else openMenu() end
        end)

        LouisHub:ListenForOutsideClick(popoutMenu, closeMenu)

        if config.Tooltip then
            LouisHub:BindTooltip(row, config.Tooltip)
        end

        LouisHub.Flags[flagKey] = isMulti and currentSelection or (next(currentSelection))

        local DropdownControl = {
            Instance = row,
            Get = function()
                return isMulti and currentSelection or (next(currentSelection))
            end,
            Set = function(_, value, silent)
                if isMulti and type(value) == "table" then
                    currentSelection = {}
                    for k, v in pairs(value) do
                        if type(k) == "string" and v == true then
                            currentSelection[k] = true
                        elseif type(v) == "string" then
                            currentSelection[v] = true
                        end
                    end
                elseif not isMulti and value ~= nil then
                    currentSelection = { [tostring(value)] = true }
                end
                rebuildOptions()
                if not silent and type(callback) == "function" then
                    pcall(callback, isMulti and currentSelection or (next(currentSelection)))
                end
            end,
            SetOptions = function(_, newOptions)
                if type(newOptions) == "table" then
                    rawOptions = newOptions
                    needsSearch = #rawOptions > 6
                    rebuildOptions()
                end
            end,
            Refresh = function(selfDrop, newOptions)
                selfDrop:SetOptions(newOptions)
            end,
            SetDisabled = function(_, disabled)
                isDisabled = (disabled == true)
                row.BackgroundTransparency = isDisabled and 0.8 or 0.45
                selectorButton.Active = not isDisabled
                if isDisabled then closeMenu() end
            end,
            SetVisible = function(_, visible)
                row.Visible = (visible == true)
                if not visible then closeMenu() end
            end,
            Destroy = function()
                LouisHub.Elements[flagKey] = nil
                pcall(function() row:Destroy() end)
            end
        }

        LouisHub.Elements[flagKey] = DropdownControl

        if config.VisibleIf then
            LouisHub:RegisterConditional(DropdownControl, config.VisibleIf, "Visible")
        end
        if config.EnabledIf then
            LouisHub:RegisterConditional(DropdownControl, config.EnabledIf, "Enabled")
        end

        return DropdownControl
    end
    Section.CreateDropdown = Section.AddDropdown

    -- ── 2. TOUCH-SAFE COLORPICKER (HSV + ALPHA + HEX) ────────────────
    function Section:AddColorPicker(config)
        config = config or {}
        local pickerName = tostring(config.Name or config.Title or "Color Picker")
        local flagKey = config.Flag or ("ColorPicker_" .. pickerName:gsub("%s+", ""))
        local currentColor = config.Default or Color3.fromRGB(255, 255, 255)
        local currentAlpha = tonumber(config.Alpha or 1)
        local hasAlpha = config.ShowAlpha == true
        local callback = config.Callback
        local isDisabled = config.Disabled == true

        local curHue, curSat, curVal = currentColor:ToHSV()
        local targetContainer = self:_GetTargetContainer("ColorPicker", config)

        local row = Instance.new("Frame")
        row.Name = "ColorRow_" .. pickerName:gsub("%s+", "")
        row.BackgroundColor3 = LouisHub.CurrentTheme.SurfaceAlt
        row.BackgroundTransparency = 0.45
        row.BorderSizePixel = 0
        row.ClipsDescendants = false
        row.Size = UDim2.new(1, 0, 0, 32)
        row.ZIndex = 40
        row.Parent = targetContainer
        LouisHub:RegisterThemeProperty(row, "BackgroundColor3", "SurfaceAlt")

        local rCorner = Instance.new("UICorner")
        rCorner.CornerRadius = UDim.new(0, 7)
        rCorner.Parent = row

        local rStroke = Instance.new("UIStroke")
        rStroke.Thickness = 1
        rStroke.Color = LouisHub.CurrentTheme.Border
        rStroke.Transparency = 0.35
        rStroke.Parent = row
        LouisHub:RegisterThemeProperty(rStroke, "Color", "Border")

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "TitleLabel"
        titleLabel.BackgroundTransparency = 1
        titleLabel.Font = Enum.Font.GothamMedium
        titleLabel.TextSize = 11.5
        titleLabel.TextColor3 = LouisHub.CurrentTheme.Text
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.Text = pickerName
        titleLabel.Position = UDim2.fromOffset(8, 0)
        titleLabel.Size = UDim2.new(1, -64, 1, 0)
        titleLabel.Parent = row
        LouisHub:RegisterThemeProperty(titleLabel, "TextColor3", "Text")
        LouisHub:RegisterFontElement(titleLabel, "Medium")

        local swatchButton = Instance.new("TextButton")
        swatchButton.Name = "SwatchButton"
        swatchButton.AutoButtonColor = false
        swatchButton.BackgroundColor3 = currentColor
        swatchButton.Size = UDim2.fromOffset(36, 18)
        swatchButton.Position = UDim2.new(1, -44, 0.5, -9)
        swatchButton.Text = ""
        swatchButton.Parent = row

        local swCorner = Instance.new("UICorner")
        swCorner.CornerRadius = UDim.new(0, 4)
        swCorner.Parent = swatchButton

        local swStroke = Instance.new("UIStroke")
        swStroke.Thickness = 1
        swStroke.Color = LouisHub.CurrentTheme.Border
        swStroke.Transparency = 0.3
        swStroke.Parent = swatchButton
        LouisHub:RegisterThemeProperty(swStroke, "Color", "Border")

        local popout = Instance.new("Frame")
        popout.Name = "PickerPopout"
        popout.BackgroundColor3 = LouisHub.CurrentTheme.Surface
        popout.BackgroundTransparency = 0.05
        popout.BorderSizePixel = 0
        popout.ClipsDescendants = true
        popout.Visible = false
        popout.Size = UDim2.fromOffset(190, 0)
        popout.Position = UDim2.new(1, -190, 1, 4)
        popout.ZIndex = 2600
        popout.Parent = row
        LouisHub:RegisterThemeProperty(popout, "BackgroundColor3", "Surface")

        local pCorner = Instance.new("UICorner")
        pCorner.CornerRadius = UDim.new(0, 8)
        pCorner.Parent = popout

        local pStroke = Instance.new("UIStroke")
        pStroke.Thickness = 1
        pStroke.Color = LouisHub.CurrentTheme.Accent
        pStroke.Transparency = 0.4
        pStroke.Parent = popout
        LouisHub:RegisterThemeProperty(pStroke, "Color", "Accent")

        local pPad = Instance.new("UIPadding")
        pPad.PaddingLeft = UDim.new(0, 10)
        pPad.PaddingRight = UDim.new(0, 10)
        pPad.PaddingTop = UDim.new(0, 10)
        pPad.PaddingBottom = UDim.new(0, 10)
        pPad.Parent = popout

        local pLayout = Instance.new("UIListLayout")
        pLayout.SortOrder = Enum.SortOrder.LayoutOrder
        pLayout.Padding = UDim.new(0, 8)
        pLayout.Parent = popout

        -- Saturation & Value 2D Box
        local satValBox = Instance.new("ImageButton")
        satValBox.Name = "SatValBox"
        satValBox.AutoButtonColor = false
        satValBox.BackgroundColor3 = Color3.fromHSV(curHue, 1, 1)
        satValBox.BorderSizePixel = 0
        satValBox.Size = UDim2.new(1, 0, 0, 100)
        satValBox.LayoutOrder = 1
        satValBox.ZIndex = 2601
        satValBox.Parent = popout

        local svCorner = Instance.new("UICorner")
        svCorner.CornerRadius = UDim.new(0, 6)
        svCorner.Parent = satValBox

        local satGradient = Instance.new("UIGradient")
        satGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1.0, Color3.fromRGB(0, 0, 0))
        })
        satGradient.Rotation = 90
        satGradient.Parent = satValBox

        local svCursor = Instance.new("Frame")
        svCursor.Name = "Cursor"
        svCursor.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        svCursor.BorderSizePixel = 0
        svCursor.Size = UDim2.fromOffset(8, 8)
        svCursor.AnchorPoint = Vector2.new(0.5, 0.5)
        svCursor.Position = UDim2.new(curSat, 0, 1 - curVal, 0)
        svCursor.ZIndex = 2602
        svCursor.Parent = satValBox

        local svcCorner = Instance.new("UICorner")
        svcCorner.CornerRadius = UDim.new(0, 4)
        svcCorner.Parent = svCursor

        -- Hue Slider
        local hueBar = Instance.new("ImageButton")
        hueBar.Name = "HueBar"
        hueBar.AutoButtonColor = false
        hueBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        hueBar.BorderSizePixel = 0
        hueBar.Size = UDim2.new(1, 0, 0, 10)
        hueBar.LayoutOrder = 2
        hueBar.ZIndex = 2601
        hueBar.Parent = popout

        local hbCorner = Instance.new("UICorner")
        hbCorner.CornerRadius = UDim.new(0, 5)
        hbCorner.Parent = hueBar

        local hueGrad = Instance.new("UIGradient")
        hueGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromHSV(0.00, 1, 1)),
            ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
            ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
            ColorSequenceKeypoint.new(0.50, Color3.fromHSV(0.50, 1, 1)),
            ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
            ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
            ColorSequenceKeypoint.new(1.00, Color3.fromHSV(1.00, 1, 1))
        })
        hueGrad.Parent = hueBar

        local hueCursor = Instance.new("Frame")
        hueCursor.Name = "HueCursor"
        hueCursor.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        hueCursor.BorderSizePixel = 0
        hueCursor.Size = UDim2.fromOffset(4, 14)
        hueCursor.AnchorPoint = Vector2.new(0.5, 0.5)
        hueCursor.Position = UDim2.new(curHue, 0, 0.5, 0)
        hueCursor.ZIndex = 2602
        hueCursor.Parent = hueBar

        local hcCorner = Instance.new("UICorner")
        hcCorner.CornerRadius = UDim.new(0, 2)
        hcCorner.Parent = hueCursor

        -- Hexadecimal Manual Box
        local hexRow = Instance.new("Frame")
        hexRow.Name = "HexRow"
        hexRow.BackgroundTransparency = 1
        hexRow.Size = UDim2.new(1, 0, 0, 20)
        hexRow.LayoutOrder = 3
        hexRow.Parent = popout

        local hexLabel = Instance.new("TextLabel")
        hexLabel.BackgroundTransparency = 1
        hexLabel.Font = Enum.Font.GothamBold
        hexLabel.TextSize = 10
        hexLabel.TextColor3 = LouisHub.CurrentTheme.TextMuted
        hexLabel.TextXAlignment = Enum.TextXAlignment.Left
        hexLabel.Text = "HEX"
        hexLabel.Size = UDim2.new(0, 28, 1, 0)
        hexLabel.ZIndex = 2601
        hexLabel.Parent = hexRow
        LouisHub:RegisterFontElement(hexLabel, "Bold")

        local hexInput = Instance.new("TextBox")
        hexInput.Name = "HexInput"
        hexInput.BackgroundColor3 = LouisHub.CurrentTheme.SurfaceAlt
        hexInput.BorderSizePixel = 0
        hexInput.Font = Enum.Font.GothamMedium
        hexInput.TextSize = 10
        hexInput.TextColor3 = LouisHub.CurrentTheme.Highlight
        hexInput.ClearTextOnFocus = false
        hexInput.Size = UDim2.new(1, -32, 1, 0)
        hexInput.Position = UDim2.fromOffset(32, 0)
        hexInput.ZIndex = 2601
        hexInput.Parent = hexRow
        LouisHub:RegisterFontElement(hexInput, "Medium")

        local hiCorner = Instance.new("UICorner")
        hiCorner.CornerRadius = UDim.new(0, 4)
        hiCorner.Parent = hexInput

        local function colorToHex(c)
            return string.format("#%02X%02X%02X", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))
        end

        local function hexToColor(hex)
            local clean = hex:gsub("#", "")
            if #clean == 6 then
                local r = tonumber(clean:sub(1, 2), 16)
                local g = tonumber(clean:sub(3, 4), 16)
                local b = tonumber(clean:sub(5, 6), 16)
                if r and g and b then
                    return Color3.fromRGB(r, g, b)
                end
            end
            return nil
        end

        local function updateColorVisuals(fireCallback)
            local newCol = Color3.fromHSV(curHue, curSat, curVal)
            currentColor = newCol

            swatchButton.BackgroundColor3 = newCol
            satValBox.BackgroundColor3 = Color3.fromHSV(curHue, 1, 1)
            svCursor.Position = UDim2.new(curSat, 0, 1 - curVal, 0)
            hueCursor.Position = UDim2.new(curHue, 0, 0.5, 0)
            hexInput.Text = colorToHex(newCol)

            LouisHub.Flags[flagKey] = newCol

            if fireCallback and type(callback) == "function" then
                local success, err = pcall(callback, newCol, currentAlpha)
                if not success then LouisHub:Log("ColorPickerCallback", err) end
            end
        end

        local isOpen = false
        local function closePicker()
            if not isOpen then return end
            isOpen = false
            row.ZIndex = 40
            LouisHub:Tween(popout, { Size = UDim2.fromOffset(190, 0) }, 0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function()
                if not isOpen then popout.Visible = false end
            end)
        end

        local function openPicker()
            if isOpen or isDisabled then return end
            isOpen = true
            row.ZIndex = 2600
            popout.Visible = true
            local targetH = hasAlpha and 180 or 160
            LouisHub:Tween(popout, { Size = UDim2.fromOffset(190, targetH) }, 0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        end

        local isDraggingSatVal = false
        satValBox.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                isDraggingSatVal = true
                local absPos = satValBox.AbsolutePosition
                local absSize = satValBox.AbsoluteSize

                local function applySV(p)
                    curSat = math.clamp((p.X - absPos.X) / absSize.X, 0, 1)
                    curVal = 1 - math.clamp((p.Y - absPos.Y) / absSize.Y, 0, 1)
                    updateColorVisuals(true)
                end
                applySV(input.Position)

                local mConn, eConn
                mConn = UserInputService.InputChanged:Connect(function(mInput)
                    if isDraggingSatVal and (mInput.UserInputType == Enum.UserInputType.MouseMovement or mInput.UserInputType == Enum.UserInputType.Touch) then
                        applySV(mInput.Position)
                    end
                end)

                eConn = UserInputService.InputEnded:Connect(function(eInput)
                    if eInput.UserInputType == Enum.UserInputType.MouseButton1 or eInput.UserInputType == Enum.UserInputType.Touch then
                        isDraggingSatVal = false
                        if mConn then mConn:Disconnect() end
                        if eConn then eConn:Disconnect() end
                    end
                end)
            end
        end)

        local isDraggingHue = false
        hueBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                isDraggingHue = true
                local absPos = hueBar.AbsolutePosition
                local absSize = hueBar.AbsoluteSize

                local function applyHue(p)
                    curHue = math.clamp((p.X - absPos.X) / absSize.X, 0, 1)
                    updateColorVisuals(true)
                end
                applyHue(input.Position)

                local mConn, eConn
                mConn = UserInputService.InputChanged:Connect(function(mInput)
                    if isDraggingHue and (mInput.UserInputType == Enum.UserInputType.MouseMovement or mInput.UserInputType == Enum.UserInputType.Touch) then
                        applyHue(mInput.Position)
                    end
                end)

                eConn = UserInputService.InputEnded:Connect(function(eInput)
                    if eInput.UserInputType == Enum.UserInputType.MouseButton1 or eInput.UserInputType == Enum.UserInputType.Touch then
                        isDraggingHue = false
                        if mConn then mConn:Disconnect() end
                        if eConn then eConn:Disconnect() end
                    end
                end)
            end
        end)

        hexInput.FocusLost:Connect(function()
            local parsed = hexToColor(hexInput.Text)
            if parsed then
                curHue, curSat, curVal = parsed:ToHSV()
                updateColorVisuals(true)
                LouisHub:ApplyFlashFeedback(hexInput, true)
            else
                hexInput.Text = colorToHex(currentColor)
                LouisHub:ApplyFlashFeedback(hexInput, false)
            end
        end)

        swatchButton.MouseButton1Click:Connect(function()
            if isOpen then closePicker() else openPicker() end
        end)

        LouisHub:ListenForOutsideClick(popout, closePicker)

        if config.Tooltip then
            LouisHub:BindTooltip(row, config.Tooltip)
        end

        updateColorVisuals(false)

        local ColorPickerControl = {
            Instance = row,
            Get = function()
                return currentColor, currentAlpha
            end,
            Set = function(_, col, alpha, silent)
                if typeof(col) == "Color3" then
                    curHue, curSat, curVal = col:ToHSV()
                    if alpha then currentAlpha = math.clamp(tonumber(alpha) or 1, 0, 1) end
                    updateColorVisuals(not silent)
                end
            end,
            SetDisabled = function(_, disabled)
                isDisabled = (disabled == true)
                row.BackgroundTransparency = isDisabled and 0.8 or 0.45
                swatchButton.Active = not isDisabled
                if isDisabled then closePicker() end
            end,
            SetVisible = function(_, visible)
                row.Visible = (visible == true)
                if not visible then closePicker() end
            end,
            Destroy = function()
                LouisHub.Elements[flagKey] = nil
                pcall(function() row:Destroy() end)
            end
        }

        LouisHub.Elements[flagKey] = ColorPickerControl

        if config.VisibleIf then
            LouisHub:RegisterConditional(ColorPickerControl, config.VisibleIf, "Visible")
        end
        if config.EnabledIf then
            LouisHub:RegisterConditional(ColorPickerControl, config.EnabledIf, "Enabled")
        end

        return ColorPickerControl
    end
    Section.CreateColorPicker = Section.AddColorPicker

    -- ── 3. MULTI-MODIFIER KEYBIND CONTROL ────────────────────────────
    function Section:AddKeybind(config)
        config = config or {}
        local bindName = tostring(config.Name or config.Title or "Keybind")
        local flagKey = config.Flag or ("Keybind_" .. bindName:gsub("%s+", ""))
        local defaultKey = config.Default or Enum.KeyCode.Unknown
        local callback = config.Callback
        local mode = config.Mode or "Toggle"
        local isDisabled = config.Disabled == true

        local currentKey = defaultKey
        local isCtrl = false
        local isShift = false
        local isAlt = false

        if type(defaultKey) == "table" and defaultKey.KeyCode then
            currentKey = defaultKey.KeyCode
            isCtrl = defaultKey.Ctrl == true
            isShift = defaultKey.Shift == true
            isAlt = defaultKey.Alt == true
        end

        local isListening = false
        local targetContainer = self:_GetTargetContainer("Keybind", config)

        local row = Instance.new("Frame")
        row.Name = "KeybindRow_" .. bindName:gsub("%s+", "")
        row.BackgroundColor3 = LouisHub.CurrentTheme.SurfaceAlt
        row.BackgroundTransparency = 0.45
        row.BorderSizePixel = 0
        row.Size = UDim2.new(1, 0, 0, 32)
        row.Parent = targetContainer
        LouisHub:RegisterThemeProperty(row, "BackgroundColor3", "SurfaceAlt")

        local rCorner = Instance.new("UICorner")
        rCorner.CornerRadius = UDim.new(0, 7)
        rCorner.Parent = row

        local rStroke = Instance.new("UIStroke")
        rStroke.Thickness = 1
        rStroke.Color = LouisHub.CurrentTheme.Border
        rStroke.Transparency = 0.35
        rStroke.Parent = row
        LouisHub:RegisterThemeProperty(rStroke, "Color", "Border")

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "TitleLabel"
        titleLabel.BackgroundTransparency = 1
        titleLabel.Font = Enum.Font.GothamMedium
        titleLabel.TextSize = 11.5
        titleLabel.TextColor3 = LouisHub.CurrentTheme.Text
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.Text = bindName
        titleLabel.Position = UDim2.fromOffset(8, 0)
        titleLabel.Size = UDim2.new(1, -94, 1, 0)
        titleLabel.Parent = row
        LouisHub:RegisterThemeProperty(titleLabel, "TextColor3", "Text")
        LouisHub:RegisterFontElement(titleLabel, "Medium")

        local bindButton = Instance.new("TextButton")
        bindButton.Name = "BindButton"
        bindButton.AutoButtonColor = false
        bindButton.BackgroundColor3 = LouisHub.CurrentTheme.Surface
        bindButton.BackgroundTransparency = 0.3
        bindButton.Size = UDim2.fromOffset(78, 22)
        bindButton.Position = UDim2.new(1, -86, 0.5, -11)
        bindButton.Font = Enum.Font.GothamBold
        bindButton.TextSize = 10
        bindButton.TextColor3 = LouisHub.CurrentTheme.Highlight
        bindButton.Parent = row
        LouisHub:RegisterThemeProperty(bindButton, "BackgroundColor3", "Surface")
        LouisHub:RegisterThemeProperty(bindButton, "TextColor3", "Highlight")
        LouisHub:RegisterFontElement(bindButton, "Bold")

        local bbCorner = Instance.new("UICorner")
        bbCorner.CornerRadius = UDim.new(0, 4)
        bbCorner.Parent = bindButton

        local bbStroke = Instance.new("UIStroke")
        bbStroke.Thickness = 1
        bbStroke.Color = LouisHub.CurrentTheme.Border
        bbStroke.Transparency = 0.5
        bbStroke.Parent = bindButton
        LouisHub:RegisterThemeProperty(bbStroke, "Color", "Border")

        local function formatKeyCombo()
            if isListening then return "..." end
            if not currentKey or currentKey == Enum.KeyCode.Unknown then return "None" end

            local parts = {}
            if isCtrl then table.insert(parts, "Ctrl") end
            if isShift then table.insert(parts, "Shift") end
            if isAlt then table.insert(parts, "Alt") end
            table.insert(parts, currentKey.Name)
            return table.concat(parts, " + ")
        end

        local function updateDisplay()
            bindButton.Text = formatKeyCombo()
        end

        local function saveState()
            local packet = {
                KeyCode = currentKey,
                Ctrl = isCtrl,
                Shift = isShift,
                Alt = isAlt
            }
            LouisHub.Flags[flagKey] = packet
        end

        bindButton.MouseButton1Click:Connect(function()
            if isDisabled then return end
            isListening = true
            bindButton.Text = "..."
            bindButton.BackgroundColor3 = LouisHub.CurrentTheme.Accent

            local captureConn
            captureConn = UserInputService.InputBegan:Connect(function(input, processed)
                if processed then return end

                if input.KeyCode == Enum.KeyCode.Escape then
                    currentKey = Enum.KeyCode.Unknown
                    isCtrl = false
                    isShift = false
                    isAlt = false
                    isListening = false
                    bindButton.BackgroundColor3 = LouisHub.CurrentTheme.Surface
                    updateDisplay()
                    saveState()
                    captureConn:Disconnect()
                    return
                end

                if input.UserInputType == Enum.UserInputType.Keyboard then
                    local kc = input.KeyCode
                    local isModifier = (kc == Enum.KeyCode.LeftControl or kc == Enum.KeyCode.RightControl
                                     or kc == Enum.KeyCode.LeftShift or kc == Enum.KeyCode.RightShift
                                     or kc == Enum.KeyCode.LeftAlt or kc == Enum.KeyCode.RightAlt)

                    if not isModifier then
                        isCtrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
                        isShift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
                        isAlt = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)

                        currentKey = kc
                        isListening = false
                        bindButton.BackgroundColor3 = LouisHub.CurrentTheme.Surface
                        updateDisplay()
                        saveState()
                        captureConn:Disconnect()
                    end
                end
            end)
        end)

        local isDown = false
        local keyTriggerConn = UserInputService.InputBegan:Connect(function(input, processed)
            if processed or isListening or isDisabled then return end
            if input.KeyCode == currentKey and currentKey ~= Enum.KeyCode.Unknown then
                local ctrlMatch = not isCtrl or (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl))
                local shiftMatch = not isShift or (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift))
                local altMatch = not isAlt or (UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt))

                if ctrlMatch and shiftMatch and altMatch then
                    if mode == "Toggle" then
                        isDown = not isDown
                        if type(callback) == "function" then pcall(callback, isDown) end
                    elseif mode == "Hold" then
                        isDown = true
                        if type(callback) == "function" then pcall(callback, true) end
                    else
                        if type(callback) == "function" then pcall(callback) end
                    end
                end
            end
        end)
        LouisHub.RootJanitor:Add(keyTriggerConn)

        local keyReleaseConn = UserInputService.InputEnded:Connect(function(input)
            if mode == "Hold" and input.KeyCode == currentKey and isDown then
                isDown = false
                if type(callback) == "function" then pcall(callback, false) end
            end
        end)
        LouisHub.RootJanitor:Add(keyReleaseConn)

        if config.Tooltip then
            LouisHub:BindTooltip(row, config.Tooltip)
        end

        updateDisplay()
        saveState()

        local KeybindControl = {
            Instance = row,
            Get = function()
                return { KeyCode = currentKey, Ctrl = isCtrl, Shift = isShift, Alt = isAlt }
            end,
            Set = function(_, bindVal)
                if typeof(bindVal) == "EnumItem" then
                    currentKey = bindVal
                    isCtrl = false
                    isShift = false
                    isAlt = false
                elseif type(bindVal) == "table" and bindVal.KeyCode then
                    currentKey = bindVal.KeyCode
                    isCtrl = bindVal.Ctrl == true
                    isShift = bindVal.Shift == true
                    isAlt = bindVal.Alt == true
                end
                updateDisplay()
                saveState()
            end,
            SetDisabled = function(_, disabled)
                isDisabled = (disabled == true)
                row.BackgroundTransparency = isDisabled and 0.8 or 0.45
                bindButton.Active = not isDisabled
            end,
            SetVisible = function(_, visible)
                row.Visible = (visible == true)
            end,
            Destroy = function()
                LouisHub.Elements[flagKey] = nil
                pcall(function() row:Destroy() end)
            end
        }

        LouisHub.Elements[flagKey] = KeybindControl

        if config.VisibleIf then
            LouisHub:RegisterConditional(KeybindControl, config.VisibleIf, "Visible")
        end
        if config.EnabledIf then
            LouisHub:RegisterConditional(KeybindControl, config.EnabledIf, "Enabled")
        end

        return KeybindControl
    end
    Section.CreateKeybind = Section.AddKeybind
    Section.AddBind = Section.AddKeybind
    Section.CreateBind = Section.AddKeybind
end

-- LOUIS HUB | PART 5A | continues in PART 5B

-- =====================================================================
-- SECTION 29: INFORMATIONAL & LAYOUT ELEMENTS
-- =====================================================================
local PreviousApplySectionControls_5A = LouisHub.ApplySectionControls

function LouisHub:ApplySectionControls(Section)
    if PreviousApplySectionControls_5A then
        PreviousApplySectionControls_5A(self, Section)
    end

    -- ── 1. LIVE LABEL ELEMENT ────────────────────────────────────────
    function Section:AddLabel(config)
        if type(config) == "string" then
            config = { Text = config }
        end
        config = config or {}

        local labelTitle = tostring(config.Text or config.Name or config.Title or "Label")
        local valueText = config.Value ~= nil and tostring(config.Value) or nil
        local flagKey = config.Flag
        local targetContainer = self:_GetTargetContainer("Label", config)

        local row = Instance.new("Frame")
        row.Name = "LabelRow_" .. labelTitle:gsub("%s+", "")
        row.BackgroundColor3 = LouisHub.CurrentTheme.SurfaceAlt
        row.BackgroundTransparency = 0.45
        row.BorderSizePixel = 0
        row.Size = UDim2.new(1, 0, 0, 30)
        row.Parent = targetContainer
        LouisHub:RegisterThemeProperty(row, "BackgroundColor3", "SurfaceAlt")

        local rCorner = Instance.new("UICorner")
        rCorner.CornerRadius = UDim.new(0, 7)
        rCorner.Parent = row

        local rStroke = Instance.new("UIStroke")
        rStroke.Thickness = 1
        rStroke.Color = LouisHub.CurrentTheme.Border
        rStroke.Transparency = 0.35
        rStroke.Parent = row
        LouisHub:RegisterThemeProperty(rStroke, "Color", "Border")

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "TitleLabel"
        titleLabel.BackgroundTransparency = 1
        titleLabel.Font = Enum.Font.GothamMedium
        titleLabel.TextSize = 11.5
        titleLabel.TextColor3 = LouisHub.CurrentTheme.Text
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
        titleLabel.Text = labelTitle
        titleLabel.Position = UDim2.fromOffset(8, 0)
        titleLabel.Size = valueText and UDim2.new(0.60, -8, 1, 0) or UDim2.new(1, -16, 1, 0)
        titleLabel.Parent = row
        LouisHub:RegisterThemeProperty(titleLabel, "TextColor3", "Text")
        LouisHub:RegisterFontElement(titleLabel, "Medium")

        local valueLabel = nil
        if valueText then
            valueLabel = Instance.new("TextLabel")
            valueLabel.Name = "ValueLabel"
            valueLabel.BackgroundTransparency = 1
            valueLabel.Font = Enum.Font.GothamBold
            valueLabel.TextSize = 10.5
            valueLabel.TextColor3 = LouisHub.CurrentTheme.AccentAlt
            valueLabel.TextXAlignment = Enum.TextXAlignment.Right
            valueLabel.TextTruncate = Enum.TextTruncate.AtEnd
            valueLabel.Text = valueText
            valueLabel.Position = UDim2.new(0.60, 0, 0, 0)
            valueLabel.Size = UDim2.new(0.40, -8, 1, 0)
            valueLabel.Parent = row
            LouisHub:RegisterThemeProperty(valueLabel, "TextColor3", "AccentAlt")
            LouisHub:RegisterFontElement(valueLabel, "Bold")
        end

        if config.Tooltip then
            LouisHub:BindTooltip(row, config.Tooltip)
        end

        if flagKey then
            LouisHub.Flags[flagKey] = valueText or labelTitle
        end

        local LabelControl = {
            Instance = row,
            Set = function(_, newPrimary, newSecondary)
                if newSecondary ~= nil and valueLabel then
                    titleLabel.Text = tostring(newPrimary)
                    valueLabel.Text = tostring(newSecondary)
                    if flagKey then LouisHub.Flags[flagKey] = tostring(newSecondary) end
                elseif valueLabel then
                    valueLabel.Text = tostring(newPrimary)
                    if flagKey then LouisHub.Flags[flagKey] = tostring(newPrimary) end
                else
                    titleLabel.Text = tostring(newPrimary)
                    if flagKey then LouisHub.Flags[flagKey] = tostring(newPrimary) end
                end
            end,
            SetText = function(selfLbl, text)
                selfLbl:Set(text)
            end,
            SetVisible = function(_, visible)
                row.Visible = (visible == true)
            end,
            Destroy = function()
                if flagKey then LouisHub.Elements[flagKey] = nil end
                pcall(function() row:Destroy() end)
            end
        }

        if flagKey then
            LouisHub.Elements[flagKey] = LabelControl
        end

        if config.VisibleIf then
            LouisHub:RegisterConditional(LabelControl, config.VisibleIf, "Visible")
        end

        return LabelControl
    end
    Section.CreateLabel = Section.AddLabel

    -- ── 2. DYNAMIC PARAGRAPH ELEMENT ─────────────────────────────────
    function Section:AddParagraph(config)
        if type(config) == "string" then
            config = { Title = "Information", Content = config }
        end
        config = config or {}

        local pTitle = tostring(config.Title or config.Name or "Notice")
        local pContent = tostring(config.Content or config.Text or config.Body or "")
        local targetContainer = self:_GetTargetContainer("Paragraph", config)

        local card = Instance.new("Frame")
        card.Name = "ParagraphCard_" .. pTitle:gsub("%s+", "")
        card.BackgroundColor3 = LouisHub.CurrentTheme.SurfaceAlt
        card.BackgroundTransparency = 0.45
        card.BorderSizePixel = 0
        card.Size = UDim2.new(1, 0, 0, 0)
        card.AutomaticSize = Enum.AutomaticSize.Y
        card.Parent = targetContainer
        LouisHub:RegisterThemeProperty(card, "BackgroundColor3", "SurfaceAlt")

        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(0, 7)
        cCorner.Parent = card

        local cStroke = Instance.new("UIStroke")
        cStroke.Thickness = 1
        cStroke.Color = LouisHub.CurrentTheme.Border
        cStroke.Transparency = 0.35
        cStroke.Parent = card
        LouisHub:RegisterThemeProperty(cStroke, "Color", "Border")

        local cPad = Instance.new("UIPadding")
        cPad.PaddingLeft = UDim.new(0, 10)
        cPad.PaddingRight = UDim.new(0, 10)
        cPad.PaddingTop = UDim.new(0, 8)
        cPad.PaddingBottom = UDim.new(0, 8)
        cPad.Parent = card

        local cLayout = Instance.new("UIListLayout")
        cLayout.SortOrder = Enum.SortOrder.LayoutOrder
        cLayout.Padding = UDim.new(0, 4)
        cLayout.Parent = card

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "Title"
        titleLabel.BackgroundTransparency = 1
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextSize = 11.5
        titleLabel.TextColor3 = LouisHub.CurrentTheme.Highlight
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.Text = pTitle
        titleLabel.Size = UDim2.new(1, 0, 0, 14)
        titleLabel.LayoutOrder = 1
        titleLabel.Parent = card
        LouisHub:RegisterThemeProperty(titleLabel, "TextColor3", "Highlight")
        LouisHub:RegisterFontElement(titleLabel, "Bold")

        local bodyLabel = Instance.new("TextLabel")
        bodyLabel.Name = "Body"
        bodyLabel.BackgroundTransparency = 1
        bodyLabel.Font = Enum.Font.Gotham
        bodyLabel.TextSize = 10.5
        bodyLabel.TextColor3 = LouisHub.CurrentTheme.Text
        bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
        bodyLabel.TextWrapped = true
        bodyLabel.Text = pContent
        bodyLabel.Size = UDim2.new(1, 0, 0, 0)
        bodyLabel.AutomaticSize = Enum.AutomaticSize.Y
        bodyLabel.LayoutOrder = 2
        bodyLabel.Parent = card
        LouisHub:RegisterThemeProperty(bodyLabel, "TextColor3", "Text")
        LouisHub:RegisterFontElement(bodyLabel, "Regular")

        local ParagraphControl = {
            Instance = card,
            Set = function(_, newContent, newTitle)
                if newTitle then titleLabel.Text = tostring(newTitle) end
                if newContent then bodyLabel.Text = tostring(newContent) end
            end,
            SetTitle = function(_, newTitle)
                titleLabel.Text = tostring(newTitle)
            end,
            SetContent = function(_, newContent)
                bodyLabel.Text = tostring(newContent)
            end,
            SetVisible = function(_, visible)
                card.Visible = (visible == true)
            end,
            Destroy = function()
                pcall(function() card:Destroy() end)
            end
        }

        if config.VisibleIf then
            LouisHub:RegisterConditional(ParagraphControl, config.VisibleIf, "Visible")
        end

        return ParagraphControl
    end
    Section.CreateParagraph = Section.AddParagraph

    -- ── 3. ANIMATED PROGRESS BAR ELEMENT ─────────────────────────────
    function Section:AddProgressBar(config)
        config = config or {}
        local progressTitle = tostring(config.Name or config.Title or "Progress")
        local flagKey = config.Flag or ("Progress_" .. progressTitle:gsub("%s+", ""))
        local currentPercent = math.clamp(tonumber(config.Default or config.Progress or 0) or 0, 0, 100)
        local targetContainer = self:_GetTargetContainer("ProgressBar", config)

        local row = Instance.new("Frame")
        row.Name = "ProgressRow_" .. progressTitle:gsub("%s+", "")
        row.BackgroundColor3 = LouisHub.CurrentTheme.SurfaceAlt
        row.BackgroundTransparency = 0.45
        row.BorderSizePixel = 0
        row.Size = UDim2.new(1, 0, 0, 36)
        row.Parent = targetContainer
        LouisHub:RegisterThemeProperty(row, "BackgroundColor3", "SurfaceAlt")

        local rCorner = Instance.new("UICorner")
        rCorner.CornerRadius = UDim.new(0, 7)
        rCorner.Parent = row

        local rStroke = Instance.new("UIStroke")
        rStroke.Thickness = 1
        rStroke.Color = LouisHub.CurrentTheme.Border
        rStroke.Transparency = 0.35
        rStroke.Parent = row
        LouisHub:RegisterThemeProperty(rStroke, "Color", "Border")

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "TitleLabel"
        titleLabel.BackgroundTransparency = 1
        titleLabel.Font = Enum.Font.GothamMedium
        titleLabel.TextSize = 11.5
        titleLabel.TextColor3 = LouisHub.CurrentTheme.Text
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.Text = progressTitle
        titleLabel.Position = UDim2.fromOffset(8, 4)
        titleLabel.Size = UDim2.new(1, -64, 0, 14)
        titleLabel.Parent = row
        LouisHub:RegisterThemeProperty(titleLabel, "TextColor3", "Text")
        LouisHub:RegisterFontElement(titleLabel, "Medium")

        local percentLabel = Instance.new("TextLabel")
        percentLabel.Name = "PercentLabel"
        percentLabel.BackgroundTransparency = 1
        percentLabel.Font = Enum.Font.GothamBold
        percentLabel.TextSize = 10
        percentLabel.TextColor3 = LouisHub.CurrentTheme.AccentAlt
        percentLabel.TextXAlignment = Enum.TextXAlignment.Right
        percentLabel.Text = tostring(math.round(currentPercent)) .. "%"
        percentLabel.Position = UDim2.new(1, -56, 0, 4)
        percentLabel.Size = UDim2.fromOffset(48, 14)
        percentLabel.Parent = row
        LouisHub:RegisterThemeProperty(percentLabel, "TextColor3", "AccentAlt")
        LouisHub:RegisterFontElement(percentLabel, "Bold")

        local trackFrame = Instance.new("Frame")
        trackFrame.Name = "Track"
        trackFrame.BackgroundColor3 = LouisHub.CurrentTheme.Surface
        trackFrame.BorderSizePixel = 0
        trackFrame.Size = UDim2.new(1, -16, 0, 6)
        trackFrame.Position = UDim2.fromOffset(8, 22)
        trackFrame.Parent = row
        LouisHub:RegisterThemeProperty(trackFrame, "BackgroundColor3", "Surface")

        local trCorner = Instance.new("UICorner")
        trCorner.CornerRadius = UDim.new(0, 3)
        trCorner.Parent = trackFrame

        local fillBar = Instance.new("Frame")
        fillBar.Name = "Fill"
        fillBar.BackgroundColor3 = LouisHub.CurrentTheme.Accent
        fillBar.BorderSizePixel = 0
        fillBar.Size = UDim2.new(currentPercent / 100, 0, 1, 0)
        fillBar.Parent = trackFrame
        LouisHub:RegisterThemeProperty(fillBar, "BackgroundColor3", "Accent")

        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(0, 3)
        fillCorner.Parent = fillBar

        local fillGrad = Instance.new("UIGradient")
        fillGrad.Parent = fillBar
        LouisHub:RegisterGradient(fillGrad)

        local function updateProgress(newVal)
            local clamped = math.clamp(tonumber(newVal) or 0, 0, 100)
            currentPercent = clamped
            percentLabel.Text = tostring(math.round(clamped)) .. "%"
            LouisHub:Tween(fillBar, { Size = UDim2.new(clamped / 100, 0, 1, 0) }, 0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            LouisHub.Flags[flagKey] = clamped
        end

        LouisHub.Flags[flagKey] = currentPercent

        local ProgressBarControl = {
            Instance = row,
            Get = function()
                return currentPercent
            end,
            Set = function(_, percent)
                updateProgress(percent)
            end,
            SetVisible = function(_, visible)
                row.Visible = (visible == true)
            end,
            Destroy = function()
                LouisHub.Elements[flagKey] = nil
                pcall(function() row:Destroy() end)
            end
        }

        LouisHub.Elements[flagKey] = ProgressBarControl

        if config.VisibleIf then
            LouisHub:RegisterConditional(ProgressBarControl, config.VisibleIf, "Visible")
        end

        return ProgressBarControl
    end
    Section.CreateProgressBar = Section.AddProgressBar

    -- ── 4. ACCENT DIVIDER ELEMENT ────────────────────────────────────
    function Section:AddDivider(config)
        if type(config) == "string" then
            config = { Text = config }
        end
        config = config or {}

        local dividerText = config.Text or config.Title
        local targetContainer = self:_GetTargetContainer("Divider", config)

        local dividerFrame = Instance.new("Frame")
        dividerFrame.Name = "Divider"
        dividerFrame.BackgroundTransparency = 1
        dividerFrame.Size = UDim2.new(1, 0, 0, dividerText and 22 or 10)
        dividerFrame.Parent = targetContainer

        if dividerText then
            local label = Instance.new("TextLabel")
            label.Name = "DividerText"
            label.BackgroundTransparency = 1
            label.Font = Enum.Font.GothamBold
            label.TextSize = 9.5
            label.TextColor3 = LouisHub.CurrentTheme.TextMuted
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Text = string.upper(tostring(dividerText))
            label.Position = UDim2.fromOffset(4, 0)
            label.Size = UDim2.new(1, -8, 0, 12)
            label.Parent = dividerFrame
            LouisHub:RegisterThemeProperty(label, "TextColor3", "TextMuted")
            LouisHub:RegisterFontElement(label, "Bold")
        end

        local line = Instance.new("Frame")
        line.Name = "Line"
        line.BackgroundColor3 = LouisHub.CurrentTheme.Accent
        line.BackgroundTransparency = 0.5
        line.BorderSizePixel = 0
        line.Size = UDim2.new(1, -8, 0, 1)
        line.Position = UDim2.new(0, 4, 1, -2)
        line.Parent = dividerFrame
        LouisHub:RegisterThemeProperty(line, "BackgroundColor3", "Accent")

        local lineGrad = Instance.new("UIGradient")
        lineGrad.Parent = line
        LouisHub:RegisterGradient(lineGrad)

        return {
            Instance = dividerFrame,
            SetText = function(_, newText)
                local txt = dividerFrame:FindFirstChild("DividerText")
                if txt then
                    txt.Text = string.upper(tostring(newText))
                end
            end,
            SetVisible = function(_, visible)
                dividerFrame.Visible = (visible == true)
            end,
            Destroy = function()
                pcall(function() dividerFrame:Destroy() end)
            end
        }
    end
    Section.CreateDivider = Section.AddDivider

    -- ── 5. ASPECT-FIT IMAGE VIEWER ───────────────────────────────────
    function Section:AddImage(config)
        config = config or {}
        local imageAsset = config.Asset or config.Image or config.Url or ""
        local imageHeight = tonumber(config.Height) or 100
        local targetContainer = self:_GetTargetContainer("Image", config)

        local container = Instance.new("Frame")
        container.Name = "ImageHolder"
        container.BackgroundColor3 = LouisHub.CurrentTheme.SurfaceAlt
        container.BackgroundTransparency = 0.45
        container.BorderSizePixel = 0
        container.Size = UDim2.new(1, 0, 0, imageHeight)
        container.ClipsDescendants = true
        container.Parent = targetContainer
        LouisHub:RegisterThemeProperty(container, "BackgroundColor3", "SurfaceAlt")

        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(0, 7)
        cCorner.Parent = container

        local cStroke = Instance.new("UIStroke")
        cStroke.Thickness = 1
        cStroke.Color = LouisHub.CurrentTheme.Border
        cStroke.Transparency = 0.35
        cStroke.Parent = container
        LouisHub:RegisterThemeProperty(cStroke, "Color", "Border")

        local imgLabel = Instance.new("ImageLabel")
        imgLabel.Name = "DisplayImage"
        imgLabel.BackgroundTransparency = 1
        imgLabel.ScaleType = Enum.ScaleType.Fit
        imgLabel.Size = UDim2.new(1, -8, 1, -8)
        imgLabel.Position = UDim2.fromOffset(4, 4)
        imgLabel.Image = tostring(imageAsset)
        imgLabel.Parent = container

        local ImageControl = {
            Instance = container,
            ImageLabel = imgLabel,
            Set = function(_, newAsset)
                imgLabel.Image = tostring(newAsset)
            end,
            SetImage = function(selfImg, newAsset)
                selfImg:Set(newAsset)
            end,
            SetVisible = function(_, visible)
                container.Visible = (visible == true)
            end,
            Destroy = function()
                pcall(function() container:Destroy() end)
            end
        }

        if config.VisibleIf then
            LouisHub:RegisterConditional(ImageControl, config.VisibleIf, "Visible")
        end

        return ImageControl
    end
    Section.CreateImage = Section.AddImage

    -- ── 6. COMPACT ELEMENT GROUP ─────────────────────────────────────
    function Section:AddGroup(config)
        config = config or {}
        local groupHeight = tonumber(config.Height) or 30
        local targetContainer = self:_GetTargetContainer("Group", config)

        local row = Instance.new("Frame")
        row.Name = "ElementGroupRow"
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1, 0, 0, groupHeight)
        row.Parent = targetContainer

        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        layout.VerticalAlignment = Enum.VerticalAlignment.Center
        layout.Padding = UDim.new(0, 6)
        layout.Parent = row

        local buttonsList = {}

        local GroupController = {
            Instance = row,
            AddButton = function(_, btnConfig)
                btnConfig = btnConfig or {}
                local title = tostring(btnConfig.Name or btnConfig.Text or "Action")
                local callback = btnConfig.Callback

                local btn = Instance.new("TextButton")
                btn.Name = "GroupBtn_" .. title:gsub("%s+", "")
                btn.AutoButtonColor = false
                btn.BackgroundColor3 = LouisHub.CurrentTheme.SurfaceAlt
                btn.Size = UDim2.new(0, 0, 1, 0)
                btn.Text = ""
                btn.Parent = row
                LouisHub:RegisterThemeProperty(btn, "BackgroundColor3", "SurfaceAlt")

                local bCorner = Instance.new("UICorner")
                bCorner.CornerRadius = UDim.new(0, 5)
                bCorner.Parent = btn

                local bStroke = Instance.new("UIStroke")
                bStroke.Thickness = 1
                bStroke.Color = LouisHub.CurrentTheme.Border
                bStroke.Transparency = 0.4
                bStroke.Parent = btn
                LouisHub:RegisterThemeProperty(bStroke, "Color", "Border")

                local bPad = Instance.new("UIPadding")
                bPad.PaddingLeft = UDim.new(0, 8)
                bPad.PaddingRight = UDim.new(0, 8)
                bPad.Parent = btn

                local bLabel = Instance.new("TextLabel")
                bLabel.BackgroundTransparency = 1
                bLabel.Font = Enum.Font.GothamMedium
                bLabel.TextSize = 10.5
                bLabel.TextColor3 = LouisHub.CurrentTheme.Text
                bLabel.Text = title
                bLabel.Size = UDim2.new(1, 0, 1, 0)
                bLabel.Parent = btn
                LouisHub:RegisterThemeProperty(bLabel, "TextColor3", "Text")
                LouisHub:RegisterFontElement(bLabel, "Medium")

                btn.MouseButton1Click:Connect(function()
                    LouisHub:ApplyPressAnimation(btn, 0.92)
                    if type(callback) == "function" then
                        pcall(callback)
                    end
                end)

                table.insert(buttonsList, btn)

                local total = #buttonsList
                for _, b in ipairs(buttonsList) do
                    b.Size = UDim2.new(1 / total, -math.floor(6 * (total - 1) / total), 1, 0)
                end

                return btn
            end,
            SetVisible = function(_, visible)
                row.Visible = (visible == true)
            end,
            Destroy = function()
                pcall(function() row:Destroy() end)
            end
        }

        return GroupController
    end
    Section.CreateGroup = Section.AddGroup

    -- ── 7. BULK BUILDER DISPATCHER ───────────────────────────────────
    function Section:Build(elementDefinitions)
        if type(elementDefinitions) ~= "table" then return {} end
        local builtControls = {}

        for _, def in ipairs(elementDefinitions) do
            local controlType = def.Type or def.Control
            if type(controlType) == "string" then
                local methodName = "Add" .. controlType
                if type(self[methodName]) == "function" then
                    local control = self[methodName](self, def)
                    table.insert(builtControls, control)
                    if def.Flag then
                        builtControls[def.Flag] = control
                    end
                end
            end
        end

        return builtControls
    end
end

-- LOUIS HUB | PART 5B | continues in PART 5C

-- =====================================================================
-- SECTION 30: GLOBAL SEARCH FILTER ENGINE
-- =====================================================================
local SearchableElementsRegistry = {}

function LouisHub:RegisterSearchTarget(guiRow, labelText, sectionRef)
    if not guiRow or not labelText then return end
    table.insert(SearchableElementsRegistry, {
        Row = guiRow,
        Text = tostring(labelText):lower(),
        Section = sectionRef
    })

    guiRow.Destroying:Connect(function()
        for idx = #SearchableElementsRegistry, 1, -1 do
            if SearchableElementsRegistry[idx].Row == guiRow then
                table.remove(SearchableElementsRegistry, idx)
                break
            end
        end
    end)
end

function LouisHub:PerformSearch(queryText)
    local query = tostring(queryText or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local isSearching = query ~= ""

    local affectedSections = {}

    for _, entry in ipairs(SearchableElementsRegistry) do
        local row = entry.Row
        local sec = entry.Section

        if row and row.Parent then
            local matches = (not isSearching) or (entry.Text:find(query, 1, true) ~= nil)
            row.Visible = matches

            if sec then
                affectedSections[sec] = affectedSections[sec] or { HasMatch = false, AnyChildren = true }
                if matches then
                    affectedSections[sec].HasMatch = true
                end
            end
        end
    end

    for sec, status in pairs(affectedSections) do
        if isSearching then
            if status.HasMatch then
                sec.Card.Visible = true
                if sec.IsCollapsed then
                    sec.WasCollapsedBeforeSearch = true
                    sec:ToggleCollapse(false)
                end
            else
                sec.Card.Visible = false
            end
        else
            sec.Card.Visible = true
            if sec.WasCollapsedBeforeSearch ~= nil then
                sec:ToggleCollapse(sec.WasCollapsedBeforeSearch)
                sec.WasCollapsedBeforeSearch = nil
            end
        end
    end
end

-- =====================================================================
-- SECTION 31: COMPACT ADAPTIVE HUD STATS OVERLAY (WITH LOCK & TOGGLE)
-- =====================================================================
local ActiveHudInstances = {}

function LouisHub:HUD(hudConfig)
    hudConfig = hudConfig or {}
    local hudName = tostring(hudConfig.Name or hudConfig.Title or "StatusHUD")
    if ActiveHudInstances[hudName] then
        return ActiveHudInstances[hudName]
    end

    local safeParent = self:GetSafeContainer()
    local hudGui = Instance.new("ScreenGui")
    hudGui.Name = "LouisHub_HUD_" .. hudName
    hudGui.ResetOnSpawn = false
    hudGui.IgnoreGuiInset = true
    hudGui.DisplayOrder = 800000
    hudGui.Parent = safeParent
    self:ProtectContainer(hudGui)
    self.RootJanitor:Add(hudGui)

    local initialPos = hudConfig.Position or UDim2.fromOffset(24, 24)
    local isLocked = hudConfig.Locked == true

    -- Frame utama otomatis menyesuaikan isi (shrink-to-fit)
    local hudFrame = Instance.new("Frame")
    hudFrame.Name = "HUDCard"
    hudFrame.BackgroundColor3 = self.CurrentTheme.Surface
    hudFrame.BackgroundTransparency = 0.25
    hudFrame.BorderSizePixel = 0
    hudFrame.Size = UDim2.fromOffset(0, 0)
    hudFrame.Position = initialPos
    hudFrame.AutomaticSize = Enum.AutomaticSize.XY
    hudFrame.ClipsDescendants = false
    hudFrame.Parent = hudGui
    hudFrame:SetAttribute("DragLocked", isLocked)
    self:RegisterThemeProperty(hudFrame, "BackgroundColor3", "Surface")

    local hCorner = Instance.new("UICorner")
    hCorner.CornerRadius = UDim.new(0, 8)
    hCorner.Parent = hudFrame

    local hStroke = Instance.new("UIStroke")
    hStroke.Thickness = 1.2
    hStroke.Color = self.CurrentTheme.Border
    hStroke.Transparency = 0.35
    hStroke.Parent = hudFrame
    self:RegisterThemeProperty(hStroke, "Color", "Border")

    local hPad = Instance.new("UIPadding")
    hPad.PaddingLeft = UDim.new(0, 10)
    hPad.PaddingRight = UDim.new(0, 10)
    hPad.PaddingTop = UDim.new(0, 8)
    hPad.PaddingBottom = UDim.new(0, 8)
    hPad.Parent = hudFrame

    local hLayout = Instance.new("UIListLayout")
    hLayout.SortOrder = Enum.SortOrder.LayoutOrder
    hLayout.Padding = UDim.new(0, 5)
    hLayout.Parent = hudFrame

    -- Drag handler bawaan yang ramah fungsi Lock
    self:MakeDraggable(hudFrame, hudFrame)

    local registeredItems = {}
    
    local function addHudItem(itemConfig)
        local flagKey = itemConfig.Flag or itemConfig.Name
        local itemTitle = tostring(itemConfig.Title or itemConfig.Name or "")
        local defaultValue = itemConfig.Value or "--"
        local suffixStr = tostring(itemConfig.Suffix or "")
        local isBar = itemConfig.Type == "Bar" or itemConfig.Type == "bar"

        local itemRow = Instance.new("Frame")
        itemRow.Name = "Item_" .. tostring(flagKey)
        itemRow.BackgroundTransparency = 1
        itemRow.Size = UDim2.fromOffset(0, isBar and 24 or 16)
        itemRow.AutomaticSize = Enum.AutomaticSize.X
        itemRow.Parent = hudFrame

        local rowLayout = Instance.new("UIListLayout")
        rowLayout.FillDirection = Enum.FillDirection.Horizontal
        rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        rowLayout.Padding = UDim.new(0, 6)
        rowLayout.Parent = itemRow

        if itemConfig.Icon then
            local iconHolder = Instance.new("Frame")
            iconHolder.BackgroundTransparency = 1
            iconHolder.Size = UDim2.fromOffset(14, 14)
            iconHolder.Parent = itemRow
            LouisHub:MountIcon(iconHolder, itemConfig.Icon, 12, LouisHub.CurrentTheme.Accent)
        end

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "TitleLabel"
        titleLabel.BackgroundTransparency = 1
        titleLabel.Font = Enum.Font.GothamMedium
        titleLabel.TextSize = 10.5
        titleLabel.TextColor3 = LouisHub.CurrentTheme.TextMuted
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.Text = itemTitle .. ":"
        titleLabel.Size = UDim2.fromOffset(0, 14)
        titleLabel.AutomaticSize = Enum.AutomaticSize.X
        titleLabel.Parent = itemRow
        LouisHub:RegisterThemeProperty(titleLabel, "TextColor3", "TextMuted")
        LouisHub:RegisterFontElement(titleLabel, "Medium")

        local valueLabel = Instance.new("TextLabel")
        valueLabel.Name = "ValueLabel"
        valueLabel.BackgroundTransparency = 1
        valueLabel.Font = Enum.Font.GothamBold
        valueLabel.TextSize = 10.5
        valueLabel.TextColor3 = LouisHub.CurrentTheme.Highlight
        valueLabel.TextXAlignment = Enum.TextXAlignment.Left
        valueLabel.Text = tostring(defaultValue) .. suffixStr
        valueLabel.Size = UDim2.fromOffset(0, 14)
        valueLabel.AutomaticSize = Enum.AutomaticSize.X
        valueLabel.Parent = itemRow
        LouisHub:RegisterThemeProperty(valueLabel, "TextColor3", "Highlight")
        LouisHub:RegisterFontElement(valueLabel, "Bold")

        local barFill = nil
        if isBar then
            local barTrack = Instance.new("Frame")
            barTrack.Name = "BarTrack"
            barTrack.BackgroundColor3 = LouisHub.CurrentTheme.SurfaceAlt
            barTrack.BorderSizePixel = 0
            barTrack.Size = UDim2.fromOffset(50, 4)
            barTrack.Parent = itemRow
            LouisHub:RegisterThemeProperty(barTrack, "BackgroundColor3", "SurfaceAlt")

            local btCorner = Instance.new("UICorner")
            btCorner.CornerRadius = UDim.new(0, 2)
            btCorner.Parent = barTrack

            barFill = Instance.new("Frame")
            barFill.Name = "BarFill"
            barFill.BackgroundColor3 = LouisHub.CurrentTheme.Accent
            barFill.BorderSizePixel = 0
            barFill.Size = UDim2.new(1, 0, 1, 0)
            barFill.Parent = barTrack
            LouisHub:RegisterThemeProperty(barFill, "BackgroundColor3", "Accent")

            local bfCorner = Instance.new("UICorner")
            bfCorner.CornerRadius = UDim.new(0, 2)
            bfCorner.Parent = barFill
        end

        registeredItems[flagKey] = {
            TitleLabel = titleLabel,
            ValueLabel = valueLabel,
            BarFill = barFill,
            MaxVal = tonumber(itemConfig.Max) or 100,
            Suffix = suffixStr
        }
    end

    if type(hudConfig.Items) == "table" then
        for _, it in ipairs(hudConfig.Items) do
            addHudItem(it)
        end
    end

    local HudController = {
        Instance = hudFrame,
        ScreenGui = hudGui,
        IsLocked = isLocked,
        Set = function(_, itemFlag, newValue)
            local item = registeredItems[itemFlag]
            if item then
                item.ValueLabel.Text = tostring(newValue) .. item.Suffix
                if item.BarFill then
                    local num = tonumber(newValue) or 0
                    local ratio = math.clamp(num / item.MaxVal, 0, 1)
                    LouisHub:Tween(item.BarFill, { Size = UDim2.new(ratio, 0, 1, 0) }, 0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                end
            end
        end,
        Bind = function(selfHud, itemFlag, updateFunction, intervalSeconds)
            local interval = tonumber(intervalSeconds) or 0.5
            local thread = task.spawn(function()
                while hudFrame and hudFrame.Parent do
                    if hudFrame.Visible then
                        local success, result = pcall(updateFunction)
                        if success and result ~= nil then
                            selfHud:Set(itemFlag, result)
                        end
                    end
                    task.wait(interval)
                end
            end)
            LouisHub.RootJanitor:Add(thread)
        end,
        -- Kontrol Visibilitas On-Off
        SetVisible = function(_, visible)
            hudFrame.Visible = (visible == true)
        end,
        Show = function(selfHud)
            selfHud:SetVisible(true)
        end,
        Hide = function(selfHud)
            selfHud:SetVisible(false)
        end,
        Toggle = function(selfHud)
            selfHud:SetVisible(not hudFrame.Visible)
        end,
        -- Kontrol Kunci Posisi Drag
        SetLocked = function(selfHud, locked)
            selfHud.IsLocked = (locked == true)
            hudFrame:SetAttribute("DragLocked", selfHud.IsLocked)
        end,
        ToggleLock = function(selfHud)
            selfHud:SetLocked(not selfHud.IsLocked)
        end,
        Destroy = function()
            ActiveHudInstances[hudName] = nil
            pcall(function() hudGui:Destroy() end)
        end
    }

    ActiveHudInstances[hudName] = HudController
    return HudController
end

-- =====================================================================
-- SECTION 32: ADAPTIVE FLOATING ACTION BUTTONS (TOGGLE/ONCE/HOLD & LOCK)
-- =====================================================================
local ActiveFloatingButtons = {}

function LouisHub:FloatingButton(btnConfig)
    btnConfig = btnConfig or {}
    local btnName = tostring(btnConfig.Name or "QuickAction")
    local iconIdentifier = btnConfig.Icon or "star"
    local btnText = btnConfig.Text
    local mode = btnConfig.Mode or "Toggle" -- Pilihan: "Toggle", "Once", "Hold"
    local callback = btnConfig.Callback
    local initialPosition = btnConfig.Position or UDim2.new(1, -64, 0.5, -23)
    local isLocked = btnConfig.Locked == true

    local safeParent = self:GetSafeContainer()
    local btnGui = Instance.new("ScreenGui")
    btnGui.Name = "LouisHub_FloatBtn_" .. btnName
    btnGui.ResetOnSpawn = false
    btnGui.IgnoreGuiInset = true
    btnGui.DisplayOrder = 850000
    btnGui.Parent = safeParent
    self:ProtectContainer(btnGui)
    self.RootJanitor:Add(btnGui)

    -- Tombol adaptif pas mengikuti isi
    local button = Instance.new("TextButton")
    button.Name = "FloatButton"
    button.AutoButtonColor = false
    button.BackgroundColor3 = self.CurrentTheme.Surface
    button.BackgroundTransparency = 0.2
    button.BorderSizePixel = 0
    button.Size = UDim2.fromOffset(btnText and 0 or 44, 44)
    button.AutomaticSize = btnText and Enum.AutomaticSize.X or Enum.AutomaticSize.None
    button.Position = initialPosition
    button.Text = ""
    button.ZIndex = 850001
    button.Parent = btnGui
    button:SetAttribute("DragLocked", isLocked)
    self:RegisterThemeProperty(button, "BackgroundColor3", "Surface")

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 22)
    bCorner.Parent = button

    local bStroke = Instance.new("UIStroke")
    bStroke.Thickness = 1.5
    bStroke.Color = self.CurrentTheme.Border
    bStroke.Transparency = 0.3
    bStroke.Parent = button
    self:RegisterThemeProperty(bStroke, "Color", "Border")

    local contentLayout = Instance.new("UIListLayout")
    contentLayout.FillDirection = Enum.FillDirection.Horizontal
    contentLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    contentLayout.Padding = UDim.new(0, 6)
    contentLayout.Parent = button

    local bPad = Instance.new("UIPadding")
    bPad.PaddingLeft = UDim.new(0, btnText and 12 or 0)
    bPad.PaddingRight = UDim.new(0, btnText and 14 or 0)
    bPad.Parent = button

    local iconHolder = Instance.new("Frame")
    iconHolder.Name = "IconHolder"
    iconHolder.BackgroundTransparency = 1
    iconHolder.Size = UDim2.fromOffset(20, 20)
    iconHolder.Parent = button

    self:MountIcon(iconHolder, iconIdentifier, 18, self.CurrentTheme.Text)

    if btnText then
        local label = Instance.new("TextLabel")
        label.Name = "ButtonLabel"
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 11
        label.TextColor3 = self.CurrentTheme.Text
        label.Text = tostring(btnText)
        label.Size = UDim2.fromOffset(0, 16)
        label.AutomaticSize = Enum.AutomaticSize.X
        label.Parent = button
        self:RegisterThemeProperty(label, "TextColor3", "Text")
        self:RegisterFontElement(label, "Medium")
    end

    self:MakeDraggable(button, button)

    local isActive = false
    local inCooldown = false

    local function applyVisual(state)
        local targetColor = state and self.CurrentTheme.Accent or self.CurrentTheme.Surface
        local strokeColor = state and self.CurrentTheme.Highlight or self.CurrentTheme.Border

        LouisHub:Tween(button, { BackgroundColor3 = targetColor }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        LouisHub:Tween(bStroke, { Color = strokeColor, Transparency = state and 0.1 or 0.3 }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end

    -- ── EKSEKUSI TIPE INTERAKSI LENGKAP (TOGGLE / ONCE / HOLD) ───────────
    if mode == "Hold" then
        button.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                isActive = true
                applyVisual(true)
                LouisHub:ApplyPressAnimation(button, 0.90)
                if type(callback) == "function" then
                    pcall(callback, true)
                end
            end
        end)

        button.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if isActive then
                    isActive = false
                    applyVisual(false)
                    if type(callback) == "function" then
                        pcall(callback, false)
                    end
                end
            end
        end)
    else
        button.MouseButton1Click:Connect(function()
            if mode == "Toggle" then
                isActive = not isActive
                applyVisual(isActive)
                LouisHub:ApplyPressAnimation(button, 0.90)
                if type(callback) == "function" then
                    pcall(callback, isActive)
                end
            elseif mode == "Once" and not inCooldown then
                inCooldown = true
                applyVisual(true)
                LouisHub:ApplyPressAnimation(button, 0.90)
                if type(callback) == "function" then
                    pcall(callback)
                end

                local duration = tonumber(btnConfig.Cooldown) or 1.0
                task.delay(duration, function()
                    inCooldown = false
                    applyVisual(false)
                end)
            end
        end)
    end

    local FloatBtnController = {
        Instance = button,
        ScreenGui = btnGui,
        IsLocked = isLocked,
        GetState = function()
            return isActive
        end,
        SetState = function(_, state)
            isActive = (state == true)
            applyVisual(isActive)
        end,
        -- Kontrol Visibilitas On-Off
        SetVisible = function(_, visible)
            button.Visible = (visible == true)
        end,
        Show = function(selfBtn)
            selfBtn:SetVisible(true)
        end,
        Hide = function(selfBtn)
            selfBtn:SetVisible(false)
        end,
        ToggleVisibility = function(selfBtn)
            selfBtn:SetVisible(not button.Visible)
        end,
        -- Kontrol Kunci Posisi Drag
        SetLocked = function(selfBtn, locked)
            selfBtn.IsLocked = (locked == true)
            button:SetAttribute("DragLocked", selfBtn.IsLocked)
        end,
        ToggleLock = function(selfBtn)
            selfBtn:SetLocked(not selfBtn.IsLocked)
        end,
        Destroy = function()
            pcall(function() btnGui:Destroy() end)
        end
    }

    table.insert(ActiveFloatingButtons, FloatBtnController)
    return FloatBtnController
end

-- =====================================================================
-- SECTION 33: COMPACT REALTIME WATERMARK OVERLAY
-- =====================================================================
local ActiveWatermark = nil

function LouisHub:Watermark(wmConfig)
    if ActiveWatermark then return ActiveWatermark end
    wmConfig = wmConfig or {}

    local titlePrefix = tostring(wmConfig.Title or "Louis Hub")
    local cornerPosition = wmConfig.Position or UDim2.fromOffset(12, 12)

    local safeParent = self:GetSafeContainer()
    local wmGui = Instance.new("ScreenGui")
    wmGui.Name = "LouisHub_Watermark"
    wmGui.ResetOnSpawn = false
    wmGui.IgnoreGuiInset = true
    wmGui.DisplayOrder = 999000
    wmGui.Parent = safeParent
    self:ProtectContainer(wmGui)
    self.RootJanitor:Add(wmGui)

    local pill = Instance.new("Frame")
    pill.Name = "WatermarkPill"
    pill.BackgroundColor3 = self.CurrentTheme.Surface
    pill.BackgroundTransparency = 0.25
    pill.BorderSizePixel = 0
    pill.Size = UDim2.fromOffset(0, 22)
    pill.AutomaticSize = Enum.AutomaticSize.X
    pill.Position = cornerPosition
    pill.Parent = wmGui
    self:RegisterThemeProperty(pill, "BackgroundColor3", "Surface")

    local pCorner = Instance.new("UICorner")
    pCorner.CornerRadius = UDim.new(0, 11)
    pCorner.Parent = pill

    local pStroke = Instance.new("UIStroke")
    pStroke.Thickness = 1
    pStroke.Color = self.CurrentTheme.Accent
    pStroke.Transparency = 0.4
    pStroke.Parent = pill
    self:RegisterThemeProperty(pStroke, "Color", "Accent")

    local pPad = Instance.new("UIPadding")
    pPad.PaddingLeft = UDim.new(0, 10)
    pPad.PaddingRight = UDim.new(0, 10)
    pPad.Parent = pill

    local contentLabel = Instance.new("TextLabel")
    contentLabel.Name = "ContentText"
    contentLabel.BackgroundTransparency = 1
    contentLabel.Font = Enum.Font.GothamMedium
    contentLabel.TextSize = 10
    contentLabel.TextColor3 = self.CurrentTheme.Highlight
    contentLabel.Text = titlePrefix .. " | Loading..."
    contentLabel.Size = UDim2.new(0, 0, 1, 0)
    contentLabel.AutomaticSize = Enum.AutomaticSize.X
    contentLabel.Parent = pill
    self:RegisterThemeProperty(contentLabel, "TextColor3", "Highlight")
    self:RegisterFontElement(contentLabel, "Medium")

    local frameCount = 0
    local lastCheck = os.clock()
    local currentFps = 60

    local fpsConn = RunService.RenderStepped:Connect(function()
        frameCount = frameCount + 1
        local now = os.clock()
        if now - lastCheck >= 1 then
            currentFps = math.round(frameCount / (now - lastCheck))
            frameCount = 0
            lastCheck = now

            local pingMs = 0
            if LocalPlayer then
                local pingStat = LocalPlayer:GetNetworkPing()
                pingMs = math.round(pingStat * 1000)
            end

            contentLabel.Text = string.format("%s | %d FPS | %d ms", titlePrefix, currentFps, pingMs)
        end
    end)
    self.RootJanitor:Add(fpsConn)

    ActiveWatermark = {
        Instance = pill,
        ScreenGui = wmGui,
        SetVisible = function(_, visible)
            pill.Visible = (visible == true)
        end,
        SetTitle = function(_, newTitle)
            titlePrefix = tostring(newTitle)
        end,
        Destroy = function()
            ActiveWatermark = nil
            pcall(function() wmGui:Destroy() end)
        end
    }

    return ActiveWatermark
end

-- LOUIS HUB | PART 5C | continues in PART 5D

-- =====================================================================
-- SECTION 34: PRE-BUILT TABS (DASHBOARD, SETTINGS, DIAGNOSTICS)
-- =====================================================================
local TeleportService = Services.TeleportService

local PreviousCreateWindow_5C = LouisHub.CreateWindow

function LouisHub:CreateWindow(windowConfig)
    local Window = PreviousCreateWindow_5C(self, windowConfig)

    -- ── 1. PRE-BUILT HOME / DASHBOARD TAB ────────────────────────────
    function Window:AddHomeTab(homeConfig)
        homeConfig = homeConfig or {}
        local tabTitle = homeConfig.Title or "Home"
        local discordInvite = tostring(homeConfig.DiscordInvite or "")

        local tab = self:AddTab({
            Name = tabTitle,
            Icon = "home"
        })

        local secProfile = tab:AddSection({
            Title = "Player Information",
            Columns = 1
        })

        local avatarThumbnail = "rbxassetid://0"
        if LocalPlayer then
            pcall(function()
                avatarThumbnail = Players:GetUserThumbnailAsync(
                    LocalPlayer.UserId,
                    Enum.ThumbnailType.HeadShot,
                    Enum.ThumbnailSize.Size150x150
                )
            end)
        end

        local dName = LocalPlayer and LocalPlayer.DisplayName or "Player"
        local uName = LocalPlayer and ("@" .. LocalPlayer.Name) or "@Player"
        local uId = LocalPlayer and tostring(LocalPlayer.UserId) or "0"
        local accAge = LocalPlayer and (tostring(LocalPlayer.AccountAge) .. " days") or "0 days"

        -- Full-width Hero Profile Card
        local profileHeroCard = Instance.new("Frame")
        profileHeroCard.Name = "ProfileHeroCard"
        profileHeroCard.BackgroundColor3 = LouisHub.CurrentTheme.SurfaceAlt
        profileHeroCard.BackgroundTransparency = 0.45
        profileHeroCard.Size = UDim2.new(1, 0, 0, 78)
        profileHeroCard.Parent = secProfile.Body
        LouisHub:RegisterThemeProperty(profileHeroCard, "BackgroundColor3", "SurfaceAlt")

        local phcCorner = Instance.new("UICorner")
        phcCorner.CornerRadius = UDim.new(0, 8)
        phcCorner.Parent = profileHeroCard

        local phcStroke = Instance.new("UIStroke")
        phcStroke.Thickness = 1
        phcStroke.Color = LouisHub.CurrentTheme.Accent
        phcStroke.Transparency = 0.4
        phcStroke.Parent = profileHeroCard
        LouisHub:RegisterThemeProperty(phcStroke, "Color", "Accent")

        local avatarFrame = Instance.new("Frame")
        avatarFrame.Name = "AvatarCircle"
        avatarFrame.BackgroundColor3 = LouisHub.CurrentTheme.Surface
        avatarFrame.Size = UDim2.fromOffset(60, 60)
        avatarFrame.Position = UDim2.fromOffset(10, 9)
        avatarFrame.Parent = profileHeroCard

        local afCorner = Instance.new("UICorner")
        afCorner.CornerRadius = UDim.new(0, 30)
        afCorner.Parent = avatarFrame

        local avatarImg = Instance.new("ImageLabel")
        avatarImg.Name = "AvatarImage"
        avatarImg.BackgroundTransparency = 1
        avatarImg.Size = UDim2.new(1, 0, 1, 0)
        avatarImg.Image = avatarThumbnail
        avatarImg.ScaleType = Enum.ScaleType.Fit
        avatarImg.Parent = avatarFrame

        local afStroke = Instance.new("UIStroke")
        afStroke.Thickness = 1.5
        afStroke.Color = LouisHub.CurrentTheme.Highlight
        afStroke.Parent = avatarFrame
        LouisHub:RegisterThemeProperty(afStroke, "Color", "Highlight")

        local infoContainer = Instance.new("Frame")
        infoContainer.Name = "InfoHolder"
        infoContainer.BackgroundTransparency = 1
        infoContainer.Position = UDim2.fromOffset(80, 8)
        infoContainer.Size = UDim2.new(1, -90, 1, -16)
        infoContainer.Parent = profileHeroCard

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "DisplayName"
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 13.5
        nameLabel.TextColor3 = LouisHub.CurrentTheme.Highlight
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Text = dName
        nameLabel.Size = UDim2.new(1, 0, 0, 16)
        nameLabel.Parent = infoContainer
        LouisHub:RegisterThemeProperty(nameLabel, "TextColor3", "Highlight")
        LouisHub:RegisterFontElement(nameLabel, "Bold")

        local userLabel = Instance.new("TextLabel")
        userLabel.Name = "Username"
        userLabel.BackgroundTransparency = 1
        userLabel.Font = Enum.Font.Gotham
        userLabel.TextSize = 10.5
        userLabel.TextColor3 = LouisHub.CurrentTheme.TextMuted
        userLabel.TextXAlignment = Enum.TextXAlignment.Left
        userLabel.Text = uName .. " • ID: " .. uId
        userLabel.Position = UDim2.fromOffset(0, 18)
        userLabel.Size = UDim2.new(1, 0, 0, 14)
        userLabel.Parent = infoContainer
        LouisHub:RegisterThemeProperty(userLabel, "TextColor3", "TextMuted")
        LouisHub:RegisterFontElement(userLabel, "Regular")

        local ageBadge = Instance.new("TextLabel")
        ageBadge.Name = "AccountAgeBadge"
        ageBadge.BackgroundColor3 = LouisHub.CurrentTheme.Surface
        ageBadge.Font = Enum.Font.GothamMedium
        ageBadge.TextSize = 9.5
        ageBadge.TextColor3 = LouisHub.CurrentTheme.AccentAlt
        ageBadge.Text = "Age: " .. accAge
        ageBadge.Position = UDim2.fromOffset(0, 36)
        ageBadge.Size = UDim2.fromOffset(100, 18)
        ageBadge.Parent = infoContainer
        LouisHub:RegisterThemeProperty(ageBadge, "BackgroundColor3", "Surface")
        LouisHub:RegisterThemeProperty(ageBadge, "TextColor3", "AccentAlt")
        LouisHub:RegisterFontElement(ageBadge, "Medium")

        local abCorner = Instance.new("UICorner")
        abCorner.CornerRadius = UDim.new(0, 4)
        abCorner.Parent = ageBadge

        local secGame = tab:AddSection({
            Title = "Game & Server Status",
            Columns = 2
        })

        local placeIdStr = tostring(game.PlaceId or 0)
        local jobIdStr = tostring(game.JobId or "SinglePlayer")

        secGame:AddLabel({ Text = "Place ID", Value = placeIdStr, Column = 1 })
        local playerCounterLabel = secGame:AddLabel({ Text = "Players Online", Value = "-- / --", Column = 1 })
        local sessionTimeLabel = secGame:AddLabel({ Text = "Session Time", Value = "00:00:00", Column = 2 })

        secGame:AddButton({
            Name = "Copy Job ID",
            Variant = "secondary",
            Column = 2,
            Callback = function()
                if LouisHub.Capabilities.HasClipboard then
                    pcall(setclipboard, jobIdStr)
                    LouisHub:Notify({ Title = "Clipboard", Content = "Server Job ID copied to clipboard!", Type = "Success", Duration = 3 })
                else
                    LouisHub:Notify({ Title = "Clipboard", Content = "Clipboard function unavailable", Type = "Warning", Duration = 3 })
                end
            end
        })

        local secActions = tab:AddSection({
            Title = "Quick Actions",
            Columns = 2
        })

        secActions:AddButton({
            Name = "Rejoin Server",
            Variant = "primary",
            Column = 1,
            Callback = function()
                if TeleportService and LocalPlayer then
                    LouisHub:Notify({ Title = "Teleport", Content = "Rejoining server...", Type = "Info", Duration = 3 })
                    pcall(function()
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
                    end)
                end
            end
        })

        secActions:AddButton({
            Name = "Server Hop",
            Variant = "secondary",
            Column = 1,
            Callback = function()
                if not (TeleportService and HttpService and LouisHub.Capabilities.HasHttpRequest) then
                    LouisHub:Notify({ Title = "Server Hop", Content = "HTTP request or TeleportService unavailable", Type = "Error", Duration = 3 })
                    return
                end

                task.spawn(function()
                    LouisHub:Notify({ Title = "Server Hop", Content = "Searching for servers...", Type = "Info", Duration = 3 })
                    local url = string.format("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100", tostring(game.PlaceId))
                    local req = (type(request) == "function" and request) or (syn and syn.request) or http_request

                    local success, res = pcall(req, { Url = url, Method = "GET" })
                    if success and res and res.Body then
                        local decodeOk, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
                        if decodeOk and data and data.data then
                            for _, srv in ipairs(data.data) do
                                if srv.playing and srv.maxPlayers and srv.playing < srv.maxPlayers and srv.id ~= game.JobId then
                                    TeleportService:TeleportToPlaceInstance(game.PlaceId, srv.id, LocalPlayer)
                                    return
                                end
                            end
                        end
                    end
                    LouisHub:Notify({ Title = "Server Hop", Content = "No alternative servers found", Type = "Warning", Duration = 3 })
                end)
            end
        })

        if discordInvite ~= "" then
            secActions:AddButton({
                Name = "Copy Discord Link",
                Variant = "secondary",
                Column = 2,
                Callback = function()
                    local inviteUrl = "https://discord.gg/" .. discordInvite
                    if LouisHub.Capabilities.HasClipboard then
                        pcall(setclipboard, inviteUrl)
                        LouisHub:Notify({ Title = "Discord", Content = "Discord invite link copied!", Type = "Success", Duration = 3 })
                    end
                end
            })
        end

        local startClock = os.clock()
        local function formatHMS(seconds)
            local hrs = math.floor(seconds / 3600)
            local mins = math.floor((seconds % 3600) / 60)
            local secs = math.floor(seconds % 60)
            return string.format("%02d:%02d:%02d", hrs, mins, secs)
        end

        task.spawn(function()
            while tab.PageFrame and tab.PageFrame.Parent do
                if Window.IsOpen and tab.PageFrame.Visible then
                    local elapsed = os.clock() - startClock
                    sessionTimeLabel:Set(formatHMS(elapsed))
                    playerCounterLabel:Set(string.format("%d / %d", #Players:GetPlayers(), Players.MaxPlayers))
                end
                task.wait(1)
            end
        end)

        return tab
    end

    -- ── 2. PRE-BUILT SETTINGS & CONFIG TAB ───────────────────────────
    function Window:AddSettingsTab()
        local tab = self:AddTab({
            Name = "Settings",
            Icon = "settings"
        })

        -- Appearance, Theme & Font
        local secTheme = tab:AddSection({
            Title = "Theme & Typography",
            Columns = 2
        })

        local themeNames = LouisHub:GetThemes()
        secTheme:AddDropdown({
            Name = "Interface Theme",
            Options = themeNames,
            Default = LouisHub.ActiveThemeName,
            Column = 1,
            Callback = function(chosenTheme)
                LouisHub:SetTheme(chosenTheme, true)
            end
        })

        local fontNames = LouisHub:GetFonts()
        secTheme:AddDropdown({
            Name = "Interface Font",
            Options = fontNames,
            Default = LouisHub.ActiveFontName,
            Column = 1,
            Callback = function(chosenFont)
                LouisHub:SetFont(chosenFont)
            end
        })

        secTheme:AddToggle({
            Name = "Animated Gradient",
            Default = LouisHub.GradientSettings.Enabled,
            Column = 1,
            Callback = function(enabled)
                LouisHub:SetGradientAnimation(enabled)
            end
        })

        secTheme:AddSlider({
            Name = "Gradient Speed",
            Min = 0.5,
            Max = 3.0,
            Step = 0.1,
            Default = LouisHub.GradientSettings.Speed,
            Suffix = "x",
            Column = 1,
            Callback = function(speed)
                LouisHub:SetGradientAnimation(nil, speed)
            end
        })

        secTheme:AddToggle({
            Name = "Reduce Motion",
            Default = LouisHub.ReduceMotion,
            Column = 2,
            Callback = function(val)
                LouisHub.ReduceMotion = val
            end
        })

        secTheme:AddSlider({
            Name = "Interface Scale",
            Min = 0.70,
            Max = 1.40,
            Step = 0.05,
            Default = 1.0,
            Suffix = "x",
            Column = 2,
            Callback = function(scaleFactor)
                local sc = Window.ScreenGui:FindFirstChildOfClass("UIScale")
                if sc then
                    sc.Scale = scaleFactor
                end
            end
        })

        -- Configuration Management
        local secConfig = tab:AddSection({
            Title = "Configuration Storage",
            Columns = 1
        })

        local configNameInput = ""
        secConfig:AddInput({
            Name = "Config Name",
            Placeholder = "Enter filename...",
            OnEnter = false,
            Callback = function(text)
                configNameInput = text
            end
        })

        local configDropdownRef = nil
        local selectedConfigName = nil

        local function refreshDropdownList()
            if configDropdownRef then
                local configs = LouisHub.ConfigManager:List()
                configDropdownRef:SetOptions(configs)
            end
        end

        local groupBtns = secConfig:AddGroup({ Height = 28 })

        groupBtns:AddButton({
            Name = "Save New",
            Callback = function()
                if configNameInput == "" then
                    LouisHub:Notify({ Title = "Config", Content = "Please enter a valid configuration name", Type = "Warning", Duration = 3 })
                    return
                end
                local ok, err = LouisHub.ConfigManager:Save(configNameInput)
                if ok then
                    LouisHub:Notify({ Title = "Config", Content = "Saved config: " .. configNameInput, Type = "Success", Duration = 3 })
                    refreshDropdownList()
                else
                    LouisHub:Notify({ Title = "Config", Content = "Save failed: " .. tostring(err), Type = "Error", Duration = 3 })
                end
            end
        })

        groupBtns:AddButton({
            Name = "Refresh List",
            Callback = function()
                refreshDropdownList()
                LouisHub:Notify({ Title = "Config", Content = "Refreshed configuration file list", Type = "Info", Duration = 2 })
            end
        })

        configDropdownRef = secConfig:AddDropdown({
            Name = "Saved Profiles",
            Options = LouisHub.ConfigManager:List(),
            Callback = function(chosen)
                selectedConfigName = chosen
            end
        })

        local groupLoad = secConfig:AddGroup({ Height = 28 })

        groupLoad:AddButton({
            Name = "Load Selected",
            Callback = function()
                if not selectedConfigName then return end
                local ok, err = LouisHub.ConfigManager:Load(selectedConfigName, false)
                if ok then
                    LouisHub:Notify({ Title = "Config", Content = "Loaded configuration: " .. selectedConfigName, Type = "Success", Duration = 3 })
                else
                    LouisHub:Notify({ Title = "Config", Content = "Load failed: " .. tostring(err), Type = "Error", Duration = 3 })
                end
            end
        })

        groupLoad:AddButton({
            Name = "Overwrite",
            Callback = function()
                if not selectedConfigName then return end
                LouisHub:Confirm({
                    Title = "Overwrite Config?",
                    Content = "Are you sure you want to overwrite profile '" .. selectedConfigName .. "' with your current settings?",
                    Icon = "warning",
                    Buttons = {
                        { Text = "Cancel", Variant = "neutral" },
                        { Text = "Overwrite", Variant = "danger", Callback = function()
                            local ok, err = LouisHub.ConfigManager:Save(selectedConfigName)
                            if ok then
                                LouisHub:Notify({ Title = "Config", Content = "Overwrote: " .. selectedConfigName, Type = "Success", Duration = 3 })
                            else
                                LouisHub:Notify({ Title = "Config", Content = "Failed: " .. tostring(err), Type = "Error", Duration = 3 })
                            end
                        end }
                    }
                })
            end
        })

        groupLoad:AddButton({
            Name = "Delete",
            Callback = function()
                if not selectedConfigName then return end
                LouisHub:Confirm({
                    Title = "Delete Config?",
                    Content = "Are you sure you want to delete profile '" .. selectedConfigName .. "'? This cannot be undone.",
                    Icon = "trash",
                    Buttons = {
                        { Text = "Cancel", Variant = "neutral" },
                        { Text = "Delete", Variant = "danger", Callback = function()
                            LouisHub.ConfigManager:Delete(selectedConfigName)
                            LouisHub:Notify({ Title = "Config", Content = "Deleted: " .. selectedConfigName, Type = "Info", Duration = 3 })
                            refreshDropdownList()
                        end }
                    }
                })
            end
        })

        local groupAutoload = secConfig:AddGroup({ Height = 28 })

        local currentAutoloadLabel = secConfig:AddLabel({
            Text = "Autoload Active",
            Value = LouisHub.ConfigManager:GetAutoload() or "None"
        })

        groupAutoload:AddButton({
            Name = "Set As Autoload",
            Callback = function()
                if not selectedConfigName then return end
                LouisHub.ConfigManager:SetAutoload(selectedConfigName)
                currentAutoloadLabel:Set("Autoload Active", selectedConfigName)
                LouisHub:Notify({ Title = "Config", Content = "Set '" .. selectedConfigName .. "' as session autoload profile", Type = "Success", Duration = 3 })
            end
        })

        groupAutoload:AddButton({
            Name = "Clear Autoload",
            Callback = function()
                LouisHub.ConfigManager:ClearAutoload()
                currentAutoloadLabel:Set("Autoload Active", "None")
                LouisHub:Notify({ Title = "Config", Content = "Cleared autoload configuration pointer", Type = "Info", Duration = 3 })
            end
        })

        return tab
    end

    -- ── 3. PRE-BUILT SYSTEM DIAGNOSTICS TAB ──────────────────────────
    function Window:AddDiagnosticsTab()
        local tab = self:AddTab({
            Name = "System",
            Icon = "analytics"
        })

        local secPerf = tab:AddSection({
            Title = "Realtime Performance",
            Columns = 2
        })

        local fpsLabel = secPerf:AddLabel({ Text = "Framerate (FPS)", Value = "60 FPS", Column = 1 })
        local frameTimeLabel = secPerf:AddLabel({ Text = "Frame Delta", Value = "16.6 ms", Column = 1 })
        local memoryLabel = secPerf:AddLabel({ Text = "Client Memory", Value = "-- MB", Column = 2 })
        local executorLabel = secPerf:AddLabel({ Text = "Executor Detected", Value = LouisHub.Capabilities.Executor, Column = 2 })

        local secCaps = tab:AddSection({
            Title = "Executor Feature Matrix",
            Columns = 2
        })

        local function formatSupport(boolVal)
            return boolVal and "🟢 Supported" or "🔴 Unsupported"
        end

        secCaps:AddLabel({ Text = "Filesystem (I/O)", Value = formatSupport(LouisHub.Capabilities.HasFilesystem), Column = 1 })
        secCaps:AddLabel({ Text = "Custom Clipboard", Value = formatSupport(LouisHub.Capabilities.HasClipboard), Column = 1 })
        secCaps:AddLabel({ Text = "HTTP Request", Value = formatSupport(LouisHub.Capabilities.HasHttpRequest), Column = 1 })
        secCaps:AddLabel({ Text = "gethui() Mount", Value = formatSupport(LouisHub.Capabilities.HasGetHui), Column = 2 })
        secCaps:AddLabel({ Text = "protect_gui() Hook", Value = formatSupport(LouisHub.Capabilities.HasProtectGui), Column = 2 })
        secCaps:AddLabel({ Text = "Device Category", Value = LouisHub.Capabilities:GetDeviceCategory(), Column = 2 })

        local secLogs = tab:AddSection({
            Title = "Internal Diagnostics & Error Log",
            Columns = 1
        })

        local logParagraph = secLogs:AddParagraph({
            Title = "Recent Anomalies (Last 5)",
            Content = "No execution anomalies recorded."
        })

        local function refreshLogs()
            local errs = LouisHub:GetErrors()
            if #errs == 0 then
                logParagraph:SetContent("No execution anomalies recorded.")
            else
                local lines = {}
                local startIdx = math.max(1, #errs - 4)
                for i = startIdx, #errs do
                    table.insert(lines, string.format("[%s] %s: %s", os.date("%X", errs[i].Timestamp), errs[i].Category, errs[i].Message))
                end
                logParagraph:SetContent(table.concat(lines, "\n"))
            end
        end

        local logBtns = secLogs:AddGroup({ Height = 28 })

        logBtns:AddButton({
            Name = "Refresh Logs",
            Callback = function()
                refreshLogs()
                LouisHub:Notify({ Title = "Diagnostics", Content = "Refreshed error stream", Type = "Info", Duration = 2 })
            end
        })

        logBtns:AddButton({
            Name = "Copy All Logs",
            Callback = function()
                local errs = LouisHub:GetErrors()
                if #errs == 0 then
                    LouisHub:Notify({ Title = "Diagnostics", Content = "No logs to copy", Type = "Info", Duration = 2 })
                    return
                end
                local dump = {}
                for _, e in ipairs(errs) do
                    table.insert(dump, string.format("[%s] [%s]: %s", os.date("%X", e.Timestamp), e.Category, e.Message))
                end
                if LouisHub.Capabilities.HasClipboard then
                    pcall(setclipboard, table.concat(dump, "\n"))
                    LouisHub:Notify({ Title = "Diagnostics", Content = "Copied entire log stream to clipboard", Type = "Success", Duration = 3 })
                end
            end
        })

        logBtns:AddButton({
            Name = "Clear Logs",
            Callback = function()
                LouisHub:ClearErrors()
                refreshLogs()
                LouisHub:Notify({ Title = "Diagnostics", Content = "Cleared error registry", Type = "Info", Duration = 2 })
            end
        })

        local frames = 0
        local lastClock = os.clock()
        local statsService = Services.Stats

        task.spawn(function()
            while tab.PageFrame and tab.PageFrame.Parent do
                if Window.IsOpen and tab.PageFrame.Visible then
                    frames = frames + 1
                    local now = os.clock()
                    local delta = now - lastClock

                    if delta >= 1 then
                        local curFps = math.round(frames / delta)
                        local curDeltaMs = math.round((delta / frames) * 1000 * 10) / 10
                        fpsLabel:Set(string.format("%d FPS", curFps))
                        frameTimeLabel:Set(string.format("%.1f ms", curDeltaMs))

                        if statsService then
                            local okMem, m = pcall(function() return statsService:GetTotalMemoryUsageMb() end)
                            if okMem and m then
                                memoryLabel:Set(string.format("%d MB", math.round(m)))
                            end
                        end

                        frames = 0
                        lastClock = now
                    end
                end
                task.wait(0.2)
            end
        end)

        return tab
    end

    return Window
end

-- LOUIS HUB | PART 5D | Final Assembly

-- =====================================================================
-- SECTION 35: GLOBAL DESTRUCTION PIPELINE & LIFECYCLE FINALIZATION
-- =====================================================================
function LouisHub:Destroy()
    if self._isDestroyed then return end
    self._isDestroyed = true

    -- Release singleton blur if active
    if self.Blur and type(self.Blur.Release) == "function" then
        pcall(function()
            self.Blur.Release()
        end)
    end

    -- Run central Janitor cleanup
    if self.RootJanitor and type(self.RootJanitor.Cleanup) == "function" then
        pcall(function()
            self.RootJanitor:Cleanup()
        end)
    end

    -- Clear global references
    local env = (type(getgenv) == "function" and getgenv()) or _G
    if env["_LOUIS_HUB_V5_REGISTRY"] == self then
        env["_LOUIS_HUB_V5_REGISTRY"] = nil
    end

    if env["LouisHub"] == self then
        env["LouisHub"] = nil
    end

    table.clear(self.Flags)
    table.clear(self.Elements)
    table.clear(self.StateListeners)
    table.clear(self.Conditionals)
    table.clear(self.Errors)
end

-- =====================================================================
-- SECTION 36: INITIALIZATION HOOK & AUTOLOAD INTEGRATION
-- =====================================================================
local FinalCreateWindow = LouisHub.CreateWindow

function LouisHub:CreateWindow(windowConfig)
    windowConfig = windowConfig or {}

    local useLoadingScreen = windowConfig.LoadingScreen ~= false

    -- 1. Buat window langsung detik ini juga
    local Window = FinalCreateWindow(self, windowConfig)

    -- 2. Sembunyikan window sementara jika loading screen aktif
    if useLoadingScreen and Window and Window.MainFrame then
        Window.MainFrame.Visible = false
        Window.IsOpen = false

        self:ShowLoadingScreen({
            Title = windowConfig.Title or "LOUIS HUB",
            Subtitle = windowConfig.Subtitle or "Master Interface Suite • V5.0",
            Logo = windowConfig.Logo or self.LogoAssetId,
            Duration = tonumber(windowConfig.LoadingDuration) or 2.5
        }, function()
            if Window and Window.MainFrame and not Window.IsMinimized then
                Window:SetState(true)
            end
        end)
    end

    -- 3. Autoload profile jika ada
    task.defer(function()
        if self.ConfigManager and self.Capabilities.HasFilesystem then
            local autoloadProfile = self.ConfigManager:GetAutoload()
            if autoloadProfile and autoloadProfile ~= "" and autoloadProfile ~= "None" then
                local success, loadedName = self.ConfigManager:Load(autoloadProfile, true)
                if success then
                    self:Notify({
                        Title = "Config Autoload",
                        Content = "Successfully autoloaded profile: " .. tostring(loadedName),
                        Type = "Success",
                        Duration = 3.5
                    })
                end
            end
        end
    end)

    return Window
end

-- Export ke global environment
if type(getgenv) == "function" then
    getgenv().LouisHub = LouisHub
end
_G.LouisHub = LouisHub

-- INI BARIS PALING PENTING YANG JANGAN SAMPAI KETINGGALAN:
return LouisHub
