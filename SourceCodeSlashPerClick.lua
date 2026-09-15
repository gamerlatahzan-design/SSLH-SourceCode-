-- ========================================================
--  PUNCH ESCAPE / 1+ SLASH PER CLICK - MASTER SUITE
--  Engine: Luna Interface Suite | 100% Full English
-- ========================================================

-- ========================================================
-- SERVICES & LOCAL PLAYER
-- ========================================================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local VirtualUser       = game:GetService("VirtualUser")
local Lighting          = game:GetService("Lighting")
local LocalPlayer       = Players.LocalPlayer

-- ========================================================
-- MODULES & REMOTES LOADER
-- ========================================================
local Config = require(ReplicatedStorage:WaitForChild("PunchEscapeConfig"))
local Worlds = require(ReplicatedStorage:WaitForChild("PunchEscapeWorlds"))
local Formatter = require(ReplicatedStorage:WaitForChild("PunchEscapeNumberFormatter"))

local Remotes = ReplicatedStorage:WaitForChild("PunchEscapeRemotes")
local PunchRequest        = Remotes:WaitForChild("PunchRequest")
local RebirthRequest      = Remotes:WaitForChild("RebirthRequest")
local PurchaseRequest     = Remotes:WaitForChild("PurchaseRequest")
local MovementSpeedReq    = Remotes:WaitForChild("MovementSpeedRequest")
local SettingsPrefReq     = Remotes:WaitForChild("SettingsPreferenceRequest")
local AutoWinRequest      = Remotes:WaitForChild("AutoWinRequest")
local AFKExitRequest      = Remotes:WaitForChild("AFKExitRequest")
local OfflineRewardReq    = Remotes:WaitForChild("OfflineRewardRequest")
local WorldTeleportReq    = Remotes:WaitForChild("WorldTeleportRequest")

local LuckyBlockOpenReq   = ReplicatedStorage:WaitForChild("LuckyBlockOpenRequest")
local LuckyBlockAutoDel   = ReplicatedStorage:WaitForChild("LuckyBlockAutoDeleteRequest")
local PetInventoryAction  = ReplicatedStorage:WaitForChild("PetInventoryAction")

-- Player Stats Folders
local NumericStats = LocalPlayer:WaitForChild("NumericStats")
local PlayerStats  = LocalPlayer:WaitForChild("PlayerStats")
local PowerStat    = NumericStats:WaitForChild("Power")
local WinsStat     = NumericStats:WaitForChild("Wins")
local RebirthsStat = NumericStats:WaitForChild("Rebirths")
local LevelStat    = PlayerStats:WaitForChild("Level")

-- ========================================================
-- LUNA INTERFACE SUITE (Auto-Fallback Loader)
-- ========================================================
local Luna = nil
local lunaUrls = {
	"https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/refs/heads/master/source.lua",
	"https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/refs/heads/main/source.lua",
	"https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/main/source.lua"
}

for _, url in ipairs(lunaUrls) do
	local ok, res = pcall(function()
		return loadstring(game:HttpGet(url, true))()
	end)
	if ok and res then
		Luna = res
		break
	end
end

if not Luna then
	warn("[Master Suite] Failed to load Luna Interface Suite!")
	return
end

local function Notify(title, text, icon)
	pcall(function()
		Luna:Notification({
			Title       = title,
			Icon        = icon or "notifications_active",
			ImageSource = "Material",
			Content     = text
		})
	end)
end

-- ========================================================
-- STATE FLAGS & CONFIGURATION
-- ========================================================
-- Tab 1: Farm Flags
local autoSlash = false
local autoSlashSmartAim = false
local slashDelay = 0.1
local autoBreakWalls = false
local autoWinFarm = false
local smartDummyFarm = false
local autoFarmKOTH = false
local autoClaimOffline = false

-- Tab 2: Rebirth Flags
local autoMultiRebirth = false
local rebirthTargetCap = 999999999
local lockPosOnRebirth = false
local lastFarmCFrame = nil

