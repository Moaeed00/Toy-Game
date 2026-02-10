--!strict
--// BrainrotCarryService.lua
--// Updates:
--// - Added DropBrainrotAtPosition() so other services (like slide collision) can force drop at a location.

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

local carriedByPlayer: { [Player]: BasePart } = {}
local promptTriggeredConnections: { [BasePart]: RBXScriptConnection } = {}

local originalAnchoredByBrainrot: { [BasePart]: boolean } = {}
local originalCanCollideByBrainrot: { [BasePart]: boolean } = {}
local originalMasslessByBrainrot: { [BasePart]: boolean } = {}

local holdTrackByPlayer: { [Player]: AnimationTrack } = {}

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


function BrainrotCarryService:_StartTwoHandHold(player: Player)
	--// Function: _StartTwoHandHold
	--// Plays a two-hand hold animation if provided; otherwise applies a simple fallback pose.

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

	--// [IMPORTANT] If animation id exists, play it
	local animId = BrainrotConfig.TWO_HAND_HOLD_ANIMATION_ID
	if typeof(animId) == "string" and animId ~= "" and animId ~= "rbxassetid://0" then
		print("[BrainrotCarryService] Playing two-hand hold animation:", animId)

		local animator = hum:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = hum
		end

		local anim = Instance.new("Animation")
		anim.AnimationId = animId

		local track = animator:LoadAnimation(anim)
		track.Looped = true
		track:Play()

		holdTrackByPlayer[player] = track
		anim:Destroy()
		return
	end

	--// [FALLBACK] Simple left-arm pose using Transform (works without animation asset)
	print("[BrainrotCarryService] No hold animation set -> using fallback left-arm pose")

	--// Try R15 joints (names are typical)
	local upperTorso = character:FindFirstChild("UpperTorso")
	if upperTorso then
		local leftShoulder = upperTorso:FindFirstChild("LeftShoulder")
		if leftShoulder and leftShoulder:IsA("Motor6D") then
			--// [IMPORTANT] Pull left arm forward
			leftShoulder.Transform = CFrame.Angles(math.rad(-35), math.rad(25), math.rad(10))
		end
	end

	--// R6 fallback (Torso -> "Left Shoulder")
	local torso = character:FindFirstChild("Torso")
	if torso then
		local leftShoulder = torso:FindFirstChild("Left Shoulder")
		if leftShoulder and leftShoulder:IsA("Motor6D") then
			leftShoulder.Transform = CFrame.Angles(math.rad(-35), 0, math.rad(15))
		end
	end
end

function BrainrotCarryService:_StopTwoHandHold(player: Player)
	--// Function: _StopTwoHandHold
	--// Stops hold animation or resets fallback transforms.

	print("[BrainrotCarryService] _StopTwoHandHold() for:", player.Name)

	--// Stop track if playing
	local track = holdTrackByPlayer[player]
	if track then
		print("[BrainrotCarryService] Stopping hold animation track for:", player.Name)
		pcall(function()
			track:Stop()
			track:Destroy()
		end)
		holdTrackByPlayer[player] = nil
	end

	--// Reset fallback Transform joints
	local character = player.Character
	if not character then return end

	local upperTorso = character:FindFirstChild("UpperTorso")
	if upperTorso then
		local leftShoulder = upperTorso:FindFirstChild("LeftShoulder")
		if leftShoulder and leftShoulder:IsA("Motor6D") then
			leftShoulder.Transform = CFrame.identity
		end
	end

	local torso = character:FindFirstChild("Torso")
	if torso then
		local leftShoulder = torso:FindFirstChild("Left Shoulder")
		if leftShoulder and leftShoulder:IsA("Motor6D") then
			leftShoulder.Transform = CFrame.identity
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

