local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")
local Camera = workspace.CurrentCamera

-- State Variables
local Waypoints = {} -- Stores frame-by-frame coordinate + delta time data
local IsRecording = false
local IsPlaying = false
local playCoroutine = nil
local recordCoroutine = nil
local ActiveTracks = {} -- Custom animation track list

-- Global Speed Config (Playback Speed Multiplier)
_G.PlaybackSpeedMultiplier = 1.0

-- Constant Files
local REGISTRY_FILE = "LouisPathsRegistry.json"

-- Thumbnail Helper Function to prevent direct asset conversion issues on mobile/PC
local function getAssetUrl(id)
    return "rbxthumb://type=Asset&id=" .. tostring(id) .. "&w=420&h=420"
end

-- Robust File Checker (Bypasses buggy isfile() implementations on mobile executors)
local function fileExists(path)
    if isfile then
        local success, result = pcall(function() return isfile(path) end)
        if success then return result end
    end
    local success, _ = pcall(function() return readfile(path) end)
    return success
end

-- UI Setup Helper
local function getGuiParent()
    local success, coreGui = pcall(function() return game:GetService("CoreGui") end)
    return (success and coreGui) or LocalPlayer:WaitForChild("PlayerGui")
end

-- Cleanup Old UI
local oldGui = getGuiParent():FindFirstChild("LouisFileManagerGui")
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui", getGuiParent())
ScreenGui.Name = "LouisFileManagerGui"
ScreenGui.ResetOnSpawn = false

-- ==================== FLOATING OPEN / CLOSE TOGGLE BUTTON ====================
local FloatingToggle = Instance.new("ImageButton", ScreenGui)
FloatingToggle.Name = "LouisFloatingToggle"
FloatingToggle.Size = UDim2.new(0, 50, 0, 50)
FloatingToggle.Position = UDim2.new(0.02, 0, 0.15, 0)
FloatingToggle.BackgroundTransparency = 1
FloatingToggle.Image = getAssetUrl("139899734802685") -- Provided Open/Close Icon
FloatingToggle.Active = true
FloatingToggle.Draggable = true -- Allows mobile/PC users to reposition the toggle button easily
FloatingToggle.ZIndex = 5

local ToggleCorner = Instance.new("UICorner", FloatingToggle)
ToggleCorner.CornerRadius = UDim.new(0, 25) -- Keeps the floating button circular

-- ==================== MAIN WINDOW SETUP ====================
local MainWindow = Instance.new("Frame", ScreenGui)
MainWindow.Size = UDim2.new(0, 360, 0, 240)
MainWindow.Position = UDim2.new(0.05, 0, 0.3, 0)
MainWindow.BackgroundTransparency = 1 -- Fully transparent base frame
MainWindow.BorderSizePixel = 0
MainWindow.Active = true
MainWindow.Draggable = true
MainWindow.Visible = true -- Starts as visible

local MainCorner = Instance.new("UICorner", MainWindow)
MainCorner.CornerRadius = UDim.new(0, 8)

-- Full Frame Background Image Label
local BackgroundImage = Instance.new("ImageLabel", MainWindow)
BackgroundImage.Name = "UIBackgroundImage"
BackgroundImage.Size = UDim2.new(1, 0, 1, 0)
BackgroundImage.BackgroundTransparency = 1
BackgroundImage.BorderSizePixel = 0
BackgroundImage.Image = getAssetUrl("126526125105002") -- Provided Background Image
BackgroundImage.ZIndex = 1 -- Renders at the very bottom layer

local BgCorner = Instance.new("UICorner", BackgroundImage)
BgCorner.CornerRadius = UDim.new(0, 8)

-- Sleek Acrylic Dark Overlay (Tints background slightly darker for extreme text readability)
local DarkOverlay = Instance.new("Frame", MainWindow)
DarkOverlay.Name = "UIDarkOverlay"
DarkOverlay.Size = UDim2.new(1, 0, 1, 0)
DarkOverlay.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
DarkOverlay.BackgroundTransparency = 0.4 -- 40% opacity dark glass look
DarkOverlay.BorderSizePixel = 0
DarkOverlay.ZIndex = 2 -- Renders above background image, below buttons