-- Tab 3: Shop Flags
local autoBuyNextSlash = false
local autoBuyAuras = false
local autoUpgradeWinsTier = false
local autoUpgradePowerTier = false

-- Tab 4: Gacha Pets Flags
local selectedStationId = 1
local selectedOpenCount = 6
local fastOpenLuckyBlock = false
local autoOpenLavaBlock = false
local autoEquipBestPets = false
local autoDeleteCommon = false
local autoDeleteUncommon = false
local autoDeleteRare = false

-- Tab 5: Combat Flags
local pvpKillAura = false
local killAuraRadius = 35
local selectedTargetPlayer = ""
local antiRagdoll = false

-- Tab 7: Utility Flags
local hidePopups = false
local popupAddedConnection = nil
local originalWalkSpeed = 16

-- ========================================================
-- HELPER FUNCTIONS
-- ========================================================
local function formatAbbrev(num)
	return Formatter.Format(num or 0, 2)
end

local function getPlayerList()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			table.insert(list, p.Name)
		end
	end
	if #list == 0 then table.insert(list, "No players found") end
	return list
end

local function getRootPart()
	local char = LocalPlayer.Character
	return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
end

local function getActiveWallTarget()
	local wallsFolder = workspace:FindFirstChild("PunchEscapePersonalWalls")
	local hrp = getRootPart()
	if not wallsFolder or not hrp then return nil end

	local closestWall = nil
	local shortestDist = Config.MaximumWallPunchDistance

	for _, wall in ipairs(wallsFolder:GetChildren()) do
		if wall:IsA("BasePart") and wall:GetAttribute("PersonalWall") == true and wall.Transparency < 1 and wall.CanQuery then
			local dist = (wall.Position - hrp.Position).Magnitude
			if dist <= shortestDist then
				shortestDist = dist
				closestWall = wall
			end
		end
	end

	return closestWall and closestWall.Position or nil
end

local function getHighestUnlockedDummy()
	local rebirths = RebirthsStat.Value
	local currentWorld = LocalPlayer:GetAttribute("CurrentWorld") or 1
	local worldRoot = Worlds.GetRoot(currentWorld)
	if not worldRoot then return nil end

	local trainFolder = worldRoot:FindFirstChild("Train")
	if not trainFolder then return nil end

	local bestDummy = nil
	local bestIndex = 0

	for i = 1, 9 do
		local trainingData = Config.Training[(currentWorld - 1) * 9 + i]
		if trainingData and trainingData.Rebirths and rebirths >= trainingData.Rebirths then
			if i > bestIndex then
				bestIndex = i
				local trainModel = trainFolder:FindFirstChild("Train" .. ((currentWorld - 1) * 9 + i))
				if trainModel then
					local trainingSub = trainModel:FindFirstChild("Training" .. i)
					bestDummy = trainingSub and trainingSub:FindFirstChild("Test Dummy")
				end
			end
		end
	end

	return bestDummy
end

-- ========================================================
-- WINDOW CREATION
-- ========================================================
local Window = Luna:CreateWindow({
	Name            = "1+ Slash Per Click",
	Subtitle        = "Master Suite V2",
	LogoID          = "82795327169782",
	LoadingEnabled  = true,
	LoadingTitle    = "Punch Escape Hub",
	LoadingSubtitle = "Loading Modules...",
	ConfigSettings  = {
		RootFolder   = nil,
		ConfigFolder = "PunchEscapeHub"
	},
	KeySystem   = false
})

Window:CreateHomeTab({
	SupportedExecutors = { "Delta", "Codex", "Wave", "Fluxus", "Hydrogen", "Arceus X" },
	DiscordInvite      = "discord.gg",
	Icon               = 1
})

-- ========================================================
-- TAB 1 : FARM
-- ========================================================
local TabFarm = Window:CreateTab({
	Name        = "FARM",
	Icon        = "fitness_center",
	ImageSource = "Material",
	ShowTitle   = true
})

TabFarm:CreateSection("Auto Slash")

