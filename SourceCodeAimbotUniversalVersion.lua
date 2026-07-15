-- ========================================================================
-- [[ LOUIS HUB - AIMBOT & UTILITY UNIVERSAL (OPTIMIZED) ]]
-- ========================================================================

-- UPVALUE CACHING FOR MAXIMUM PERFORMANCE UNDER OBFUSCATION
local Vector3_new = Vector3.new
local Vector2_new = Vector2.new
local CFrame_new = CFrame.new
local CFrame_lookAt = CFrame.lookAt or function(p, t) return CFrame.new(p, t) end
local math_rad = math.rad
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

-- 1. LOAD UI LIBRARY FROM YOUR SOURCE
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/nazumirui5-oss/Ui-Library/refs/heads/main/Ui%20Library.lua"))()

-- 2. SETUP MAIN ROBLOX SERVICES
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- Dynamic function to retrieve the most updated Camera instance (prevents respawn issues)
local function getCamera()
    return workspace.CurrentCamera or Workspace.CurrentCamera
end

-- ========================================================
-- [[ DYNAMIC AUTO-SAVE & AUTO-LOAD CONFIGURATION SYSTEM ]]
-- ========================================================
local HttpService = game:GetService("HttpService")
local ConfigFile = "LouisHub_AimbotUniversal_Config.json"
local Config = {}

