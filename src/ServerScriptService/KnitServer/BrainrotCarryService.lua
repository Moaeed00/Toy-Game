local Players: Players = game:GetService("Players")
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

local carriedByPlayer: { [Player]: BasePart } = {}
local promptTriggeredConnections: { [BasePart]: RBXScriptConnection } = {}

local originalAnchoredByBrainrot: { [BasePart]: boolean } = {}
local originalCanCollideByBrainrot: { [BasePart]: boolean } = {}
local originalMasslessByBrainrot: { [BasePart]: boolean } = {}

local holdTrackByPlayer: { [Player]: AnimationTrack } = {}

--// [NEW] Reference to BlocksSpawnAreaService
BrainrotCarryService.BlocksSpawnAreaService = nil

local function getBrainrotToolCount(player: Player): number
	--// Function: getBrainrotToolCount
	--// Counts brainrot tools in Backpack + Character.

	local count = 0

	--// [IMPORTANT] Count in Backpack
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		--// LOOP: backpack children
		for _, inst in ipairs(backpack:GetChildren()) do
			--// Loop: backpack child
			if inst:IsA("Tool") and inst:GetAttribute("IsBrainrotTool") == true then
				count += 1
			end
		end
	end

	--// [IMPORTANT] Count in Character
	local character = player.Character
	if character then
		--// LOOP: character children
		for _, inst in ipairs(character:GetChildren()) do
			--// Loop: character child
			if inst:IsA("Tool") and inst:GetAttribute("IsBrainrotTool") == true then
				count += 1
			end
		end
	end

	print("[BrainrotCarryService] getBrainrotToolCount() ->", player.Name, "count =", count)
	return count
end


function BrainrotCarryService:_StartTwoHandHold(player: Player, handlePart: BasePart?)
	--// Function: _StartTwoHandHold
	--// Plays Hold animation from ReplicatedStorage.Assets.Animations.Hold

	print("[BrainrotCarryService] _StartTwoHandHold() for:", player.Name)

	local character = player.Character
	if not character then
		print("[BrainrotCarryService] _StartTwoHandHold() FAIL -> no character")
		return
	end

	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then
		print("[BrainrotCarryService] _StartTwoHandHold() FAIL -> no humanoid")
		return
	end

	-- 🔥 Load new HoldBrainrot animation
	local holdAnim = ReplicatedStorage
		:WaitForChild("Assets")
		:WaitForChild("Animations")
		:WaitForChild("HoldBrainrot")

	if holdAnim and holdAnim:IsA("Animation") then
		print("[BrainrotCarryService] Found Hold animation, loading...")

		local animator = hum:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = hum
		end

		local track = animator:LoadAnimation(holdAnim)
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Action
		track:Play()

		holdTrackByPlayer[player] = track

		print("[BrainrotCarryService] Hold animation playing")
		return
	end

	-- FALLBACK: Simple arm pose if animation not found
	warn("[BrainrotCarryService] Hold animation not found at ReplicatedStorage.Assets.Animations.Hold")
	print("[BrainrotCarryService] Using fallback arm pose")

	-- R15 - both arms forward and inward
	local upperTorso = character:FindFirstChild("UpperTorso")
	if upperTorso then
		local leftShoulder = upperTorso:FindFirstChild("LeftShoulder")
		if leftShoulder and leftShoulder:IsA("Motor6D") then
			leftShoulder.Transform = CFrame.Angles(math.rad(-45), math.rad(15), math.rad(-10))
		end

		local rightShoulder = upperTorso:FindFirstChild("RightShoulder")
		if rightShoulder and rightShoulder:IsA("Motor6D") then
			rightShoulder.Transform = CFrame.Angles(math.rad(-45), math.rad(-15), math.rad(10))
		end
	end

	-- R6 - both arms forward
	local torso = character:FindFirstChild("Torso")
	if torso then
		local leftShoulder = torso:FindFirstChild("Left Shoulder")
		if leftShoulder and leftShoulder:IsA("Motor6D") then
			leftShoulder.Transform = CFrame.Angles(math.rad(-45), math.rad(15), 0)
		end

		local rightShoulder = torso:FindFirstChild("Right Shoulder")
		if rightShoulder and rightShoulder:IsA("Motor6D") then
			rightShoulder.Transform = CFrame.Angles(math.rad(-45), math.rad(-15), 0)
		end
	end

	print("[BrainrotCarryService] Fallback pose applied")