TabFarm:CreateToggle({
	Name         = "Auto Slash (Pure Farm)",
	Description  = "Automatically swings katana in-place to gain Power constantly",
	CurrentValue = false,
	Callback     = function(State)
		autoSlash = State
		if autoSlash then
			task.spawn(function()
				while autoSlash do
					local hrp = getRootPart()
					if hrp then
						local aim = hrp.Position + hrp.CFrame.LookVector * Config.MaximumPunchDistance
						PunchRequest:FireServer(aim)
					end
					task.wait(slashDelay)
				end
			end)
		end
	end
}, "AutoSlashToggle")

TabFarm:CreateToggle({
	Name         = "Auto Slash + Smart Aim",
	Description  = "Automatically aims slashes at active personal walls, training dummies, or forward",
	CurrentValue = false,
	Callback     = function(State)
		autoSlashSmartAim = State
		if autoSlashSmartAim then
			task.spawn(function()
				while autoSlashSmartAim do
					local hrp = getRootPart()
					if hrp then
						local targetPos = getActiveWallTarget()
						if not targetPos then
							local dummy = getHighestUnlockedDummy()
							targetPos = dummy and dummy:GetPivot().Position or (hrp.Position + hrp.CFrame.LookVector * Config.MaximumPunchDistance)
						end
						PunchRequest:FireServer(targetPos)
					end
					task.wait(slashDelay)
				end
			end)
		end
	end
}, "AutoSlashSmartAimToggle")

TabFarm:CreateSlider({
	Name         = "Slash Delay Interval",
	Description  = "Controls delay between slashes (in seconds)",
	Range        = {0.05, 0.5},
	Increment    = 0.01,
	CurrentValue = 0.1,
	Callback     = function(Val)
		slashDelay = Val
	end
}, "SlashDelaySlider")

TabFarm:CreateSection("Wall & Win Automation")

TabFarm:CreateToggle({
	Name         = "Auto Break Personal Walls",
	Description  = "Continuously hits active personal walls directly until stages clear",
	CurrentValue = false,
	Callback     = function(State)
		autoBreakWalls = State
		if autoBreakWalls then
			task.spawn(function()
				while autoBreakWalls do
					local wallPos = getActiveWallTarget()
					if wallPos then
						PunchRequest:FireServer(wallPos)
					end
					task.wait(slashDelay)
				end
			end)
		end
	end
}, "AutoBreakWallsToggle")

TabFarm:CreateToggle({
	Name         = "Auto Win Farm",
	Description  = "Toggles native Auto-Win controller to automatically clear stages and collect wins",
	CurrentValue = false,
	Callback     = function(State)
		autoWinFarm = State
		AutoWinRequest:FireServer(autoWinFarm)
	end
}, "AutoWinFarmToggle")

TabFarm:CreateSection("Training Areas")

TabFarm:CreateToggle({
	Name         = "Smart Training Dummy Farm",
	Description  = "Locks position at the highest multiplier Test Dummy you can use",
	CurrentValue = false,
	Callback     = function(State)
		smartDummyFarm = State
		if smartDummyFarm then
			task.spawn(function()
				while smartDummyFarm do
					local dummy = getHighestUnlockedDummy()
					local hrp = getRootPart()
					if dummy and hrp then
						local dummyTorso = dummy:FindFirstChild("Torso") or dummy.PrimaryPart
						if dummyTorso then
							hrp.CFrame = dummyTorso.CFrame * CFrame.new(0, 0, 3)
							hrp.AssemblyLinearVelocity = Vector3.zero
							PunchRequest:FireServer(dummyTorso.Position)
						end
					end
					task.wait(slashDelay)
				end
			end)
		end
	end
}, "SmartDummyFarmToggle")

