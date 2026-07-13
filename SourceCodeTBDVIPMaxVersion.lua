-- ========================================================================
-- [[ LOUIS HUB - TIME BOMB DUELS FUNCTIONAL PREMIUM EDITION (OPTIMIZED) ]]
-- ========================================================================

-- UPVALUE CACHING FOR MAXIMUM PERFORMANCE UNDER OBFUSCATION
local Vector3_new = Vector3.new
local CFrame_new = CFrame.new
local CFrame_Angles = CFrame.Angles
local CFrame_lookAt = CFrame.lookAt or function(p, t) return CFrame.new(p, t) end
local math_rad = math.rad
local math_random = math.random
local math_clamp = math.clamp
local math_huge = math.huge
local tick = tick
local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber
local pcall = pcall
local task_wait = task.wait
local task_spawn = task.spawn
local task_defer = task.defer

-- Macro definition for local compatibility before obfuscation
local LPH_NO_VIRTUALIZE = LPH_NO_VIRTUALIZE or function(f) return f end

-- Safe fallback to prevent runtime crashes on slider updates
local function updateSliderLabelSafe(val) end

-- 1. LOAD UI LIBRARY FROM YOUR SOURCE
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/nazumirui5-oss/Ui-Library/refs/heads/main/Ui%20Library.lua"))()

-- 2. SETUP MAIN ROBLOX SERVICES
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- ========================================================
-- [[ GITHUB RAW COORDINATES CONFIGURATION ]]
-- ========================================================
-- Base URL configured to point directly to your gamerlatahzan-design GitHub repository
local BaseUrl = "https://raw.githubusercontent.com/gamerlatahzan-design/CFRAMELUAHUB/refs/heads/main/"

-- Safe mapped database for path IDs, displays, and encoding to prevent space crashes in UI Library
local FlingPaths = {
    {id = "FlingLeft",     display = "Fling Left",      file = "LouisPath_fling%20left.lua"},
    {id = "FlingLeft2",    display = "Fling Left 2",    file = "LouisPath_fling%20left%202.lua"},
    {id = "FlingLeft3",    display = "Fling Left 3",    file = "LouisPath_fling%20left%203.lua"},
    {id = "FlingLeft4",    display = "Fling Left 4",    file = "LouisPath_fling%20left%204.lua"},
    {id = "FlingLeftBack", display = "Fling Left Back", file = "LouisPath_fling%20left%20back%20.lua"},
    {id = "FlingRight",    display = "Fling Right",     file = "LouisPath_fling%20right.lua"},
    {id = "FlingRight1",   display = "Fling Right 1",   file = "LouisPath_fling%20right%201.lua"},
    {id = "FlingRight2",   display = "Fling Right 2",   file = "LouisPath_fling%20right%202.lua"},
    {id = "FlingRight3",   display = "Fling Right 3",   file = "LouisPath_fling%20right%203.lua"},
    {id = "FlingRightBack1", display = "Fling Right Back 1", file = "LouisPath_fling%20right%20back%201.lua"},
    {id = "FlingRightBack2", display = "Fling Right Back 2", file = "LouisPath_fling%20right%20back%202.lua"},
    {id = "FlingRightBack3", display = "Fling Right Back 3", file = "LouisPath_fling%20right%20back%203.lua"}
}

local PathButtons = {} -- Stores dynamically generated external floating button instances
local ExternalButtonStates = {} -- Tracks manual visibility selection states of each path button
_G.CustomPathsEnabled = false
_G.FlingSpeedMultiplier = 5.0 -- Default speed configured to 5.0x

-- DYNAMIC CFRAME PATH PLAYER
local function playPath(pathId, pathData)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    for _, point in ipairs(pathData) do
        -- Instant termination check if custom paths are toggled Off or if individual button is disabled [1]
        if not _G.CustomPathsEnabled or not ExternalButtonStates[pathId] then 
            break 
        end
        
        if not hrp or not hrp.Parent then break end
        if point.cf then
            pcall(function()
                hrp.CFrame = CFrame.new(table.unpack(point.cf))
            end)
        end
        
        -- Applies playback speed multiplier directly to the recorded delta time
        local speedMult = _G.FlingSpeedMultiplier or 5.0
        task_wait((point.dt or 0.016) / speedMult) 
    end
end

-- REAL-TIME DOWNLOADER & SCRIPT REPLICATION RUNNER
local function triggerPath(pathInfo)
    local url = BaseUrl .. pathInfo.file

    -- Trigger execution notification [1]
    Library:Notify("Fling Active", "Executing: " .. pathInfo.display:upper(), 1.5)

    -- Process download coordinates from GitHub raw and execute path once [1]
    task_spawn(function()
        local success, result = pcall(function()
            return game:HttpGet(url)
        end)

        if success and result then
            local successLoad, pathTable = pcall(function()
                return loadstring(result)()
            end)

            if successLoad and type(pathTable) == "table" then
                playPath(pathInfo.id, pathTable)
            else
                Library:Notify("Error", "Failed to process coordinate structure for: " .. pathInfo.display, 2.5)
            end
        else
            Library:Notify("Error", "Failed to download " .. pathInfo.display .. " from GitHub.", 2.5)
        end
    end)
end

-- ========================================================
-- [[ DYNAMIC CUSTOM PATHS GENERATOR ]]
-- ========================================================
local function setupPathButtons()
    -- Dynamically toggle button visibility based on master toggle and individual selections [1]
    for _, pathInfo in ipairs(FlingPaths) do
        local extBtn = PathButtons[pathInfo.id]
        if extBtn then
            if _G.CustomPathsEnabled then
                local isVisible = ExternalButtonStates[pathInfo.id] or false
                SafeSetVisible(extBtn, isVisible)
            else
                SafeSetVisible(extBtn, false)
            end
        end
    end
end

-- ========================================================
-- [[ DYNAMIC AUTO-SAVE & AUTO-LOAD CONFIGURATION SYSTEM ]]
-- ========================================================
local HttpService = game:GetService("HttpService")
local ConfigFile = "LouisHub_TBD_Premium_Config.json"
local Config = {}

-- Config defaults for the Premium version
local Defaults = {
    FollowEnabled = false,
    PredictEnabled = false,
    AutoWalkEnabled = false,
    AutoWalkRetreatSpeed = 22,
    FollowTypeMode = "Follow + Retreat",
    AutoPassEnabled = false,
    PassTargetMode = "Without Bomb",
    PassMaxDistance = 100,
    PassExternalVisible = false,
    RangeChaseEnabled = false,
    RangeChaseValue = 30,
    FlickEnabled = false,
    FlickStrength = 45,
    FlickTargetMode = "Camera Only", -- Options: Camera Only, Character Only, Both
    CharFlickStrength = 45,          -- Slider for Character Flick
    AutoHoldEnabled = false,
    LocalHitboxEnabled = true,
    HitboxVisualEnabled = true,
    LocalHitboxSize = 2.0,
    HitboxTeleportDelay = 4,
    HitboxShape = "Cylinder",
    TPWalkEnabled = false,
    TPWalkSpeed = 16,
    CamlockEnabled = false,
    CamlockActive = false,
    DesyncImmunityEnabled = false,
    DesyncImmunityActive = false,
    DesyncVisualEnabled = false,
    TripEnabled = false,
    FreezeEnabled = false,
    InfJumpEnabled = false,
    MaxJumpCount = 5,
    WH_Distance = 2.5,
    WallhopEnabled = false,
    WallhopActive = false,
    WallhopMode = "Manual",
    WallhopType = "Normal",
    WallhopDetectionMode = "Raycast Only", -- Options: Raycast Only, Bounding Box, Hybrid
    WallhopFlickMode = "Default",          -- Options: Default, Front-to-Back Flick, Back-to-Front Flick
    WallhopStudEnabled = true,             -- Stud / Raycast detection toggle
    FOVEnabled = false,
    FOVValue = 70,
    ResolutionEnabled = false,
    ResolutionValue = 10,
    
    -- Target hijacking configurations
    HijackEnabled = true,
    HijackDistance = 7,
    
    -- Player ESP configurations
    ESPEnabled = false,
    
    -- Custom Keybind Defaults (Stored as Strings)
    Keybind_UIToggle = "RightControl",
    Keybind_FollowToggle = "None",
    Keybind_AutoWalkToggle = "None",
    Keybind_AutoPassToggle = "None",
    Keybind_RangeChaseToggle = "None",
    Keybind_FlickToggle = "None",
    Keybind_AutoHoldToggle = "None",
    Keybind_TripToggle = "None",
    Keybind_FreezeToggle = "None",
    Keybind_InfJumpToggle = "None",
    Keybind_WallhopToggle = "None",
    Keybind_HitboxToggle = "None",
    Keybind_CrosshairToggle = "None",
    Keybind_CamlockToggle = "None",
    Keybind_TPWalkToggle = "None",
    Keybind_DesyncImmunityToggle = "None"
}

local function LoadConfig()
    if isfile and isfile(ConfigFile) then
        local success, decoded = pcall(function()
            return HttpService:JSONDecode(readfile(ConfigFile))
        end)
        if success and type(decoded) == "table" then
            Config = decoded
        else
            Config = {}
        end
    else
        Config = {}
    end
    -- Fill missing settings with default variables
    for k, v in pairs(Defaults) do
        if Config[k] == nil then
            Config[k] = v
        end
    end
    -- Dynamically register custom path keybind defaults if missing in the JSON file [1]
    for _, pathInfo in ipairs(FlingPaths) do
        local key = "Keybind_" .. pathInfo.id
        if Config[key] == nil then
            Config[key] = "None"
        end
    end
end

local function SaveConfig()
    if writefile then
        pcall(function()
            writefile(ConfigFile, HttpService:JSONEncode(Config))
        end)
    end
end

-- Execute load configuration on instantiation
LoadConfig()

-- Synchronize internal global states with config files
_G.FollowEnabled = Config.FollowEnabled
_G.FollowActive = Config.FollowEnabled 
_G.PredictEnabled = Config.PredictEnabled 
_G.HJEnabled = false 
_G.FlickEnabled = Config.FlickEnabled 
_G.FlickActive = Config.FlickEnabled
_G.FlickStrength = Config.FlickStrength
_G.FlickTargetMode = Config.FlickTargetMode 
_G.CharFlickStrength = Config.CharFlickStrength 
_G.WallHopDist = Config.WH_Distance 
_G.WallhopEnabled = Config.WallhopEnabled
_G.WallhopActive = Config.WallhopActive
_G.WallhopMode = Config.WallhopMode
_G.WallhopType = Config.WallhopType
_G.WallhopDetectionMode = Config.WallhopDetectionMode 
_G.WallhopFlickMode = Config.WallhopFlickMode 
_G.WallhopStudEnabled = Config.WallhopStudEnabled
_G.PotatoEnabled = false

_G.FOVEnabled = Config.FOVEnabled
_G.FOVValue = Config.FOVValue
_G.FreezeEnabled = Config.FreezeEnabled

-- Target hijacking configuration
_G.HijackEnabled = Config.HijackEnabled
_G.HijackDistance = Config.HijackDistance

-- Player ESP configuration
_G.ESPEnabled = Config.ESPEnabled

-- INFINITE JUMP STATE
_G.InfJumpEnabled = Config.InfJumpEnabled
_G.MaxJumpCount = Config.MaxJumpCount
_G.CurrentJumpCount = 0

-- AUTO HOLD BOMB STATE
_G.AutoHoldEnabled = Config.AutoHoldEnabled
_G.AutoHoldActive = Config.AutoHoldEnabled

-- SCREEN RESOLUTION (STRETCH RES) STATE
_G.ResolutionEnabled = Config.ResolutionEnabled
_G.ResolutionValue = Config.ResolutionValue / 10

-- GLOBAL SIZE VALUES
_G.UIScaleValue = 100
_G.ExtScaleValue = 100

-- NEW AUTO WALK FEATURE
_G.AutoWalkEnabled = Config.AutoWalkEnabled
_G.AutoWalkActive = Config.AutoWalkEnabled
_G.AutoWalkRetreatSpeed = Config.AutoWalkRetreatSpeed

-- NEW AUTO & MANUAL PASS BOMB FEATURE
_G.AutoPassEnabled = Config.AutoPassEnabled
_G.PassTargetMode = Config.PassTargetMode 
_G.PassMaxDistance = Config.PassMaxDistance 
_G.PassExternalVisible = Config.PassExternalVisible 

-- ========================================================
-- [[ INTEGRATED NEW FEATURES STATE GLOBALS ]]
-- ========================================================
_G.RangeChaseEnabled = Config.RangeChaseEnabled
_G.RangeChaseValue = Config.RangeChaseValue
_G.TripEnabled = Config.TripEnabled

-- FOLLOW & RETREAT MODE SELECTION
_G.FollowTypeMode = Config.FollowTypeMode 

-- LOCAL LIMBS HITBOX EXPANDER STATE (OPPONENTS TARGET)
_G.LocalHitboxEnabled = Config.LocalHitboxEnabled 
_G.HitboxVisualEnabled = Config.HitboxVisualEnabled 
_G.LocalHitboxSize = Config.LocalHitboxSize
_G.HitboxTeleportDelay = Config.HitboxTeleportDelay / 1000 
_G.HitboxShape = Config.HitboxShape

-- CORE WALK VALUES
_G.TPWalkEnabled = Config.TPWalkEnabled
_G.TPWalkSpeed = Config.TPWalkSpeed

-- CAMLOCK STATE
_G.CamlockEnabled = Config.CamlockEnabled
_G.CamlockActive = Config.CamlockActive

-- DESYNC IMMUNITY & GHOST VISUAL STATE
_G.DesyncImmunityEnabled = Config.DesyncImmunityEnabled
_G.DesyncImmunityActive = Config.DesyncImmunityActive
_G.DesyncVisualEnabled = Config.DesyncVisualEnabled

local CFrameHistory = {}
local GhostModel = nil
local LocalHitboxPart = nil
local isHeadlessActive = false
local isKorbloxActive = false
local RangeVisualPart = nil

-- State Internal TBD
local faceSpeed = 0.18
local lockedTarget = nil 
local lastHadBomb = false
local retreatTimer = 0
local autoWalkRetreatTimer = 0
local targetMemory = 0 
local bombTimer = 0 
local isLocked = false
local canWallJump = true
local jumpDebounce = false
local isTweening = false
local lastWallHopTime = 0
local lastShouldFollow = false

-- Performance Throttling & Caching Variables
local lastRaycastCheck = 0
local lastTargetSearch = 0
local raycastInterval = 0.1
local searchInterval = 0.25
local isVisibleCached = false
local lastAutoWalkRaycast = 0
local currentMoveDir = Vector3_new(0, 0, 0)

-- Camera Rotation Cache
local isSticking = false
local previewContainers = {} 

-- ========================================================
-- [[ CUSTOM GLOBAL KEYBIND CONFIGURATION SYSTEM ]]
-- ========================================================
local Keybinds = {}

local function GetKeyCode(str)
    local success, result = pcall(function()
        return Enum.KeyCode[str]
    end)
    if success and result then
        return result
    end
    return Enum.KeyCode.None
end

