--!strict
--// File: ServerScriptService/KnitServer/Services/GearShopService.lua
--// GearShopService.lua
--// COMPLETE FINAL VERSION

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GearModule = require(ReplicatedStorage:WaitForChild("GearModule"))

local GearShopService = Knit.CreateService({
	Name = "GearShopService",
	Client = {
		BuyGear = Knit.CreateProperty(),
		ToggleAutoBuy = Knit.CreateProperty(),
		PurchaseResult = Knit.CreateSignal(),
		GearUpdated = Knit.CreateSignal(),
	},
})

local DEBUG_PRINTS = true

local function dprint(...: any)
	if DEBUG_PRINTS then
		print("[GearShopService]", ...)
	end
end

GearShopService.DataHandlerService = nil

function GearShopService:GetPlayerData(player: Player)
	if not self.DataHandlerService then
		warn("[GearShopService] DataHandlerService not available!")
		return nil
	end

	local data = self.DataHandlerService:GetPlayerData(player)
	if data then
		dprint("✅ Got player data for:", player.Name)
		return data
	else
		warn("[GearShopService] No data returned for:", player.Name)
		return nil
	end
end

function GearShopService:CanUnlockGear(player: Player, gearName: string): boolean
	local gearData = GearModule[gearName]
	if not gearData then
		warn("[GearShopService] ❌ Invalid gear in CanUnlockGear:", gearName)
		print("[GearShopService] Available gears in GearModule:")
		for name, data in pairs(GearModule) do
			if type(data) == "table" and data.Price then
				print("  -", name)
			end
		end
		return false
	end

	local playerData = self:GetPlayerData(player)
	if not playerData then
		return false
	end

	local playerPoints = playerData.Points or 0
	local requiredPoints = gearData.UnlockPoints or 0

	return playerPoints >= requiredPoints
end

function GearShopService:OwnsGear(player: Player, gearName: string): boolean
	local playerData = self:GetPlayerData(player)
	if not playerData or not playerData.Gear then
		return false
	end

	return playerData.Gear[gearName] == true
end

--// ==========================================
--// TOOL CREATION
--// ==========================================
function GearShopService:GiveGearTool(player: Player, gearName: string)
	dprint("GiveGearTool() ->", player.Name, gearName)

	local gearData = GearModule[gearName]
	if not gearData then
		warn("[GearShopService] ❌ Invalid gear in GiveGearTool:", gearName)
		return
	end

	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")

	if not backpack then
		warn("[GearShopService] No backpack for:", player.Name)
		return
	end

	-- Remove any old version of the tool so the newest model is used
	for _, obj in ipairs(player:GetDescendants()) do
		if obj:IsA("Tool") and obj.Name == gearName then
			obj:Destroy()
		end
	end

	local tool: Tool? = nil

	if gearData.Type == "Slide" then
		--// CREATE SLIDE TOOL
		tool = Instance.new("Tool")
		tool.Name = gearName
		tool.RequiresHandle = false
		tool:SetAttribute("GearType", "Slide")
		tool:SetAttribute("GearName", gearName)

		if gearData.Image and gearData.Image ~= "rbxassetid://0" then
			tool.TextureId = gearData.Image
		end

		print("[GearShopService] ✅ Created Slide tool:", gearName)

	elseif gearData.Type == "Punch" then

		print("[GearShopService] Creating punch tool:", gearName)

		local assetsFolder = ReplicatedStorage:WaitForChild("Assets")
		local punchesFolder = assetsFolder:WaitForChild("Punches")

		local templateModel: Model?

		if gearName == "Golden Punch" then
			templateModel = punchesFolder
				:WaitForChild("GoldenPunch")
				:WaitForChild("GoldenPunch1")
		else
			templateModel = punchesFolder
				:WaitForChild("NormalPunch")
				:WaitForChild("Punch1")
		end

		if not templateModel then
			warn("Punch model missing:", gearName)
			return
		end

		-- Remove any existing tool
		for _, obj in ipairs(player:GetDescendants()) do
			if obj:IsA("Tool") and obj.Name == gearName then
				obj:Destroy()
			end
		end

		local model = templateModel:Clone()

		local tool = Instance.new("Tool")
		tool.Name = gearName
		tool.RequiresHandle = true
		tool:SetAttribute("GearType","Punch")
		tool:SetAttribute("GearName",gearName)

		-- find mesh inside model
		local meshPart = model:FindFirstChildWhichIsA("BasePart", true)
		if not meshPart then
			warn("Punch mesh missing:", gearName)
			return
		end

		meshPart.Name = "Handle"
		meshPart.Anchored = false
		meshPart.CanCollide = false
		meshPart.Massless = true

		meshPart.Parent = tool

		-- Correct punch orientation in the hand
		tool.Grip =
			CFrame.new(-0.3, -1.5, -0.27) *
			CFrame.Angles(math.rad(-70), math.rad(-170), math.rad(-30))

		model:Destroy()

		tool.Parent = backpack
		return

	elseif gearData.Type == "Coil" then

		local assetsFolder = ReplicatedStorage:WaitForChild("Assets")
		local coilFolder = assetsFolder:WaitForChild("Coil")

		local template = coilFolder:FindFirstChild(gearName)
		if not template then
			warn("[GearShopService] ❌ Coil model not found:", gearName)
			return
		end

		local model = template:Clone()

		local handle = model:FindFirstChildWhichIsA("BasePart", true)
		if not handle then
			warn("[GearShopService] ❌ BasePart missing in:", gearName)
			return
		end

		tool = Instance.new("Tool")
		tool.Name = gearName
		tool.RequiresHandle = true
		tool:SetAttribute("GearType", "Coil")
		tool:SetAttribute("GearName", gearName)

		handle.Name = "Handle"
		handle.Anchored = false
		handle.CanCollide = false
		handle.Massless = true

		handle.Parent = tool

		for _, obj in ipairs(model:GetDescendants()) do
			if obj ~= handle and obj.Parent ~= handle then
				obj.Parent = handle
			end
		end

		model:Destroy()

		print("[GearShopService] ✅ Created Coil tool:", gearName)
	end

	tool.Parent = backpack
	print("[GearShopService] ✅ Gave tool to", player.Name, ":", gearName)