TabFarm:CreateToggle({
	Name         = "Auto Farm King of the Hill (KOTH)",
	Description  = "Teleports to and holds the KOTH zone for massive passive multipliers",
	CurrentValue = false,
	Callback     = function(State)
		autoFarmKOTH = State
		if autoFarmKOTH then
			task.spawn(function()
				while autoFarmKOTH do
					local currentWorld = LocalPlayer:GetAttribute("CurrentWorld") or 1
					local root = Worlds.GetRoot(currentWorld)
					local kothZone = root and (root:FindFirstChild("KOTH", true) or root:FindFirstChild("Hill", true))
					local hrp = getRootPart()
					if kothZone and hrp then
						local targetPart = kothZone:IsA("BasePart") and kothZone or kothZone:FindFirstChildWhichIsA("BasePart", true)
						if targetPart then
							hrp.CFrame = targetPart.CFrame * CFrame.new(0, 3, 0)
							hrp.AssemblyLinearVelocity = Vector3.zero
							PunchRequest:FireServer(hrp.Position + hrp.CFrame.LookVector * 10)
						end
					end
					task.wait(slashDelay)
				end
			end)
		end
	end
}, "AutoFarmKOTHToggle")

TabFarm:CreateButton({
	Name        = "Claim Offline Power Now",
	Description = "Collects accumulated offline strength reward",
	Callback    = function()
		OfflineRewardReq:FireServer("Claim")
		Notify("FARM", "Offline strength rewards claimed!", "check_circle")
	end
})

-- ========================================================
-- TAB 2 : REBIRTH
-- ========================================================
local TabRebirth = Window:CreateTab({
	Name        = "REBIRTH",
	Icon        = "autorenew",
	ImageSource = "Material",
	ShowTitle   = true
})

TabRebirth:CreateSection("Smart Multi-Rebirth")

TabRebirth:CreateInput({
	Name            = "Rebirth Target Cap",
	Description     = "Stops auto rebirth once this total is reached",
	PlaceholderText = "Example: 1000",
	CurrentValue    = "",
	Numeric         = true,
	Enter           = true,
	Callback        = function(Text)
		local num = tonumber(Text)
		rebirthTargetCap = num or 999999999
		Notify("REBIRTH", "Target cap set to " .. tostring(rebirthTargetCap), "info")
	end
}, "RebirthTargetCapInput")

TabRebirth:CreateToggle({
	Name         = "Smart Auto Rebirth",
	Description  = "Automatically triggers the highest eligible rebirth batch (x1000, x100, x10, x1)",
	CurrentValue = false,
	Callback     = function(State)
		autoMultiRebirth = State
		if autoMultiRebirth then
			task.spawn(function()
				local batchSizes = { 1000, 100, 10, 1 }
				while autoMultiRebirth do
					local curRebirths = RebirthsStat.Value
					if curRebirths >= rebirthTargetCap then
						autoMultiRebirth = false
						Notify("REBIRTH", "Rebirth goal reached!", "check_circle")
						break
					end

					local curLevel = LevelStat.Value
					for _, amount in ipairs(batchSizes) do
						local req = Config.GetRebirthRequirement(curRebirths, amount)
						if curLevel >= req then
							RebirthRequest:FireServer(amount)
							task.wait(0.3)
							break
						end
					end
					task.wait(0.2)
				end
			end)
		end
	end
}, "SmartAutoRebirthToggle")

TabRebirth:CreateToggle({
	Name         = "Lock Position on Rebirth",
	Description  = "Restores your coordinates instantly after character resets from a rebirth",
	CurrentValue = false,
	Callback     = function(State)
		lockPosOnRebirth = State
		if lockPosOnRebirth then
			local hrp = getRootPart()
			if hrp then lastFarmCFrame = hrp.CFrame end
		end
	end
}, "LockPosOnRebirthToggle")

LocalPlayer.CharacterAdded:Connect(function(char)
	if lockPosOnRebirth and lastFarmCFrame then
		task.spawn(function()
			local hrp = char:WaitForChild("HumanoidRootPart", 5)
			if hrp then
				task.wait(0.2)
				hrp.CFrame = lastFarmCFrame
				hrp.AssemblyLinearVelocity = Vector3.zero
			end
		end)
	end
end)