local function isValidBrainrotPart(inst: Instance): boolean
	--// Function: isValidBrainrotPart
	--// Validates BasePart.

	if not inst:IsA("BasePart") then
		print("[BrainrotCarryService] Invalid brainrot (not BasePart):", inst:GetFullName())
		return false
	end

	return true
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
	--// Function: _convertBrainrotPartToTool
	--// Moves the world brainrot part into a Tool (inventory item).

	print("[BrainrotCarryService] _convertBrainrotPartToTool() player:", player.Name, "part:", brainrotPart:GetFullName())

	--// [IF] backpack missing
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		warn("[BrainrotCarryService] Backpack missing for:", player.Name)
		return nil
	end

	--// [IMPORTANT] Ensure id
	local id = ensureBrainrotId(brainrotPart)

	--// [IMPORTANT] Create tool
	local tool = Instance.new("Tool")
	tool.Name = "Brainrot_" .. string.sub(id, 1, 6)
	tool.RequiresHandle = true

	--// [IMPORTANT] Tag tool so PvP services can detect “brainrot equipped”
	tool:SetAttribute("IsBrainrotTool", true)
	tool:SetAttribute("BrainrotId", id)
	--// [IMPORTANT] Mark carried state so old prompt logic doesn't block later
	brainrotPart:SetAttribute("IsCarried", true)
	brainrotPart:SetAttribute("CarriedByUserId", player.UserId)

	--// [IMPORTANT] Remove ProximityPrompt entirely while brainrot is in inventory/equipped
	local prompt = brainrotPart:FindFirstChild(BrainrotConfig.PROMPT_NAME)
	if prompt and prompt:IsA("ProximityPrompt") then
		print("[BrainrotCarryService] Destroying prompt (inventory tool) for:", brainrotPart:GetFullName())
		prompt:Destroy()
	end

	--// [IMPORTANT] Disconnect any stored Triggered connection for this part
	if promptTriggeredConnections[brainrotPart] then
		print("[BrainrotCarryService] Disconnecting prompt Triggered connection (inventory tool) for:", brainrotPart:GetFullName())
		promptTriggeredConnections[brainrotPart]:Disconnect()
		promptTriggeredConnections[brainrotPart] = nil
	end

	--// [IMPORTANT] Make it a valid tool Handle
	brainrotPart:SetAttribute("BrainrotWorldName", brainrotPart.Name)
	brainrotPart.Name = "Handle"
	brainrotPart.Anchored = false
	brainrotPart.Massless = true
	brainrotPart.CanCollide = false

	--// [IMPORTANT] Parent part into tool, then tool into backpack
	brainrotPart.Parent = tool
	tool.Parent = backpack
	--// [IMPORTANT] Auto-equip immediately after pickup (so it appears in hands)
	local character = player.Character
	if character then
		local hum = character:FindFirstChildOfClass("Humanoid")
		if hum then
			print("[BrainrotCarryService] Auto-equipping brainrot tool for:", player.Name)
			hum:EquipTool(tool)
		end
	end

	--// [IMPORTANT] Auto-equip immediately after pickup
	local character = player.Character
	if character then
		local hum = character:FindFirstChildOfClass("Humanoid")
		if hum then
			print("[BrainrotCarryService] Auto-equipping brainrot tool for:", player.Name)
			hum:EquipTool(tool)
		end
	end


	print("[BrainrotCarryService] ✅ Brainrot converted into Tool:", tool.Name, "for:", player.Name)

	--// [IMPORTANT] Maintain “has brainrot in inventory” flag
	player:SetAttribute("IsCarryingBrainrot", true)

	--// [EVENT] Equipped/Unequipped debug + attribute
	tool.Equipped:Connect(function()
		--// Event: Equipped
		print("[BrainrotCarryService] Brainrot EQUIPPED:", player.Name, tool.Name)

		player:SetAttribute("IsBrainrotEquipped", true)

		--// [IMPORTANT] Start two-hand hold pose
		self:_StartTwoHandHold(player)
	end)

	tool.Unequipped:Connect(function()
		--// Event: Unequipped
		print("[BrainrotCarryService] Brainrot UNEQUIPPED:", player.Name, tool.Name)

		player:SetAttribute("IsBrainrotEquipped", false)

		--// [IMPORTANT] Stop two-hand hold pose
		self:_StopTwoHandHold(player)
	end)

	return tool
