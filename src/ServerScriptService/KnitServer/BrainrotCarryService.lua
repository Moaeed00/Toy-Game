--!strict
--// BrainrotCarryService.lua - THE ACTUAL FIX!
--// Problem: Can't set network owner while in backpack - that's why it failed!
--// Solution: Keep parts ANCHORED, equip tool, THEN unanchor in character!

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BrainrotConfig = require(ReplicatedStorage:WaitForChild("Configuration"):WaitForChild("BrainrotConfig"))

local BrainrotCarryService = Knit.CreateService({
	Name = "BrainrotCarryService",
	Client = {
		CarryStateChanged = Knit.CreateSignal(),
		RequestDrop = function() end,
	},
})

local promptConnections: { [BasePart]: RBXScriptConnection } = {}
local holdAnimTracks: { [Player]: AnimationTrack } = {}

BrainrotCarryService.BlocksSpawnAreaService = nil

local function countBrainrots(player: Player): number
	local count = 0
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("IsBrainrotTool") then
				count += 1
			end
		end
	end
	if player.Character then
		for _, tool in ipairs(player.Character:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("IsBrainrotTool") then
				count += 1
			end
		end
	end
	return count
end

function BrainrotCarryService:_playHoldAnimation(player: Player)
	print("🎬 Animation")
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local holdAnim = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Animations"):WaitForChild("HoldBrainrot")

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local track = animator:LoadAnimation(holdAnim)
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Action
	track:Play()

	holdAnimTracks[player] = track
end

function BrainrotCarryService:_stopHoldAnimation(player: Player)
	local track = holdAnimTracks[player]
	if track then
		track:Stop()
		track:Destroy()
		holdAnimTracks[player] = nil
	end
end

function BrainrotCarryService:_weldBrainrotToHands(player: Player, tool: Tool, handlePart: BasePart)
	print("🔧 Welding...")

	local character = player.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Remove existing welds
	for _, desc in ipairs(handlePart:GetDescendants()) do
		if desc.Name == "BrainrotCarryWeld" then
			desc:Destroy()
		end
	end

	-- Position
	local centerCF = hrp.CFrame * BrainrotConfig.CARRY_CENTER_OFFSET * BrainrotConfig.CARRY_ROTATION_OFFSET
	handlePart.CFrame = centerCF

	-- Create Motor6D
	local weld = Instance.new("WeldConstraint")
	weld.Name = "BrainrotCarryWeld"
	weld.Part0 = hrp
	weld.Part1 = handlePart
	weld.Parent = handlePart

	handlePart.CFrame =
		hrp.CFrame
		* BrainrotConfig.CARRY_CENTER_OFFSET
		* BrainrotConfig.CARRY_ROTATION_OFFSET

	print("✅ Motor6D created!")

	-- 🔥 NOW unanchor (motor exists, network owner set)
	handlePart.Anchored = false
	handlePart.CanCollide = false
	handlePart.Massless = true
	print("✅ Handle unanchored!")

	-- Unanchor mesh parts
	local parentModel = handlePart.Parent
	if parentModel and parentModel:IsA("Model") then
		for _, part in ipairs(parentModel:GetDescendants()) do
			for _, part in ipairs(parentModel:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = false
					part.CanCollide = false
					part.Massless = true
				end
			end
		end
		print("✅ All parts unanchored!")
	end
	print("✅ Weld complete!")
end

function BrainrotCarryService:_unweldBrainrotFromHands(tool: Tool)
	for _, desc in ipairs(tool:GetDescendants()) do
		if desc.Name == "BrainrotCarryWeld" then
			desc:Destroy()
		end
	end
end

function BrainrotCarryService:_createBrainrotTool(player: Player, brainrotModel: Model): Tool?
	print("🛠️ Creating tool...")

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return nil end

	local rootPart = brainrotModel:FindFirstChild("RootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return nil
	end

	local id = HttpService:GenerateGUID(false)

	local tool = Instance.new("Tool")
	tool.Name = "Brainrot_" .. string.sub(id, 1, 6)
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("IsBrainrotTool", true)
	tool:SetAttribute("BrainrotId", id)
	tool:SetAttribute("IsModelBrainrot", true)

	-- 🔥 KEEP ALL PARTS ANCHORED!
	local handle = rootPart

	for _, part in ipairs(brainrotModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Massless = true

			if part ~= handle then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = part
				weld.Parent = handle
			end
		end
	end

	rootPart.Name = "Handle"
	CollectionService:RemoveTag(brainrotModel, BrainrotConfig.BRAINROT_TAG_NAME)
	brainrotModel.Parent = tool
	tool.Parent = backpack

	print("✅ Tool in backpack (parts ANCHORED)")

	tool.Unequipped:Connect(function()
		print("🔴 Unequipped!")
		player:SetAttribute("IsBrainrotEquipped", false)
		self:_stopHoldAnimation(player)
		self:_unweldBrainrotFromHands(tool)
	end)

	local character = player.Character
	if character then
		local hum = character:FindFirstChildOfClass("Humanoid")
		if hum then
			print("📦 Equipping...")
			hum:EquipTool(tool)

			-- 🔥 Wait for tool to fully enter character!
			task.wait(0.1)

			print("🔧 Tool in character, NOW welding & unanchoring...")
			player:SetAttribute("IsBrainrotEquipped", true)

			-- NOW weld and unanchor (tool is in character!)
			self:_weldBrainrotToHands(player, tool, rootPart)
			self:_playHoldAnimation(player)

			-- Re-equip detection
			task.spawn(function()
				task.wait(0.2)

				character.ChildAdded:Connect(function(child)
					if child == tool then
						print("⚠️ RE-EQUIPPED!")
						player:SetAttribute("IsBrainrotEquipped", true)

						task.wait(0.1)

						local handle = tool:FindFirstChild("Handle", true)
						if handle and handle:IsA("BasePart") then
							self:_weldBrainrotToHands(player, tool, handle)
							self:_playHoldAnimation(player)
						end

						if self.BlocksSpawnAreaService then
							self.BlocksSpawnAreaService:UpdatePlayerSpeed(player)
						end
					end
				end)

				character.ChildRemoved:Connect(function(child)
					if child == tool then
						player:SetAttribute("IsBrainrotEquipped", false)
						self:_stopHoldAnimation(player)
						self:_unweldBrainrotFromHands(tool)
					end
				end)
			end)
		end
	end

	print("✅ Tool creation complete!")
	return tool
end

function BrainrotCarryService:TryPickup(player: Player, brainrotModel: Model)
	print("📦 TryPickup!")

	if not brainrotModel or not brainrotModel:IsA("Model") then return end

	local rootPart = brainrotModel:FindFirstChild("RootPart")
	if not rootPart or rootPart:GetAttribute("IsCarried") then return end

	if self.BlocksSpawnAreaService then
		if not self.BlocksSpawnAreaService:CanPickupBrainrot(player) then
			return
		end
	end

	if countBrainrots(player) >= BrainrotConfig.MAX_BRAINROT_INVENTORY then
		return
	end

	local prompt = rootPart:FindFirstChild(BrainrotConfig.PROMPT_NAME)
	if prompt then
		prompt.Enabled = false
	end

	if promptConnections[rootPart] then
		promptConnections[rootPart]:Disconnect()
		promptConnections[rootPart] = nil
	end

	local tool = self:_createBrainrotTool(player, brainrotModel)
	if not tool then return end

	rootPart:SetAttribute("IsCarried", true)
	player:SetAttribute("IsCarryingBrainrot", true)

	self.Client.CarryStateChanged:Fire(player, true, rootPart)

	if self.BlocksSpawnAreaService then
		self.BlocksSpawnAreaService:UpdatePlayerSpeed(player)
	end

	print("✅ Pickup complete!")
end

function BrainrotCarryService:DropBrainrot(player: Player, reason: string?)
	if self.BlocksSpawnAreaService and reason ~= "SlideCollisionDrop" and reason ~= "PunchHitDrop" then
		if not self.BlocksSpawnAreaService:CanDropBrainrot(player) then
			return
		end
	end

	local character = player.Character
	if not character then return end

	local equippedTool: Tool? = nil
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("IsBrainrotTool") then
			equippedTool = child
			break
		end
	end

	if not equippedTool then return end

	self:_stopHoldAnimation(player)

	local handle = equippedTool:FindFirstChild("Handle", true)
	if not handle or not handle:IsA("BasePart") then
		equippedTool:Destroy()
		return
	end

	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:UnequipTools()
	end

	self:_unweldBrainrotFromHands(equippedTool)
	task.wait()

	equippedTool.RequiresHandle = false

	local folder = workspace:FindFirstChild(BrainrotConfig.WORKSPACE_BRAINROT_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = BrainrotConfig.WORKSPACE_BRAINROT_FOLDER_NAME
		folder.Parent = workspace
	end

	local parentModel = handle.Parent

	if equippedTool:GetAttribute("IsModelBrainrot") then
		parentModel.Parent = folder

		for _, part in ipairs(parentModel:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = false
				part.CanCollide = false
				part.Massless = true
			end
		end

		handle.Name = "RootPart"
		handle:SetAttribute("IsCarried", false)

		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local forwardPos = (hrp.CFrame * CFrame.new(0, 0, -4)).Position
			local fixedPos = Vector3.new(forwardPos.X, -7.4, forwardPos.Z)
			local rotation = CFrame.Angles(0, math.rad(-90), 0)
			parentModel:PivotTo(CFrame.new(fixedPos) * rotation)
		end

		CollectionService:AddTag(parentModel, BrainrotConfig.BRAINROT_TAG_NAME)
		self:_setupPrompt(parentModel)
	end

	player:SetAttribute("IsCarryingBrainrot", false)
	player:SetAttribute("IsBrainrotEquipped", false)

	local remaining = countBrainrots(player)
	player:SetAttribute("IsCarryingBrainrot", remaining > 0)

	self.Client.CarryStateChanged:Fire(player, false, nil)

	if self.BlocksSpawnAreaService then
		self.BlocksSpawnAreaService:UpdatePlayerSpeed(player)
	end

	equippedTool:Destroy()
end

function BrainrotCarryService.Client:RequestDrop(player: Player, reason: string?)
	if self.Server.BlocksSpawnAreaService then
		if not self.Server.BlocksSpawnAreaService:CanDropBrainrot(player) then
			return
		end
	end
	self.Server:DropBrainrot(player, reason or "ClientRequested")
end

function BrainrotCarryService:_setupPrompt(brainrotModel: Model)
	if not brainrotModel:IsDescendantOf(workspace) then return end
	if not brainrotModel:IsA("Model") then return end

	local rootPart = brainrotModel:FindFirstChild("RootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	local prompt = rootPart:FindFirstChild(BrainrotConfig.PROMPT_NAME)
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = BrainrotConfig.PROMPT_NAME
		prompt.Parent = rootPart
	end

	prompt.ActionText = BrainrotConfig.PROMPT_ACTION_TEXT
	prompt.ObjectText = BrainrotConfig.PROMPT_OBJECT_TEXT
	prompt.KeyboardKeyCode = BrainrotConfig.PROMPT_KEYCODE
	prompt.MaxActivationDistance = BrainrotConfig.PROMPT_MAX_DISTANCE
	prompt.RequiresLineOfSight = BrainrotConfig.PROMPT_REQUIRES_LOS
	prompt.HoldDuration = 0.2
	prompt.Enabled = not rootPart:GetAttribute("IsCarried")

	if promptConnections[rootPart] then
		promptConnections[rootPart]:Disconnect()
	end

	promptConnections[rootPart] = prompt.Triggered:Connect(function(player: Player)
		self:TryPickup(player, brainrotModel)
	end)
end

function BrainrotCarryService:KnitInit()
	if not workspace:FindFirstChild(BrainrotConfig.WORKSPACE_BRAINROT_FOLDER_NAME) then
		local folder = Instance.new("Folder")
		folder.Name = BrainrotConfig.WORKSPACE_BRAINROT_FOLDER_NAME
		folder.Parent = workspace
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		self:DropBrainrot(player, "PlayerRemoving")
	end)
end

function BrainrotCarryService:KnitStart()
	pcall(function()
		self.BlocksSpawnAreaService = Knit.GetService("BlocksSpawnAreaService")
	end)

	for _, model in ipairs(CollectionService:GetTagged(BrainrotConfig.BRAINROT_TAG_NAME)) do
		if model:IsA("Model") then
			self:_setupPrompt(model)
		end
	end

	CollectionService:GetInstanceAddedSignal(BrainrotConfig.BRAINROT_TAG_NAME):Connect(function(inst: Instance)
		if inst:IsA("Model") then
			self:_setupPrompt(inst)
		end
	end)
end

return BrainrotCarryService