-- ========================================================
-- TAB 3 : SHOP
-- ========================================================
local TabShop = Window:CreateTab({
	Name        = "SHOP",
	Icon        = "shopping_cart",
	ImageSource = "Material",
	ShowTitle   = true
})

TabShop:CreateSection("Slash Progression")

TabShop:CreateToggle({
	Name         = "Auto Buy Next Slash",
	Description  = "Automatically purchases next slash tier once you have enough Wins",
	CurrentValue = false,
	Callback     = function(State)
		autoBuyNextSlash = State
		if autoBuyNextSlash then
			task.spawn(function()
				while autoBuyNextSlash do
					local equippedFist = PlayerStats:FindFirstChild("EquippedFist")
					local currentFist = equippedFist and equippedFist.Value or 1
					local nextFist = currentFist + 1
					local fistData = Config.Fists[nextFist]

					if fistData and WinsStat.Value >= fistData.Cost then
						-- Trigger proximity prompt at pad if in world or fire purchase
						local worldNum = Config.GetWorldForFist(nextFist)
						local root = Worlds.GetRoot(worldNum)
						local pad = root and root:FindFirstChild("Fists") and root.Fists:FindFirstChild("Fist " .. nextFist)
						local prompt = pad and pad:FindFirstChildWhichIsA("ProximityPrompt", true)
						if prompt and fireproximityprompt then
							fireproximityprompt(prompt, 0)
						end
					end
					task.wait(1.5)
				end
			end)
		end
	end
}, "AutoBuyNextSlashToggle")

TabShop:CreateSection("Auras & Multipliers")

TabShop:CreateToggle({
	Name         = "Auto Buy Auras",
	Description  = "Sequentially buys all available auras using Wins",
	CurrentValue = false,
	Callback     = function(State)
		autoBuyAuras = State
		if autoBuyAuras do
			task.spawn(function()
				while autoBuyAuras do
					local ownedAuras = LocalPlayer:FindFirstChild("OwnedAuras")
					local wins = WinsStat.Value
					for i, auraData in ipairs(Config.Auras) do
						local auraVal = ownedAuras and ownedAuras:FindFirstChild("Aura" .. i)
						if auraVal and not auraVal.Value and wins >= auraData.Cost then
							PurchaseRequest:FireServer("AuraWins", i)
							task.wait(0.5)
						end
					end
					task.wait(2)
				end
			end)
		end
	end
}, "AutoBuyAurasToggle")

TabShop:CreateToggle({
	Name         = "Auto Upgrade Wins Tier",
	Description  = "Continuously upgrades Wins multiplier tier with Wins",
	CurrentValue = false,
	Callback     = function(State)
		autoUpgradeWinsTier = State
		if autoUpgradeWinsTier then
			task.spawn(function()
				while autoUpgradeWinsTier do
					local winsTier = PlayerStats:FindFirstChild("WinsTier")
					if winsTier and winsTier.Value < #Config.WinsTierOffers then
						PurchaseRequest:FireServer("WinsTier")
					end
					task.wait(2)
				end
			end)
		end
	end
}, "AutoUpgradeWinsTierToggle")

TabShop:CreateToggle({
	Name         = "Auto Upgrade Power Tier",
	Description  = "Continuously upgrades Power multiplier tier with Wins",
	CurrentValue = false,
	Callback     = function(State)
		autoUpgradePowerTier = State
		if autoUpgradePowerTier then
			task.spawn(function()
				while autoUpgradePowerTier do
					local powerTier = PlayerStats:FindFirstChild("PowerTier")
					if powerTier and powerTier.Value < #Config.PowerTierOffers then
						PurchaseRequest:FireServer("PowerTier")
					end
					task.wait(2)
				end
			end)
		end
	end
}, "AutoUpgradePowerTierToggle")

-- ========================================================
-- TAB 4 : GACHA PETS
-- ========================================================
local TabGacha = Window:CreateTab({
	Name        = "GACHA PETS",
	Icon        = "pets",
	ImageSource = "Material",
	ShowTitle   = true
})

