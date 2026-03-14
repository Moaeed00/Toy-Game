--!strict
--// BrainrotCarryService.lua - THE ACTUAL FIX!
--// Problem: Can't set network owner while in backpack - that's why it failed!
--// Solution: Keep parts ANCHORED, equip tool, THEN unanchor in character!

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local getBiomeByEntity = require(ReplicatedStorage.Shared.Utils.getBiomeByEntity)

local Knit = require(ReplicatedStorage.Packages.Knit)
local BrainrotConfig = require(ReplicatedStorage:WaitForChild("Configuration"):WaitForChild("BrainrotConfig"))

local BaseService

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
	-- ensure weld exists before unanchoring
	handlePart.CanCollide = false
	handlePart.Massless = true
	handlePart.Anchored = false

	for _, part in ipairs(handlePart.Parent:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
		end
	end
	print("✅ Handle unanchored!")

	-- Unanchor mesh parts
	local parentModel = handlePart.Parent
	if parentModel and parentModel:IsA("Model") then
		for _, part in ipairs(parentModel:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = false
				part.CanCollide = false
				part.Massless = true
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

function BrainrotCarryService:_attachBrainrotModel(player: Player, brainrotModel: Model): Model?
	print("🧠 Attaching model...")

	local character = player.Character
	if not character then return nil end

	local rootPart = brainrotModel:FindFirstChild("RootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return nil
	end

	CollectionService:RemoveTag(brainrotModel, BrainrotConfig.BRAINROT_TAG_NAME)

	-- weld all parts to root
	for _, part in ipairs(brainrotModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Massless = true

			if part ~= rootPart then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = rootPart
				weld.Part1 = part
				weld.Parent = rootPart
			end
		end
	end

	-- parent to character
	brainrotModel.Parent = character

	-- FORCE UNEQUIP ANY TOOL WHEN BRAINROT MODEL IS CARRIED
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:UnequipTools()
	end

	-- anchor temporarily
	rootPart.Anchored = true

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end

	rootPart.CFrame =
		hrp.CFrame
		* BrainrotConfig.CARRY_CENTER_OFFSET
		* BrainrotConfig.CARRY_ROTATION_OFFSET

	local weld = Instance.new("WeldConstraint")
	weld.Name = "BrainrotCarryWeld"
	weld.Part0 = hrp
	weld.Part1 = rootPart
	weld.Parent = rootPart

	-- 🔥 UNANCHOR ALL PARTS WHEN PICKED
	for _, part in ipairs(brainrotModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
		end
	end

	player:SetAttribute("IsBrainrotEquipped", true)

	self:_playHoldAnimation(player)

	return brainrotModel
end

function BrainrotCarryService:TryPickup(player: Player, brainrotModel: Model)

	print("[BrainrotCarryService] TryPickup called by:", player.Name)

	if not brainrotModel or not brainrotModel:IsA("Model") then
		print("[BrainrotCarryService] Invalid brainrot model")
		return
	end

	-- 🔴 PLAYER ALREADY CARRYING CHECK
	if player:GetAttribute("IsCarryingBrainrot") then
		print("[BrainrotCarryService] Player already carrying brainrot:", player.Name)
		return
	end

	if not brainrotModel or not brainrotModel:IsA("Model") then return end

	local rootPart = brainrotModel:FindFirstChild("RootPart")

	if not rootPart then
		print("[BrainrotCarryService] RootPart missing")
		return
	end

	-- 🔴 BRAINROT ALREADY CARRIED
	if brainrotModel:GetAttribute("IsCarried") then
		print("[BrainrotCarryService] Brainrot already carried by another player:", brainrotModel.Name)
		return
	end

	-- ATOMIC LOCK (prevents duplicate pickup)
	if rootPart:GetAttribute("PickupLocked") then
		return
	end

	rootPart:SetAttribute("PickupLocked", true)

	if rootPart:GetAttribute("IsCarried") then
		rootPart:SetAttribute("PickupLocked", false)
		return
	end

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

	-- 🔴 LOCK MODEL BEFORE ATTACH
	brainrotModel:SetAttribute("IsCarried", true)

	local tool = self:_attachBrainrotModel(player, brainrotModel)

	if not tool then
		print("[BrainrotCarryService] Attach failed, unlocking brainrot")
		brainrotModel:SetAttribute("IsCarried", false)
		rootPart:SetAttribute("PickupLocked", false)
		return
	end
	rootPart:SetAttribute("PickupLocked", false)

	player:SetAttribute("IsCarryingBrainrot", true)

	-- Store brainrot info for ownership later
	player:SetAttribute("CarriedBrainrotBiome", brainrotModel:GetAttribute("Biome"))
	player:SetAttribute("CarriedBrainrotName", brainrotModel.Name)
	player:SetAttribute("CarriedBrainrotMutation", brainrotModel:GetAttribute("Mutation"))

	self.Client.CarryStateChanged:Fire(player, true, rootPart)

	if self.BlocksSpawnAreaService then
		self.BlocksSpawnAreaService:UpdatePlayerSpeed(player)
	end

	print("✅ Pickup complete!")
end

function BrainrotCarryService:GiveOwnership(player: Player)

	print("========== GiveOwnership START ==========")
	print("[BrainrotCarryService] Player:", player.Name)
	print("[BrainrotCarryService] IsBrainrotEquipped:", player:GetAttribute("IsBrainrotEquipped"))

	if not player:GetAttribute("IsBrainrotEquipped") then
		print("[BrainrotCarryService] ❌ Player not holding brainrot")
		return
	end

	local character = player.Character
	if not character then
		print("[BrainrotCarryService] ❌ Character missing")
		return
	end

	print("[BrainrotCarryService] Searching brainrot model in character...")

	local brainrotModel: Model? = nil

	for _, child in ipairs(character:GetChildren()) do
		print("[BrainrotCarryService] Child:", child.Name, child.ClassName)

		if child:IsA("Model") and child:GetAttribute("IsCarried") then
			brainrotModel = child
			print("[BrainrotCarryService] ✅ Found brainrot:", child.Name)
			break
		end
	end

	if not brainrotModel then
		print("[BrainrotCarryService] ❌ No carried brainrot model found")
		return
	end

	-- READ DATA FROM MODEL ATTRIBUTES
	local biomeName = brainrotModel:GetAttribute("Biome")
	local entityName = brainrotModel:GetAttribute("EntityName")
	local mutationName = brainrotModel:GetAttribute("Mutation")

	print("[BrainrotCarryService] biome:", biomeName)
	print("[BrainrotCarryService] entity:", entityName)
	print("[BrainrotCarryService] mutation:", mutationName)

	if not entityName then
		print("[BrainrotCarryService] ❌ Missing EntityName attribute")
		return
	end

	if not biomeName then
		print("[BrainrotCarryService] ❌ Missing Biome attribute")
		return
	end

	if not biomeName then
		local biomeData = getBiomeByEntity(entityName)
		if biomeData then
			biomeName = biomeData
		end
	end

	if not biomeName then
		print("[BrainrotCarryService] ❌ biome still missing")
		return
	end

	------------------------------------------------
	-- STOP HOLD ANIMATION
	------------------------------------------------
	print("[BrainrotCarryService] Stopping animation")
	self:_stopHoldAnimation(player)

	------------------------------------------------
	-- CALL BASE SERVICE FIRST
	------------------------------------------------
	print("[BrainrotCarryService] BaseService reference:", BaseService)

	print("[BrainrotCarryService] 🚀 Calling BaseService:GiveTool")

	-- DESTROY MODEL FIRST
	print("[BrainrotCarryService] Destroying carried model")

	brainrotModel:Destroy()

	-- NOW GIVE TOOL
	BaseService:GiveTool(
		player,
		biomeName,
		entityName,
		mutationName
	)

	player:SetAttribute("IsBrainrotEquipped", false)

	print("[BrainrotCarryService] Tool given to player")

	-- wait one frame so the tool appears in backpack
	task.wait()

	local backpack = player:FindFirstChildOfClass("Backpack")

	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool.Name == entityName then

				print("[BrainrotCarryService] Found new tool:", tool.Name)

				tool:SetAttribute("IsBrainrotTool", true)

				-- also mark ownership so BlocksSpawnArea works
				tool:SetAttribute("OwnedByUserId", player.UserId)

				print("[BrainrotCarryService] Brainrot attributes applied")

			end
		end
	end

	print("[BrainrotCarryService] Tool given to player")

	------------------------------------------------
	-- SMALL DELAY (allow backpack replication)
	------------------------------------------------
	task.wait()

	player:SetAttribute("IsCarryingBrainrot", false)
	player:SetAttribute("IsBrainrotEquipped", false)

	-- equip the tool that was just created
	task.defer(function()

		local character = player.Character
		if not character then return end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end

		for _, tool in ipairs(player.Backpack:GetChildren()) do
			if tool:IsA("Tool") and tool.Name == entityName then
				humanoid:EquipTool(tool)
				print("[BrainrotCarryService] Equipped new brainrot tool:", tool.Name)
				break
			end
		end

	end)

	player:SetAttribute("OwnsEquippedBrainrot", true)
	player:SetAttribute("IsBrainrotEquipped", false)

	print("[BrainrotCarryService] ✅ GiveTool executed")
	print("========== GiveOwnership END ==========")

end

function BrainrotCarryService:DropBrainrot(player: Player, reason: string?)

	print("[BrainrotCarryService] DropBrainrot() called for:", player.Name)

	if self.BlocksSpawnAreaService and reason ~= "SlideCollisionDrop" and reason ~= "PunchHitDrop" then
		if not self.BlocksSpawnAreaService:CanDropBrainrot(player) then
			print("[BrainrotCarryService] Drop blocked by BlocksSpawnAreaService")
			return
		end
	end

	local character = player.Character
	if not character then
		print("[BrainrotCarryService] No character")
		return
	end

	local brainrotModel: Model? = nil

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("IsCarried") then
			brainrotModel = child
			break
		end
	end

	if not brainrotModel then
		print("[BrainrotCarryService] No carried brainrot found")
		return
	end

	print("[BrainrotCarryService] Found brainrot:", brainrotModel.Name)

	self:_stopHoldAnimation(player)

	local root = brainrotModel:FindFirstChild("RootPart")
	if not root or not root:IsA("BasePart") then
		print("[BrainrotCarryService] RootPart missing")
		return
	end

	----------------------------------------------------
	-- REMOVE carry weld
	----------------------------------------------------
	for _, obj in ipairs(brainrotModel:GetDescendants()) do
		if obj:IsA("WeldConstraint") and obj.Name == "BrainrotCarryWeld" then
			print("[BrainrotCarryService] Removing carry weld")
			obj:Destroy()
		end
	end

	----------------------------------------------------
	-- RESET PHYSICS
	----------------------------------------------------
	for _, part in ipairs(brainrotModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
	end

	print("[BrainrotCarryService] Physics cleared")

	----------------------------------------------------
	-- REBUILD MODEL WELDS (VERY IMPORTANT)
	----------------------------------------------------
	for _, obj in ipairs(root:GetChildren()) do
		if obj:IsA("WeldConstraint") then
			obj:Destroy()
		end
	end

	for _, part in ipairs(brainrotModel:GetDescendants()) do
		if part:IsA("BasePart") and part ~= root then

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = root

			part.Anchored = true
			part.CanCollide = false
			part.Massless = true

		end
	end

	print("[BrainrotCarryService] Model welds rebuilt")

	----------------------------------------------------
	-- ANCHOR ROOT
	----------------------------------------------------
	root.Anchored = true
	root.CanCollide = false
	root.Massless = false

	----------------------------------------------------
	-- MOVE MODEL TO WORKSPACE
	----------------------------------------------------
	local folder = workspace:FindFirstChild(BrainrotConfig.WORKSPACE_BRAINROT_FOLDER_NAME)

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = BrainrotConfig.WORKSPACE_BRAINROT_FOLDER_NAME
		folder.Parent = workspace
	end

	brainrotModel.Parent = folder

	print("[BrainrotCarryService] Model moved to workspace")

	----------------------------------------------------
	-- PLACE MODEL IN FRONT OF PLAYER
	----------------------------------------------------
	local hrp = character:FindFirstChild("HumanoidRootPart")

	if hrp then

		local forwardPos = (hrp.CFrame * CFrame.new(0,0,-4)).Position

		local fixedPos = Vector3.new(
			forwardPos.X,
			-6.8,
			forwardPos.Z
		)

		brainrotModel:PivotTo(
			CFrame.new(fixedPos) * CFrame.Angles(0, math.rad(-90), 0)
		)

		print("[BrainrotCarryService] Brainrot placed at:", fixedPos)

	end

	----------------------------------------------------
	-- RESET ATTRIBUTES
	----------------------------------------------------
	root:SetAttribute("IsCarried", false)
	brainrotModel:SetAttribute("IsCarried", false)

	CollectionService:AddTag(brainrotModel, BrainrotConfig.BRAINROT_TAG_NAME)

	self:_setupPrompt(brainrotModel)

	player:SetAttribute("IsCarryingBrainrot", false)
	player:SetAttribute("IsBrainrotEquipped", false)

	local remaining = countBrainrots(player)
	player:SetAttribute("IsCarryingBrainrot", remaining > 0)

	self.Client.CarryStateChanged:Fire(player, false, nil)

	if self.BlocksSpawnAreaService then
		self.BlocksSpawnAreaService:UpdatePlayerSpeed(player)
	end

	print("[BrainrotCarryService] Drop completed")

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
	prompt.Enabled = not rootPart:GetAttribute("IsCarried") and not rootPart:GetAttribute("PickupLocked")

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

	pcall(function()
		BaseService = Knit.GetService("BaseService")
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