end

function BrainrotCarryService:_applyTwoHandVisual(player: Player, tool: Tool, handle: BasePart)
	--// Function: _applyTwoHandVisual
	--// Creates a LEFT-hand visual clone so brainrot appears in both hands (visual only).

	print("[BrainrotCarryService] _applyTwoHandVisual() for:", player.Name, "tool:", tool.Name)

	local character = player.Character
	--// [IF] no character
	if not character then
		print("[BrainrotCarryService] _applyTwoHandVisual() FAIL -> no character")
		return
	end

	--// [IMPORTANT] Find left hand part (R15: LeftHand, R6: Left Arm)
	local leftHand: BasePart? = character:FindFirstChild("LeftHand") :: BasePart?
	if not leftHand or not leftHand:IsA("BasePart") then
		leftHand = character:FindFirstChild("Left Arm") :: BasePart?
	end

	--// [IF] missing left hand
	if not leftHand or not leftHand:IsA("BasePart") then
		print("[BrainrotCarryService] _applyTwoHandVisual() FAIL -> left hand not found")
		return
	end

	--// [IMPORTANT] Cleanup old visual if exists
	local old = character:FindFirstChild("BrainrotLeftVisual")
	if old then
		old:Destroy()
	end

	--// [IMPORTANT] Clone handle (VISUAL ONLY)
	local leftVisual = handle:Clone()
	leftVisual.Name = "BrainrotLeftVisual"

	--// [IMPORTANT] Safety: no collision
	leftVisual.CanCollide = false
	leftVisual.Massless = true
	leftVisual.Anchored = false

	--// [IMPORTANT] Remove proximity prompt from visual if it exists
	local prompt = leftVisual:FindFirstChild(BrainrotConfig.PROMPT_NAME)
	if prompt then
		prompt:Destroy()
	end

	--// [IMPORTANT] Remove CollectionService tag (avoid prompt systems)
	pcall(function()
		CollectionService:RemoveTag(leftVisual, BrainrotConfig.BRAINROT_TAG_NAME)
	end)

	--// [IMPORTANT] Position near left hand (tweak offsets if needed)
	leftVisual.CFrame = leftHand.CFrame * CFrame.new(0, 0, -0.6)

	--// [IMPORTANT] Weld visual to left hand
	local weld = Instance.new("WeldConstraint")
	weld.Name = "BrainrotLeftVisualWeld"
	weld.Part0 = leftHand
	weld.Part1 = leftVisual
	weld.Parent = leftVisual

	leftVisual.Parent = character

	print("[BrainrotCarryService] ✅ Left-hand visual created for:", player.Name)
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

	--// [IF] don't create prompts in inventory/tools
	if not brainrotPart:IsDescendantOf(workspace) then
		print("[BrainrotCarryService] _ensurePickupPrompt ignored (not in workspace):", brainrotPart:GetFullName())
		return
	end

	--// Function: _ensurePickupPrompt
	--// Ensures prompt exists and connects Triggered.

	print("[BrainrotCarryService] _ensurePickupPrompt() for:", brainrotPart:GetFullName())

	local brainrotId = ensureBrainrotId(brainrotPart)
	local prompt = brainrotPart:FindFirstChild(BrainrotConfig.PROMPT_NAME)

	if not prompt or not prompt:IsA("ProximityPrompt") then
		print("[BrainrotCarryService] Creating ProximityPrompt for BrainrotId:", brainrotId)

		local newPrompt = Instance.new("ProximityPrompt")
		newPrompt.Name = BrainrotConfig.PROMPT_NAME
		newPrompt.ActionText = BrainrotConfig.PROMPT_ACTION_TEXT
		newPrompt.ObjectText = BrainrotConfig.PROMPT_OBJECT_TEXT
		newPrompt.KeyboardKeyCode = BrainrotConfig.PROMPT_KEYCODE
		newPrompt.MaxActivationDistance = BrainrotConfig.PROMPT_MAX_DISTANCE
		newPrompt.RequiresLineOfSight = BrainrotConfig.PROMPT_REQUIRES_LOS
		newPrompt.HoldDuration = BrainrotConfig.PROMPT_HOLD_DURATION
		newPrompt.Parent = brainrotPart

		prompt = newPrompt
	else
		print("[BrainrotCarryService] Updating existing prompt for BrainrotId:", brainrotId)

		prompt.ActionText = BrainrotConfig.PROMPT_ACTION_TEXT
		prompt.ObjectText = BrainrotConfig.PROMPT_OBJECT_TEXT
		prompt.KeyboardKeyCode = BrainrotConfig.PROMPT_KEYCODE
		prompt.MaxActivationDistance = BrainrotConfig.PROMPT_MAX_DISTANCE
		prompt.RequiresLineOfSight = BrainrotConfig.PROMPT_REQUIRES_LOS
		prompt.HoldDuration = BrainrotConfig.PROMPT_HOLD_DURATION
	end

	--// IF: carried -> keep disabled
	if brainrotPart:GetAttribute("IsCarried") == true then
		prompt.Enabled = false
		print("[BrainrotCarryService] Brainrot carried -> prompt disabled:", brainrotId)
		return
	end

	prompt.Enabled = true

	--// Disconnect old connection if any
	if promptTriggeredConnections[brainrotPart] then
		promptTriggeredConnections[brainrotPart]:Disconnect()
		promptTriggeredConnections[brainrotPart] = nil
		print("[BrainrotCarryService] Old Triggered connection disconnected for BrainrotId:", brainrotId)
	end

	--// Connect Triggered
	print("[BrainrotCarryService] Connecting prompt Triggered for BrainrotId:", brainrotId)

	promptTriggeredConnections[brainrotPart] = prompt.Triggered:Connect(function(player: Player)
		--// Event: prompt triggered
		print("[BrainrotCarryService] Prompt triggered by:", player.Name, "BrainrotId:", brainrotId)
		self:TryPickup(player, brainrotPart)
	end)