TabGacha:CreateSection("Lucky Block Automation")

local stationOptions = {}
for i = 1, 15 do table.insert(stationOptions, "Station " .. i) end

TabGacha:CreateDropdown({
	Name          = "Select Lucky Block Station",
	Description   = "Choose which Lucky Block station to open",
	Options       = stationOptions,
	CurrentOption = {"Station 1"},
	MultipleOptions = false,
	Callback      = function(OptionTable)
		local choice = typeof(OptionTable) == "table" and OptionTable[1] or OptionTable
		selectedStationId = tonumber(choice:match("%d+")) or 1
	end
}, "LuckyStationDropdown")

TabGacha:CreateDropdown({
	Name          = "Open Amount",
	Description   = "Select opening batch amount (1x, 3x, or 6x)",
	Options       = {"1", "3", "6"},
	CurrentOption = {"6"},
	MultipleOptions = false,
	Callback      = function(OptionTable)
		local choice = typeof(OptionTable) == "table" and OptionTable[1] or OptionTable
		selectedOpenCount = tonumber(choice) or 6
	end
}, "LuckyOpenAmountDropdown")

TabGacha:CreateToggle({
	Name         = "Fast Open Lucky Block",
	Description  = "Continuously rolls chosen block station and suppresses camera cinematic",
	CurrentValue = false,
	Callback     = function(State)
		fastOpenLuckyBlock = State
		if fastOpenLuckyBlock then
			task.spawn(function()
				while fastOpenLuckyBlock do
					LuckyBlockOpenReq:FireServer(selectedStationId, "Wins", selectedOpenCount)
					task.wait(0.2)
				end
			end)
		end
	end
}, "FastOpenLuckyBlockToggle")

TabGacha:CreateSection("Inventory Management")

TabGacha:CreateButton({
	Name        = "Equip Best Pets Now",
	Description = "Equips your strongest pets instantly",
	Callback    = function()
		PetInventoryAction:FireServer("EquipBest")
		Notify("GACHA PETS", "Equipped highest multiplier pets!", "pets")
	end
})

TabGacha:CreateToggle({
	Name         = "Auto Equip Best Pets",
	Description  = "Periodically updates your equipped pets as you hatch stronger companions",
	CurrentValue = false,
	Callback     = function(State)
		autoEquipBestPets = State
		if autoEquipBestPets then
			task.spawn(function()
				while autoEquipBestPets do
					PetInventoryAction:FireServer("EquipBest")
					task.wait(5)
				end
			end)
		end
	end
}, "AutoEquipBestToggle")

TabGacha:CreateToggle({
	Name         = "Auto Delete Common Pets",
	Description  = "Automatically configures auto-delete for Common pets",
	CurrentValue = false,
	Callback     = function(State)
		autoDeleteCommon = State
		local inventory = LocalPlayer:FindFirstChild("PetInventory")
		if inventory then
			for _, pet in ipairs(inventory:GetChildren()) do
				if pet:GetAttribute("Rarity") == "Common" then
					LuckyBlockAutoDel:FireServer(pet.Name, autoDeleteCommon)
				end
			end
		end
	end
}, "AutoDelCommonToggle")

-- ========================================================
-- TAB 5 : COMBAT
-- ========================================================
local TabCombat = Window:CreateTab({
	Name        = "COMBAT",
	Icon        = "sports_mma",
	ImageSource = "Material",
	ShowTitle   = true
})

TabCombat:CreateSection("PvP Kill Aura")

TabCombat:CreateSlider({
	Name         = "Kill Aura Radius",
	Description  = "Attack detection distance in studs",
	Range        = {10, 180},
	Increment    = 5,
	CurrentValue = 35,
	Callback     = function(Val)
		killAuraRadius = Val
	end
}, "KillAuraRadiusSlider")