end

function GearShopService:BuyGear(player: Player, gearName: string): (boolean, string)
	dprint("BuyGear() ->", player.Name, "wants to buy:", gearName)

	local gearData = GearModule[gearName]
	if not gearData then
		warn("[GearShopService] ❌ Invalid gear in BuyGear:", gearName)
		return false, "Invalid gear"
	end

	local playerData = self:GetPlayerData(player)
	if not playerData then
		return false, "Data not loaded"
	end

	if playerData.Gear and playerData.Gear[gearName] == true then
		dprint("Already owns:", gearName)
		return false, "Already owned"
	end

	if not self:CanUnlockGear(player, gearName) then
		local required = gearData.UnlockPoints or 0
		local current = playerData.Points or 0
		dprint("Not enough Points:", current, "/", required)
		return false, string.format("Requires %d Points (you have %d)", required, current)
	end

	local price = gearData.Price or 0
    local playerCoins = playerData.Money or 0

	if playerCoins < price then
		dprint("Not enough Coins:", playerCoins, "/", price)
		return false, string.format("Need %d Money (you have %d)", price, playerCoins)
	end

	if price > 0 then
		local success = self.DataHandlerService:DeductMoney(player, price)
		if not success then
			warn("[GearShopService] Failed to deduct coins!")
			return false, "Transaction failed"
		end
		dprint("Deducted", price, "Coins")
	end

	if not playerData.Gear then
		playerData.Gear = {}
	end
	playerData.Gear[gearName] = true

	self.DataHandlerService:SetPlayerData(player, { Gear = playerData.Gear })
	dprint("✅ Granted ownership:", gearName)

	local gearFolder = player:FindFirstChild("Gear")
	if gearFolder then
		gearFolder:SetAttribute(gearName:gsub(" ", "_"), true)
	end

	self:GiveGearTool(player, gearName)
	self.Client.GearUpdated:Fire(player)

	return true, "Purchased!"
end

function GearShopService:ToggleAutoBuy(player: Player, gearName: string, enabled: boolean)
	dprint("ToggleAutoBuy() ->", player.Name, gearName, enabled)

	local playerData = self:GetPlayerData(player)
	if not playerData then
		return
	end

	if not playerData.AutoBuy then
		playerData.AutoBuy = {}
	end

	playerData.AutoBuy[gearName] = enabled
	self.DataHandlerService:SetPlayerData(player, { AutoBuy = playerData.AutoBuy })

	local autoBuyFolder = player:FindFirstChild("AutoBuy")
	if autoBuyFolder then
		autoBuyFolder:SetAttribute(gearName:gsub(" ", "_"), enabled)
	end

	dprint("✅ Auto-buy", gearName, "=", enabled)