local OverlayCorner = Instance.new("UICorner", DarkOverlay)
OverlayCorner.CornerRadius = UDim.new(0, 8)

-- Header Title
local Header = Instance.new("TextLabel", MainWindow)
Header.Size = UDim2.new(1, -40, 0, 30)
Header.Position = UDim2.new(0, 10, 0, 0)
Header.BackgroundTransparency = 1
Header.Text = "LouisHub Recording" -- Title Updated
Header.TextColor3 = Color3.fromRGB(255, 255, 255)
Header.Font = Enum.Font.SourceSansBold
Header.TextSize = 13
Header.TextXAlignment = Enum.TextXAlignment.Left
Header.ZIndex = 3

-- "X" Close Button (Top-Right)
local CloseBtn = Instance.new("TextButton", MainWindow)
CloseBtn.Name = "UICloseButton"
CloseBtn.Size = UDim2.new(0, 25, 0, 20)
CloseBtn.Position = UDim2.new(1, -30, 0, 5)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(231, 76, 60) -- Bright Red Color
CloseBtn.Font = Enum.Font.SourceSansBold
CloseBtn.TextSize = 13
CloseBtn.ZIndex = 3

CloseBtn.MouseButton1Click:Connect(function()
    MainWindow.Visible = false
end)

-- Toggle Main Window visibility when clicking the Floating Icon
FloatingToggle.MouseButton1Click:Connect(function()
    MainWindow.Visible = not MainWindow.Visible
end)

-- Status Label
local StatusLabel = Instance.new("TextLabel", MainWindow)
StatusLabel.Size = UDim2.new(1, -20, 0, 20)
StatusLabel.Position = UDim2.new(0, 10, 0, 30)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: Idle"
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
StatusLabel.Font = Enum.Font.SourceSansItalic
StatusLabel.TextSize = 11
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.ZIndex = 3

-- Splitter Line
local Line = Instance.new("Frame", MainWindow)
Line.Size = UDim2.new(0, 1, 0, 175)
Line.Position = UDim2.new(0.48, 0, 0, 55)
Line.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
Line.BorderSizePixel = 0
Line.ZIndex = 3

-- LEFT PANEL (Controls & Recording)
local LeftFrame = Instance.new("Frame", MainWindow)
LeftFrame.Size = UDim2.new(0.45, 0, 0, 175)
LeftFrame.Position = UDim2.new(0, 10, 0, 55)
LeftFrame.BackgroundTransparency = 1
LeftFrame.ZIndex = 3

-- RIGHT PANEL (File List Scroll)
local RightFrame = Instance.new("Frame", MainWindow)
RightFrame.Size = UDim2.new(0.48, 0, 0, 175)
RightFrame.Position = UDim2.new(0.5, 5, 0, 55)
RightFrame.BackgroundTransparency = 1
RightFrame.ZIndex = 3

local ScrollFrame = Instance.new("ScrollingFrame", RightFrame)
ScrollFrame.Size = UDim2.new(1, 0, 1, 0)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollFrame.ZIndex = 3

local function refreshCharacter()
    Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    Humanoid = Character:WaitForChild("Humanoid")
    RootPart = Character:WaitForChild("HumanoidRootPart")
    Camera = workspace.CurrentCamera
end

-- Helper: Toggles character collisions to prevent vertical shaking and floor clipping
local function setCharacterCollision(state)
    pcall(function()
        for _, part in ipairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = state
            end
        end
    end)
end

-- ==================== SYSTEM REGISTRY (FILE MANAGEMENT) ====================

local function getRegistry()
    if fileExists(REGISTRY_FILE) then
        local success, decoded = pcall(function()
            return HttpService:JSONDecode(readfile(REGISTRY_FILE))
        end)
        if success and type(decoded) == "table" then
            return decoded
        end
    end
    return {}
end

local function saveRegistry(registry)
    if writefile then
        pcall(function()
            writefile(REGISTRY_FILE, HttpService:JSONEncode(registry))
        end)
    end
end