TabCombat:CreateToggle({
	Name         = "PvP Kill Aura",
	Description  = "Automatically slashes all active PvP players within radius",
	CurrentValue = false,
	Callback     = function(State)
		pvpKillAura = State
		if pvpKillAura then
			task.spawn(function()
				while pvpKillAura do
					local hrp = getRootPart()
					if hrp then
						for _, enemy in ipairs(Players:GetPlayers()) do
							if enemy ~= LocalPlayer and enemy:GetAttribute("PVPEnabled") == true and enemy:GetAttribute("PVPDeathLocked") ~= true then
								local eChar = enemy.Character
								local eHrp = eChar and eChar:FindFirstChild("HumanoidRootPart")
								local eHum = eChar and eChar:FindFirstChildOfClass("Humanoid")
								if eHrp and eHum and eHum.Health > 0 then
									if (eHrp.Position - hrp.Position).Magnitude <= killAuraRadius then
										PunchRequest:FireServer(eHrp.Position)
									end
								end
							end
						end
					end
					task.wait(slashDelay)
				end
			end)
		end
	end
}, "PvPKillAuraToggle")

TabCombat:CreateSection("Player Hunt")

local playerDropdown = TabCombat:CreateDropdown({
	Name          = "Select Target Player",
	Description   = "Target player to focus slashes",
	Options       = getPlayerList(),
	CurrentOption = {getPlayerList()[1]},
	MultipleOptions = false,
	Callback      = function(OptionTable)
		selectedTargetPlayer = typeof(OptionTable) == "table" and OptionTable[1] or OptionTable
	end
}, "TargetPlayerDropdown")

TabCombat:CreateButton({
	Name     = "Refresh Player List",
	Callback = function()
		playerDropdown:SetOptions(getPlayerList())
		Notify("COMBAT", "Player list refreshed!", "refresh")
	end
})

TabCombat:CreateToggle({
	Name         = "Anti-Ragdoll",
	Description  = "Prevents character stun, knockdown, and falling states",
	CurrentValue = false,
	Callback     = function(State)
		antiRagdoll = State
		if antiRagdoll then
			task.spawn(function()
				while antiRagdoll do
					local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
					if hum then
						hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
						hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
						hum.Sit = false
					end
					task.wait(0.2)
				end
			end)
		end
	end
}, "AntiRagdollToggle")

-- ========================================================
-- TAB 6 : TELEPORT
-- ========================================================
local TabTeleport = Window:CreateTab({
	Name        = "TELEPORT",
	Icon        = "explore",
	ImageSource = "Material",
	ShowTitle   = true
})

TabTeleport:CreateSection("World Teleportation")

for worldNum = 1, 5 do
	TabTeleport:CreateButton({
		Name        = "Teleport to World " .. worldNum,
		Description = "Initiates official server transition to World " .. worldNum,
		Callback    = function()
			WorldTeleportReq:FireServer("Prepare", worldNum)
			task.wait(0.5)
			WorldTeleportReq:FireServer("Commit", worldNum)
			Notify("TELEPORT", "Traveling to World " .. worldNum .. "...", "flight_takeoff")
		end
	})
end

TabTeleport:CreateSection("Areas & Zones")

TabTeleport:CreateButton({
	Name        = "Teleport to Current Spawn",
	Description = "Transports back to world starting spawn location",
	Callback    = function()
		local spawnPart = Worlds.GetSpawn(LocalPlayer:GetAttribute("CurrentWorld") or 1)
		local hrp = getRootPart()
		if spawnPart and hrp then
			hrp.CFrame = spawnPart.CFrame * CFrame.new(0, 4, 0)
			hrp.AssemblyLinearVelocity = Vector3.zero
		end
	end
})