-- Config defaults for Aimbot Universal & Utilities
local Defaults = {
    AimbotEnabled = false,
    AimbotMode = "Normal", -- "Normal" or "Prediction"
    AimbotType = "Camera", -- "Camera" or "Character"
    AimPart = "Head",
    WallCheck = true,
    TeamCheck = true,
    DrawFOV = true,
    FOVRadius = 100,
    ESPEnabled = false,
    ExternalButtonVisible = true,
    
    -- Smoothness & Stickiness Settings
    AimbotSmoothness = 1,  -- 1 (Instant) to 100 (Extremely Smooth)
    AimbotStickiness = 1,  -- 1 (Disabled/Low) to 100 (Highly Sticky)

    -- Movement Methods
    SpeedEnabled = false,
    SpeedMethod = "Normal", -- "Normal" or "TPWalk"
    SpeedValue = 16,
    
    JumpEnabled = false,
    JumpMethod = "Normal", -- "Normal", "Velocity", or "TPJump"
    JumpValue = 50,

    -- Visual Settings
    AntiLag = false,
    CrosshairEnabled = false,
    CrosshairSize = 10,
    CrosshairGap = 5,
    
    -- Custom Keybind Defaults (Stored as Strings)
    Keybind_UIToggle = "RightControl",
    Keybind_AimbotToggle = "None",
    Keybind_ESPToggle = "None"
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
end

local function SaveConfig()
    if writefile then
        pcall(function()
            writefile(ConfigFile, HttpService:JSONEncode(Config))
        end)
    end
end

-- Execute configuration load
LoadConfig()

-- Synchronize internal global states with loaded config
_G.AimbotEnabled = Config.AimbotEnabled
_G.AimbotMode = Config.AimbotMode
_G.AimbotType = Config.AimbotType
_G.AimPart = Config.AimPart
_G.WallCheck = Config.WallCheck
_G.TeamCheck = Config.TeamCheck
_G.DrawFOV = Config.DrawFOV
_G.FOVRadius = Config.FOVRadius
_G.ESPEnabled = Config.ESPEnabled
_G.ExternalButtonVisible = Config.ExternalButtonVisible

_G.AimbotSmoothness = Config.AimbotSmoothness
_G.AimbotStickiness = Config.AimbotStickiness

_G.SpeedEnabled = Config.SpeedEnabled
_G.SpeedMethod = Config.SpeedMethod
_G.SpeedValue = Config.SpeedValue

_G.JumpEnabled = Config.JumpEnabled
_G.JumpMethod = Config.JumpMethod
_G.JumpValue = Config.JumpValue

_G.AntiLag = Config.AntiLag
_G.CrosshairEnabled = Config.CrosshairEnabled
_G.CrosshairSize = Config.CrosshairSize
_G.CrosshairGap = Config.CrosshairGap

_G.ExtScaleValue = 100

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

local function ClearAllESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            local highlight = player.Character:FindFirstChild("LouisAimbotUniversal_ESP")
            if highlight then
                pcall(function() highlight:Destroy() end)
            end
        end
    end
end

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
Keybinds.AimbotToggle = GetKeyCode(Config.Keybind_AimbotToggle)
Keybinds.ESPToggle = GetKeyCode(Config.Keybind_ESPToggle)

-- ========================================================
-- [[ CORE UTILITIES & DETECTIONS ]]
-- ========================================================
local function isAlive(p) 
    return p and p.Character and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 and p.Character:FindFirstChild("HumanoidRootPart") 
end

local function getPing()
    local success, result = pcall(function()
        return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if success then return result else return 100 end
end

-- Retrieve Team Color dynamically
local function getPlayerTeamColor(p)
    if p.Team then
        return p.Team.TeamColor.Color
    elseif p.TeamColor then
        return p.TeamColor.Color
    end
    return Color3.fromRGB(0, 255, 0) -- fallback color
end

-- ========================================================
-- [[ VISUALS: ESP & CROSSHAIR CONTROLLER ]]
-- ========================================================
local function applyESP(player)
    if not player or player == LocalPlayer then return end
    local char = player.Character
    if not char then return end
    
    local highlight = char:FindFirstChild("LouisAimbotUniversal_ESP")
    if not highlight then
        highlight = Instance.new("Highlight")
        highlight.Name = "LouisAimbotUniversal_ESP"
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 0.2
        highlight.Parent = char
    end
    
    if _G.ESPEnabled then
        highlight.Enabled = true
        local teamColor = getPlayerTeamColor(player)
        highlight.FillColor = teamColor
        highlight.OutlineColor = teamColor
    else
        highlight.Enabled = false
    end
end

-- Crosshair System Lines Configuration
local CrosshairLines = {
    Top = Drawing.new("Line"),
    Bottom = Drawing.new("Line"),
    Left = Drawing.new("Line"),
    Right = Drawing.new("Line")
}

for _, line in pairs(CrosshairLines) do
    line.Visible = false
    line.Color = Color3.fromRGB(0, 255, 255) -- Standard active light blue/cyan color
    line.Thickness = 1.5
    line.Transparency = 1
    table.insert(_G.LouisDrawings, line)
end

local function UpdateCrosshair()
    local cam = getCamera()
    if _G.CrosshairEnabled and cam then
        local center = Vector2_new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
        local size = _G.CrosshairSize or 10
        local gap = _G.CrosshairGap or 5

        CrosshairLines.Top.Visible = true
        CrosshairLines.Top.From = Vector2_new(center.X, center.Y - gap)
        CrosshairLines.Top.To = Vector2_new(center.X, center.Y - gap - size)

        CrosshairLines.Bottom.Visible = true
        CrosshairLines.Bottom.From = Vector2_new(center.X, center.Y + gap)
        CrosshairLines.Bottom.To = Vector2_new(center.X, center.Y + gap + size)

        CrosshairLines.Left.Visible = true
        CrosshairLines.Left.From = Vector2_new(center.X - gap, center.Y)
        CrosshairLines.Left.To = Vector2_new(center.X - gap - size, center.Y)

        CrosshairLines.Right.Visible = true
        CrosshairLines.Right.From = Vector2_new(center.X + gap, center.Y)
        CrosshairLines.Right.To = Vector2_new(center.X + gap + size, center.Y)
    else
        for _, line in pairs(CrosshairLines) do
            line.Visible = false
        end
    end
end

-- ========================================================
-- [[ ANTI-LAG ENGINE OPTIMIZER ]]
-- ========================================================
local function ApplyAntiLag()
    if not _G.AntiLag then return end
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        workspace.Terrain.WaterWaveSize = 0
        workspace.Terrain.WaterWaveSpeed = 0
        workspace.Terrain.WaterDetail = Enum.WaterDetail.Low
    end)
    
    local function clean(obj)
        if obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = 1
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Sparkles") then
            obj.Enabled = false
        elseif obj:IsA("PostEffect") or obj:IsA("SunRaysEffect") or obj:IsA("ColorCorrectionEffect") or obj:IsA("BlurEffect") or obj:IsA("BloomEffect") then
            obj.Enabled = false
        elseif obj:IsA("Lighting") then
            obj.GlobalShadows = false
        end
    end
    
    for _, v in ipairs(game:GetDescendants()) do
        pcall(clean, v)
    end
end

-- ========================================================
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

-- Proxy engine for dynamic initialization of external HUD buttons
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

-- Floating HUD Button Instance
_G.ExtAimbotBtn = Library:CreateExternalButton("Aimbot", "AIMBOT", UDim2.new(0.5, -22, 0.8, 0), function()
    _G.AimbotEnabled = not _G.AimbotEnabled
    Config.AimbotEnabled = _G.AimbotEnabled
    SaveConfig()
    if _G.AimbotEnabled then
        SafeSetText(_G.ExtAimbotBtn, "AIMBOT ON")
    else
        SafeSetText(_G.ExtAimbotBtn, "AIMBOT")
    end
end)
RegisterExternalButton(_G.ExtAimbotBtn)

-- ========================================================
-- [[ AIMBOT ENGINE SYSTEM ]]
-- ========================================================
local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = false
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Thickness = 1.5
FOVCircle.NumSides = 64
FOVCircle.Radius = _G.FOVRadius
FOVCircle.Filled = false
FOVCircle.Transparency = 1
table.insert(_G.LouisDrawings, FOVCircle)

local lastTarget = nil

local function getClosestPlayerToCursor()
    local cam = getCamera()
    if not cam then return nil end
    local screenCenter = Vector2_new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    
    -- Stickiness target evaluation
    local stickinessVal = _G.AimbotStickiness or 1
    if lastTarget and isAlive(lastTarget) and stickinessVal > 1 then
        if not (_G.TeamCheck and lastTarget.Team == LocalPlayer.Team) then
            local char = lastTarget.Character
            local partName = _G.AimPart or "Head"
            local part = char:FindFirstChild(partName) or char:FindFirstChild("Head")
            if part then
                local screenPos, onScreen = cam:WorldToViewportPoint(part.Position)
                if onScreen then
                    local distance = (Vector2_new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                    -- Target retention scales dynamically with the Stickiness multiplier value
                    local stickyFOVMultiplier = 1 + (stickinessVal / 100)
                    if distance <= (_G.FOVRadius * stickyFOVMultiplier) then
                        local wallPassed = true
                        if _G.WallCheck then
                            local params = RaycastParams.new()
                            params.FilterDescendantsInstances = {LocalPlayer.Character, cam}
                            params.FilterType = Enum.RaycastFilterType.Exclude
                            local origin = cam.CFrame.Position
                            local direction = part.Position - origin
                            local result = Workspace:Raycast(origin, direction, params)
                            if result and not result.Instance:IsDescendantOf(char) then
                                wallPassed = false
                            end
                        end
                        if wallPassed then
                            return lastTarget
                        end
                    end
                end
            end
        end
    end

    local closestPlayer = nil
    local shortestDistance = math_huge
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and isAlive(player) then
            if _G.TeamCheck and player.Team == LocalPlayer.Team then
                continue
            end
            
            local char = player.Character
            local partName = _G.AimPart or "Head"
            local part = char:FindFirstChild(partName) or char:FindFirstChild("Head")
            
            if part then
                if _G.WallCheck then
                    local params = RaycastParams.new()
                    params.FilterDescendantsInstances = {LocalPlayer.Character, cam}
                    params.FilterType = Enum.RaycastFilterType.Exclude
                    local origin = cam.CFrame.Position
                    local direction = part.Position - origin
                    local result = Workspace:Raycast(origin, direction, params)
                    if result and not result.Instance:IsDescendantOf(char) then
                        continue
                    end
                end
                
                local screenPos, onScreen = cam:WorldToViewportPoint(part.Position)
                if onScreen then
                    local distance = (Vector2_new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                    if distance <= _G.FOVRadius and distance < shortestDistance then
                        shortestDistance = distance
                        closestPlayer = player
                    end
                end
            end
        end
    end
    lastTarget = closestPlayer
    return closestPlayer
end

-- Render loop handles drawing FOV visual elements & active crosshairs
SafeConnect(RunService.RenderStepped, function()
    local cam = getCamera()
    if _G.DrawFOV and _G.AimbotEnabled and cam then
        FOVCircle.Visible = true
        FOVCircle.Radius = _G.FOVRadius
        FOVCircle.Position = Vector2_new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    else
        FOVCircle.Visible = false
    end
    UpdateCrosshair()
end)

-- Process frame modifications inside Heartbeat
SafeConnect(RunService.Heartbeat, LPH_NO_VIRTUALIZE(function(dt)
    -- Process ESP Players
    if _G.ESPEnabled then
        for _, player in ipairs(Players:GetPlayers()) do
            applyESP(player)
        end
    else
        ClearAllESP()
    end

    -- Process Movement Systems
    if LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        
        -- Speed Walk Mechanics
        if _G.SpeedEnabled and humanoid and root then
            if _G.SpeedMethod == "TPWalk" then
                if humanoid.MoveDirection.Magnitude > 0 then
                    root.CFrame = root.CFrame + (humanoid.MoveDirection * (_G.SpeedValue / 10) * dt * 60)
                end
            elseif _G.SpeedMethod == "Normal" then
                humanoid.WalkSpeed = _G.SpeedValue
            end
        elseif not _G.SpeedEnabled and humanoid then
            -- Reset fallback WalkSpeed
            if humanoid.WalkSpeed ~= 16 then
                humanoid.WalkSpeed = 16
            end
        end

        -- Jump Power Modification (Direct Method)
        if _G.JumpEnabled and humanoid and _G.JumpMethod == "Normal" then
            humanoid.UseJumpPower = true
            humanoid.JumpPower = _G.JumpValue
        elseif not _G.JumpEnabled and humanoid then
            -- Reset fallback JumpPower
            if humanoid.JumpPower ~= 50 then
                humanoid.JumpPower = 50
            end
        end
    end

    -- Process Aimbot Engine
    if _G.AimbotEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local target = getClosestPlayerToCursor()
        if target and target.Character then
            local partName = _G.AimPart or "Head"
            local targetPart = target.Character:FindFirstChild(partName) or target.Character:FindFirstChild("Head")
            
            if targetPart then
                local targetPos = targetPart.Position
                
                -- Prediction calculations
                if _G.AimbotMode == "Prediction" then
                    local rootPart = target.Character:FindFirstChild("HumanoidRootPart")
                    if rootPart then
                        local velocity = rootPart.AssemblyLinearVelocity or rootPart.Velocity
                        local ping = getPing() / 1000
                        targetPos = targetPos + (velocity * ping)
                    end
                end
                
                -- Dynamic smoothness evaluation 
                local smoothness = _G.AimbotSmoothness or 1
                local alpha = 1 / smoothness
                
                -- Dynamic Camera Lock
                if _G.AimbotType == "Camera" then
                    local cam = getCamera()
                    if cam then
                        local desiredCF = CFrame_lookAt(cam.CFrame.Position, targetPos)
                        if smoothness > 1 then
                            cam.CFrame = cam.CFrame:Lerp(desiredCF, alpha)
                        else
                            cam.CFrame = desiredCF
                        end
                    end
                
                -- Dynamic Character Lock
                elseif _G.AimbotType == "Character" then
                    local root = LocalPlayer.Character.HumanoidRootPart
                    local flatTarget = Vector3_new(targetPos.X, root.Position.Y, targetPos.Z)
                    local desiredCF = CFrame_new(root.Position, flatTarget)
                    if smoothness > 1 then
                        root.CFrame = root.CFrame:Lerp(desiredCF, alpha)
                    else
                        root.CFrame = desiredCF
                    end
                end
            end
        end
    end
end))

-- UserInput JumpRequest connection for Velocity & Teleport Jump Methods
SafeConnect(UserInputService.JumpRequest, function()
    if not _G.JumpEnabled or not LocalPlayer.Character then return end
    local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if humanoid and root and humanoid.Health > 0 then
        if _G.JumpMethod == "Velocity" then
            root.AssemblyLinearVelocity = Vector3_new(root.AssemblyLinearVelocity.X, _G.JumpValue, root.AssemblyLinearVelocity.Z)
        elseif _G.JumpMethod == "TPJump" then
            root.CFrame = root.CFrame * CFrame_new(0, _G.JumpValue / 10, 0)
        end
    end
end)

-- Dynamic hook optimization for Anti-Lag additions
SafeConnect(game.DescendantAdded, function(obj)
    if _G.AntiLag then
        pcall(function()
            if obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 1
            elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Sparkles") then
                obj.Enabled = false
            elseif obj:IsA("PostEffect") or obj:IsA("SunRaysEffect") or obj:IsA("ColorCorrectionEffect") or obj:IsA("BlurEffect") or obj:IsA("BloomEffect") then
                obj.Enabled = false
            end
        end)
    end
end)

-- ========================================================
-- [[ MAIN MENU STRUCTURE ]]
-- ========================================================
local Window = Library:CreateWindow("AIMBOT & MOVEMENT UNIVERSAL", "discord.gg/P2FEVBz2PG")
Window:BindToggleKey(Keybinds.UIToggle)

-- [[ EXECUTE DEFERRED BUTTONS ]]
Library.CreateExternalButton = realCreateButton 

for _, btn in ipairs(deferredButtons) do
    local realBtn = Library:CreateExternalButton(btn.name, btn.text, btn.pos, btn.cb)
    btn.proxy.Instance = realBtn
    
    if btn.proxy._visible ~= nil then realBtn:SetVisible(btn.proxy._visible) end
    if btn.proxy._text ~= nil then realBtn:SetText(btn.proxy._text) end
    if btn.proxy._size ~= nil then realBtn:SetSize(btn.proxy._size) end
    if btn.proxy._dragLocked ~= nil then realBtn:SetDragLock(btn.proxy._dragLocked) end
end

Library:Notify("SCRIPT INSTANTIATED", "Press UI Menu Key to hide/show the Main UI.", 4)

-- --- TAB 1: WELCOME ---
local TabMain = Window:CreateTab("Welcome", "rbxassetid://6023426915")
TabMain:CreateParagraph("Welcome!", "Hello " .. LocalPlayer.Name .. "!\nThank you for executing the Universal Hub.")
TabMain:CreateParagraph("UI Instructions", "Toggle Menu: UI Menu Key\nConfigure and scale floating action elements directly from the tabs.")
TabMain:CreateParagraph("Official Community", "Join our Discord server to get script updates!")

TabMain:CreateButton("Copy Discord Server Link", function()
    if setclipboard then
        setclipboard("https://discord.gg/P2FEVBz2PG")
        Library:Notify("Discord Link", "Discord link copied successfully to your clipboard!", 2)
    else
        Library:Notify("Error", "Your exploit does not support clipboard copying.", 2.5)
    end
end)

-- --- TAB 2: AIMBOT SETTINGS ---
local TabAimbot = Window:CreateTab("Aimbot Settings", "rbxassetid://4483345998")

TabAimbot:CreateToggle("Enable Aimbot System", Config.AimbotEnabled, "AimbotEnabled", function(state)
    _G.AimbotEnabled = state
    Config.AimbotEnabled = state
    SaveConfig()
    if state then
        SafeSetText(_G.ExtAimbotBtn, "AIMBOT ON")
    else
        SafeSetText(_G.ExtAimbotBtn, "AIMBOT")
    end
end)

TabAimbot:CreateDropdown("Aimbot Targeting Mode", {"Normal", "Prediction"}, Config.AimbotMode, "AimbotMode", function(val)
    _G.AimbotMode = val
    Config.AimbotMode = val
    SaveConfig()
end)

TabAimbot:CreateDropdown("Aimbot Lock Type", {"Camera", "Character"}, Config.AimbotType, "AimbotType", function(val)
    _G.AimbotType = val
    Config.AimbotType = val
    SaveConfig()
end)

TabAimbot:CreateDropdown("Aimbot Target Part", {"Head", "HumanoidRootPart", "Torso", "Left Arm", "Right Arm"}, Config.AimPart, "AimPart", function(val)
    _G.AimPart = val
    Config.AimPart = val
    SaveConfig()
end)

TabAimbot:CreateToggle("Check Wall (Visibility Lock)", Config.WallCheck, "WallCheck", function(state)
    _G.WallCheck = state
    Config.WallCheck = state
    SaveConfig()
end)

TabAimbot:CreateToggle("Enable Team Check (Ignore Allies)", Config.TeamCheck, "TeamCheck", function(state)
    _G.TeamCheck = state
    Config.TeamCheck = state
    SaveConfig()
end)

TabAimbot:CreateParagraph("Tracking Mechanics", "Adjust the smoothness and stickiness of the camera lock-on below.")

TabAimbot:CreateSlider("Lock Smoothness (1 = Instant)", 1, 100, Config.AimbotSmoothness, "AimbotSmoothness", function(val)
    _G.AimbotSmoothness = val
    Config.AimbotSmoothness = val
    SaveConfig()
end)

TabAimbot:CreateSlider("Target Stickiness", 1, 100, Config.AimbotStickiness, "AimbotStickiness", function(val)
    _G.AimbotStickiness = val
    Config.AimbotStickiness = val
    SaveConfig()
end)

TabAimbot:CreateToggle("Show FOV Visual Circle", Config.DrawFOV, "DrawFOV", function(state)
    _G.DrawFOV = state
    Config.DrawFOV = state
    SaveConfig()
end)

TabAimbot:CreateSlider("FOV Circle Radius", 10, 500, Config.FOVRadius, "FOVRadius", function(val)
    _G.FOVRadius = val
    Config.FOVRadius = val
    SaveConfig()
end)

TabAimbot:CreateToggle("Show Aimbot Floating Button", Config.ExternalButtonVisible, "ExternalButtonVisible", function(state)
    _G.ExternalButtonVisible = state
    Config.ExternalButtonVisible = state
    SaveConfig()
    SafeSetVisible(_G.ExtAimbotBtn, state)
end)

-- --- TAB 3: MOVEMENT CONTROLS ---
local TabMovement = Window:CreateTab("Movement Modifications", "rbxassetid://4483362458")

TabMovement:CreateParagraph("Speed Configuration", "Modify WalkSpeed or use the TPWalk bypass engine.")

TabMovement:CreateToggle("Enable Speed Modification", Config.SpeedEnabled, "SpeedEnabled", function(state)
    _G.SpeedEnabled = state
    Config.SpeedEnabled = state
    SaveConfig()
end)

TabMovement:CreateDropdown("Speed Walk Method", {"Normal", "TPWalk"}, Config.SpeedMethod, "SpeedMethod", function(val)
    _G.SpeedMethod = val
    Config.SpeedMethod = val
    SaveConfig()
end)

TabMovement:CreateSlider("Speed Power", 16, 150, Config.SpeedValue, "SpeedValue", function(val)
    _G.SpeedValue = val
    Config.SpeedValue = val
    SaveConfig()
end)

TabMovement:CreateParagraph("Jump Customization", "Select alternate jump options if standard JumpPower is patched by the game.")

TabMovement:CreateToggle("Enable Jump Modification", Config.JumpEnabled, "JumpEnabled", function(state)
    _G.JumpEnabled = state
    Config.JumpEnabled = state
    SaveConfig()
end)

TabMovement:CreateDropdown("Jump Method", {"Normal", "Velocity", "TPJump"}, Config.JumpMethod, "JumpMethod", function(val)
    _G.JumpMethod = val
    Config.JumpMethod = val
    SaveConfig()
end)

TabMovement:CreateSlider("Jump Power", 50, 300, Config.JumpValue, "JumpValue", function(val)
    _G.JumpValue = val
    Config.JumpValue = val
    SaveConfig()
end)

-- --- TAB 4: VISUALS (ESP & HUD) ---
local TabVisuals = Window:CreateTab("Visuals & Screen Elements", "rbxassetid://4483345998")

TabVisuals:CreateToggle("Enable Player ESP Highlight", Config.ESPEnabled, "ESPEnabled", function(state)
    _G.ESPEnabled = state
    Config.ESPEnabled = state
    SaveConfig()
    if not state then
        ClearAllESP()
    end
end)

TabVisuals:CreateParagraph("Visual HUD Elements", "Display a centered classic plus-sign crosshair.")

TabVisuals:CreateToggle("Enable HUD Crosshair", Config.CrosshairEnabled, "CrosshairEnabled", function(state)
    _G.CrosshairEnabled = state
    Config.CrosshairEnabled = state
    SaveConfig()
end)

TabVisuals:CreateSlider("Crosshair Line Size", 2, 50, Config.CrosshairSize, "CrosshairSize", function(val)
    _G.CrosshairSize = val
    Config.CrosshairSize = val
    SaveConfig()
end)

TabVisuals:CreateSlider("Crosshair Inner Gap", 0, 30, Config.CrosshairGap, "CrosshairGap", function(val)
    _G.CrosshairGap = val
    Config.CrosshairGap = val
    SaveConfig()
end)

-- --- TAB 5: OPTIMIZATION & SETTINGS ---
local TabSettings = Window:CreateTab("Optimization Settings", "rbxassetid://4483362458")

TabSettings:CreateParagraph("Graphic Anti-Lag Booster", "Alters atmospheric lighting, disables dynamic particle generation, and modifies rendering qualities to prevent FPS drops.")

TabSettings:CreateToggle("Enable Performance Anti-Lag", Config.AntiLag, "AntiLag", function(state)
    _G.AntiLag = state
    Config.AntiLag = state
    SaveConfig()
    if state then
        ApplyAntiLag()
        Library:Notify("Anti-Lag System", "Applied engine changes to stabilize performance.", 3)
    else
        Library:Notify("Anti-Lag Info", "Please re-execute or rejoin the game to fully restore original visual graphics.", 4)
    end
end)

-- --- TAB 6: KEYBIND SETTINGS ---
local TabKeybinds = Window:CreateTab("Keybind Settings", "rbxassetid://4483362458")
TabKeybinds:CreateParagraph("Custom Keybind System", "Type the exact KeyCode name to bind actions. Use 'None' to clear.")

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

RegisterKeybindUI("UI Menu Toggle Key", "UIToggle", "RightControl")
RegisterKeybindUI("Aimbot System Toggle Key", "AimbotToggle", "None")
RegisterKeybindUI("ESP Players Toggle Key", "ESPToggle", "None")

-- --- TAB 7: BUTTON CONTROLS ---
local TabControls = Window:CreateTab("HUD & Window Scaling", "rbxassetid://4483362458")

TabControls:CreateParagraph("Scale External Floating Buttons (%)", "Adjust the scale of individual HUD floating action items dynamically.")

TabControls:CreateSlider("External Buttons Size", 10, 200, 100, "ExtScaleValue", function(val)
    _G.ExtScaleValue = val
    UpdateAllButtonsSize(val / 100)
end)

TabControls:CreateParagraph("Window Lock Options", "Lock active panel dragging positions.")
TabControls:CreateToggle("Lock Main UI Dragging", false, "DragLocked", function(state)
    Window:SetDragLock(state)
    UpdateAllButtonsDragLock(state)
end)

-- ========================================================================
-- [[ KEYBOARD QUICK SHORTCUTS CONNECTION ]]
-- ========================================================================
local function ToggleFeature(name)
    if name == "Aimbot" then
        _G.AimbotEnabled = not _G.AimbotEnabled
        Config.AimbotEnabled = _G.AimbotEnabled
        SaveConfig()
        SafeSetVisible(_G.ExtAimbotBtn, _G.AimbotEnabled)
        if _G.AimbotEnabled then
            SafeSetText(_G.ExtAimbotBtn, "AIMBOT ON")
        else
            SafeSetText(_G.ExtAimbotBtn, "AIMBOT")
        end
        Library:Notify("Aimbot System", "Status: " .. (_G.AimbotEnabled and "ON" or "OFF"), 1.5)
    elseif name == "ESP" then
        _G.ESPEnabled = not _G.ESPEnabled
        Config.ESPEnabled = _G.ESPEnabled
        SaveConfig()
        if not _G.ESPEnabled then
            ClearAllESP()
        end
        Library:Notify("ESP System", "Status: " .. (_G.ESPEnabled and "ON" or "OFF"), 1.5)
    end
end

local function HandleKeybindTrigger(keyCode)
    if keyCode == Enum.KeyCode.None or keyCode == Enum.KeyCode.Unknown then return end
    
    if keyCode == Keybinds.AimbotToggle then ToggleFeature("Aimbot") end
    if keyCode == Keybinds.ESPToggle then ToggleFeature("ESP") end
end

SafeConnect(UserInputService.InputBegan, function(input, gameProcessed)
    if gameProcessed then return end
    HandleKeybindTrigger(input.KeyCode)
end)

SafeConnect(LocalPlayer.CharacterAdded, function(char)
    table.clear(_G.LouisDrawings)
    table.insert(_G.LouisDrawings, FOVCircle)
    for _, line in pairs(CrosshairLines) do
        table.insert(_G.LouisDrawings, line)
    end
end)

-- ========================================================================
-- [[ DYNAMIC VISIBILITY SYNCHRONIZATION CORE ]]
-- ========================================================================
SafeSetVisible(_G.ExtAimbotBtn, _G.ExternalButtonVisible)

-- Pre-apply optimization check on initial execution
if _G.AntiLag then
    ApplyAntiLag()
end

print("Louis Hub: Core Loaded Successfully.")