end

function BrainrotCarryService:_StopTwoHandHold(player: Player)
	--// Function: _StopTwoHandHold
	--// Stops hold animation and resets both arm transforms

	print("[BrainrotCarryService] _StopTwoHandHold() for:", player.Name)

	-- Stop animation track if playing
	local track = holdTrackByPlayer[player]
	if track then
		print("[BrainrotCarryService] Stopping hold animation track for:", player.Name)
		pcall(function()
			track:Stop()
			track:Destroy()
		end)
		holdTrackByPlayer[player] = nil
	end

	-- Reset arm transforms
	local character = player.Character
	if not character then return end

	-- R15 - reset BOTH shoulders
	local upperTorso = character:FindFirstChild("UpperTorso")
	if upperTorso then
		local leftShoulder = upperTorso:FindFirstChild("LeftShoulder")
		if leftShoulder and leftShoulder:IsA("Motor6D") then
			leftShoulder.Transform = CFrame.identity
		end

		local rightShoulder = upperTorso:FindFirstChild("RightShoulder")
		if rightShoulder and rightShoulder:IsA("Motor6D") then
			rightShoulder.Transform = CFrame.identity
		end
	end

	-- R6 - reset BOTH shoulders
	local torso = character:FindFirstChild("Torso")
	if torso then
		local leftShoulder = torso:FindFirstChild("Left Shoulder")
		if leftShoulder and leftShoulder:IsA("Motor6D") then
			leftShoulder.Transform = CFrame.identity
		end

		local rightShoulder = torso:FindFirstChild("Right Shoulder")
		if rightShoulder and rightShoulder:IsA("Motor6D") then
			rightShoulder.Transform = CFrame.identity
		end
	end

	print("[BrainrotCarryService] Both arms reset to identity")
end

function BrainrotCarryService:_weldBrainrotToHands(player: Player, tool: Tool, handlePart: BasePart)

	local character = player.Character
	if not character then
		return
	end

	self:_unweldBrainrotFromHands(tool)

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	-- Remove any existing welds
	for _, desc in ipairs(handlePart:GetDescendants()) do
		if desc:IsA("WeldConstraint") then
			desc:Destroy()
		end
	end

	-- ✅ CENTERED FIXED POSITION IN FRONT OF PLAYER
	-- ✅ CENTERED + ROTATED POSITION IN FRONT OF PLAYER
	local centerCF =
		hrp.CFrame
		* BrainrotConfig.CARRY_CENTER_OFFSET
		* BrainrotConfig.CARRY_ROTATION_OFFSET

	handlePart.CFrame = centerCF

	-- Create single weld to HRP (NOT hands anymore)
	local weld = Instance.new("WeldConstraint")
	weld.Name = "CenterCarryWeld"
	weld.Part0 = handlePart
	weld.Part1 = hrp
	weld.Parent = handlePart

	-- Ensure physics safe
	handlePart.Anchored = false
	handlePart.CanCollide = false
	handlePart.Massless = true

	print("[BrainrotCarryService] Brainrot centered and welded to HRP")
end

function BrainrotCarryService:_unweldBrainrotFromHands(tool: Tool)

	for _, desc in ipairs(tool:GetDescendants()) do
		if desc:IsA("WeldConstraint") then
			desc:Destroy()
		end
	end

	local handle = tool:FindFirstChild("Handle")
	if handle then
		for _, desc in ipairs(handle:GetChildren()) do
			if desc:IsA("WeldConstraint") then
				desc:Destroy()
			end
		end
	end
end