TabTeleport:CreateButton({
	Name        = "Teleport to KOTH Area",
	Description = "Transports character directly into the King of the Hill platform",
	Callback    = function()
		local currentWorld = LocalPlayer:GetAttribute("CurrentWorld") or 1
		local root = Worlds.GetRoot(currentWorld)
		local koth = root and (root:FindFirstChild("KOTH", true) or root:FindFirstChild("Hill", true))
		local hrp = getRootPart()
		if koth and hrp then
			local target = koth:IsA("BasePart") and koth or koth:FindFirstChildWhichIsA("BasePart", true)
			if target then
				hrp.CFrame = target.CFrame * CFrame.new(0, 4, 0)
				hrp.AssemblyLinearVelocity = Vector3.zero
				Notify("TELEPORT", "Arrived at KOTH!", "place")
			end
		end
	end
})

-- ========================================================
-- TAB 7 : UTILITY
-- ========================================================
local TabUtility = Window:CreateTab({
	Name        = "UTILITY",
	Icon        = "settings",
	ImageSource = "Material",
	ShowTitle   = true
})

TabUtility:CreateSection("Speed & Character")

TabUtility:CreateSlider({
	Name         = "Server WalkSpeed",
	Description  = "Adjusts official server-synced agility speed",
	Range        = {16, 100},
	Increment    = 1,
	CurrentValue = 16,
	Callback     = function(Val)
		MovementSpeedReq:FireServer(Val)
	end
}, "ServerWalkSpeedSlider")

TabUtility:CreateSlider({
	Name         = "Client WalkSpeed",
	Description  = "Overrides local character Humanoid speed directly",
	Range        = {16, 250},
	Increment    = 1,
	CurrentValue = 16,
	Callback     = function(Val)
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = Val end
	end
}, "ClientWalkSpeedSlider")

TabUtility:CreateSlider({
	Name         = "Client JumpPower",
	Description  = "Overrides local character jump height",
	Range        = {50, 300},
	Increment    = 5,
	CurrentValue = 50,
	Callback     = function(Val)
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.UseJumpPower = true
			hum.JumpPower = Val
		end
	end
}, "ClientJumpPowerSlider")

TabUtility:CreateSection("Optimization & Performance")

TabUtility:CreateButton({
	Name        = "Zero Lag / FPS Booster",
	Description  = "Disables 3D slash visual effects, shadows, and heavy textures",
	Callback     = function()
		Lighting.GlobalShadows = false
		Lighting.FogEnd = 9e9
		settings().Rendering.QualityLevel = 1

		for _, v in ipairs(workspace:GetDescendants()) do
			if v:IsA("BasePart") and not v:IsA("MeshPart") then
				v.Material = Enum.Material.SmoothPlastic
				v.Reflectance = 0
			elseif v:IsA("Decal") or v:IsA("Texture") then
				v.Transparency = 1
			elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then
				v.Enabled = false
			end
		end
		Notify("UTILITY", "FPS Booster applied cleanly!", "speed")
	end
})

local function hidePopupElement(v)
	if not hidePopups then return end
	if v:IsA("BillboardGui") then
		v.Enabled = false
	elseif v:IsA("TextLabel") or v:IsA("Frame") then
		local name = v.Name:lower()
		local text = (v:IsA("TextLabel") and v.Text:lower()) or ""
		if text:find("%+") or text:find("power") or name:find("popup") or name:find("damage") then
			v.Visible = false
		end
	end
end

TabUtility:CreateToggle({
	Name         = "Hide Damage Popups",
	Description  = "Suppresses on-screen numeric damage and power gain bubbles",
	CurrentValue = false,
	Callback     = function(State)
		hidePopups = State
		local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
		if playerGui then
			for _, gui in ipairs(playerGui:GetDescendants()) do
				hidePopupElement(gui)
			end
			if hidePopups and not popupAddedConnection then
				popupAddedConnection = playerGui.DescendantAdded:Connect(hidePopupElement)
			elseif not hidePopups and popupAddedConnection then
				popupAddedConnection:Disconnect()
				popupAddedConnection = nil
			end
		end
	end
}, "HidePopupsToggle")

-- ========================================================
-- SAFE ANTI-AFK & RUNTIME STARTUP
-- ========================================================
LocalPlayer.Idled:Connect(function()
	VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.zero)
end)

Notify("Punch Escape", "Master Suite successfully loaded!", "verified")