local function savePath(name)
    if #Waypoints == 0 then return false, "Route is empty! Please record first." end
    if name == "" or name == nil then return false, "Please enter a route name!" end
    if not writefile or not readfile then return false, "Save failed: Executor lacks file support." end
    
    local fileName = "LouisPath_" .. name .. ".json"
    local success, err = pcall(function()
        writefile(fileName, HttpService:JSONEncode(Waypoints))
    end)
    
    if not success then 
        return false, "Save failed: " .. tostring(err) 
    end
    
    local reg = getRegistry()
    local exists = false
    for _, existingName in ipairs(reg) do
        if existingName == name then exists = true break end
    end
    if not exists then
        table.insert(reg, name)
        saveRegistry(reg)
    end
    return true, "Successfully saved!"
end

local function loadPath(name)
    local fileName = "LouisPath_" .. name .. ".json"
    if not readfile then return false, "Load failed: Executor lacks file support." end
    
    if fileExists(fileName) then
        local success, decoded = pcall(function()
            return HttpService:JSONDecode(readfile(fileName))
        end)
        if success and type(decoded) == "table" then
            -- SOLUSI RE-ASPARASI: Mengisi ulang tabel secara in-place agar referensi upvalue tetap terjaga
            table.clear(Waypoints)
            for _, wp in ipairs(decoded) do
                table.insert(Waypoints, wp)
            end
            return true, "Route " .. name .. " (" .. #Waypoints .. " frames) loaded!"
        else
            return false, "Load failed: " .. tostring(decoded)
        end
    end
    return false, "File not found!"
end

local function deletePath(name)
    local reg = getRegistry()
    local newReg = {}
    for _, existingName in ipairs(reg) do
        if existingName ~= name then
            table.insert(newReg, existingName)
        end
    end
    saveRegistry(newReg)
    
    local fileName = "LouisPath_" .. name .. ".json"
    if fileExists(fileName) and delfile then
        pcall(function() delfile(fileName) end)
    end
    return true
end

-- ==================== PLAYBACK (PHYSICS-BYPASSED LANDING) ====================

local function getClosestFrameIndex()
    local closestIdx = 1
    local minDist = math.huge
    refreshCharacter()
    local myPos = RootPart.Position
    for i, frame in ipairs(Waypoints) do
        local framePos = Vector3.new(frame.cf[1], frame.cf[2], frame.cf[3])
        local dist = (myPos - framePos).Magnitude
        if dist < minDist then
            minDist = dist
            closestIdx = i
        end
    end
    return closestIdx
end

local function stopPlayback()
    IsPlaying = false
    if playCoroutine then
        task.cancel(playCoroutine)
        playCoroutine = nil
    end
    
    setCharacterCollision(true) -- Restores character collisions
    
    if RootPart then
        RootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    end
    if Humanoid then
        Humanoid:Move(Vector3.new(0, 0, 0))
    end
end