end

function BrainrotCarryService:_attachBrainrotToCharacter(player: Player, brainrotPart: BasePart): boolean
	--// Function: _attachBrainrotToCharacter
	--// Welds brainrot to HRP.

	print("[BrainrotCarryService] _attachBrainrotToCharacter() called for:", player.Name)

	local character = player.Character
	if not character then
		print("[BrainrotCarryService] FAIL -> no character:", player.Name)
		return false
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		print("[BrainrotCarryService] FAIL -> no HRP:", player.Name)
		return false
	end

	--// Store original physics once
	if originalAnchoredByBrainrot[brainrotPart] == nil then
		originalAnchoredByBrainrot[brainrotPart] = brainrotPart.Anchored
		originalCanCollideByBrainrot[brainrotPart] = brainrotPart.CanCollide
		originalMasslessByBrainrot[brainrotPart] = brainrotPart.Massless
		print("[BrainrotCarryService] Stored original physics for:", brainrotPart:GetFullName())
	end

	brainrotPart:SetAttribute("IsCarried", true)
	brainrotPart:SetAttribute("CarriedByUserId", player.UserId)

	brainrotPart.Anchored = false
	brainrotPart.CanCollide = false
	brainrotPart.Massless = true

	brainrotPart.Parent = character
	brainrotPart.CFrame = hrp.CFrame * BrainrotConfig.CARRY_OFFSET_CFRAME

	local oldWeld = brainrotPart:FindFirstChild("BrainrotCarryWeld")
	if oldWeld then
		oldWeld:Destroy()
		print("[BrainrotCarryService] Old weld destroyed:", brainrotPart:GetFullName())
	end

	local weld = Instance.new("WeldConstraint")
	weld.Name = "BrainrotCarryWeld"
	weld.Part0 = hrp
	weld.Part1 = brainrotPart
	weld.Parent = brainrotPart

	print("[BrainrotCarryService] ✅ Weld created for:", player.Name)
	return true
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

	print("[BrainrotCarryService] TryPickup() called by:", player.Name)

	if not isValidBrainrotPart(brainrotPart) then
		return
	end

	if brainrotPart:GetAttribute("IsCarried") == true then
		print("[BrainrotCarryService] TryPickup blocked -> already carried")
		return
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

	print("[BrainrotCarryService] ✅ Pickup success:", player.Name)