local function getOrCreateBrainrotFolder(): Folder
	--// Function: getOrCreateBrainrotFolder
	--// Ensures Workspace folder exists.

	print("[BrainrotCarryService] getOrCreateBrainrotFolder() called")

	local existing = workspace:FindFirstChild(BrainrotConfig.WORKSPACE_BRAINROT_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		print("[BrainrotCarryService] Found existing folder:", existing:GetFullName())
		return existing
	end

	print("[BrainrotCarryService] Creating folder:", BrainrotConfig.WORKSPACE_BRAINROT_FOLDER_NAME)

	local folder = Instance.new("Folder")
	folder.Name = BrainrotConfig.WORKSPACE_BRAINROT_FOLDER_NAME
	folder.Parent = workspace
	return folder
end

local function isValidBrainrot(inst: Instance): (boolean, BasePart?)
	--// Function: isValidBrainrot
	--// Validates both BasePart and Model brainrots, returns the part to attach prompt to

	-- Case 1: Direct BasePart
	if inst:IsA("BasePart") then
		print("[BrainrotCarryService] Valid brainrot (BasePart):", inst:GetFullName())
		return true, inst
	end

	-- Case 2: Model with parts
	if inst:IsA("Model") then
		-- Try PrimaryPart first
		if inst.PrimaryPart and inst.PrimaryPart:IsA("BasePart") then
			print("[BrainrotCarryService] Valid brainrot (Model with PrimaryPart):", inst:GetFullName())
			return true, inst.PrimaryPart
		end

		-- Find first BasePart
		for _, child in ipairs(inst:GetDescendants()) do
			if child:IsA("BasePart") then
				print("[BrainrotCarryService] Valid brainrot (Model with part):", inst:GetFullName())
				return true, child
			end
		end

		warn("[BrainrotCarryService] Model has no BasePart:", inst:GetFullName())
		return false, nil
	end

	print("[BrainrotCarryService] Invalid brainrot (not BasePart or Model):", inst:GetFullName())
	return false, nil
end

local function ensureBrainrotId(part: BasePart): string
	--// Function: ensureBrainrotId
	--// Adds unique id attribute.

	local existing = part:GetAttribute("BrainrotId")
	if typeof(existing) == "string" and existing ~= "" then
		return existing
	end

	local newId = HttpService:GenerateGUID(false)
	part:SetAttribute("BrainrotId", newId)
	print("[BrainrotCarryService] Assigned BrainrotId:", newId, "to", part:GetFullName())
	return newId
end

function BrainrotCarryService:_convertBrainrotPartToTool(player: Player, brainrotPart: BasePart): Tool?

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return nil
	end

	local id = ensureBrainrotId(brainrotPart)

	local tool = Instance.new("Tool")
	tool.Name = "Brainrot_" .. string.sub(id, 1, 6)
	tool.RequiresHandle = true
	tool:SetAttribute("IsBrainrotTool", true)
	tool:SetAttribute("BrainrotId", id)
	tool.CanBeDropped = false

	local parentModel = brainrotPart.Parent
	local isModelBrainrot = parentModel 
		and parentModel:IsA("Model") 
		and CollectionService:HasTag(parentModel, BrainrotConfig.BRAINROT_TAG_NAME)

	local handlePart: BasePart

	if isModelBrainrot then
		handlePart = parentModel:FindFirstChild("RootPart")
		if not handlePart then
			return nil
		end

		-- DO NOT TOUCH PHYSICS LOGIC (keep your current working logic)
		for _, part in ipairs(parentModel:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = false
				part.CanCollide = false
				part.Massless = true
			end
		end

		handlePart.Name = "Handle"
		CollectionService:RemoveTag(parentModel, BrainrotConfig.BRAINROT_TAG_NAME)
		parentModel.Parent = tool
		tool:SetAttribute("IsModelBrainrot", true)

	else
		handlePart = brainrotPart
		handlePart.Name = "Handle"
		handlePart.Anchored = false
		handlePart.CanCollide = false
		handlePart.Massless = true
		handlePart.Parent = tool
	end

	tool.Parent = backpack
	
	-- 🔥 GLOBAL EQUIP DETECTION (robust fix)
	local character = player.Character
	if character then

		character.ChildAdded:Connect(function(child)
			if child == tool then

				print("[BrainrotCarryService] Brainrot re-equipped detected via Character.ChildAdded")

				local handle = tool:FindFirstChild("Handle", true)
				if not handle or not handle:IsA("BasePart") then
					warn("[BrainrotCarryService] Re-equip failed: Handle missing")
					return
				end

				player:SetAttribute("IsBrainrotEquipped", true)

				self:_weldBrainrotToHands(player, tool, handle)
				self:_StartTwoHandHold(player, handle)

				if self.BlocksSpawnAreaService then
					self.BlocksSpawnAreaService:UpdatePlayerSpeed(player)
				end
			end
		end)

		character.ChildRemoved:Connect(function(child)
			if child == tool then
				print("[BrainrotCarryService] Brainrot unequipped detected via Character.ChildRemoved")

				player:SetAttribute("IsBrainrotEquipped", false)
				self:_StopTwoHandHold(player)
				self:_unweldBrainrotFromHands(tool)
			end
		end)

	end
	
	-- 🔥 HARD STOP if tool leaves character (player switches item)
	tool.AncestryChanged:Connect(function(_, parent)
		local character = player.Character
		if not character then return end

		-- If tool is no longer in character, stop hold
		if parent ~= character then
			if holdTrackByPlayer[player] then
				print("[BrainrotCarryService] Brainrot tool left character → stopping hold")
				self:_StopTwoHandHold(player)
			end
		end
	end)

	local character = player.Character
	if character then
		local hum = character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:EquipTool(tool)

			-- 🔥 FORCE EQUIPPED STATE IMMEDIATELY
			player:SetAttribute("IsBrainrotEquipped", true)

			-- 🔥 Sync ownership state immediately
			local ownerId = tool:GetAttribute("OwnedByUserId")
			player:SetAttribute("OwnsEquippedBrainrot", ownerId == player.UserId)

			task.wait(0.05)
			self:_weldBrainrotToHands(player, tool, handlePart)
			self:_StartTwoHandHold(player, handlePart)
		end
	end

	player:SetAttribute("IsCarryingBrainrot", true)

	tool.Unequipped:Connect(function()
		player:SetAttribute("IsBrainrotEquipped", false)

		-- DO NOT TOUCH OWNERSHIP HERE
		-- Ownership stays stored on the tool

		self:_StopTwoHandHold(player)
		self:_unweldBrainrotFromHands(tool)
	end)

	return tool
end

function BrainrotCarryService:_disablePickupPrompt(brainrotPart: BasePart)
	--// Function: _disablePickupPrompt
	--// Disables prompt and disconnects Triggered.

	print("[BrainrotCarryService] _disablePickupPrompt() called for:", brainrotPart:GetFullName())

	local prompt = brainrotPart:FindFirstChild(BrainrotConfig.PROMPT_NAME)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = false
		print("[BrainrotCarryService] Prompt disabled for:", brainrotPart:GetFullName())
	end

	if promptTriggeredConnections[brainrotPart] then
		promptTriggeredConnections[brainrotPart]:Disconnect()
		promptTriggeredConnections[brainrotPart] = nil
		print("[BrainrotCarryService] Triggered connection disconnected for:", brainrotPart:GetFullName())
	end
end

function BrainrotCarryService:_ensurePickupPrompt(brainrotPart: BasePart)

	if not brainrotPart:IsDescendantOf(workspace) then
		return
	end

	local brainrotId = ensureBrainrotId(brainrotPart)
	local prompt = brainrotPart:FindFirstChild(BrainrotConfig.PROMPT_NAME)

	if not prompt or not prompt:IsA("ProximityPrompt") then
		local newPrompt = Instance.new("ProximityPrompt")
		newPrompt.Name = BrainrotConfig.PROMPT_NAME
		newPrompt.ActionText = BrainrotConfig.PROMPT_ACTION_TEXT
		newPrompt.ObjectText = BrainrotConfig.PROMPT_OBJECT_TEXT
		newPrompt.KeyboardKeyCode = BrainrotConfig.PROMPT_KEYCODE
		newPrompt.MaxActivationDistance = BrainrotConfig.PROMPT_MAX_DISTANCE
		newPrompt.RequiresLineOfSight = BrainrotConfig.PROMPT_REQUIRES_LOS

		-- ✅ FIXED INTERACTION TIME
		newPrompt.HoldDuration = 0.2

		newPrompt.Parent = brainrotPart
		prompt = newPrompt
	else
		prompt.HoldDuration = 0.2 -- enforce
	end

	if brainrotPart:GetAttribute("IsCarried") == true then
		prompt.Enabled = false
		return
	end

	prompt.Enabled = true

	if promptTriggeredConnections[brainrotPart] then
		promptTriggeredConnections[brainrotPart]:Disconnect()
		promptTriggeredConnections[brainrotPart] = nil
	end

	promptTriggeredConnections[brainrotPart] = prompt.Triggered:Connect(function(player: Player)
		self:TryPickup(player, brainrotPart)
	end)
end

function BrainrotCarryService:_placeBrainrotAtWorldPosition(player: Player, brainrotPart: BasePart, worldPos: Vector3)
	--// Function: _placeBrainrotAtWorldPosition
	--// Drops brainrot at/near a specific world position, raycasting down to ground.

	print("[BrainrotCarryService] _placeBrainrotAtWorldPosition() called for:", player.Name, "pos:", worldPos)

	local rayOrigin = worldPos + Vector3.new(0, 5, 0)
	local rayDir = Vector3.new(0, -50, 0)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	--// Excluding player character and the brainrot part itself
	local excludeList = { brainrotPart }
	if player.Character then
		table.insert(excludeList, player.Character)
	end

	params.FilterDescendantsInstances = excludeList
	params.IgnoreWater = true

	local result = workspace:Raycast(rayOrigin, rayDir, params)

	if result then
		--// IF: hit ground
		local yOffset = (brainrotPart.Size.Y / 2) + 0.25
		local finalPos = result.Position + Vector3.new(0, yOffset, 0)
		brainrotPart.CFrame = CFrame.new(finalPos)
		print("[BrainrotCarryService] Dropped at ground hit:", finalPos)
	else
		--// ELSE: no ground hit
		brainrotPart.CFrame = CFrame.new(worldPos + Vector3.new(0, 2, 0))
		print("[BrainrotCarryService] No ground hit -> fallback drop at:", brainrotPart.Position)
	end
end

function BrainrotCarryService:_placeBrainrotInFrontOfPlayer(player: Player, brainrotPart: BasePart)
	--// Function: _placeBrainrotInFrontOfPlayer
	--// Default drop placement.

	local character = player.Character
	if not character then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return
	end

	local forwardPos = (hrp.CFrame * CFrame.new(0, 0, -4)).Position
	self:_placeBrainrotAtWorldPosition(player, brainrotPart, forwardPos)
end

function BrainrotCarryService:TryPickup(player: Player, brainrotPart: BasePart)
	--// Function: TryPickup
	--// Triggered by ProximityPrompt.
	--// [NEW] Checks BlocksSpawnAreaService permission.

	print("[BrainrotCarryService] TryPickup() called by:", player.Name)

	local modelPath = brainrotPart:GetAttribute("BrainrotModel")
	local brainrotInstance = brainrotPart

	if modelPath then
		local model = workspace:FindFirstChild(modelPath, true)
		if model and model:IsA("Model") then
			brainrotInstance = model
			print("[BrainrotCarryService] Using Model brainrot:", model:GetFullName())
		end
	end

	if brainrotPart:GetAttribute("IsCarried") == true then
		print("[BrainrotCarryService] TryPickup blocked -> already carried")
		return
	end

	--// [NEW] Check BlocksSpawnArea permission
	if self.BlocksSpawnAreaService then
		local canPickup = self.BlocksSpawnAreaService:CanPickupBrainrot(player)
		if not canPickup then
			print("[BrainrotCarryService] TryPickup BLOCKED -> not in BlocksSpawnArea:", player.Name)
			return
		end
	end

	--// [IMPORTANT] Limit inventory to MAX_BRAINROT_INVENTORY
	local currentCount = getBrainrotToolCount(player)

	--// [IF] inventory full -> block pickup
	if currentCount >= BrainrotConfig.MAX_BRAINROT_INVENTORY then
		print("[BrainrotCarryService] TryPickup blocked -> inventory full for:", player.Name, "count:", currentCount, "max:", BrainrotConfig.MAX_BRAINROT_INVENTORY)
		return
	end

	local tool = self:_convertBrainrotPartToTool(player, brainrotPart)
	--// [DEBUG] Print new count after pickup
	local newCount = getBrainrotToolCount(player)
	print("[BrainrotCarryService] ✅ Pickup count now:", player.Name, newCount, "/", BrainrotConfig.MAX_BRAINROT_INVENTORY)

	local ok = (tool ~= nil)
	if not ok then
		print("[BrainrotCarryService] TryPickup failed -> attach failed")
		return
	end

	self:_disablePickupPrompt(brainrotPart)

	player:SetAttribute("IsCarryingBrainrot", true)

	self.Client.CarryStateChanged:Fire(player, true, brainrotPart)
	
	-- 🔥 FORCE SPEED UPDATE AFTER PICKUP
	local blocksService = self.BlocksSpawnAreaService
	if blocksService then
		blocksService:UpdatePlayerSpeed(player)
	end

	print("[BrainrotCarryService] ✅ Pickup success:", player.Name)
end

function BrainrotCarryService:DropBrainrot(player: Player, reason: string?, _dropWorldPos: Vector3?)
	--// Function: DropBrainrot
	--// Drops the equipped brainrot Tool by extracting its Handle and placing it in front of the player.
	--// [NEW] Checks BlocksSpawnAreaService permission.

	local why = reason or "Unknown"
	print("[BrainrotCarryService] DropBrainrot() called for:", player.Name, "Reason:", why)

	--// [NEW] Check BlocksSpawnArea permission (unless forced by system)
	if self.BlocksSpawnAreaService and reason ~= "SlideCollisionDrop" and reason ~= "PunchHitDrop" then
		local canDrop = self.BlocksSpawnAreaService:CanDropBrainrot(player)
		if not canDrop then
			print("[BrainrotCarryService] DropBrainrot BLOCKED -> not in BlocksSpawnArea:", player.Name)
			return
		end
	end

	--// [IMPORTANT] Validate character
	local character = player.Character
	if not character then
		print("[BrainrotCarryService] DropBrainrot blocked -> no character:", player.Name)
		return
	end

	--// [IMPORTANT] Find equipped brainrot tool (in hands)
	local equippedTool: Tool? = nil
	for _, child in ipairs(character:GetChildren()) do
		--// Loop: character child
		if child:IsA("Tool") and child:GetAttribute("IsBrainrotTool") == true then
			equippedTool = child
			break
		end
	end

	--// [IF] no equipped tool found
	if not equippedTool then
		print("[BrainrotCarryService] DropBrainrot ignored -> no equipped brainrot tool:", player.Name)
		return
	end

	print("[BrainrotCarryService] Equipped brainrot tool found:", equippedTool.Name)

	--// [IMPORTANT] Get Handle
	local handle = equippedTool:FindFirstChild("Handle")

	if not handle then
		handle = equippedTool:FindFirstChild("Handle", true) -- recursive search
	end

	if not handle or not handle:IsA("BasePart") then
		warn("[BrainrotCarryService] Equipped brainrot tool missing Handle:", equippedTool.Name)
		return
	end

	--// [IMPORTANT] Unequip tools first so Roblox releases RightGrip safely
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		print("[BrainrotCarryService] UnequipTools() before drop for:", player.Name)
		hum:UnequipTools()
	end

	self:_unweldBrainrotFromHands(equippedTool)

	--// [IMPORTANT] Wait 1 tick so grips release (prevents "Parent locked" error)
	task.wait()

	--// [IMPORTANT] Stop two-hand pose
	if self._StopTwoHandHold then
		self:_StopTwoHandHold(player)
	end

	--// [IMPORTANT] Tool must not require handle once we extract it
	equippedTool.RequiresHandle = false

	--// [IMPORTANT] Put Handle back into world folder
	local folder = getOrCreateBrainrotFolder()
	print("[BrainrotCarryService] Moving Handle back to:", folder:GetFullName())

	-- Check if this was a Model brainrot
	local parentModel = handle.Parent
	local wasModel = equippedTool:GetAttribute("IsModelBrainrot") == true

	if wasModel then
		print("[BrainrotCarryService] Dropping Model brainrot:", parentModel.Name)

		-- Move entire model back to workspace folder
		local folder = getOrCreateBrainrotFolder()
		parentModel.Parent = folder

		-- RE-ANCHOR all parts when dropped (for stable placement)
		for _, part in ipairs(parentModel:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
				part.Massless = false
				print("[BrainrotCarryService] Re-anchored part:", part.Name)
			end
		end

		-- Restore RootPart name
		local originalName = handle:GetAttribute("OriginalName")
		if originalName then
			handle.Name = originalName
			handle:SetAttribute("OriginalName", nil)
		else
			handle.Name = "RootPart"  -- Default to RootPart
		end

		-- Reset attributes
		if parentModel:IsA("Model") then
			parentModel:SetAttribute("IsCarried", false)
			parentModel:SetAttribute("CarriedByUserId", nil)
		end

		handle:SetAttribute("IsCarried", false)
		handle:SetAttribute("CarriedByUserId", nil)

		-- Place model in front of player
		-- 🔥 Custom fixed Y drop + fixed Y rotation for MODEL brainrots

		local character = player.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				-- Position in front of player (keep X/Z)
				local forwardPos = (hrp.CFrame * CFrame.new(0, 0, -4)).Position

				-- Force Y to -7.4
				local fixedPos = Vector3.new(forwardPos.X, -7.4, forwardPos.Z)

				-- 🔥 Fixed Y rotation = -90 degrees
				local rotation = CFrame.Angles(0, math.rad(-90), 0)

				parentModel:PivotTo(CFrame.new(fixedPos) * rotation)
			end
		end

		-- Re-add tag to MODEL
		pcall(function()
			CollectionService:AddTag(parentModel, BrainrotConfig.BRAINROT_TAG_NAME)
		end)

		-- Add prompt to RootPart for pickup
		self:_ensurePickupPrompt(handle)

		print("[BrainrotCarryService] Model drop complete")


	else
		-- Single part brainrot (original logic)
		--// ✅ CRITICAL: parent first
		handle.Parent = folder
		--// [IMPORTANT] Reset carried markers so prompt is allowed again
		handle:SetAttribute("IsCarried", false)
		handle:SetAttribute("CarriedByUserId", nil)

		print("[BrainrotCarryService] Drop reset attributes -> IsCarried=false, CarriedByUserId=nil for:", handle:GetFullName())

		--// [IMPORTANT] Restore name (optional) so it's not always "Handle"
		local originalName = handle:GetAttribute("BrainrotWorldName")
		if typeof(originalName) == "string" and originalName ~= "" then
			handle.Name = originalName
			print("[BrainrotCarryService] Restored world name:", handle.Name)
		end

		--// [IMPORTANT] World physics: NO collision but MUST be anchored (otherwise falls through floor)
		handle.CanCollide = false
		handle.Massless = false
		handle.Anchored = true

		--// [IMPORTANT] Place IN FRONT of player
		self:_placeBrainrotInFrontOfPlayer(player, handle)

		--// [IMPORTANT] Re-add tag + prompt so it can be picked again
		pcall(function()
			CollectionService:AddTag(handle, BrainrotConfig.BRAINROT_TAG_NAME)
		end)

		self:_ensurePickupPrompt(handle)
	end

	print("[BrainrotCarryService] Drop reset attributes -> IsCarried=false, CarriedByUserId=nil for:", handle:GetFullName())

	print("[BrainrotCarryService] Handle parent is now:", handle.Parent and handle.Parent:GetFullName() or "nil")

	--// [IMPORTANT] Restore name (optional) so it's not always "Handle"
	local originalName = handle:GetAttribute("BrainrotWorldName")
	if typeof(originalName) == "string" and originalName ~= "" then
		handle.Name = originalName
		print("[BrainrotCarryService] Restored world name:", handle.Name)
	end

	--// [IMPORTANT] World physics: NO collision but MUST be anchored (otherwise falls through floor)
	handle.CanCollide = false
	handle.Massless = false
	handle.Anchored = true

	--// [IMPORTANT] Place IN FRONT of player
	self:_placeBrainrotInFrontOfPlayer(player, handle)

	--// [IMPORTANT] Re-add tag + prompt so it can be picked again
	pcall(function()
		CollectionService:AddTag(handle, BrainrotConfig.BRAINROT_TAG_NAME)
	end)

	self:_ensurePickupPrompt(handle)

	--// [IMPORTANT] Clear player flags
	player:SetAttribute("IsCarryingBrainrot", false)
	player:SetAttribute("IsBrainrotEquipped", false)

	--// [IMPORTANT] Update carrying flag based on remaining tools
	local remaining = getBrainrotToolCount(player)
	player:SetAttribute("IsCarryingBrainrot", remaining > 0)

	print("[BrainrotCarryService] Drop complete -> remaining brainrots:", player.Name, remaining)

	--// [DEBUG] Tell client carry stopped
	self.Client.CarryStateChanged:Fire(player, false, nil)

	-- 🔥 FORCE SPEED UPDATE AFTER DROP
	local blocksService = self.BlocksSpawnAreaService
	if blocksService then
		blocksService:UpdatePlayerSpeed(player)
	end

	--// [IMPORTANT] Destroy ONLY tool shell after handle is safe in workspace
	print("[BrainrotCarryService] Destroying tool shell AFTER drop:", equippedTool.Name)
	equippedTool:Destroy()

	print("[BrainrotCarryService] ✅ DropBrainrot complete for:", player.Name)
end


function BrainrotCarryService:DropBrainrotAtPosition(player: Player, worldPos: Vector3, reason: string?)
	--// Function: DropBrainrotAtPosition
	--// Server-only helper used by other services (like slide collision).

	print("[BrainrotCarryService] DropBrainrotAtPosition() called for:", player.Name, "pos:", worldPos)
	self:DropBrainrot(player, reason or "DropAtPosition", worldPos)
end

function BrainrotCarryService.Client:RequestDrop(player: Player, reason: string?)
	--// Function: Client.RequestDrop
	--// Client request drop (default key G). No custom position.
	--// [NEW] Checks BlocksSpawnArea permission.

	print("[BrainrotCarryService] Client.RequestDrop called by:", player.Name, "reason:", reason or "nil")

	--// [NEW] Check BlocksSpawnArea permission
	if self.Server.BlocksSpawnAreaService then
		local canDrop = self.Server.BlocksSpawnAreaService:CanDropBrainrot(player)
		if not canDrop then
			print("[BrainrotCarryService] Client.RequestDrop BLOCKED -> not in BlocksSpawnArea:", player.Name)
			return
		end
	end

	self.Server:DropBrainrot(player, reason or "ClientRequested", nil)
end

function BrainrotCarryService:_registerBrainrot(brainrotInst: Instance)
	--// Function: _registerBrainrot
	--// Ensures prompt exists on tagged brainrot (supports Model + BasePart)

	if not brainrotInst:IsDescendantOf(workspace) then
		print("[BrainrotCarryService] _registerBrainrot ignored (not in workspace):", brainrotInst:GetFullName())
		return
	end

	print("[BrainrotCarryService] _registerBrainrot() called for:", brainrotInst:GetFullName())

	local isValid, promptPart = isValidBrainrot(brainrotInst)
	if not isValid or not promptPart then
		return
	end

	-- Store reference to model if applicable
	if brainrotInst:IsA("Model") then
		promptPart:SetAttribute("BrainrotModel", brainrotInst:GetFullName())
	end

	self:_ensurePickupPrompt(promptPart)
end


function BrainrotCarryService:KnitInit()
	--// Function: KnitInit
	--// Setup folder + cleanup events.

	print("[BrainrotCarryService] KnitInit() start")

	getOrCreateBrainrotFolder()

	Players.PlayerRemoving:Connect(function(player: Player)
		--// Event: PlayerRemoving
		print("[BrainrotCarryService] PlayerRemoving -> forcing drop if carrying:", player.Name)
		self:DropBrainrot(player, "PlayerRemoving", nil)
	end)

	print("[BrainrotCarryService] KnitInit() complete")
end

function BrainrotCarryService:KnitStart()
	--// Function: KnitStart
	--// Register existing tagged brainrots + listen for new tags.
	--// [NEW] Get BlocksSpawnAreaService reference.

	print("[BrainrotCarryService] KnitStart() start")

	--// [NEW] Get BlocksSpawnAreaService
	local ok, serviceOrErr = pcall(function()
		return Knit.GetService("BlocksSpawnAreaService")
	end)

	if ok then
		self.BlocksSpawnAreaService = serviceOrErr
		print("[BrainrotCarryService] Got BlocksSpawnAreaService ✅")
	else
		warn("[BrainrotCarryService] BlocksSpawnAreaService not found:", serviceOrErr)
	end

	local tagged = CollectionService:GetTagged(BrainrotConfig.BRAINROT_TAG_NAME)
	print("[BrainrotCarryService] Tagged brainrots count:", #tagged)

	for _, inst in ipairs(tagged) do
		--// Loop: register
		self:_registerBrainrot(inst)
	end

	CollectionService:GetInstanceAddedSignal(BrainrotConfig.BRAINROT_TAG_NAME):Connect(function(inst: Instance)
		--// Event: new brainrot tagged
		print("[BrainrotCarryService] New brainrot tagged:", inst:GetFullName())
		self:_registerBrainrot(inst)
	end)

	print("[BrainrotCarryService] KnitStart() complete")
end

return BrainrotCarryService