local function startPlayback()
    if #Waypoints == 0 then 
        StatusLabel.Text = "Status: Playback failed, route is empty!"
        return 
    end
    IsPlaying = true
    refreshCharacter()
    Humanoid.AutoRotate = true
    
    local closestIdx = getClosestFrameIndex()
    
    playCoroutine = task.spawn(function()
        local targetStartWp = Waypoints[closestIdx]
        local targetStartCF = CFrame.new(table.unpack(targetStartWp.cf))
        
        -- SMOOTH CONNECTOR: If far away, smoothly lerp/glide to the closest node first
        local distanceToStart = (RootPart.Position - targetStartCF.Position).Magnitude
        if distanceToStart > 2.0 then
            StatusLabel.Text = "Status: Rejoining closest route..."
            local glideDuration = math.clamp(distanceToStart / 16, 0.5, 3.0)
            local elapsed = 0
            local startCF = RootPart.CFrame
            
            while elapsed < glideDuration and IsPlaying do
                local dt = RunService.PreSimulation:Wait()
                elapsed = elapsed + dt
                local t = math.clamp(elapsed / glideDuration, 0, 1)
                
                refreshCharacter()
                setCharacterCollision(false) -- Bypasses collision during rejoin
                
                local currentCF = startCF:Lerp(targetStartCF, t)
                local velocity = (currentCF.Position - RootPart.Position) / dt
                RootPart.AssemblyLinearVelocity = velocity
                Humanoid:Move(Vector3.new(velocity.X, 0, velocity.Z).Unit, false)
                RootPart.CFrame = currentCF
            end
        end
        
        StatusLabel.Text = "Status: Replaying movement..."
        local lastFacingDirection = nil
        local currentFrameIndex = closestIdx
        local timeAccumulator = 0
        
        -- Character stays unanchored, relying on pure physical velocity to drive locomotion
        RootPart.Anchored = false
        
        while IsPlaying do
            -- Updates in PreSimulation (before physics calculate) to ensure absolute camera stability
            local dt = RunService.PreSimulation:Wait()
            refreshCharacter()
            
            -- Turns off collisions every frame to prevent any collision conflicts with terrain/floors
            setCharacterCollision(false)
            
            local speedMult = _G.PlaybackSpeedMultiplier or 1.0
            timeAccumulator = timeAccumulator + (dt * speedMult)
            
            -- ACCUMULATOR GAME-LOOP: Iterates frames based on their recorded delta times for 100% accurate speed
            while IsPlaying do
                local currentFrame = Waypoints[currentFrameIndex]
                if not currentFrame then
                    currentFrameIndex = 1
                    currentFrame = Waypoints[1]
                end
                
                local frameDuration = currentFrame.dt or 0.03
                if timeAccumulator >= frameDuration then
                    timeAccumulator = timeAccumulator - frameDuration
                    currentFrameIndex = currentFrameIndex + 1
                    if currentFrameIndex > #Waypoints then
                        currentFrameIndex = 1
                    end
                else
                    break
                end
            end
            
            local currentIndex = currentFrameIndex
            local nextIndex = currentIndex + 1
            if nextIndex > #Waypoints then nextIndex = 1 end
            
            local currentFrame = Waypoints[currentIndex]
            local nextFrame = Waypoints[nextIndex]
            
            if currentFrame and nextFrame then
                local currentCF = CFrame.new(table.unpack(currentFrame.cf))
                local nextCF = CFrame.new(table.unpack(nextFrame.cf))
                
                local frameDuration = currentFrame.dt or 0.03
                local alpha = math.clamp(timeAccumulator / frameDuration, 0, 1)
                local targetCF = currentCF:Lerp(nextCF, alpha)
                
                local myPos = RootPart.Position
                local deltaPos = targetCF.Position - myPos
                
                local horizontalDist = Vector3.new(deltaPos.X, 0, deltaPos.Z).Magnitude
                
                -- SMOOTH PHYSICAL GLIDE: Moves position purely via velocity
                -- Bypasses CFrame snapping conflicts, entirely eliminating screen/character shake
                local targetVelocity = deltaPos / dt
                if targetVelocity.Magnitude > 150 then
                    targetVelocity = targetVelocity.Unit * 150
                end
                RootPart.AssemblyLinearVelocity = targetVelocity
                
                -- Dynamic animation triggers based on exact delta velocity vectors
                local horizontalDist = Vector3.new(deltaPos.X, 0, deltaPos.Z).Magnitude
                if horizontalDist > 0.01 then
                    -- Feeds the relative direction vector to the Humanoid to trigger strafe/backwards animations naturally
                    Humanoid:Move(Vector3.new(deltaPos.X, 0, deltaPos.Z).Unit, false)
                else
                    Humanoid:Move(Vector3.new(0, 0, 0))
                end
                
                -- SINKRONISASI SHIFT-LOCK / ARAH HADAP KARAKTER ASLI:
                if deltaPos.Magnitude > 3.0 then
                    -- Anti-Drift: Snaps whole CFrame if pushed too far away
                    RootPart.CFrame = targetCF
                else
                    -- Memisahkan bagian rotasi asli rekaman (targetCF) dan menggabungkannya dengan posisi fisik nyata (myPos)
                    local rotationOnly = targetCF - targetCF.Position
                    RootPart.CFrame = CFrame.new(myPos) * rotationOnly
                end
            end
        end
    end)
end

-- ==================== RENDER FILE LIST (GUI DYNAMIC) ====================
local refreshFileList