end

function GearShopService:ProcessAutoBuy(player: Player)
	dprint("ProcessAutoBuy() for", player.Name)

	local playerData = self:GetPlayerData(player)
	if not playerData or not playerData.AutoBuy then
		return
	end

	for gearName, isEnabled in pairs(playerData.AutoBuy) do
		if isEnabled == true then
			if not playerData.Gear or playerData.Gear[gearName] ~= true then
				local success, message = self:BuyGear(player, gearName)
				if success then
					dprint("✅ Auto-bought:", gearName)
				else
					dprint("❌ Auto-buy failed:", gearName, message)
				end
			else
				self:GiveGearTool(player, gearName)
			end
		end
	end
end

function GearShopService:SetupPlayer(player: Player)
	dprint("SetupPlayer() for", player.Name)

	local autoBuyFolder = Instance.new("Folder")
	autoBuyFolder.Name = "AutoBuy"
	autoBuyFolder.Parent = player

	local gearFolder = Instance.new("Folder")
	gearFolder.Name = "Gear"
	gearFolder.Parent = player

	local connection = nil
	connection = self.DataHandlerService.OnPlayerProfileLoaded:Connect(function(loadedPlayer, profileData)
		if loadedPlayer == player then
			print("[GearShopService] ========== PROFILE LOADED ==========")
			print("[GearShopService] Player:", player.Name)
			print("[GearShopService] Coins:", profileData.Money)
			print("[GearShopService] Points:", profileData.Points)


			if profileData.Gear then
				print("[GearShopService] Gear ownership:")
				for gearName, isOwned in pairs(profileData.Gear) do
					print("  -", gearName, "=", isOwned)
					gearFolder:SetAttribute(gearName:gsub(" ", "_"), isOwned)
				end
			end

			if profileData.AutoBuy then
				for gearName, isEnabled in pairs(profileData.AutoBuy) do
					autoBuyFolder:SetAttribute(gearName:gsub(" ", "_"), isEnabled)
				end
			end

			-- Give owned gear
			if profileData.Gear then
				for gearName, isOwned in pairs(profileData.Gear) do
					if isOwned == true then
						print("[GearShopService] Giving owned gear:", gearName)
						self:GiveGearTool(player, gearName)
					end
				end
			end

			task.delay(1, function()
				self:ProcessAutoBuy(player)
			end)

			print("[GearShopService] ========== SETUP COMPLETE ==========")

			if connection then
				connection:Disconnect()
			end
		end
	end)

	player.CharacterAdded:Connect(function(character: Model)
		dprint("CharacterAdded for", player.Name)
		task.wait(1)

		local playerData = self:GetPlayerData(player)
		if playerData and playerData.Gear then
			for gearName, isOwned in pairs(playerData.Gear) do
				if isOwned == true then
					self:GiveGearTool(player, gearName)
				end
			end
		end
	end)
end

function GearShopService.Client:BuyGear(player: Player, gearName: string)
	dprint("Client.BuyGear from", player.Name, ":", gearName)

	local success, message = self.Server:BuyGear(player, gearName)
	self.PurchaseResult:Fire(player, success, gearName, message)
end

function GearShopService.Client:ToggleAutoBuy(player: Player, gearName: string, enabled: boolean)
	dprint("Client.ToggleAutoBuy from", player.Name, ":", gearName, enabled)

	self.Server:ToggleAutoBuy(player, gearName, enabled)
end

function GearShopService:KnitInit()
	dprint("KnitInit() start")

	Players.PlayerAdded:Connect(function(player: Player)
		dprint("PlayerAdded:", player.Name)
		self:SetupPlayer(player)
	end)

	dprint("KnitInit() complete")
end

function GearShopService:KnitStart()
	dprint("KnitStart() start")

	local ok, result = pcall(function()
		return Knit.GetService("DataHandlerService")
	end)

	if ok then
		self.DataHandlerService = result
		dprint("✅ Got DataHandlerService")

		-- Debug: Print available gears
		print("[GearShopService] Available gears in GearModule:")
		for name, data in pairs(GearModule) do
			if type(data) == "table" and data.Price ~= nil then
				print("  -", name, "| Type:", data.Type, "| Price:", data.Price)
			end
		end
	else
		warn("[GearShopService] Failed to get DataHandlerService:", result)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		self:SetupPlayer(player)
	end

	dprint("KnitStart() complete")
end

return GearShopService