end

function BrainrotCarryService:DropBrainrot(player: Player, reason: string?, _dropWorldPos: Vector3?)
	--// Function: DropBrainrot
	--// Drops the equipped brainrot Tool by extracting its Handle and placing it in front of the player.
	--// IMPORTANT: Handle will be ANCHORED in world because it has NO collisions (otherwise it falls through floor).

	local why = reason or "Unknown"
	print("[BrainrotCarryService] DropBrainrot() called for:", player.Name, "Reason:", why)

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

	--// [IMPORTANT] Wait 1 tick so grips release (prevents "Parent locked" error)
	task.wait()

	--// [IMPORTANT] Stop two-hand pose (if you add it below)
	if self._StopTwoHandHold then
		self:_StopTwoHandHold(player)
	end

	--// [IMPORTANT] Tool must not require handle once we extract it
	equippedTool.RequiresHandle = false

	--// [IMPORTANT] Put Handle back into world folder
	local folder = getOrCreateBrainrotFolder()
	print("[BrainrotCarryService] Moving Handle back to:", folder:GetFullName())

	--// ✅ CRITICAL: parent first
	handle.Parent = folder
	--// [IMPORTANT] Reset carried markers so prompt is allowed again
	handle:SetAttribute("IsCarried", false)
	handle:SetAttribute("CarriedByUserId", nil)

	print("[BrainrotCarryService] Drop reset attributes -> IsCarried=false, CarriedByUserId=nil for:", handle:GetFullName())

	print("[BrainrotCarryService] Handle parent is now:", handle.Parent and handle.Parent:GetFullName() or "nil")

	--// [IMPORTANT] Restore name (optional) so it’s not always "Handle"
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

	print("[BrainrotCarryService] Client.RequestDrop called by:", player.Name, "reason:", reason or "nil")
	self.Server:DropBrainrot(player, reason or "ClientRequested", nil)
end

function BrainrotCarryService:_registerBrainrot(brainrotInst: Instance)
	--// Function: _registerBrainrot
	--// Ensures prompt exists on tagged brainrot.

	--// [IF] ignore non-workspace brainrots (inventory/tools)
	if not brainrotInst:IsDescendantOf(workspace) then
		print("[BrainrotCarryService] _registerBrainrot ignored (not in workspace):", brainrotInst:GetFullName())
		return
	end


	print("[BrainrotCarryService] _registerBrainrot() called for:", brainrotInst:GetFullName())

	if not isValidBrainrotPart(brainrotInst) then
		return
	end

	self:_ensurePickupPrompt(brainrotInst :: BasePart)
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
		--// Cleanup debug hitbox on leaving
		self:_cleanupSlideDebugPart(player)
	end)
	

	print("[BrainrotCarryService] KnitInit() complete")
end

function BrainrotCarryService:KnitStart()
	--// Function: KnitStart
	--// Register existing tagged brainrots + listen for new tags.

	print("[BrainrotCarryService] KnitStart() start")

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