refreshFileList = function()
    for _, child in ipairs(ScrollFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local reg = getRegistry()
    local yOffset = 0
    
    for _, pathName in ipairs(reg) do
        local itemFrame = Instance.new("Frame", ScrollFrame)
        itemFrame.Size = UDim2.new(0.95, 0, 0, 32)
        itemFrame.Position = UDim2.new(0, 0, 0, yOffset)
        itemFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        itemFrame.BorderSizePixel = 0
        itemFrame.ZIndex = 3
        
        local itemCorner = Instance.new("UICorner", itemFrame)
        itemCorner.CornerRadius = UDim.new(0, 4)
        
        local textLabel = Instance.new("TextLabel", itemFrame)
        textLabel.Size = UDim2.new(0.5, 0, 1, 0)
        textLabel.Position = UDim2.new(0, 6, 0, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = pathName
        textLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
        textLabel.Font = Enum.Font.SourceSans
        textLabel.TextSize = 12
        textLabel.TextXAlignment = Enum.TextXAlignment.Left
        textLabel.ZIndex = 3
        
        -- Load Button
        local loadBtn = Instance.new("TextButton", itemFrame)
        loadBtn.Size = UDim2.new(0.2, 0, 0.7, 0)
        loadBtn.Position = UDim2.new(0.55, 0, 0.15, 0)
        loadBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
        loadBtn.Text = "LOAD"
        loadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        loadBtn.Font = Enum.Font.SourceSansBold
        loadBtn.TextSize = 10
        loadBtn.ZIndex = 3
        Instance.new("UICorner", loadBtn).CornerRadius = UDim.new(0, 3)
        
        loadBtn.MouseButton1Click:Connect(function()
            stopPlayback()
            local success, msg = loadPath(pathName)
            StatusLabel.Text = "Status: " .. msg
        end)
        
        -- Delete Button
        local delBtn = Instance.new("TextButton", itemFrame)
        delBtn.Size = UDim2.new(0.2, 0, 0.7, 0)
        delBtn.Position = UDim2.new(0.78, 0, 0.15, 0)
        delBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
        delBtn.Text = "DEL"
        delBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        delBtn.Font = Enum.Font.SourceSansBold
        delBtn.TextSize = 10
        delBtn.ZIndex = 3
        Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0, 3)
        
        delBtn.MouseButton1Click:Connect(function()
            deletePath(pathName)
            StatusLabel.Text = "Status: Deleted " .. pathName .. " successfully."
            refreshFileList()
        end)
        
        yOffset = yOffset + 36
    end
    
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, yOffset)
end

-- ==================== LEFT CONTROL PANELS (GUI CREATOR) ====================

local NameInput = Instance.new("TextBox", LeftFrame)
NameInput.Size = UDim2.new(1, 0, 0, 25)
NameInput.Position = UDim2.new(0, 0, 0, 0)
NameInput.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
NameInput.PlaceholderText = "Enter Route Name..." -- Translated
NameInput.Text = ""
NameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
NameInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
NameInput.Font = Enum.Font.SourceSans
NameInput.TextSize = 12
NameInput.ZIndex = 3
Instance.new("UICorner", NameInput).CornerRadius = UDim.new(0, 4)

local function createLeftBtn(text, yPos, color, cb)
    local btn = Instance.new("TextButton", LeftFrame)
    btn.Size = UDim2.new(1, 0, 0, 25)
    btn.Position = UDim2.new(0, 0, 0, yPos)
    btn.BackgroundColor3 = color
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = text
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 11
    btn.ZIndex = 3
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    btn.MouseButton1Click:Connect(cb)
    return btn
end