Keybinds.UIToggle = GetKeyCode(Config.Keybind_UIToggle)
Keybinds.FollowToggle = GetKeyCode(Config.Keybind_FollowToggle)
Keybinds.AutoWalkToggle = GetKeyCode(Config.Keybind_AutoWalkToggle)
Keybinds.AutoPassToggle = GetKeyCode(Config.Keybind_AutoPassToggle)
Keybinds.RangeChaseToggle = GetKeyCode(Config.Keybind_RangeChaseToggle)
Keybinds.FlickToggle = GetKeyCode(Config.Keybind_FlickToggle)
Keybinds.AutoHoldToggle = GetKeyCode(Config.Keybind_AutoHoldToggle)
Keybinds.TripToggle = GetKeyCode(Config.Keybind_TripToggle)
Keybinds.FreezeToggle = GetKeyCode(Config.Keybind_FreezeToggle)
Keybinds.InfJumpToggle = GetKeyCode(Config.Keybind_InfJumpToggle)
Keybinds.WallhopToggle = GetKeyCode(Config.Keybind_WallhopToggle)
Keybinds.HitboxToggle = GetKeyCode(Config.Keybind_HitboxToggle)
Keybinds.CrosshairToggle = GetKeyCode(Config.Keybind_CrosshairToggle)
Keybinds.CamlockToggle = GetKeyCode(Config.Keybind_CamlockToggle)
Keybinds.TPWalkToggle = GetKeyCode(Config.Keybind_TPWalkToggle)
Keybinds.DesyncImmunityToggle = GetKeyCode(Config.Keybind_DesyncImmunityToggle)

-- Register dynamic custom path keybinds on script startup [1]
for _, pathInfo in ipairs(FlingPaths) do
    local savedVal = Config["Keybind_" .. pathInfo.id] or "None"
    Keybinds[pathInfo.id] = GetKeyCode(savedVal)
end

-- ========================================================
-- [[ DYNAMIC CUSTOM CROSSHAIR STATE & PRESETS ]]
-- ========================================================
_G.CrosshairSettings = {
    Enabled = false,
    Style = "Cross",
    Size = 10,
    Gap = 5,
    Thickness = 1.5,
    Color = Color3.fromRGB(0, 255, 150),
    Rainbow = false,
    ImageId = "6877713475",
    Rotation = 0,
    AutoSpin = false,
    SpinSpeed = 50,
    OnlyShiftLock = false,
    HideDefaultCursor = true
}
_G.CrosshairLoaded = false

local PresetNames = {
    "Preset 1 (ID: 6877713475)", "Preset 2 (ID: 11767039030)", "Preset 3 (ID: 11763581182)",
    "Preset 4 (ID: 11816181606)", "Preset 5 (ID: 11816262829)", "Preset 6 (ID: 11894211724)",
    "Preset 7 (ID: 11903012166)", "Preset 8 (ID: 12308297405)", "Preset 9 (ID: 13515759440)",
    "Preset 10 (ID: 13561401101)", "Preset 11 (ID: 13413721933)", "Preset 12 (ID: 12952422567)",
    "Preset 13 (ID: 12789524132)", "Preset 14 (ID: 12681078223)", "Preset 15 (ID: 12403457353)",
    "Preset 16 (ID: 17665878559)", "Preset 17 (ID: 11863480747)", "Preset 18 (ID: 11958213641)",
    "Preset 19 (ID: 17117394116)", "Preset 20 (ID: 10879103438)", "Preset 21 (ID: 12099552082)",
    "Preset 22 (ID: 12645685438)", "Preset 23 (ID: 13187494895)", "Preset 24 (ID: 14165283181)",
    "Preset 25 (ID: 14196151488)", "Preset 26 (ID: 14175340156)", "Preset 27 (ID: 15064835974)",
    "Preset 28 (ID: 11717828334)", "Preset 29 (ID: 11770890261)", "Preset 30 (ID: 12436450999)",
    "Preset 31 (ID: 14828905230)", "Preset 32 (ID: 5112357171)", "Preset 33 (ID: 8351520948)",
    "Preset 34 (ID: 12294092863)", "Preset 35 (ID: 11746881057)", "Preset 36 (ID: 11756692092)",
    "Preset 37 (ID: 11763243469)", "Preset 38 (ID: 12077205402)", "Preset 39 (ID: 12146988029)",
    "Preset 40 (ID: 2366671460)", "Preset 41 (ID: 11915618919)", "Preset 42 (ID: 10164277641)",
    "Preset 43 (ID: 4818758746)", "Preset 44 (ID: 11720549778)", "Preset 45 (ID: 15963047794)",
    "Preset 46 (ID: 13413667445)", "Preset 47 (ID: 12323570810)", "Preset 48 (6877713475)",
    "Preset 49 (9126971642)", "Preset 50 (6848903054)"
}

local CrosshairColorPresets = {
    ["Green (Neon)"] = Color3.fromRGB(0, 255, 150),
    ["Red"] = Color3.fromRGB(255, 75, 75),
    ["Blue"] = Color3.fromRGB(0, 150, 255),
    ["White"] = Color3.fromRGB(255, 255, 255),
    ["Yellow"] = Color3.fromRGB(255, 220, 0),
    ["Cyan"] = Color3.fromRGB(0, 255, 255),
    ["Pink"] = Color3.fromRGB(255, 100, 200)
}

local function GetCleanImageId(id)
    local str = tostring(id)
    local found = str:match("ID:%s*(%d+)")
    if found then
        return found
    end
    return str:gsub("%D", "")
end

-- [[ FORWARD DECLARATIONS ]]
local triggerManualPass
local applyFreeze
local stopFreeze
local startFreeze
local isFreezing = false
local updatePlayersHitboxes
local cleanHitboxes
local WallhopMainToggle, WallhopModeDropdown, WallhopTypeDropdown, FollowToggle
local updateWallhopButtonsSync
local TabPremium
local ToggleFeature = nil

-- ========================================================================
-- [[ REGISTER & SCALE EXTERNAL UTILITY BUTTONS ENGINE ]]
-- ========================================================
local ExternalButtonsList = {}

local function RegisterExternalButton(btnWrapper)
    table.insert(ExternalButtonsList, btnWrapper)
end

local function SetButtonSize(btnWrapper, scaleValue)
    pcall(function()
        if type(btnWrapper) == "table" then
            if btnWrapper.SetSize then
                btnWrapper:SetSize(44 * scaleValue)
            elseif typeof(btnWrapper.Instance) == "Instance" then
                btnWrapper.Instance.Size = UDim2.new(0, 44 * scaleValue, 0, 44 * scaleValue)
            end
        elseif typeof(btnWrapper) == "Instance" and btnWrapper:IsA("GuiObject") then
            btnWrapper.Size = UDim2.new(0, 44 * scaleValue, 0, 44 * scaleValue)
        end
    end)
end

local function SetButtonDragLock(btnWrapper, locked)
    pcall(function()
        if type(btnWrapper) == "table" and btnWrapper.SetDragLock then
            btnWrapper:SetDragLock(locked)
        end
    end)
end

local function UpdateAllButtonsDragLock(locked)
    for _, btn in ipairs(ExternalButtonsList) do
        SetButtonDragLock(btn, locked)
    end
end

local function UpdateAllButtonsSize(scaleValue)
    for _, btn in ipairs(ExternalButtonsList) do
        SetButtonSize(btn, scaleValue)
    end
end

local function SafeSetVisible(btn, visible)
    if btn and type(btn) == "table" and btn.SetVisible then
        pcall(function() btn:SetVisible(visible) end)
    end
end

local function SafeSetText(btn, text)
    if btn and type(btn) == "table" and btn.SetText then
        pcall(function() btn:SetText(text) end)
    end
end

-- ========================================================
-- [[ RE-EXECUTION CLEANUP SYSTEM ]]
-- ========================================================
if _G.LouisConnections then
    for _, conn in pairs(_G.LouisConnections) do
        if conn then pcall(function() conn:Disconnect() end) end
    end
end
_G.LouisConnections = {}

local function SafeConnect(signal, callback)
    local conn = signal:Connect(callback)
    table.insert(_G.LouisConnections, conn)
    return conn
end

if _G.LouisDrawings then
    for _, drawing in pairs(_G.LouisDrawings) do
        pcall(function() drawing:Remove() end)
    end
end
_G.LouisDrawings = {}

pcall(function()
    local successHui, hui = pcall(function() return gethui and gethui() end)
    local parent = (successHui and hui) or game:GetService("CoreGui")
    
    local oldCross = parent:FindFirstChild("LouisHub_FREE_Crosshair")
    if oldCross then oldCross:Destroy() end
    local oldCrossPrem = parent:FindFirstChild("LouisHub_Premium_Crosshair")
    if oldCrossPrem then oldCrossPrem:Destroy() end
end)

pcall(function()
    local oldVisual = workspace:FindFirstChild("LouisHub_RangeVisual")
    if oldVisual then oldVisual:Destroy() end
end)

pcall(function()
    local successHui, hui = pcall(function() return gethui and gethui() end)
    local parent = (successHui and hui) or game:GetService("CoreGui")
    
    local oldHUD = parent:FindFirstChild("LouisHub_FPS_Ping_HUD")
    if oldHUD then oldHUD:Destroy() end
end)

pcall(function()
    local oldLocalVisual = workspace:FindFirstChild("LocalHitboxVisual")
    if oldLocalVisual then oldLocalVisual:Destroy() end
end)

pcall(function()
    local oldGhost = workspace:FindFirstChild("DesyncGhost")
    if oldGhost then oldGhost:Destroy() end
end)

-- Remove old ESP highlights
for _, p in ipairs(Players:GetPlayers()) do
    if p.Character then
        local esp = p.Character:FindFirstChild("LouisESP")
        if esp then pcall(function() esp:Destroy() end) end
    end
end

-- ========================================================
-- [[ TBD GRAPHICS & CORE HELPER FUNCTIONS ]]
-- ========================================================
local function ApplyPotato()
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 250
        Lighting.Brightness = 2
        local s = settings()
        s.Rendering.QualityLevel = 1
        s.Physics.AllowSleep = true
    end)
    task_defer(function()
        local function Clean(v)
            if not v:IsA("BasePart") and not v:IsA("MeshPart") then 
                if v:IsA("Decal") or v:IsA("Texture") or v:IsA("Light") then v:Destroy()
                elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled = false end
                return 
            end
            v.Material = Enum.Material.SmoothPlastic
            v.CastShadow = false
            v.Reflectance = 0
            if v:IsA("MeshPart") then v.TextureID = "" end
        end
        local descendants = workspace:GetDescendants()
        for i, v in ipairs(descendants) do 
            pcall(Clean, v) 
            if i % 200 == 0 then 
                task_wait()
            end
        end
    end)
end

-- ADVANCED BOMB CHECKER (STRICT BOMB TOOL & MODEL DETECTION - NO ACC_COSMETIC CLASH)
local function hasBomb(p) 
    if not p or not p.Character then return false end
    local char = p.Character
    
    local bomb = char:FindFirstChild("Bomb")
    if bomb and (bomb:IsA("Tool") or bomb:IsA("Model")) then
        return true
    end
    
    local backpack = p:FindFirstChildOfClass("Backpack")
    if backpack and backpack:FindFirstChild("Bomb") then
        return true
    end
    
    return false
end