local function createLeftSlider(text, yPos, min, max, default, cb)
    local sliderFrame = Instance.new("Frame", LeftFrame)
    sliderFrame.Size = UDim2.new(1, 0, 0, 35)
    sliderFrame.Position = UDim2.new(0, 0, 0, yPos)
    sliderFrame.BackgroundTransparency = 1
    sliderFrame.ZIndex = 3
    
    local label = Instance.new("TextLabel", sliderFrame)
    label.Size = UDim2.new(1, 0, 0, 14)
    label.BackgroundTransparency = 1
    label.Text = text .. ": " .. default .. "x"
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 3
    
    local sliderBar = Instance.new("TextButton", sliderFrame)
    sliderBar.Size = UDim2.new(1, 0, 0, 8)
    sliderBar.Position = UDim2.new(0, 0, 0, 18)
    sliderBar.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    sliderBar.Text = ""
    sliderBar.ZIndex = 3
    Instance.new("UICorner", sliderBar).CornerRadius = UDim.new(0, 4)
    
    local sliderFill = Instance.new("Frame", sliderBar)
    sliderFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
    sliderFill.ZIndex = 3
    Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(0, 4)
    
    local function updateSlider(input)
        local percentage = math.clamp((input.Position.X - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X, 0, 1)
        sliderFill.Size = UDim2.new(percentage, 0, 1, 0)
        local value = min + (percentage * (max - min))
        value = math.round(value * 10) / 10 -- Rounding to 1 decimal place
        label.Text = text .. ": " .. value .. "x"
        cb(value)
    end
    
    local dragging = false
    sliderBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateSlider(input)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local RecBtn, PlayBtn, SaveBtn

RecBtn = createLeftBtn("START RECORD", 30, Color3.fromRGB(52, 152, 219), function()
    if IsPlaying then stopPlayback() end
    if not IsRecording then
        IsRecording = true
        table.clear(Waypoints)
        refreshCharacter()
        
        -- SYNCHRONIZED RECORDING: PostSimulation event ensures exact duration measurements
        recordCoroutine = task.spawn(function()
            local lastTime = os.clock()
            while IsRecording do
                RunService.PostSimulation:Wait()
                refreshCharacter()
                
                local now = os.clock()
                local elapsed = now - lastTime
                lastTime = now
                
                local currentCF = RootPart.CFrame
                table.insert(Waypoints, {
                    cf = {currentCF:GetComponents()},
                    dt = elapsed -- Stores exact duration spent in this frame
                })
            end
        end)
        
        StatusLabel.Text = "Status: Recording movement..." -- Translated
        RecBtn.Text = "STOP RECORD" -- Translated
        RecBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
    else
        IsRecording = false
        if recordCoroutine then
            task.cancel(recordCoroutine)
            recordCoroutine = nil
        end
        StatusLabel.Text = "Status: Recording completed (" .. #Waypoints .. " frames)" -- Translated
        RecBtn.Text = "START RECORD" -- Translated
        RecBtn.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
    end
end)

SaveBtn = createLeftBtn("SAVE TO MANAGER", 60, Color3.fromRGB(46, 204, 113), function()
    IsRecording = false
    if recordCoroutine then
        task.cancel(recordCoroutine)
        recordCoroutine = nil
    end
    RecBtn.Text = "START RECORD"
    RecBtn.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
    
    local success, msg = savePath(NameInput.Text)
    StatusLabel.Text = "Status: " .. msg
    if success then
        NameInput.Text = ""
        refreshFileList()
    end
end)

PlayBtn = createLeftBtn("PLAYBACK [OFF]", 90, Color3.fromRGB(127, 140, 141), function()
    if IsRecording then 
        IsRecording = false
        if recordCoroutine then
            task.cancel(recordCoroutine)
            recordCoroutine = nil
        end
        RecBtn.Text = "START RECORD"
        RecBtn.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
    end
    
    if not IsPlaying then
        if #Waypoints == 0 then
            StatusLabel.Text = "Status: Please load or record a route first." -- Translated
            return
        end
        PlayBtn.Text = "PLAYBACK [ON]" -- Translated
        PlayBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
        startPlayback()
    else
        stopPlayback()
        PlayBtn.Text = "PLAYBACK [OFF]" -- Translated
        PlayBtn.BackgroundColor3 = Color3.fromRGB(127, 140, 141)
        StatusLabel.Text = "Status: Stopped." -- Translated
    end
end)

-- Multiplier Speed Slider (0.5x to 3.0x speed)
createLeftSlider("SPEED MULTI", 120, 0.5, 3.0, 1.0, function(value)
    _G.PlaybackSpeedMultiplier = value
end)

-- Reconnects automatically upon character respawn
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1.5)
    refreshCharacter()
    if IsPlaying then
        stopPlayback()
        task.wait(1)
        if PlayBtn.Text == "PLAYBACK [ON]" then
            startPlayback()
        end
    end
end)

refreshFileList()