-- HIGH-PERFORMANCE TIMER SCANNER
local cachedBombLabel = nil
local lastBombLabelCheck = 0
local function getBombTime()
    local now = tick()
    if cachedBombLabel and cachedBombLabel.Parent and cachedBombLabel.Visible then
        local cleanTxt = cachedBombLabel.Text:match("[%d%.]+")
        if cleanTxt then
            local num = tonumber(cleanTxt)
            if num and num > 0 and num <= 30 then
                return num
            end
        end
    else
        cachedBombLabel = nil
    end
    
    if now - lastBombLabelCheck >= 0.5 then
        lastBombLabelCheck = now
        
        -- Priority Direct Check: Check character for BillboardGuis on the bomb
        local char = LocalPlayer.Character
        if char then
            local bomb = char:FindFirstChild("Bomb")
            if bomb then
                local billboard = bomb:FindFirstChildOfClass("BillboardGui")
                local label = billboard and billboard:FindFirstChildOfClass("TextLabel")
                if label then
                    cachedBombLabel = label
                    local num = tonumber(label.Text:match("[%d%.]+"))
                    if num then return num end
                end
            end
        end
        
        -- Secondary Direct Check: Shallow-scan active screen elements in PlayerGui
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if playerGui then
            for _, gui in ipairs(playerGui:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Enabled then
                    for _, obj in ipairs(gui:GetChildren()) do
                        if obj:IsA("TextLabel") and obj.Visible then
                            local num = tonumber(obj.Text:match("[%d%.]+"))
                            if num and num > 0 and num <= 30 then
                                cachedBombLabel = obj
                                return num
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function isAlive(p) 
    return p and p.Character and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 and p.Character:FindFirstChild("HumanoidRootPart") 
end

local function isTeammate(p)
    if not p or not p.Character then return false end
    if p.Team ~= nil and p.Team == LocalPlayer.Team then return true end
    local success, isTeam = pcall(function()
        for _, v in pairs(p.Character:GetDescendants()) do 
            if v:IsA("Highlight") and (v.FillColor.G > 0.5 or v.OutlineColor.G > 0.5) then return true end 
        end
        return false
    end)
    if success then return isTeam else return false end
end

-- TARGET VALIDATION FILTER WITH BOMB RULES
local function isValidTarget(p, amIHolder)
    if not p or p == LocalPlayer or not isAlive(p) or isTeammate(p) then 
        return false 
    end
    -- If we carry the bomb, do not lock onto targets that also carry the bomb
    if amIHolder and hasBomb(p) then 
        return false 
    end
    return true
end

-- SAFE CHARACTER TO TOUCH BOUNDARY MODIFIER
local function setCharacterCanTouch(state)
    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanTouch = state
            end
        end
    end
end

local function canSeePlayerSticky(p)
    if not p.Character or not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return false end
    local char = p.Character; local origin = LocalPlayer.Character.HumanoidRootPart.Position
    local params = RaycastParams.new(); params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local partsToCheck = {"Head", "HumanoidRootPart"}
    for _, partName in ipairs(partsToCheck) do
        local part = char:FindFirstChild(partName)
        if part then
            local direction = part.Position - origin
            local success, r = pcall(function() return Workspace:Raycast(origin, direction, params) end)
            if success and (not r or r.Instance:IsDescendantOf(char)) then return true end
        end
    end
    return false
end

-- WALLHOP DETAILED DETECTION (BOUNDING BOX)
local function checkBoundingBoxDetection(root, char)
    local overlapParams = OverlapParams.new()
    overlapParams.FilterDescendantsInstances = {char}
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.MaxParts = 5
    
    local size = Vector3_new(4.5, 5.5, 4.5)
    local success, parts = pcall(function()
        return Workspace:GetPartBoundsInBox(root.CFrame, size, overlapParams)
    end)
    if success and parts then
        for _, part in ipairs(parts) do
            if part.CanCollide then
                return true
            end
        end
    end
    return false
end

local function CreateRangeVisual()
    if RangeVisualPart then pcall(function() RangeVisualPart:Destroy() end) end
    RangeVisualPart = Instance.new("Part")
    RangeVisualPart.Name = "LouisHub_RangeVisual"
    RangeVisualPart.Anchored = true
    RangeVisualPart.CanCollide = false
    RangeVisualPart.CastShadow = false
    RangeVisualPart.Material = Enum.Material.ForceField
    RangeVisualPart.Color = Color3.fromRGB(0, 255, 255)
    RangeVisualPart.Shape = Enum.PartType.Cylinder
    RangeVisualPart.Orientation = Vector3_new(0, 0, 90)
    RangeVisualPart.Transparency = 0.6
    RangeVisualPart.Parent = workspace
end

local function ApplyTrip(state)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end
    
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanTouch = not state 
        end
    end
    
    if state then
        hum.PlatformStand = true 
        hum:ChangeState(Enum.HumanoidStateType.Physics)
        pcall(function()
            hrp.CFrame = hrp.CFrame * CFrame_Angles(math_rad(45), 0, 0)
        end)
    else
        hum.PlatformStand = false
        hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end

task_spawn(function()
    while true do
        task_wait(0.08)
        if _G.TripEnabled and LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hum and hrp then
                pcall(function()
                    hum.PlatformStand = true
                    hum:ChangeState(Enum.HumanoidStateType.Physics)
                end)
            end
        end
    end
end)

local function ApplyHeadless()
    local char = LocalPlayer.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if head then
        head.Transparency = 1
        local face = head:FindFirstChildOfClass("Decal")
        if face then face.Transparency = 1 end
        
        for _, access in ipairs(char:GetChildren()) do
            if access:IsA("Accessory") then
                local handle = access:FindFirstChild("Handle")
                if handle then
                    if handle:FindFirstChildOfClass("SpecialMesh") then
                        local mesh = handle:FindFirstChildOfClass("SpecialMesh")
                        if mesh.MeshType == Enum.MeshType.Head or handle.Name:lower():find("head") or access.Name:lower():find("headless") then
                            handle.Transparency = 1
                        end
                    end
                end
            end
        end
    end
end

local function ApplyKorblox()
    local char = LocalPlayer.Character
    if not char then return end
    
    local rUpper = char:FindFirstChild("RightUpperLeg")
    local rLower = char:FindFirstChild("RightLowerLeg")
    local rFoot = char:FindFirstChild("RightFoot")
    
    if rUpper and rLower and rFoot then
        rUpper.Transparency = 1
        rLower.Transparency = 1
        rFoot.Transparency = 1
        
        if char:FindFirstChild("LocalKorbloxLeg") then
            char.LocalKorbloxLeg:Destroy()
        end
        
        local visualModel = Instance.new("Model", char)
        visualModel.Name = "LocalKorbloxLeg"
        
        local stick = Instance.new("Part", visualModel)
        stick.Name = "StickLeg"
        stick.Size = Vector3_new(0.3, 2.4, 0.3)
        stick.Color = Color3.fromRGB(25, 25, 25)
        stick.Material = Enum.Material.Metal
        stick.CanCollide = false
        stick.Massless = true
        
        local weld = Instance.new("WeldConstraint", stick)
        weld.Part0 = stick
        weld.Part1 = rUpper
        stick.CFrame = rUpper.CFrame * CFrame_new(0, -0.6, 0)
        
        local ring = Instance.new("Part", visualModel)
        ring.Name = "GlowRing"
        ring.Size = Vector3_new(0.5, 0.1, 0.5)
        ring.Color = Color3.fromRGB(0, 150, 255)
        ring.Material = Enum.Material.Neon
        ring.CanCollide = false
        ring.Massless = true
        
        local weld2 = Instance.new("WeldConstraint", ring)
        weld2.Part0 = ring
        weld2.Part1 = rLower
        ring.CFrame = rLower.CFrame * CFrame_new(0, -0.5, 0)
    else
        local rLeg = char:FindFirstChild("Right Leg")
        if rLeg then
            rLeg.Transparency = 1
            if char:FindFirstChild("LocalKorbloxLeg") then
                char.LocalKorbloxLeg:Destroy()
            end
            
            local visualModel = Instance.new("Model", char)
            visualModel.Name = "LocalKorbloxLeg"
            
            local stick = Instance.new("Part", visualModel)
            stick.Size = Vector3_new(0.4, 2, 0.4)
            stick.Color = Color3.fromRGB(25, 25, 25)
            stick.Material = Enum.Material.Metal
            stick.CanCollide = false
            stick.Massless = true
            
            local weld = Instance.new("WeldConstraint", stick)
            weld.Part0 = stick
            weld.Part1 = rLeg
            stick.CFrame = rLeg.CFrame
        end
    end
end

local function ApplyRandomAvatar()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    local presetIds = {1, 150, 261, 187514, 10000, 1610487}
    local selectedId = presetIds[math.random(1, #presetIds)]
    task_spawn(function()
        local success, desc = pcall(function()
            return Players:GetHumanoidDescriptionFromUserId(selectedId)
        end)
        
        if success and desc then
            local applySuccess, err = pcall(function()
                hum:ApplyDescription(desc)
            end)
            if applySuccess then
                Library:Notify("Avatar Changer", "Random client-side avatar loaded successfully!", 2)
                return
            end
        end
        
        pcall(function()
            local shirts = {"rbxassetid://121925345", "rbxassetid://607785314", "rbxassetid://144076387"}
            local pants = {"rbxassetid://122304648", "rbxassetid://607785731", "rbxassetid://144076760"}
            
            local shirt = char:FindFirstChildOfClass("Shirt") or Instance.new("Shirt", char)
            shirt.ShirtTemplate = shirts[math.random(1, #shirts)]
            
            local pant = char:FindFirstChildOfClass("Pants") or Instance.new("Pants", char)
            pant.PantsTemplate = pants[math.random(1, #pants)]
            
            local head = char:FindFirstChild("Head")
            local face = head and head:FindFirstChildOfClass("Decal")
            if face then
                face.Texture = "rbxassetid://143890332"
            end
        end)
        Library:Notify("Avatar Changer", "Random client-side avatar applied successfully (Fallback Mode).", 2)
    end)
end

-- ========================================================================
-- [[ OPTIMIZED HITBOX & OWN CHARACTER RANGE AREA VISUALIZER ENGINE ]]
-- ========================================================================
cleanHitboxes = function()
    if LocalHitboxPart then
        pcall(function() LocalHitboxPart:Destroy() end)
        LocalHitboxPart = nil
    end
end

local lastHitboxUpdate = 0
updatePlayersHitboxes = function()
    local ourChar = LocalPlayer.Character
    local ourHRP = ourChar and ourChar:FindFirstChild("HumanoidRootPart")
    local amIHolder = hasBomb(LocalPlayer)
    
    if not _G.LocalHitboxEnabled or not ourHRP then
        cleanHitboxes()
    else
        -- 1. INSTANT FRAME-BY-FRAME HITBOX TELEPORT PASS ENGINE
        if amIHolder and not isTweening then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and isAlive(player) and not isTeammate(player) and not hasBomb(player) then
                    local opponentHRP = player.Character:FindFirstChild("HumanoidRootPart")
                    if opponentHRP then
                        local distance = (ourHRP.Position - opponentHRP.Position).Magnitude
                        if distance <= _G.LocalHitboxSize then
                            isTweening = true
                            local startCFrame = ourHRP.CFrame
                            
                            task_spawn(function()
                                local success, err = pcall(function()
                                    ourHRP.CFrame = opponentHRP.CFrame * CFrame_new(0, 0, 0.8)
                                    task_wait(_G.HitboxTeleportDelay)
                                    ourHRP.CFrame = startCFrame
                                    task_wait(0.12)
                                end)
                                isTweening = false
                            end)
                            break
                        end
                    end
                end
            end
        end

        -- 2. HIGHLY VISIBLE NEON GLOWING LOCAL RANGE BOUNDS
        local now = tick()
        if (now - lastHitboxUpdate >= 0.08) then
            lastHitboxUpdate = now
            if _G.HitboxVisualEnabled then
                local shape = _G.HitboxShape or "Cylinder"
                local neededClassName = (shape == "Wedge") and "WedgePart" or "Part"
                
                if not LocalHitboxPart or LocalHitboxPart.ClassName ~= neededClassName or LocalHitboxPart.Parent == nil then
                    if LocalHitboxPart then pcall(function() LocalHitboxPart:Destroy() end) end
                    
                    LocalHitboxPart = Instance.new(neededClassName)
                    LocalHitboxPart.Name = "LocalHitboxVisual"
                    LocalHitboxPart.Anchored = true
                    LocalHitboxPart.CanCollide = false
                    LocalHitboxPart.CastShadow = false
                    LocalHitboxPart.Material = Enum.Material.Neon 
                    LocalHitboxPart.Color = Color3.fromRGB(255, 0, 100) 
                    LocalHitboxPart.Transparency = 0.3 
                    LocalHitboxPart.Parent = workspace
                end
                
                if shape == "Cylinder" then
                    LocalHitboxPart.Shape = Enum.PartType.Cylinder
                    LocalHitboxPart.Size = Vector3_new(0.2, _G.LocalHitboxSize * 2, _G.LocalHitboxSize * 2)
                    LocalHitboxPart.CFrame = CFrame_new(ourHRP.Position - Vector3_new(0, 2.8, 0)) * CFrame_Angles(0, 0, math_rad(90))
                elseif shape == "Sphere" then
                    LocalHitboxPart.Shape = Enum.PartType.Ball
                    LocalHitboxPart.Size = Vector3_new(_G.LocalHitboxSize * 2, _G.LocalHitboxSize * 2, _G.LocalHitboxSize * 2)
                    LocalHitboxPart.CFrame = CFrame_new(ourHRP.Position)
                elseif shape == "Block" then
                    LocalHitboxPart.Shape = Enum.PartType.Block
                    LocalHitboxPart.Size = Vector3_new(_G.LocalHitboxSize * 2, _G.LocalHitboxSize * 2, _G.LocalHitboxSize * 2)
                    LocalHitboxPart.CFrame = CFrame_new(ourHRP.Position)
                elseif shape == "Wedge" then
                    LocalHitboxPart.Size = Vector3_new(0.2, _G.LocalHitboxSize * 2, _G.LocalHitboxSize * 2)
                    LocalHitboxPart.CFrame = CFrame_new(ourHRP.Position - Vector3_new(0, 1.5, 0))
                end
                
                LocalHitboxPart.Visible = true
            else
                cleanHitboxes()
            end
        end
    end
end

local HitboxRenderConnection = RunService.PreSimulation:Connect(function()
    if _G.LocalHitboxEnabled then
        pcall(updatePlayersHitboxes)
    end
end)
table.insert(_G.LouisConnections, HitboxRenderConnection)

-- ========================================================
-- [[ LIGHTWEIGHT PLAYERS ESP ENGINE ]]
-- ========================================================
local highlights = {}
local function updateESP()
    if not _G.ESPEnabled then
        for player, highlight in pairs(highlights) do
            pcall(function() highlight:Destroy() end)
        end
        table.clear(highlights)
        return
    end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and isAlive(player) then
            local char = player.Character
            if char then
                local highlight = highlights[player] or char:FindFirstChild("LouisESP")
                if not highlight then
                    highlight = Instance.new("Highlight")
                    highlight.Name = "LouisESP"
                    highlight.FillColor = Color3.fromRGB(255, 0, 0)
                    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                    highlight.FillTransparency = 0.5
                    highlight.OutlineTransparency = 0
                    highlight.Parent = char
                    highlights[player] = highlight
                end
                if hasBomb(player) then
                    highlight.FillColor = Color3.fromRGB(255, 0, 0) 
                elseif isTeammate(player) then
                    highlight.FillColor = Color3.fromRGB(0, 255, 0) 
                else
                    highlight.FillColor = Color3.fromRGB(0, 150, 255) 
                end
            end
        end
    end
    
    for player, highlight in pairs(highlights) do
        if not player.Parent or not isAlive(player) then
            pcall(function() highlight:Destroy() end)
            highlights[player] = nil
        end
    end
end

local ESPConnection = RunService.Heartbeat:Connect(function()
    pcall(updateESP)
end)
table.insert(_G.LouisConnections, ESPConnection)

-- ========================================================
-- [[ GHOST & PHYSICS DESYNC HELPERS ]]
-- ========================================================
local function getPing()
    local success, result = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if success then return result else return 100 end
end

local function updateDesyncGhost(cframe)
    if not _G.DesyncVisualEnabled then
        if GhostModel then GhostModel:Destroy(); GhostModel = nil end
        return
    end
    
    local char = LocalPlayer.Character
    if not char then return end
    
    if not GhostModel or GhostModel.Parent ~= workspace then
        if GhostModel then GhostModel:Destroy() end
        
        local successClone = pcall(function()
            char.Archivable = true
            GhostModel = char:Clone()
            char.Archivable = false
        end)
        
        if successClone and GhostModel then
            GhostModel.Name = "DesyncGhost"
            for _, v in ipairs(GhostModel:GetDescendants()) do
                if v:IsA("LocalScript") or v:IsA("Script") or v:IsA("Animator") or v:IsA("Humanoid") then
                    v:Destroy()
                elseif v:IsA("BasePart") then
                    v.Anchored = true
                    v.CanCollide = false
                    v.CanTouch = false
                    v.CanQuery = false
                    v.Material = Enum.Material.Neon 
                    v.Color = Color3.fromRGB(0, 255, 255) 
                    v.Transparency = 0.3 
                elseif v:IsA("Decal") then
                    v:Destroy()
                end
            end
        else
            GhostModel = Instance.new("Part")
            GhostModel.Name = "DesyncGhost"
            GhostModel.Size = Vector3_new(2, 5, 2)
            GhostModel.Anchored = true
            GhostModel.CanCollide = false
            GhostModel.CanTouch = false
            GhostModel.CanQuery = false
            GhostModel.Color = Color3.fromRGB(0, 255, 255)
            GhostModel.Material = Enum.Material.Neon
            GhostModel.Transparency = 0.6
        end
        GhostModel.Parent = workspace
    end
    
    if GhostModel:IsA("Part") then
        GhostModel.CFrame = cframe
    else
        local ghostRoot = GhostModel:FindFirstChild("HumanoidRootPart")
        if ghostRoot then
            ghostRoot.CFrame = cframe
            for _, limb in ipairs(GhostModel:GetChildren()) do
                if limb:IsA("BasePart") and limb.Name ~= "HumanoidRootPart" then
                    local realLimb = char:FindFirstChild(limb.Name)
                    if realLimb then
                        limb.CFrame = cframe * (char.HumanoidRootPart.CFrame:ToObjectSpace(realLimb.CFrame))
                    end
                end
            end
        end
    end
end

local DesyncPreConnection = RunService.PreSimulation:Connect(function()
    local char = LocalPlayer.Character
    if char then
        if _G.DesyncImmunityEnabled and _G.DesyncImmunityActive then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanTouch then
                    part.CanTouch = false
                end
            end
        else
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and not part.CanTouch then
                    part.CanTouch = true
                end
            end
        end
    end
end)
table.insert(_G.LouisConnections, DesyncPreConnection)

-- ========================================================
-- [[ MOVEMENT & PASS WORKAROUND DEFINITIONS ]]
-- ========================================================

local function teleportTween(targetPart)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and targetPart then
        isTweening = true
        local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear)
        local tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetPart.CFrame})
        tween:Play()
        tween.Completed:Connect(function()
            isTweening = false
        end)
    end
end

triggerManualPass = function()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local rootPos = root.Position
    local bestTarget = nil
    local minDist = math_huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isAlive(p) and not isTeammate(p) and not hasBomb(p) then
            local d = (rootPos - p.Character.HumanoidRootPart.Position).Magnitude
            if d < minDist then
                minDist = d
                bestTarget = p
            end
        end
    end
    if bestTarget then
        teleportTween(bestTarget.Character.HumanoidRootPart)
    else
        Library:Notify("Manual Pass", "No valid player found to pass the bomb!", 2)
    end
end

-- ========================================================
-- [[ AUTOMATIC DEFERRED BUTTON INITIALIZATION ENGINE (PROXY) ]]
-- ========================================================
local deferredButtons = {}
local realCreateButton = Library.CreateExternalButton

Library.CreateExternalButton = function(self, name, text, position, callback)
    local proxy = {
        _visible = false,
        _text = text,
        _size = nil,
        _dragLocked = nil,
        Instance = nil
    }
    
    function proxy:SetVisible(visible)
        self._visible = visible
        if self.Instance and self.Instance.SetVisible then
            pcall(function() self.Instance:SetVisible(visible) end)
        end
    end
    
    function proxy:SetText(txt)
        self._text = txt
        if self.Instance and self.Instance.SetText then
            pcall(function() self.Instance:SetText(txt) end)
        end
    end
    
    function proxy:SetSize(size)
        self._size = size
        if self.Instance and self.Instance.SetSize then
            pcall(function() self.Instance:SetSize(size) end)
        end
    end
    
    function proxy:SetDragLock(locked)
        self._dragLocked = locked
        if self.Instance and self.Instance.SetDragLock then
            pcall(function() self.Instance:SetDragLock(locked) end)
        end
    end
    
    table.insert(deferredButtons, {
        proxy = proxy,
        name = name,
        text = text,
        pos = position,
        cb = callback
    })
    
    return proxy
end

-- ========================================================
-- [[ PREMIUM EXTERNAL BUTTONS CONFIGURATION ]]
-- ========================================================

_G.ExtFollowBtn = Library:CreateExternalButton("Follow", "AUTO FOLLOW", UDim2.new(0.5, -235, 0.8, 0), function()
    if not _G.FollowEnabled then return end
    _G.FollowActive = not _G.FollowActive
    if _G.FollowActive then
        SafeSetText(_G.ExtFollowBtn, "FOLLOWING")
    else
        SafeSetText(_G.ExtFollowBtn, "AUTO FOLLOW")
    end
end)
RegisterExternalButton(_G.ExtFollowBtn)

_G.ExtFreezeBtn = Library:CreateExternalButton("Freeze", "FREEZE", UDim2.new(0.5, -155, 0.8, 0), function()
    if isFreezing then
        stopFreeze()
    else
        startFreeze()
    end
end)
RegisterExternalButton(_G.ExtFreezeBtn)

_G.ExtFlickBtn = Library:CreateExternalButton("Flick", "FLICK", UDim2.new(0.5, -75, 0.8, 0), function()
    _G.FlickActive = not _G.FlickActive
    if _G.FlickActive then
        SafeSetText(_G.ExtFlickBtn, "FLICKING")
    else
        SafeSetText(_G.ExtFlickBtn, "FLICK")
    end
end)
RegisterExternalButton(_G.ExtFlickBtn)

_G.ExtHoldBtn = Library:CreateExternalButton("Hold", "HOLD BOMB", UDim2.new(0.5, 5, 0.8, 0), function()
    _G.AutoHoldActive = not _G.AutoHoldActive
    if _G.AutoHoldActive then
        SafeSetText(_G.ExtHoldBtn, "HOLDING")
    else
        SafeSetText(_G.ExtHoldBtn, "HOLD BOMB")
    end
end)
RegisterExternalButton(_G.ExtHoldBtn)

_G.ExtPassBtn = Library:CreateExternalButton("Pass", "PASS BOMB", UDim2.new(0.5, 85, 0.8, 0), function()
    triggerManualPass()
end)
RegisterExternalButton(_G.ExtPassBtn)

_G.ExtAutoWalkBtn = Library:CreateExternalButton("AutoWalk", "AUTO WALK", UDim2.new(0.5, 165, 0.8, 0), function()
    _G.AutoWalkActive = not _G.AutoWalkActive
    if _G.AutoWalkActive then
        SafeSetText(_G.ExtAutoWalkBtn, "WALKING")
    else
        SafeSetText(_G.ExtAutoWalkBtn, "AUTO WALK")
    end
end)
RegisterExternalButton(_G.ExtAutoWalkBtn)

_G.ExtRangeChaseBtn = Library:CreateExternalButton("RangeChase", "RANGE CHASE", UDim2.new(0.5, -235, 0.72, 0), function()
    _G.RangeChaseEnabled = not _G.RangeChaseEnabled
    if _G.RangeChaseEnabled then
        SafeSetText(_G.ExtRangeChaseBtn, "CHASING")
    else
        SafeSetText(_G.ExtRangeChaseBtn, "RANGE CHASE")
    end
end)
RegisterExternalButton(_G.ExtRangeChaseBtn)

_G.ExtTripBtn = Library:CreateExternalButton("TripFall", "TRIP FALL", UDim2.new(0.5, -155, 0.72, 0), function()
    _G.TripEnabled = not _G.TripEnabled
    ApplyTrip(_G.TripEnabled)
    if _G.TripEnabled then
        SafeSetText(_G.ExtTripBtn, "TRIPPED")
    else
        SafeSetText(_G.ExtTripBtn, "TRIP FALL")
    end
end)
RegisterExternalButton(_G.ExtTripBtn)

-- CAMLOCK FLOATING EXTERNAL BUTTON
_G.ExtCamlockBtn = Library:CreateExternalButton("Camlock", "CAMLOCK", UDim2.new(0.5, 5, 0.72, 0), function()
    if not _G.CamlockEnabled then return end
    _G.CamlockActive = not _G.CamlockActive
    if _G.CamlockActive then
        SafeSetText(_G.ExtCamlockBtn, "CAMLOCK [ON]")
    else
        SafeSetText(_G.ExtCamlockBtn, "CAMLOCK")
    end
end)
RegisterExternalButton(_G.ExtCamlockBtn)

-- AETHERIAL DESYNC SHIELD FLOATING EXTERNAL BUTTON
_G.ExtDesyncImmunityBtn = Library:CreateExternalButton("DesyncShield", "DESYNC SHIELD", UDim2.new(0.5, 85, 0.72, 0), function()
    if not _G.DesyncImmunityEnabled then return end
    _G.DesyncImmunityActive = not _G.DesyncImmunityActive
    setCharacterCanTouch(not _G.DesyncImmunityActive)
    if _G.DesyncImmunityActive then
        SafeSetText(_G.ExtDesyncImmunityBtn, "SHIELD [ON]")
    else
        SafeSetText(_G.ExtDesyncImmunityBtn, "DESYNC SHIELD")
    end
end)
RegisterExternalButton(_G.ExtDesyncImmunityBtn)

-- CONSOLIDATED WALLHOP TYPE EXTERNAL BUTTONS
_G.ExtWHNormalBtn = Library:CreateExternalButton("WHNormal", "wh_normal", UDim2.new(0.5, -75, 0.72, 0), function()
    ToggleFeature("Wallhop")
end)
RegisterExternalButton(_G.ExtWHNormalBtn)

_G.ExtWHInstantBtn = Library:CreateExternalButton("WHInstant", "wh_instant", UDim2.new(0.5, -75, 0.72, 0), function()
    ToggleFeature("Wallhop")
end)
RegisterExternalButton(_G.ExtWHInstantBtn)

_G.ExtWHUltraBtn = Library:CreateExternalButton("WHUltra", "wh_ultra", UDim2.new(0.5, -75, 0.72, 0), function()
    ToggleFeature("Wallhop")
end)
RegisterExternalButton(_G.ExtWHUltraBtn)

-- ========================================================
-- [[ REGISTER CUSTOM PATH EXTERNAL BUTTONS (DEFERRED) ]]
-- ========================================================
local startX = -235
local startY = 0.64
local count = 0

for _, pathInfo in ipairs(FlingPaths) do
    local currentInfo = pathInfo
    local xOffset = startX + ((count % 6) * 80)
    local yOffset = startY - (math.floor(count / 6) * 0.08)

    local btn = Library:CreateExternalButton(currentInfo.id, currentInfo.display:upper(), UDim2.new(0.5, xOffset, yOffset, 0), function()
        triggerPath(currentInfo)
    end)

    RegisterExternalButton(btn) -- Adds to the scaling/draglock management list! [1]
    PathButtons[currentInfo.id] = btn
    count = count + 1
end

applyFreeze = function(state)
    local char = LocalPlayer.Character
    if not char then return end
    
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = state
        end
    end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = state
    end
end

stopFreeze = function()
    if not isFreezing then return end
    isFreezing = false
    applyFreeze(false)
    SafeSetText(_G.ExtFreezeBtn, "FREEZE")
end

startFreeze = function()
    if isFreezing then return end
    isFreezing = true
    applyFreeze(true)
    SafeSetText(_G.ExtFreezeBtn, "FROZEN")
end


-- ========================================================
-- [[ PASSIVE CUSTOM CROSSHAIR MOUSE BYPASS ENGINE (SAFE VERSION) ]]
-- ========================================================
local TRANSPARENT_ICON = "rbxassetid://0"

SafeConnect(RunService.PostSimulation, function()
    if _G.CrosshairSettings.Enabled and _G.CrosshairSettings.HideDefaultCursor then
        if Mouse.Icon ~= TRANSPARENT_ICON then
            pcall(function()
                Mouse.Icon = TRANSPARENT_ICON
            end)
        end
    else
        if Mouse.Icon == TRANSPARENT_ICON then
            pcall(function()
                Mouse.Icon = ""
            end)
        end
    end
end)

-- ========================================================
-- [[ MOVEMENT & TBD AUTOMATIONS PHYSICS ENGINE ]]
-- ========================================================
local function performWallhop(visualStyle)
    if not canWallJump or (tick() - lastWallHopTime < 0.18) then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {char}
    params.FilterType = Enum.RaycastFilterType.Exclude

    local isNearWall = false
    local dMode = _G.WallhopDetectionMode or "Raycast Only"
    local studEnabled = _G.WallhopStudEnabled

    -- Detect with Stud (Raycast) - Only if studEnabled is true
    if studEnabled and (dMode == "Raycast Only" or dMode == "Hybrid") then
        local dir = Vector3_new(0, 0, 0)
        for i = 0, 7 do
            local angle = math_rad(i * 45)
            dir = (root.CFrame * CFrame_Angles(0, angle, 0)).LookVector
            local r = Workspace:Raycast(root.Position, dir * _G.WallHopDist, params)
            if r and r.Instance.CanCollide then -- Syntax typo corrected from "r wholesaler" to "r" [1]
                isNearWall = true
                break
            end
        end
    end

    -- Alternative Detection: Bounding Box
    if not isNearWall and (not studEnabled or dMode == "Bounding Box" or dMode == "Hybrid") then
        isNearWall = checkBoundingBoxDetection(root, char)
    end

    if isNearWall and hum.FloorMaterial == Enum.Material.Air then
        lastWallHopTime = tick()
        canWallJump = false

        local jumpPowerBoost = hum.JumpPower > 0 and hum.JumpPower or 50
        root.AssemblyLinearVelocity = Vector3_new(root.AssemblyLinearVelocity.X, jumpPowerBoost * 0.95, root.AssemblyLinearVelocity.Z)
        hum:ChangeState(Enum.HumanoidStateType.Jumping)

        -- Wallhop CFrame Customization
        local fMode = _G.WallhopFlickMode or "Default"
        if fMode == "Front-to-Back Flick" then
            local cameraDir = Camera.CFrame.LookVector
            local flatCamDir = Vector3_new(cameraDir.X, 0, cameraDir.Z).Unit
            
            root.CFrame = CFrame_new(root.Position, root.Position + flatCamDir)
            
            task_wait(0.01)
            root.CFrame = root.CFrame * CFrame_Angles(0, math_rad(180), 0)
        elseif fMode == "Back-to-Front Flick" then
            local cameraDir = Camera.CFrame.LookVector
            local flatCamDir = Vector3_new(cameraDir.X, 0, cameraDir.Z).Unit
            
            root.CFrame = CFrame_new(root.Position, root.Position + flatCamDir) * CFrame_Angles(0, math_rad(180), 0)
            
            task_wait(0.01)
            root.CFrame = CFrame_new(root.Position, root.Position + flatCamDir)
        end

        if visualStyle == "Instant" then
            task_spawn(function()
                pcall(function()
                    local angle = math_rad(15)
                    Camera.CFrame = Camera.CFrame * CFrame_Angles(0, -angle, 0)
                    task_wait(0.01)
                    Camera.CFrame = Camera.CFrame * CFrame_Angles(0, angle * 2, 0)
                    task_wait(0.01)
                    Camera.CFrame = Camera.CFrame * CFrame_Angles(0, -angle, 0)
                end)
            end)
        elseif visualStyle == "Normal" then
            task_spawn(function()
                root.CFrame = root.CFrame * CFrame_Angles(0, math_rad(-30), 0)
                task_wait(0.06)
                root.CFrame = root.CFrame * CFrame_Angles(0, math_rad(30), 0)
            end)
        end

        task_wait(0.18)
        canWallJump = true
    end
end

-- WALLHOP EXTERNAL BUTTONS VISIBILITY SYNCHRONIZATION ENGINE
updateWallhopButtonsSync = function()
    local isEnabled = _G.WallhopEnabled
    local isActive = _G.WallhopActive
    local wType = _G.WallhopType
    
    SafeSetVisible(_G.ExtWHNormalBtn, false)
    SafeSetVisible(_G.ExtWHInstantBtn, false)
    SafeSetVisible(_G.ExtWHUltraBtn, false)
    
    if isEnabled then
        if wType == "Normal" then
            SafeSetVisible(_G.ExtWHNormalBtn, true)
            if isActive then
                SafeSetText(_G.ExtWHNormalBtn, "WH_NORMAL [ON]")
            else
                SafeSetText(_G.ExtWHNormalBtn, "wh_normal")
            end
        elseif wType == "Instant" then
            SafeSetVisible(_G.ExtWHInstantBtn, true)
            if isActive then
                SafeSetText(_G.ExtWHInstantBtn, "WH_INSTANT [ON]")
            else
                SafeSetText(_G.ExtWHInstantBtn, "wh_instant")
            end
        elseif wType == "Ultra" then
            SafeSetVisible(_G.ExtWHUltraBtn, true)
            if isActive then
                SafeSetText(_G.ExtWHUltraBtn, "WH_ULTRA [ON]")
            else
                SafeSetText(_G.ExtWHUltraBtn, "wh_ultra")
            end
        end
    end
end

-- PRIMARY GAMEPLAY CORE LOOP
SafeConnect(RunService.Heartbeat, LPH_NO_VIRTUALIZE(function(dt)
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    local root = LocalPlayer.Character.HumanoidRootPart
    local hum = LocalPlayer.Character.Humanoid
    
    local amIHolder = hasBomb(LocalPlayer)
    local fovEnabled = _G.FOVEnabled
    local fovValue = _G.FOVValue
    local rangeChaseEnabled = _G.RangeChaseEnabled
    local rangeChaseValue = _G.RangeChaseValue
    local autoWalkActive = _G.AutoWalkActive
    local followTypeMode = _G.FollowTypeMode
    local autoPassEnabled = _G.AutoPassEnabled
    local passTargetMode = _G.PassTargetMode
    local passMaxDistance = _G.PassMaxDistance
    local followEnabled = _G.FollowEnabled
    local followActive = _G.FollowActive 
    local predictEnabled = _G.PredictEnabled
    local autoHoldActive = _G.AutoHoldActive
    local flickActive = _G.FlickActive
    local wallhopEnabled = _G.WallhopEnabled
    local wallhopActive = _G.WallhopActive
    local wallhopMode = _G.WallhopMode
    local wallhopType = _G.WallhopType
    local flickStrength = _G.FlickStrength
    local autoWalkRetreatSpeed = _G.AutoWalkRetreatSpeed
    local hijackEnabled = _G.HijackEnabled
    local hijackDistance = _G.HijackDistance
    
    if hum and hum.FloorMaterial ~= Enum.Material.Air then
        _G.CurrentJumpCount = 0
    end

    if fovEnabled and Camera.FieldOfView ~= fovValue then
        Camera.FieldOfView = fovValue
    end

    if _G.TPWalkEnabled and hum and hum.MoveDirection.Magnitude > 0 then
        local tpSpeed = _G.TPWalkSpeed or 16
        local cf = root.CFrame
        local offset = hum.MoveDirection * (tpSpeed * dt)
        local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
        root.CFrame = CFrame_new(cf.X + offset.X, cf.Y + offset.Y, cf.Z + offset.Z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
    end

    if _G.DesyncVisualEnabled then
        table.insert(CFrameHistory, {Time = tick(), CFrame = root.CFrame})
        while #CFrameHistory > 0 and tick() - CFrameHistory[1].Time > 2 do
            table.remove(CFrameHistory, 1)
        end
        
        local currentPing = getPing()
        local latencyDelay = math_clamp(currentPing / 1000, 0.03, 1.5)
        local ghostCFrame = root.CFrame
        for i = #CFrameHistory, 1, -1 do
            if tick() - CFrameHistory[i].Time >= latencyDelay then
                ghostCFrame = CFrameHistory[i].CFrame
                break
            end
        end
        updateDesyncGhost(ghostCFrame)
    else
        if GhostModel then GhostModel:Destroy(); GhostModel = nil end
    end

    if _G.DesyncImmunityEnabled and _G.DesyncImmunityActive then
        setCharacterCanTouch(false)
    end

    if rangeChaseEnabled then
        if not RangeVisualPart or RangeVisualPart.Parent == nil then
            CreateRangeVisual()
        end
        if RangeVisualPart then
            RangeVisualPart.Size = Vector3_new(0.2, rangeChaseValue * 2, rangeChaseValue * 2)
            local groundPosition = root.Position - Vector3_new(0, 2.8, 0)
            RangeVisualPart.CFrame = CFrame_new(groundPosition) * CFrame_Angles(0, 0, math_rad(90))
        end
    else
        if RangeVisualPart then
            pcall(function() RangeVisualPart:Destroy() end)
            RangeVisualPart = nil
        end
    end

    if hum.FloorMaterial == Enum.Material.Air and root.Velocity.Magnitude > 100 then 
        root.Velocity = root.Velocity.Unit * 100 
    end
    if amIHolder then bombTimer = bombTimer + dt else bombTimer = 0 end

    isSticking = false

    if tick() - lastRaycastCheck >= raycastInterval then
        if lockedTarget then isVisibleCached = canSeePlayerSticky(lockedTarget) end
        lastRaycastCheck = tick()
    end

    if not lastHadBomb and amIHolder then
        retreatTimer = 0
        local minDist = math_huge
        local bestTarget = nil
        for _, p in ipairs(Players:GetPlayers()) do
            if isValidTarget(p, true) then
                local d = (root.Position - p.Character.HumanoidRootPart.Position).Magnitude
                if d < minDist then 
                    minDist = d
                    bestTarget = p 
                end
            end
        end
        if bestTarget then 
            lockedTarget = bestTarget
            targetMemory = 2 
        end 
    end

    if lockedTarget and not isValidTarget(lockedTarget, amIHolder) then 
        lockedTarget = nil 
    end
    
    if isVisibleCached then 
        targetMemory = 1.2 
    elseif targetMemory > 0 then 
        targetMemory = targetMemory - dt 
    end

    if tick() - lastTargetSearch >= searchInterval then
        local pList = Players:GetPlayers()
        local minDist = math_huge; local best = nil; local closestDist = math_huge; local closestPlayer = nil
        
        if rangeChaseEnabled then
            for _, p in pairs(pList) do
                if isValidTarget(p, amIHolder) then
                    local d = (root.Position - p.Character.HumanoidRootPart.Position).Magnitude
                    if d <= rangeChaseValue and d < minDist then
                        minDist = d
                        best = p
                    end
                end
            end
            lockedTarget = best
        else
            for _, p in pairs(pList) do
                if isValidTarget(p, amIHolder) then
                    local d = (root.Position - p.Character.HumanoidRootPart.Position).Magnitude
                    if d < closestDist then 
                        closestDist = d
                        closestPlayer = p 
                    end
                    
                    if d < minDist then
                        if canSeePlayerSticky(p) then 
                            minDist = d
                            best = p 
                        end
                    end
                end
            end
            
            if lockedTarget and isValidTarget(lockedTarget, amIHolder) and (targetMemory > 0 or isVisibleCached) then
                if isVisibleCached then
                    targetMemory = 1.2
                end
                
                if hijackEnabled and closestPlayer and closestPlayer ~= lockedTarget then
                    if closestDist <= hijackDistance then
                        lockedTarget = closestPlayer
                        targetMemory = 1.2
                    end
                end
            else
                if hijackEnabled and closestPlayer and closestDist <= hijackDistance then
                    lockedTarget = closestPlayer
                    targetMemory = 1.2
                elseif best then
                    lockedTarget = best
                    targetMemory = 1.2
                else
                    lockedTarget = nil
                end
            end
        end
        lastTargetSearch = tick()
    end

    if lastHadBomb and not amIHolder then 
        hum.WalkSpeed = 16
        retreatTimer = _G.HJEnabled and 3.8 or 2.5
        if _G.HJEnabled then task_spawn(function() hum:ChangeState(3); task_wait(0.4); hum:ChangeState(3) end) end
        if autoWalkActive then
            autoWalkRetreatTimer = 2.5
        end
    end

    if autoPassEnabled and amIHolder and not isTweening then
        local rootPos = root.Position
        local bestTarget = nil
        local minDist = math_huge
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and isAlive(p) and not isTeammate(p) and not hasBomb(p) then
                local d = (rootPos - p.Character.HumanoidRootPart.Position).Magnitude
                if d <= passMaxDistance and d < minDist then
                    minDist = d
                    bestTarget = p
                end
            end
        end
        if bestTarget then
            teleportTween(bestTarget.Character.HumanoidRootPart)
        end
    end

    if rangeChaseEnabled then
        if lockedTarget and isAlive(lockedTarget) then
            local tRoot = lockedTarget.Character.HumanoidRootPart
            local targetPos = tRoot.Position
            hum:MoveTo(targetPos)
        end
    elseif autoWalkActive then
        local params = RaycastParams.new()
        params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
        params.FilterType = Enum.RaycastFilterType.Exclude

        if amIHolder then
            if lockedTarget and isAlive(lockedTarget) then
                local tRoot = lockedTarget.Character.HumanoidRootPart; local dist = (root.Position - tRoot.Position).Magnitude
                if dist <= 12 then hum.WalkSpeed = 25 else hum.WalkSpeed = 16 end
                
                local targetPos = tRoot.Position
                local speed = 25
                
                local now = tick()
                if now - lastAutoWalkRaycast >= 0.12 or currentMoveDir == nil then
                    lastAutoWalkRaycast = now
                    local moveDir = (targetPos - root.Position).Unit
                    local rayOrigin = root.Position + Vector3_new(0, -1.2, 0)
                    local raycastResult = Workspace:Raycast(rayOrigin, moveDir * 6, params)
                    if raycastResult and raycastResult.Instance.CanCollide then
                        local angles = {30, -30, 60, -60, 90, -90, 120, -120}
                        for _, angle in ipairs(angles) do
                            local worldAltDir = (CFrame_lookAt(root.Position, targetPos) * CFrame_Angles(0, math_rad(angle), 0)).LookVector
                            local altRay = Workspace:Raycast(rayOrigin, worldAltDir * 6, params)
                            if not altRay or not altRay.Instance.CanCollide then
                                moveDir = worldAltDir
                                break
                            end
                        end
                    end
                    currentMoveDir = moveDir
                end
                
                local nextPos = root.Position + (currentMoveDir * speed * dt)
                local targetY = root.Position.Y
                
                if hum.FloorMaterial ~= Enum.Material.Air then
                    local groundRay = Workspace:Raycast(nextPos + Vector3_new(0, 5, 0), Vector3_new(0, -12, 0), params)
                    if groundRay then
                        targetY = groundRay.Position.Y + 3.0
                    end
                else
                    targetY = root.Position.Y + (root.AssemblyLinearVelocity.Y * dt)
                end
                
                root.CFrame = CFrame_new(Vector3_new(nextPos.X, targetY, nextPos.Z), Vector3_new(targetPos.X, targetY, targetPos.Z))
                hum:Move(Vector3_new(0, 0, 0))
            else
                hum.WalkSpeed = 16
            end
        else
            if followTypeMode == "Follow Only" then
                if lockedTarget and isAlive(lockedTarget) then
                    local tRoot = lockedTarget.Character.HumanoidRootPart
                    hum:MoveTo(tRoot.Position)
                else
                    hum:Move(Vector3_new(0, 0, 0))
                end
            else 
                local bombHolder = nil
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and isAlive(p) and hasBomb(p) then
                        bombHolder = p
                        break
                    end
                end
                
                if bombHolder then
                    local targetPos = bombHolder.Character.HumanoidRootPart.Position
                    local speed = autoWalkRetreatSpeed or 22
                    
                    local now = tick()
                    if now - lastAutoWalkRaycast >= 0.12 or currentMoveDir == nil then
                        lastAutoWalkRaycast = now
                        local moveDir = (root.Position - targetPos).Unit
                        local rayOrigin = root.Position + Vector3_new(0, -1.2, 0)
                        local raycastResult = Workspace:Raycast(rayOrigin, moveDir * 6, params)
                        if raycastResult and raycastResult.Instance.CanCollide then
                            local angles = {30, -30, 60, -60, 90, -90, 120, -120}
                            for _, angle in ipairs(angles) do
                                local worldAltDir = (CFrame_lookAt(root.Position, root.Position + moveDir) * CFrame_Angles(0, math_rad(angle), 0)).LookVector
                                local altRay = Workspace:Raycast(rayOrigin, worldAltDir * 6, params)
                                if not altRay or not altRay.Instance.CanCollide then
                                    moveDir = worldAltDir
                                    break
                                end
                            end
                        end
                        currentMoveDir = moveDir
                    end
                    
                    local nextPos = root.Position + (currentMoveDir * speed * dt)
                    local targetY = root.Position.Y
                    
                    if hum.FloorMaterial ~= Enum.Material.Air then
                        local groundRay = Workspace:Raycast(nextPos + Vector3_new(0, 5, 0), Vector3_new(0, -12, 0), params)
                        if groundRay then
                            targetY = groundRay.Position.Y + 3.0
                        end
                    else
                        targetY = root.Position.Y + (root.AssemblyLinearVelocity.Y * dt)
                    end
                    
                    root.CFrame = CFrame_new(Vector3_new(nextPos.X, targetY, nextPos.Z), Vector3_new(targetPos.X, targetY, targetPos.Z))
                    hum:Move(Vector3_new(0, 0, 0))
                else
                    if lockedTarget and isAlive(lockedTarget) then
                        local tRoot = lockedTarget.Character.HumanoidRootPart
                        hum:MoveTo(root.Position + (root.Position - tRoot.Position).Unit * 22)
                    end
                end
            end
        end
    else
        if lockedTarget and isAlive(lockedTarget) then
            local tRoot = lockedTarget.Character.HumanoidRootPart; local dist = (root.Position - tRoot.Position).Magnitude
            if amIHolder and dist <= 12 then hum.WalkSpeed = 25 else hum.WalkSpeed = 16 end
            
            local shouldFollow = (followEnabled and followActive) or autoHoldActive
            local targetPos = predictEnabled and (tRoot.Position + (tRoot.Velocity * 0.13)) or tRoot.Position
            
            if shouldFollow then
                if followTypeMode == "Follow Only" then
                    hum:MoveTo(targetPos)
                else 
                    if retreatTimer <= 0 then 
                        hum:MoveTo(targetPos) 
                    else
                        retreatTimer = retreatTimer - dt
                        hum:MoveTo(root.Position + (root.Position - tRoot.Position).Unit * 22)
                    end
                end
            elseif lastShouldFollow then
                hum:Move(Vector3_new(0, 0, 0))
            end
            lastShouldFollow = shouldFollow
        else 
            hum.WalkSpeed = 16 
            if lastShouldFollow then
                hum:Move(Vector3_new(0, 0, 0))
                lastShouldFollow = false
            end
        end
    end

    if flickActive and amIHolder and isAlive(lockedTarget) and (root.Position - lockedTarget.Character.HumanoidRootPart.Position).Magnitude <= 4 then
        local flickMode = _G.FlickTargetMode or "Camera Only"
        
        if flickMode == "Camera Only" or flickMode == "Both" then
            local str = flickStrength or 45
            Camera.CFrame = Camera.CFrame * CFrame_Angles(math_rad(math_random(-str/2, str/2)), math_rad(math_random(-str, str)), 0)
        end
        
        if flickMode == "Character Only" or flickMode == "Both" then
            local charStr = _G.CharFlickStrength or 45
            root.CFrame = root.CFrame * CFrame_Angles(0, math_rad(math_random(-charStr, charStr)), 0)
        end
    end

    local needsFacing = false
    local lookDir = nil

    if isAlive(lockedTarget) then
        local targetPos = lockedTarget.Character.HumanoidRootPart.Position
        local flatTargetPos = Vector3_new(targetPos.X, root.Position.Y, targetPos.Z)
        
        if _G.CamlockEnabled and _G.CamlockActive then
            needsFacing = true
            if amIHolder then
                lookDir = flatTargetPos
            else
                lookDir = root.Position + (root.Position - flatTargetPos).Unit
            end
        elseif autoHoldActive and amIHolder then
            needsFacing = true
            local remaining = getBombTime()
            if remaining and remaining <= 1.05 then
                lookDir = flatTargetPos
            else
                lookDir = root.Position + (root.Position - flatTargetPos).Unit
            end
        end
    end

    if needsFacing and lookDir then
        hum.AutoRotate = false
        root.CFrame = root.CFrame:Lerp(CFrame_new(root.Position, lookDir), 0.3)
    else
        hum.AutoRotate = true
    end

    if canWallJump and (tick() - lastWallHopTime >= 0.18) then
        if wallhopEnabled and wallhopActive and wallhopMode == "Automatic" then
            local visualStyle = wallhopType
            if visualStyle == "Ultra" then
                if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
                    visualStyle = "Instant"
                else
                    visualStyle = "Normal"
                end
            end
            performWallhop(visualStyle)
        end
    end

    lastHadBomb = amIHolder
end))

-- STRETCH RESOLUTION RENDER LOOP
SafeConnect(RunService.RenderStepped, function()
    if _G.ResolutionEnabled and _G.ResolutionValue ~= 1.00 then
        Camera.CFrame = Camera.CFrame * CFrame_new(0, 0, 0, 1, 0, 0, 0, _G.ResolutionValue, 0, 0, 0, 1)
    end
end)

-- WALLHOP & MULTI-JUMP CONNECTOR (PREMIUM IMPLEMENTATION)
local JumpRequestConnection = UserInputService.JumpRequest:Connect(function()
    isSticking = false 

    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local r_top = char:FindFirstChild("HumanoidRootPart")
    if not hum or not r_top then return end

    if _G.WallhopEnabled and _G.WallhopActive and _G.WallhopMode == "Manual" then
        local visualStyle = _G.WallhopType
        if visualStyle == "Ultra" then
            if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
                visualStyle = "Instant"
            else
                visualStyle = "Normal"
            end
        end
        performWallhop(visualStyle)
    end

    if _G.InfJumpEnabled and not jumpDebounce then
        jumpDebounce = true
        if hum.FloorMaterial == Enum.Material.Air then
            if _G.CurrentJumpCount < _G.MaxJumpCount - 1 then
                _G.CurrentJumpCount = _G.CurrentJumpCount + 1
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        else
            _G.CurrentJumpCount = 0
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
        task_spawn(function()
            task_wait(0.2)
            jumpDebounce = false
        end)
    end
end)
table.insert(_G.LouisConnections, JumpRequestConnection)

-- ========================================================
-- [[ MAIN MENU STRUCTURE ]]
-- ========================================================
local Window = Library:CreateWindow("LOUIS TBD PREMIUM EDITION", "discord.gg/P2FEVBz2PG")
Window:BindToggleKey(Keybinds.UIToggle)


-- [[ EXECUTE DEFERRED BUTTONS ]]
Library.CreateExternalButton = realCreateButton 

for _, btn in ipairs(deferredButtons) do
    local realBtn = Library:CreateExternalButton(btn.name, btn.text, btn.pos, btn.cb)
    btn.proxy.Instance = realBtn
    
    -- Check if it's one of our custom path buttons [1]
    local isCustomPath = false
    for _, pathInfo in ipairs(FlingPaths) do
        if pathInfo.id == btn.name then
            isCustomPath = true
            break
        end
    end

    if isCustomPath then
        realBtn:SetVisible(false) -- Custom path buttons start as hidden [1]
    else
        if btn.proxy._visible ~= nil then realBtn:SetVisible(btn.proxy._visible) end
    end
    
    if btn.proxy._text ~= nil then realBtn:SetText(btn.proxy._text) end
    if btn.proxy._size ~= nil then realBtn:SetSize(btn.proxy._size) end
    if btn.proxy._dragLocked ~= nil then realBtn:SetDragLock(btn.proxy._dragLocked) end
end

Library:Notify("LOUIS HUB PREMIUM EDITION INSTANTIATED", "Press UI Menu Key to show or hide Main UI.", 4)

-- --- TAB 1: WELCOME (LUCIDE ICON: "home") ---
local TabMain = Window:CreateTab("Welcome", "home")
TabMain:CreateParagraph("Welcome!", "Hello " .. LocalPlayer.Name .. "!\nThank you for executing Louis TBD Premium Edition.")
TabMain:CreateParagraph("UI Instructions", "Keybind to open/hide menu: UI Toggle Key\nYou can toggle external buttons from settings.")
TabMain:CreateParagraph("Official Community", "Join our Discord server to get the latest update information!")

TabMain:CreateButton("Copy Discord Server Link", function()
    if setclipboard then
        setclipboard("https://discord.gg/P2FEVBz2PG")
        Library:Notify("Discord Link", "Discord link copied successfully to your clipboard!", 2)
    else
        Library:Notify("Error", "Your exploit does not support clipboard copying.", 2.5)
    end
end)

TabMain:CreateButton("Activate Potato Graphics Optimization", function()
    ApplyPotato()
    Library:Notify("Potato Mode", "Graphics optimized successfully!", 3)
end)

-- --- TAB 2: COMBAT (LUCIDE ICON: "swords") ---
local TabCombat = Window:CreateTab("Combat", "swords")

TabCombat:CreateParagraph("Auto Chase & Walk Controls", "Configure automated player tracking, prediction systems, and movement paths.")

FollowToggle = TabCombat:CreateToggle("Enable Follow System", Config.FollowEnabled, "FollowEnabled", function(state)
    _G.FollowEnabled = state
    _G.FollowActive = state 
    Config.FollowEnabled = state
    SaveConfig()
    SafeSetVisible(_G.ExtFollowBtn, state)
    if state then
        SafeSetText(_G.ExtFollowBtn, "FOLLOWING")
    else
        SafeSetText(_G.ExtFollowBtn, "AUTO FOLLOW")
    end
end)

TabCombat:CreateToggle("Predict Coordinates", Config.PredictEnabled, "PredictEnabled", function(state)
    _G.PredictEnabled = state
    Config.PredictEnabled = state
    SaveConfig()
end)

TabCombat:CreateToggle("Enable Auto Walk System", Config.AutoWalkEnabled, "AutoWalkEnabled", function(state)
    _G.AutoWalkEnabled = state
    _G.AutoWalkActive = state 
    Config.AutoWalkEnabled = state
    SaveConfig()
    SafeSetVisible(_G.ExtAutoWalkBtn, state)
    if state then
        SafeSetText(_G.ExtAutoWalkBtn, "WALKING")
    else
        SafeSetText(_G.ExtAutoWalkBtn, "AUTO WALK")
    end
end)

TabCombat:CreateSlider("Auto Walk Retreat Speed", 10, 50, Config.AutoWalkRetreatSpeed, "AutoWalkRetreatSpeed", function(val)
    _G.AutoWalkRetreatSpeed = val
    Config.AutoWalkRetreatSpeed = val
    SaveConfig()
end)

TabCombat:CreateDropdown("Follow & Walk Mode", {"Follow + Retreat", "Follow Only"}, Config.FollowTypeMode, "FollowTypeMode", function(val)
    _G.FollowTypeMode = val
    Config.FollowTypeMode = val
    SaveConfig()
end)

TabCombat:CreateParagraph("Target Hijack Controls", "Locks onto players automatically. If enabled, it allows you to dynamically shift your active follow target to any nearby opponent who enters your specified radius.")

TabCombat:CreateToggle("Enable Target Hijacking", Config.HijackEnabled, "HijackEnabled", function(state)
    _G.HijackEnabled = state
    Config.HijackEnabled = state
    SaveConfig()
end)

TabCombat:CreateSlider("Hijack Override Distance (Studs)", 1, 100, Config.HijackDistance, "HijackDistance", function(val)
    _G.HijackDistance = val
    Config.HijackDistance = val
    SaveConfig()
end)

TabCombat:CreateParagraph("Automatic Bomb Passing", "Instantly transitions to a target player, hands over the bomb, and safely returns back.")

TabCombat:CreateToggle("Enable Auto Pass Bomb", Config.AutoPassEnabled, "AutoPassEnabled", function(state)
    _G.AutoPassEnabled = state
    Config.AutoPassEnabled = state
    SaveConfig()
end)

TabCombat:CreateDropdown("Pass Target Mode", {"Without Bomb", "With Bomb"}, Config.PassTargetMode, "PassTargetMode", function(val)
    _G.PassTargetMode = val
    Config.PassTargetMode = val
    SaveConfig()
end)

TabCombat:CreateSlider("Pass Max Distance (Studs)", 1, 200, Config.PassMaxDistance, "PassMaxDistance", function(val)
    _G.PassMaxDistance = val
    Config.PassMaxDistance = val
    SaveConfig()
end)

TabCombat:CreateToggle("Show Manual Pass Button [PASS]", Config.PassExternalVisible, "PassExternalVisible", function(state)
    _G.PassExternalVisible = state
    Config.PassExternalVisible = state
    SaveConfig()
    SafeSetVisible(_G.ExtPassBtn, state)
end)

TabCombat:CreateButton("Manual Trigger Pass Bomb Now", function()
    triggerManualPass()
end)

TabCombat:CreateParagraph("Range Area Chase System", "Automatically chases any players who enter your configured visual boundaries.")

TabCombat:CreateToggle("Enable Range Area Chase", Config.RangeChaseEnabled, "RangeChaseEnabled", function(state)
    _G.RangeChaseEnabled = state
    Config.RangeChaseEnabled = state
    SaveConfig()
    SafeSetVisible(_G.ExtRangeChaseBtn, state)
    if state then
        SafeSetText(_G.ExtRangeChaseBtn, "CHASING")
    else
        SafeSetText(_G.ExtRangeChaseBtn, "RANGE CHASE")
    end
end)

TabCombat:CreateSlider("Chase Range (Studs)", 10, 150, Config.RangeChaseValue, "RangeChaseValue", function(val)
    _G.RangeChaseValue = val
    Config.RangeChaseValue = val
    SaveConfig()
end)

TabCombat:CreateParagraph("Flick & Hold Controls", "Manipulate camera/character behaviors when holding the bomb or approaching opponents.")

TabCombat:CreateToggle("Enable Flick System", Config.FlickEnabled, "FlickEnabled", function(state)
    _G.FlickEnabled = state
    _G.FlickActive = state 
    Config.FlickEnabled = state
    SaveConfig()
    SafeSetVisible(_G.ExtFlickBtn, state)
    if state then
        SafeSetText(_G.ExtFlickBtn, "FLICKING")
    else
        SafeSetText(_G.ExtFlickBtn, "FLICK")
    end
end)

TabCombat:CreateDropdown("Flick Target Mode", {"Camera Only", "Character Only", "Both"}, Config.FlickTargetMode, "FlickTargetMode", function(val)
    _G.FlickTargetMode = val
    Config.FlickTargetMode = val
    SaveConfig()
end)

TabCombat:CreateSlider("Character Flick Strength (Degrees)", 5, 180, Config.CharFlickStrength, "CharFlickStrength", function(val)
    _G.CharFlickStrength = val
    Config.CharFlickStrength = val
    SaveConfig()
end)

TabCombat:CreateSlider("Camera Flick Strength (Degrees)", 5, 90, Config.FlickStrength, "FlickStrength", function(val)
    _G.FlickStrength = val
    Config.FlickStrength = val
    SaveConfig()
end)

TabCombat:CreateToggle("Enable Auto Hold Bomb", Config.AutoHoldEnabled, "AutoHoldEnabled", function(state)
    _G.AutoHoldEnabled = state
    _G.AutoHoldActive = state 
    Config.AutoHoldEnabled = state
    SaveConfig()
    SafeSetVisible(_G.ExtHoldBtn, state)
    if state then
        SafeSetText(_G.ExtHoldBtn, "HOLDING")
    else
        SafeSetText(_G.ExtHoldBtn, "HOLD BOMB")
    end
end)

TabCombat:CreateParagraph("Teleport Walk (TPWalk)", "Execute step-by-step vector teleports to alter walkspeed limits.")

TabCombat:CreateToggle("Enable TPWalk Speed", Config.TPWalkEnabled, "TPWalkEnabled", function(state)
    _G.TPWalkEnabled = state
    Config.TPWalkEnabled = state
    SaveConfig()
end)

TabCombat:CreateSlider("TPWalk Speed Scale", 1, 100, Config.TPWalkSpeed, "TPWalkSpeed", function(val)
    _G.TPWalkSpeed = val
    Config.TPWalkSpeed = val
    SaveConfig()
end)

TabCombat:CreateParagraph("Replication Desync Utilities", "Network position replication modifications to bypass client touch interactions.")

TabCombat:CreateToggle("Aetherial Desync Shield", Config.DesyncImmunityEnabled, "DesyncImmunityEnabled", function(state)
    _G.DesyncImmunityEnabled = state
    _G.DesyncImmunityActive = state
    Config.DesyncImmunityEnabled = state
    Config.DesyncImmunityActive = state
    SaveConfig()
    SafeSetVisible(_G.ExtDesyncImmunityBtn, state)
    setCharacterCanTouch(not state)
    if state then
        SafeSetText(_G.ExtDesyncImmunityBtn, "SHIELD [ON]")
    else
        SafeSetText(_G.ExtDesyncImmunityBtn, "DESYNC SHIELD")
    end
end)

TabCombat:CreateParagraph("Range Hitbox Expander (Local Area Bounds)", "Locally displays physical boundaries representing your custom contact radius.")

TabCombat:CreateToggle("Enable Opponents Hitbox Expander", Config.LocalHitboxEnabled, "LocalHitboxEnabled", function(state)
    _G.LocalHitboxEnabled = state
    Config.LocalHitboxEnabled = state
    SaveConfig()
    pcall(updatePlayersHitboxes)
end)

TabCombat:CreateToggle("Show Hitbox Outlines (Visual)", Config.HitboxVisualEnabled, "HitboxVisualEnabled", function(state)
    _G.HitboxVisualEnabled = state
    Config.HitboxVisualEnabled = state
    SaveConfig()
    pcall(updatePlayersHitboxes)
end)

TabCombat:CreateDropdown("Hitbox Range Shape", {"Cylinder", "Sphere", "Block", "Wedge"}, Config.HitboxShape, "HitboxShape", function(val)
    _G.HitboxShape = val
    Config.HitboxShape = val
    SaveConfig()
    pcall(updatePlayersHitboxes)
end)

TabCombat:CreateSlider("Hitbox Range Size (Studs)", 1, 20, Config.LocalHitboxSize, "LocalHitboxSize", function(val)
    _G.LocalHitboxSize = val
    Config.LocalHitboxSize = val
    SaveConfig()
    pcall(updatePlayersHitboxes)
end)

TabCombat:CreateSlider("Teleport Hold Duration (ms)", 1, 100, Config.HitboxTeleportDelay, "HitboxTeleportDelay", function(val)
    _G.HitboxTeleportDelay = val / 1000
    Config.HitboxTeleportDelay = val
    SaveConfig()
    task_defer(function()
        updateSliderLabelSafe(val)
    end)
end)
task_defer(function()
    updateSliderLabelSafe(Config.HitboxTeleportDelay) 
end)

TabCombat:CreateParagraph("Trip Fall Physics", "Safely trips your character to slide stably across flat surfaces.")

TabCombat:CreateToggle("Enable Trip Fall", Config.TripEnabled, "TripEnabled", function(state)
    _G.TripEnabled = state
    Config.TripEnabled = state
    SaveConfig()
    ApplyTrip(_G.TripEnabled)
    SafeSetVisible(_G.ExtTripBtn, state)
    if state then
        SafeSetText(_G.ExtTripBtn, "TRIPPED")
    else
        SafeSetText(_G.ExtTripBtn, "TRIP FALL")
    end
end)

TabCombat:CreateParagraph("Freeze System", "Freeze your character locally in place.")

TabCombat:CreateToggle("Enable Freeze System", Config.FreezeEnabled, "FreezeEnabled", function(state)
    _G.FreezeEnabled = state
    Config.FreezeEnabled = state
    SaveConfig()
    SafeSetVisible(_G.ExtFreezeBtn, state)
    if not state then
        pcall(function()
            if isFreezing then
                stopFreeze()
            end
        end)
    end
end)

TabCombat:CreateParagraph("Infinite Jump", "Jump freely in mid-air with limit constraint.")

TabCombat:CreateToggle("Infinite Jump Toggle", Config.InfJumpEnabled, "InfJumpEnabled", function(state)
    _G.InfJumpEnabled = state
    Config.InfJumpEnabled = state
    SaveConfig()
end)

TabCombat:CreateSlider("Maximum Jump Air-Count", 2, 10, Config.MaxJumpCount, "MaxJumpCount", function(val)
    _G.MaxJumpCount = val
    Config.MaxJumpCount = val
    SaveConfig()
end)

-- --- TAB 3: VISUALS (LUCIDE ICON: "eye") ---
local TabVisuals = Window:CreateTab("Visuals", "eye")

TabVisuals:CreateParagraph("Player ESP Highlights", "Highlights opponents and teammates through solid map geometry.")

TabVisuals:CreateToggle("Enable Player ESP", Config.ESPEnabled, "ESPEnabled", function(state)
    _G.ESPEnabled = state
    Config.ESPEnabled = state
    SaveConfig()
end)

TabVisuals:CreateParagraph("Network Latency Visualizer", "Visualize your server-side position delay replica.")

TabVisuals:CreateToggle("Desync Ghost Visualizer", Config.DesyncVisualEnabled, "DesyncVisualEnabled", function(state)
    _G.DesyncVisualEnabled = state
    Config.DesyncVisualEnabled = state
    SaveConfig()
    if not state then
        if GhostModel then GhostModel:Destroy(); GhostModel = nil end
    end
end)

TabVisuals:CreateParagraph("Record Protection & Cosmetics (Local)", "Change your character's visuals locally when recording.")

TabVisuals:CreateButton("Randomize Avatar (Client)", function()
    ApplyRandomAvatar()
end)

TabVisuals:CreateButton("Apply FE Korblox & Headless", function()
    isHeadlessActive = true
    isKorbloxActive = true
    ApplyHeadless()
    ApplyKorblox()
    Library:Notify("Visuals applied", "FE Headless & Korblox successfully loaded locally!", 2)
end)

TabVisuals:CreateParagraph("Camera & Resolution Scaling", "Manipulate field of view and resolution stretch scale.")

TabVisuals:CreateToggle("FOV Override Toggle", Config.FOVEnabled, "FOVEnabled", function(state)
    _G.FOVEnabled = state
    Config.FOVEnabled = state
    SaveConfig()
    if not state then
        Camera.FieldOfView = 70
    end
end)

TabVisuals:CreateSlider("Field Of View Value", 1, 200, Config.FOVValue, "FOVValue", function(val)
    _G.FOVValue = val
    Config.FOVValue = val
    SaveConfig()
end)

TabVisuals:CreateToggle("Stretch Resolution Toggle", Config.ResolutionEnabled, "ResolutionEnabled", function(state)
    _G.ResolutionEnabled = state
    Config.ResolutionEnabled = state
    SaveConfig()
end)

TabVisuals:CreateSlider("Stretch Resolution Scale", 1, 20, Config.ResolutionValue, "ResolutionValue", function(val)
    _G.ResolutionValue = val / 10
    Config.ResolutionValue = val
    SaveConfig()
end)

-- --- TAB 4: CUSTOM CROSSHAIRS (LUCIDE ICON: "crosshair") ---
local TabCrosshair = Window:CreateTab("Custom Crosshairs", "crosshair")

TabCrosshair:CreateToggle("Enable Custom Crosshair", false, "CustomCrosshairEnabled", function(state)
    _G.CrosshairSettings.Enabled = state
    
    if state and not _G.CrosshairLoaded_2 then
        _G.CrosshairLoaded_2 = true
        task_spawn(function()
            local url = "https://raw.githubusercontent.com/nazumirui5-oss/Ui-Library/refs/heads/main/crosshair.lua"
            local success, err = pcall(function()
                loadstring(game:HttpGet(url))()
            end)
            if not success then
                _G.CrosshairLoaded_2 = false
                Library:Notify("Crosshair Error", "Failed to download crosshair module.", 3)
            end
        end)
    end
end)

TabCrosshair:CreateToggle("Show Only When Shift Lock is On", false, "CrosshairOnlyShiftLock", function(state)
    _G.CrosshairSettings.OnlyShiftLock = state
end)

TabCrosshair:CreateToggle("Hide Roblox Default Cursor", true, "CrosshairHideDefaultCursor", function(state)
    _G.CrosshairSettings.HideDefaultCursor = state
end)

TabCrosshair:CreateDropdown("Crosshair Style", {"Cross", "T-Shape", "Diamond", "Circle", "Dot", "Image"}, "Cross", "CrosshairStyle", function(selected)
    _G.CrosshairSettings.Style = selected
end)

TabCrosshair:CreateDropdown("Select Preset Image ID", PresetNames, PresetNames[1], "CrosshairPresetImage", function(selectedPreset)
    local cleanId = selectedPreset:match("(%d+)%)") 
    if cleanId then
        _G.CrosshairSettings.ImageId = cleanId
    end
end)

TabCrosshair:CreateTextBox("Custom Image ID", "Enter Image Asset ID manually...", "CrosshairCustomImage", function(text)
    local cleanId = text:gsub("%D", "")
    if cleanId ~= "" then
        _G.CrosshairSettings.ImageId = cleanId
        Library:Notify("Crosshair ID", "ID updated manually to: " .. cleanId, 1.5)
    end
end)

TabCrosshair:CreateDropdown("Crosshair Color Preset", {"Green (Neon)", "Red", "Blue", "White", "Yellow", "Cyan", "Pink"}, "Green (Neon)", "CrosshairColorPreset", function(selectedName)
    local targetColor = CrosshairColorPresets[selectedName]
    if targetColor then
        _G.CrosshairSettings.Color = targetColor
    end
end)

TabCrosshair:CreateToggle("Rainbow Crosshair Effect", false, "CrosshairRainbow", function(state)
    _G.CrosshairSettings.Rainbow = state
end)

TabCrosshair:CreateSlider("Crosshair Size / Radius", 2, 35, 10, "CrosshairSize", function(val)
    _G.CrosshairSettings.Size = val
end)

TabCrosshair:CreateSlider("Crosshair Gap Size", 0, 25, 5, "CrosshairGap", function(val)
    _G.CrosshairSettings.Gap = val
end)

TabCrosshair:CreateSlider("Crosshair Thickness", 1, 6, 2, "CrosshairThickness", function(val)
    _G.CrosshairSettings.Thickness = val / 1.3
end)

TabCrosshair:CreateParagraph("Crosshair Rotation Controls", "Adjust manual rotation angle or enable Auto-Spin mode for all styles.")

TabCrosshair:CreateSlider("Manual Rotation Angle", 0, 360, 0, "CrosshairRotation", function(val)
    _G.CrosshairSettings.Rotation = val
end)

TabCrosshair:CreateToggle("Auto-Spin Crosshair", false, "CrosshairAutoSpin", function(state)
    _G.CrosshairSettings.AutoSpin = state
end)

TabCrosshair:CreateSlider("Auto-Spin Speed", 10, 200, 50, "CrosshairSpinSpeed", function(val)
    _G.CrosshairSettings.SpinSpeed = val
end)

-- --- TAB 5: PREMIUM (LUCIDE ICON: "crown" - UNLOCKED FOR VIP) ---
TabPremium = Window:CreateTab("Premium", "crown")

-- ========================================================
-- [[ DYNAMIC CUSTOM FLINGS LAYOUT & VISIBILITY CONTROLS ]]
-- ========================================================
TabPremium:CreateParagraph("Custom Fling Coordinates", "Configure custom coordinate flings. Clicking a button below toggles its external floating button on your screen.")

TabPremium:CreateToggle("Enable Custom Paths", false, "CustomPathsEnabled", function(state)
    _G.CustomPathsEnabled = state
    setupPathButtons()
    Library:Notify("Custom Paths", "Custom paths feature: " .. (state and "ENABLED" or "DISABLED"), 2)
end)

_G.FlingSpeedMultiplier = 5.0
TabPremium:CreateSlider("Fling Speed Multiplier", 1, 100, 50, "FlingSpeedMultiplier", function(val)
    _G.FlingSpeedMultiplier = val / 10
end)

TabPremium:CreateParagraph("Fling Activation Panel", "Click a button below to show/hide its screen button. Once visible, click the screen button to trigger the fling.")

for _, pathInfo in ipairs(FlingPaths) do
    local currentInfo = pathInfo
    TabPremium:CreateButton(currentInfo.display:upper(), function()
        local currentState = ExternalButtonStates[currentInfo.id] or false
        local newState = not currentState
        ExternalButtonStates[currentInfo.id] = newState
        
        -- Update the external button visibility
        local extBtn = PathButtons[currentInfo.id]
        if extBtn then
            -- Only show if the master toggle is also enabled [1]
            if _G.CustomPathsEnabled then
                SafeSetVisible(extBtn, newState)
            end
        end
        
        if newState then
            if _G.CustomPathsEnabled then
                Library:Notify("Custom Paths", currentInfo.display .. " button is now VISIBLE on screen.", 1.5)
            else
                Library:Notify("Custom Paths", currentInfo.display .. " button is enabled, but turn on 'Enable Custom Paths' to show it on screen.", 2.5)
            end
        else
            Library:Notify("Custom Paths", currentInfo.display .. " button is now HIDDEN.", 1.5)
        end
    end)
end

TabPremium:CreateParagraph("Camlock Targeting Alignment", "Enforces directional locking relative to your current target.")

TabPremium:CreateToggle("Camlock", Config.CamlockEnabled, "CamlockEnabled", function(state)
    _G.CamlockEnabled = state
    _G.CamlockActive = state
    Config.CamlockEnabled = state
    Config.CamlockActive = state
    SaveConfig()
    SafeSetVisible(_G.ExtCamlockBtn, state)
    if state then
        SafeSetText(_G.ExtCamlockBtn, "CAMLOCK [ON]")
    else
        SafeSetText(_G.ExtCamlockBtn, "CAMLOCK")
    end
end)

TabPremium:CreateParagraph("Wallhop Consolidated Panel", "Scales walls and executes direction tilts seamlessly.")

WallhopMainToggle = TabPremium:CreateToggle("Enable Wallhop System", Config.WallhopEnabled, "WallhopEnabled", function(state)
    _G.WallhopEnabled = state
    _G.WallhopActive = state
    Config.WallhopEnabled = state
    Config.WallhopActive = state
    SaveConfig()
    updateWallhopButtonsSync()
    Library:Notify("Wallhop System", "Wallhop Master Toggle: " .. (state and "ENABLED" or "DISABLED"), 2.0)
end)

TabPremium:CreateToggle("Enable Stud (Raycast) Detection", Config.WallhopStudEnabled, "WallhopStudEnabled", function(state)
    _G.WallhopStudEnabled = state
    Config.WallhopStudEnabled = state
    SaveConfig()
    Library:Notify("Wallhop Detection", "Stud (Raycast) Detection: " .. (state and "ENABLED" or "DISABLED"), 2.0)
end)

WallhopModeDropdown = TabPremium:CreateDropdown("Wallhop Mode", {"Manual", "Automatic"}, Config.WallhopMode, "WallhopMode", function(val)
    _G.WallhopMode = val
    Config.WallhopMode = val
    SaveConfig()
    Library:Notify("Wallhop System", "Wallhop Mode changed to: " .. val, 2.0)
end)

WallhopTypeDropdown = TabPremium:CreateDropdown("Wallhop Type", {"Normal", "Instant", "Ultra"}, Config.WallhopType, "WallhopType", function(val)
    _G.WallhopType = val
    Config.WallhopType = val
    SaveConfig()
    updateWallhopButtonsSync()
    Library:Notify("Wallhop System", "Wallhop Type changed to: " .. val, 2.0)
end)

TabPremium:CreateDropdown("Wallhop Detection Mode", {"Raycast Only", "Bounding Box", "Hybrid"}, Config.WallhopDetectionMode, "WallhopDetectionMode", function(val)
    _G.WallhopDetectionMode = val
    Config.WallhopDetectionMode = val
    SaveConfig()
    Library:Notify("Wallhop Detection", "Mode set to: " .. val, 2.0)
end)

TabPremium:CreateDropdown("Wallhop Action Style", {"Default", "Front-to-Back Flick", "Back-to-Front Flick"}, Config.WallhopFlickMode, "WallhopFlickMode", function(val)
    _G.WallhopFlickMode = val
    Config.WallhopFlickMode = val
    SaveConfig()
    Library:Notify("Wallhop Action", "Style set to: " .. val, 2.0)
end)

TabPremium:CreateSlider("Wallhop Distance Range (Studs)", 1, 15, Config.WH_Distance, "WH_Distance", function(val)
    _G.WallHopDist = val
    Config.WH_Distance = val
    SaveConfig()
end)

TabPremium:CreateParagraph("Wallhop Explanation & Guidelines", 
    "Modes:\n" ..
    "• Manual: Executes a wallhop only when manually pressing Spacebar next to a wall.\n" ..
    "• Automatic: Instantly and continuously launches you upwards while in mid-air near walls without manual inputs.\n\n" ..
    "Types:\n" ..
    "• Normal: Generates a classical, physics-based rotation on the local character's root model.\n" ..
    "• Instant: Generates a sharp CFrame camera angle tilt/flick instead of rotating physically.\n" ..
    "• Ultra: Combines both Normal and Instant. It checks if Shift Lock is active: if inactive, Normal style is applied; if active, Instant flick style is applied.\n\n" ..
    "Action Styles:\n" ..
    "• Default: standard jump/rotation movement.\n" ..
    "• Front-to-Back Flick: Faces forward relative to movement/camera first, then immediately forces character facing backward.\n" ..
    "• Back-to-Front Flick: Faces backward first, then immediately forces character facing forward after a microsecond delay.")

-- Loadstring script attachment (Bot Walk System) added dynamically at the bottom of Premium Tab
TabPremium:CreateButton("Bot Walk System", function()
    local success, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/gamerlatahzan-design/SSLH-SourceCode-/main/SourceCodePathFinder.lua"))()
    end)
    if success then
        Library:Notify("Bot Walk System", "Bot Walk System loaded successfully!", 3)
    else
        Library:Notify("Bot Walk System Error", "Failed to load script: " .. tostring(err), 3)
    end
end)

-- --- TAB 6: KEYBIND SETTINGS (LUCIDE ICON: "keyboard") ---
local TabKeybinds = Window:CreateTab("Keybind Settings", "keyboard")
TabKeybinds:CreateParagraph("Custom Keybind System", "Type the KeyCode name exactly to bind actions. Set to 'None' to clear.")

local function RegisterKeybindUI(label, configKey, defaultVal)
    local savedVal = Config["Keybind_" .. configKey] or defaultVal
    TabKeybinds:CreateTextBox(label, savedVal, configKey .. "Keybind", function(text)
        local success, result = pcall(function()
            return Enum.KeyCode[text]
        end)
        if success and result then
            Keybinds[configKey] = result
            Config["Keybind_" .. configKey] = result.Name
            SaveConfig()
            if configKey == "UIToggle" then
                pcall(function() Window:BindToggleKey(result) end)
            end
            Library:Notify("Keybind", label .. " set to: " .. result.Name, 2)
        else
            Library:Notify("Keybind Error", "Invalid KeyName!", 2)
        end
    end)
end

-- Re-organized registration lists as compressed key loops to prevent single-turn truncation
local keybindsList = {
    {"UI Menu Toggle Key", "UIToggle", "RightControl"},
    {"Follow Toggle Key", "FollowToggle", "None"},
    {"Auto Walk Toggle Key", "AutoWalkToggle", "None"},
    {"Auto Pass Toggle Key", "AutoPassToggle", "None"},
    {"Range Chase Toggle Key", "RangeChaseToggle", "None"},
    {"Flick Toggle Key", "FlickToggle", "None"},
    {"Auto Hold Toggle Key", "AutoHoldToggle", "None"},
    {"Trip Fall Toggle Key", "TripToggle", "None"},
    {"Freeze Toggle Key", "FreezeToggle", "None"},
    {"Infinite Jump Toggle Key", "InfJumpToggle", "None"},
    {"Wallhop Toggle Key", "WallhopToggle", "None"},
    {"Hitbox Expander Toggle Key", "HitboxToggle", "None"},
    {"Crosshair Toggle Key", "CrosshairToggle", "None"},
    {"Camlock Toggle Key", "CamlockToggle", "None"},
    {"walkspeed Toggle Key", "TPWalkToggle", "None"},
    {"Desync Shield Toggle Key", "DesyncImmunityToggle", "None"}
}
for _, k in ipairs(keybindsList) do
    RegisterKeybindUI(k[1], k[2], k[3])
end

-- Dynamic Fling hotkeys [1]
TabKeybinds:CreateParagraph("Custom Fling Keybinds", "Assign hotkeys to execute your custom coordinate paths directly [1].")
for _, pathInfo in ipairs(FlingPaths) do
    RegisterKeybindUI(pathInfo.display .. " Keybind", pathInfo.id, "None")
end

-- --- TAB 7: BUTTON CONTROLS (LUCIDE ICON: "sliders") ---
local TabControls = Window:CreateTab("Controls & Scales", "sliders")

TabControls:CreateParagraph("External Button Scales (%)", "Adjust the scale of each floating button dynamically.")

TabControls:CreateSlider("External Buttons Size", 10, 200, 100, "ExtScaleValue", function(val)
    _G.ExtScaleValue = val
    UpdateAllButtonsSize(val / 100)
end)

TabControls:CreateParagraph("Window Lock", "Lock window dragging positions.")
TabControls:CreateToggle("Lock Main UI Dragging", false, "DragLocked", function(state)
    Window:SetDragLock(state)
    UpdateAllButtonsDragLock(state)
end)

-- ========================================================================
-- [[ KEYBOARD QUICK SHORTCUTS CONNECTION ]]
-- ========================================================================
ToggleFeature = function(name)
    if name == "Follow" then
        _G.FollowEnabled = not _G.FollowEnabled
        _G.FollowActive = _G.FollowEnabled 
        Config.FollowEnabled = _G.FollowEnabled
        SaveConfig()
        if FollowToggle and FollowToggle.Set then
            FollowToggle:Set(_G.FollowEnabled)
        end
        SafeSetVisible(_G.ExtFollowBtn, _G.FollowEnabled)
        if _G.FollowEnabled then
            SafeSetText(_G.ExtFollowBtn, "FOLLOWING")
        else
            SafeSetText(_G.ExtFollowBtn, "AUTO FOLLOW")
        end
        Library:Notify("Follow System", "Status: " .. (_G.FollowEnabled and "ON" or "OFF"), 1.5)
    elseif name == "AutoWalk" then
        _G.AutoWalkEnabled = not _G.AutoWalkEnabled
        _G.AutoWalkActive = _G.AutoWalkEnabled 
        Config.AutoWalkEnabled = _G.AutoWalkEnabled
        SaveConfig()
        SafeSetVisible(_G.ExtAutoWalkBtn, _G.AutoWalkEnabled)
        if _G.AutoWalkEnabled then
            SafeSetText(_G.ExtAutoWalkBtn, "WALKING")
        else
            SafeSetText(_G.ExtAutoWalkBtn, "AUTO WALK")
        end
        Library:Notify("Auto Walk", "Status: " .. (_G.AutoWalkEnabled and "ON" or "OFF"), 1.5)
    elseif name == "AutoPass" then
        _G.AutoPassEnabled = not _G.AutoPassEnabled
        Config.AutoPassEnabled = _G.AutoPassEnabled
        SaveConfig()
        Library:Notify("Auto Pass", "Status: " .. (_G.AutoPassEnabled and "ON" or "OFF"), 1.5)
    elseif name == "RangeChase" then
        _G.RangeChaseEnabled = not _G.RangeChaseEnabled
        Config.RangeChaseEnabled = _G.RangeChaseEnabled
        SaveConfig()
        SafeSetVisible(_G.ExtRangeChaseBtn, _G.RangeChaseEnabled)
        if _G.RangeChaseEnabled then
            SafeSetText(_G.ExtRangeChaseBtn, "CHASING")
        else
            SafeSetText(_G.ExtRangeChaseBtn, "RANGE CHASE")
        end
        Library:Notify("Range Chase", "Status: " .. (_G.RangeChaseEnabled and "ON" or "OFF"), 1.5)
    elseif name == "Flick" then
        _G.FlickEnabled = not _G.FlickEnabled
        _G.FlickActive = _G.FlickEnabled 
        Config.FlickEnabled = _G.FlickEnabled
        SaveConfig()
        SafeSetVisible(_G.ExtFlickBtn, _G.FlickEnabled)
        if _G.FlickEnabled then
            SafeSetText(_G.ExtFlickBtn, "FLICKING")
        else
            SafeSetText(_G.ExtFlickBtn, "FLICK")
        end
        Library:Notify("Flick", "Status: " .. (_G.FlickEnabled and "ON" or "OFF"), 1.5)
    elseif name == "AutoHold" then
        _G.AutoHoldEnabled = not _G.AutoHoldEnabled
        _G.AutoHoldActive = _G.AutoHoldEnabled 
        Config.AutoHoldEnabled = _G.AutoHoldEnabled
        SaveConfig()
        SafeSetVisible(_G.ExtHoldBtn, _G.AutoHoldEnabled)
        if _G.AutoHoldEnabled then
            SafeSetText(_G.ExtHoldBtn, "HOLDING")
        else
            SafeSetText(_G.ExtHoldBtn, "HOLD BOMB")
        end
        Library:Notify("Auto Hold", "Status: " .. (_G.AutoHoldEnabled and "ON" or "OFF"), 1.5)
    elseif name == "Trip" then
        _G.TripEnabled = not _G.TripEnabled
        Config.TripEnabled = _G.TripEnabled
        SaveConfig()
        ApplyTrip(_G.TripEnabled)
        SafeSetVisible(_G.ExtTripBtn, _G.TripEnabled)
        if _G.TripEnabled then
            SafeSetText(_G.ExtTripBtn, "TRIPPED")
        else
            SafeSetText(_G.ExtTripBtn, "TRIP FALL")
        end
        Library:Notify("Trip Fall", "Status: " .. (_G.TripEnabled and "ON" or "OFF"), 1.5)
    elseif name == "Freeze" then
        _G.FreezeEnabled = not _G.FreezeEnabled
        Config.FreezeEnabled = _G.FreezeEnabled
        SaveConfig()
        SafeSetVisible(_G.ExtFreezeBtn, _G.FreezeEnabled)
        if _G.FreezeEnabled then
            startFreeze()
        else
            stopFreeze()
        end
        Library:Notify("Freeze System", "Status: " .. (_G.FreezeEnabled and "ON" or "OFF"), 1.5)
    elseif name == "InfJump" then
        _G.InfJumpEnabled = not _G.InfJumpEnabled
        Config.InfJumpEnabled = _G.InfJumpEnabled
        SaveConfig()
        Library:Notify("Inf Jump", "Status: " .. (_G.InfJumpEnabled and "ON" or "OFF"), 1.5)
    elseif name == "Wallhop" then
        if _G.WallhopEnabled then
            _G.WallhopActive = not _G.WallhopActive
            Config.WallhopActive = _G.WallhopActive
            SaveConfig()
            updateWallhopButtonsSync()
            
            if _G.WallhopActive then
                Library:Notify("Wallhop Mode", "Status: ACTIVE (" .. _G.WallhopType .. ")", 1.5)
            else
                Library:Notify("Wallhop Mode", "Status: INACTIVE", 1.5)
            end
        else
            Library:Notify("Wallhop Error", "Please enable the Wallhop System in the UI first!", 2.5)
        end
    elseif name == "Hitbox" then
        _G.LocalHitboxEnabled = not _G.LocalHitboxEnabled
        Config.LocalHitboxEnabled = _G.LocalHitboxEnabled
        SaveConfig()
        pcall(updatePlayersHitboxes)
        Library:Notify("Hitbox Expander", "Status: " .. (_G.LocalHitboxEnabled and "ON" or "OFF"), 1.5)
    elseif name == "Crosshair" then
        _G.CrosshairSettings.Enabled = not _G.CrosshairSettings.Enabled
        if _G.CrosshairSettings.Enabled and not _G.CrosshairLoaded_2 then
            _G.CrosshairLoaded_2 = true
            task_spawn(function()
                local url = "https://raw.githubusercontent.com/nazumirui5-oss/Ui-Library/refs/heads/main/crosshair.lua"
                pcall(function() loadstring(game:HttpGet(url))() end)
            end)
        end
        Library:Notify("Crosshair", "Status: " .. (_G.CrosshairSettings.Enabled and "ON" or "OFF"), 1.5)
    elseif name == "Camlock" then
        if _G.CamlockEnabled then
            _G.CamlockActive = not _G.CamlockActive
            Config.CamlockActive = _G.CamlockActive
            SaveConfig()
            if _G.CamlockActive then
                SafeSetText(_G.ExtCamlockBtn, "CAMLOCK [ON]")
            else
                SafeSetText(_G.ExtCamlockBtn, "CAMLOCK")
            end
            Library:Notify("Camlock Mode", "Status: " .. (_G.CamlockActive and "ON" or "OFF"), 1.5)
        else
            Library:Notify("Camlock Error", "Please enable Camlock System in the UI first!", 2.5)
        end
    elseif name == "TPWalk" then
        _G.TPWalkEnabled = not _G.TPWalkEnabled
        Config.TPWalkEnabled = _G.TPWalkEnabled
        SaveConfig()
        Library:Notify("TPWalk", "Status: " .. (_G.TPWalkEnabled and "ON" or "OFF"), 1.5)
    elseif name == "DesyncImmunity" then
        if _G.DesyncImmunityEnabled then
            _G.DesyncImmunityActive = not _G.DesyncImmunityActive
            Config.DesyncImmunityActive = _G.DesyncImmunityActive
            SaveConfig()
            setCharacterCanTouch(not _G.DesyncImmunityActive)
            if _G.DesyncImmunityActive then
                SafeSetText(_G.ExtDesyncImmunityBtn, "SHIELD [ON]")
            else
                SafeSetText(_G.ExtDesyncImmunityBtn, "DESYNC SHIELD")
            end
            Library:Notify("Desync Shield", "Status: " .. (_G.DesyncImmunityActive and "ACTIVE" or "INACTIVE"), 1.5)
        else
            Library:Notify("Desync Shield Error", "Please enable Desync Shield in the UI first!", 2.5)
        end
    end
end

local function HandleKeybindTrigger(keyCode)
    if keyCode == Enum.KeyCode.None or keyCode == Enum.KeyCode.Unknown then return end
    
    if keyCode == Keybinds.FollowToggle then ToggleFeature("Follow") end
    if keyCode == Keybinds.AutoWalkToggle then ToggleFeature("AutoWalk") end
    if keyCode == Keybinds.AutoPassToggle then ToggleFeature("AutoPass") end
    if keyCode == Keybinds.RangeChaseToggle then ToggleFeature("RangeChase") end
    if keyCode == Keybinds.FlickToggle then ToggleFeature("Flick") end
    if keyCode == Keybinds.AutoHoldToggle then ToggleFeature("AutoHold") end
    if keyCode == Keybinds.TripToggle then ToggleFeature("Trip") end
    if keyCode == Keybinds.FreezeToggle then ToggleFeature("Freeze") end
    if keyCode == Keybinds.InfJumpToggle then ToggleFeature("InfJump") end
    if keyCode == Keybinds.WallhopToggle then ToggleFeature("Wallhop") end
    if keyCode == Keybinds.HitboxToggle then ToggleFeature("Hitbox") end
    if keyCode == Keybinds.CrosshairToggle then ToggleFeature("Crosshair") end
    if keyCode == Keybinds.CamlockToggle then ToggleFeature("Camlock") end
    if keyCode == Keybinds.TPWalkToggle then ToggleFeature("TPWalk") end
    if keyCode == Keybinds.DesyncImmunityToggle then ToggleFeature("DesyncImmunity") end
    
    -- Dynamic Fling hotkeys [1]
    for _, pathInfo in ipairs(FlingPaths) do
        if keyCode == Keybinds[pathInfo.id] then
            triggerPath(pathInfo)
            break
        end
    end
end

SafeConnect(UserInputService.InputBegan, function(input, gameProcessed)
    if gameProcessed then return end
    HandleKeybindTrigger(input.KeyCode)
end)

SafeConnect(LocalPlayer.CharacterAdded, function(char)
    lastHadBomb = false
    retreatTimer = 0
    autoWalkRetreatTimer = 0
    targetMemory = 0
    bombTimer = 0
    isTweening = false
    _G.CurrentJumpCount = 0
    lastShouldFollow = false
    cachedBombLabel = nil
    table.clear(CFrameHistory)
end)

-- ========================================================================
-- [[ DYNAMIC VISIBILITY SYNCHRONIZATION CORE ]]
-- ========================================================================
SafeSetVisible(_G.ExtFollowBtn, _G.FollowEnabled)
SafeSetVisible(_G.ExtFreezeBtn, _G.FreezeEnabled)
SafeSetVisible(_G.ExtFlickBtn, _G.FlickEnabled)
SafeSetVisible(_G.ExtHoldBtn, _G.AutoHoldEnabled)
SafeSetVisible(_G.ExtPassBtn, _G.PassExternalVisible)
SafeSetVisible(_G.ExtAutoWalkBtn, _G.AutoWalkEnabled)
SafeSetVisible(_G.ExtRangeChaseBtn, _G.RangeChaseEnabled)
SafeSetVisible(_G.ExtTripBtn, _G.TripEnabled)
SafeSetVisible(_G.ExtCamlockBtn, _G.CamlockEnabled)
SafeSetVisible(_G.ExtDesyncImmunityBtn, _G.DesyncImmunityEnabled)

-- Synchronize initial states of bypassed Wallhop buttons on startup
updateWallhopButtonsSync()

if _G.LocalHitboxEnabled then
    pcall(updatePlayersHitboxes)
end
