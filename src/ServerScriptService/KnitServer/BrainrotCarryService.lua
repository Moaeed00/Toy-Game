local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundPlay = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utils"):WaitForChild("PlaySound"))
local CollectionService = game:GetService("CollectionService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local BrainrotConfig = require(
	ReplicatedStorage.Configuration.BrainrotConfig
)

local holdAnimTracks: {[Player]: AnimationTrack} = {}
local promptConnections: {[Model]: RBXScriptConnection} = {}

local BrainrotCarryService = Knit.CreateService({
	Name = "BrainrotCarryService",

	Client = {
		CarryStateChanged = Knit.CreateSignal(),
		RequestDropEvent = Knit.CreateSignal(),
		RequestDrop = function() end,
	}
})

--------------------------------------------------
-- Helpers
--------------------------------------------------

local function getCarriedBrainrot(player: Player): Model?
	local char = player.Character
	if not char then return nil end

	for _,obj in ipairs(char:GetChildren()) do
		if obj:IsA("Model") and obj:GetAttribute("IsCarried") then
			return obj
		end
	end

	return nil
end

function BrainrotCarryService:_playHoldAnimation(player: Player)

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local anim = ReplicatedStorage
		:WaitForChild("Assets")
		:WaitForChild("Animations")
		:WaitForChild("HoldBrainrot")

	local animator = humanoid:FindFirstChildOfClass("Animator")

	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local track = animator:LoadAnimation(anim)
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

--------------------------------------------------
-- PICKUP
--------------------------------------------------

function BrainrotCarryService:TryPickup(player: Player, brainrot: Model)

	if not brainrot then return end

	--------------------------------------------------
	-- AREA CHECK
	--------------------------------------------------

	if self.BlocksSpawnAreaService then
		if not self.BlocksSpawnAreaService:CanPickupBrainrot(player) then
			return
		end
	end

	--------------------------------------------------
	-- ALREADY CARRYING
	--------------------------------------------------

	if player:GetAttribute("IsCarryingBrainrot") then
		return
	end

	-- HARD SAFETY: ensure no carried brainrot already attached
	if getCarriedBrainrot(player) then
		return
	end

	--------------------------------------------------
	-- LOCK MODEL
	--------------------------------------------------

	if brainrot:GetAttribute("IsCarried") then
		return
	end

	brainrot:SetAttribute("IsCarried", true)

	--------------------------------------------------
	-- UNEQUIP TOOLS
	--------------------------------------------------

	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:UnequipTools()
		end
	end

	--------------------------------------------------
	-- ATTACH MODEL
	--------------------------------------------------

	local root = brainrot:FindFirstChild("RootPart")

	local attachment = root:FindFirstChild("PromptAttachment")

	if attachment then
		local prompt = attachment:FindFirstChild("PickupPrompt")
		if prompt then
			prompt.Enabled = false
		end
	end

	if not root then return end

	brainrot.Parent = player.Character
	self:TrackCarriedBrainrot(player, brainrot)

	root.CFrame =
		player.Character.HumanoidRootPart.CFrame
		* BrainrotConfig.CARRY_CENTER_OFFSET
		* BrainrotConfig.CARRY_ROTATION_OFFSET

	local weld = Instance.new("WeldConstraint")
	weld.Name = "BrainrotCarryWeld"
	weld.Part0 = player.Character.HumanoidRootPart
	weld.Part1 = root
	weld.Parent = root

	for _,part in ipairs(brainrot:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
		end
	end

	self.GameAnalyticsService:TrackFunnelStep(player, "brainrot_picked")

	--------------------------------------------------
	-- SET PLAYER STATE
	--------------------------------------------------

	player:SetAttribute("IsCarryingBrainrot", true)
	self:_playHoldAnimation(player)

	self.Client.CarryStateChanged:Fire(player, true, root)

	if self.BlocksSpawnAreaService then
		self.BlocksSpawnAreaService:UpdatePlayerSpeed(player)
	end
end

--------------------------------------------------
-- DROP
--------------------------------------------------

function BrainrotCarryService:DropBrainrot(player: Player)

	self:_stopHoldAnimation(player)

	local brainrot = getCarriedBrainrot(player)
	if not brainrot then return end

	if self.BlocksSpawnAreaService then
		if not self.BlocksSpawnAreaService:CanDropBrainrot(player) then
			return
		end
	end

	local root = brainrot:FindFirstChild("RootPart")
	if not root then return end

	--------------------------------------------------
	-- REMOVE WELD
	--------------------------------------------------

	for _,obj in ipairs(brainrot:GetDescendants()) do
		if obj.Name == "BrainrotCarryWeld" then
			obj:Destroy()
		end
	end

	--------------------------------------------------
	-- MOVE TO WORLD
	--------------------------------------------------

	local folder =
		workspace:FindFirstChild(
			BrainrotConfig.WORKSPACE_BRAINROT_FOLDER_NAME
		)

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = BrainrotConfig.WORKSPACE_BRAINROT_FOLDER_NAME
		folder.Parent = workspace
	end

	brainrot.Parent = folder

	local hrp = player.Character.HumanoidRootPart

	local forwardPos = (hrp.CFrame * CFrame.new(0,0,-4)).Position

	local fixedPos = Vector3.new(
		forwardPos.X,
		-6.5,
		forwardPos.Z
	)

	brainrot:PivotTo(
		CFrame.new(fixedPos) * CFrame.Angles(0, math.rad(180), 0)
	)

	--------------------------------------------------
	-- RESET MODEL STATE & PHYSICS
	--------------------------------------------------

	for _,part in ipairs(brainrot:GetDescendants()) do
		if part:IsA("BasePart") then
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
	end

	--------------------------------------------------
	-- REBUILD MODEL WELDS
	--------------------------------------------------

	for _,obj in ipairs(root:GetChildren()) do
		if obj:IsA("WeldConstraint") then
			obj:Destroy()
		end
	end

	for _,part in ipairs(brainrot:GetDescendants()) do
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

	--------------------------------------------------
	-- ANCHOR ROOT
	--------------------------------------------------

	root.Anchored = true
	root.CanCollide = false
	root.Massless = false

	brainrot:SetAttribute("IsCarried", false)

	local promptAttach = root:FindFirstChild("PromptAttachment")
	local prompt = promptAttach and promptAttach:FindFirstChild("PickupPrompt")
	if prompt then
		prompt.Enabled = true
	end

	CollectionService:AddTag(
		brainrot,
		BrainrotConfig.BRAINROT_TAG_NAME
	)

	self:_setupPrompt(brainrot)

	--------------------------------------------------
	-- PLAYER STATE
	--------------------------------------------------

	player:SetAttribute("IsCarryingBrainrot", false)

	self.Client.CarryStateChanged:Fire(player, false, nil)

	if self.BlocksSpawnAreaService then
		self.BlocksSpawnAreaService:UpdatePlayerSpeed(player)
	end
end

--------------------------------------------------
-- CONVERT TO TOOL
--------------------------------------------------

function BrainrotCarryService:ConvertToTool(player: Player)

	self:_stopHoldAnimation(player)

	local brainrot = getCarriedBrainrot(player)
	if not brainrot then return end

	local entity = brainrot.Name
	local mutation = brainrot:GetAttribute("Variant")
	local biome = brainrot:GetAttribute("RarityType")

	self.BaseService:GiveTool(
		player,
		biome,
		entity,
		mutation
	)

	brainrot:Destroy()

	player:SetAttribute("IsCarryingBrainrot", false)

	if self.BlocksSpawnAreaService then
		self.BlocksSpawnAreaService:UpdatePlayerSpeed(player)
	end

	-- 🔊 Play reward sound using SoundModule system
	SoundPlay:Play("RewardSound", "Touch", -- or "Touch" depending on your setup
		1, -- pitch
		1  -- volume
	)

end

--------------------------------------------------
-- TRACK BRAINROT DESTROY TIME in BLOCKSPAWNAREA
--------------------------------------------------

function BrainrotCarryService:TrackCarriedBrainrot(player: Player, brainrot: Model)

	if not brainrot then return end

	--------------------------------------------------
	-- detect external destroy
	--------------------------------------------------

	brainrot.Destroying:Connect(function()

		-- if player still thinks they carry it
		if player:GetAttribute("IsCarryingBrainrot") then

			self:_stopHoldAnimation(player)

			player:SetAttribute("IsCarryingBrainrot", false)

			self.Client.CarryStateChanged:Fire(player,false,nil)

			-- notify BlocksSpawnAreaService to reset systems
			if self.BlocksSpawnAreaService then
				self.BlocksSpawnAreaService:_brainrotDestroyed(player)
			end

		end

	end)

end

--------------------------------------------------
-- CLIENT DROP REQUEST
--------------------------------------------------

function BrainrotCarryService.Client:RequestDrop(player: Player)
	self.Server:DropBrainrot(player)
end

function BrainrotCarryService:RequestDrop(player: Player)
	self.Client:RequestDrop(player)
end

--------------------------------------------------
-- PROMPT SETUP
--------------------------------------------------

function BrainrotCarryService:_setupPrompt(model: Model)

	if not model:IsDescendantOf(workspace) then return end
	if not model:IsA("Model") then return end

	local root = model:FindFirstChild("RootPart")
	if not root then return end

	--------------------------------------------------
	-- Create / find attachment above model
	--------------------------------------------------

	local attachment = root:FindFirstChild("PromptAttachment")

	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "PromptAttachment"
		attachment.Parent = root

		-- lift prompt above the brainrot
		attachment.Position = Vector3.new(0, 3, 0)
	end

	--------------------------------------------------
	-- Create / find prompt
	--------------------------------------------------

	local prompt = root:FindFirstChild("PromptAttachment") and root.PromptAttachment:FindFirstChild("PickupPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PickupPrompt"
		prompt.Parent = attachment
	end

	--------------------------------------------------
	-- Prompt settings
	--------------------------------------------------

	prompt.ActionText = "Pick Up"
	prompt.ObjectText = model.Name

	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.2

	prompt.MaxActivationDistance = 12

	-- IMPORTANT FIX
	prompt.RequiresLineOfSight = false

	prompt.Enabled = false

	--------------------------------------------------
	-- Trigger
	--------------------------------------------------
	if promptConnections[model] then
		promptConnections[model]:Disconnect()
		promptConnections[model] = nil
	end

	promptConnections[model] = prompt.Triggered:Connect(function(player)
		self:TryPickup(player, model)
	end)

	local mesh = model:FindFirstChildOfClass("MeshPart")

	if mesh then

		-- wait until spawn animation reveals the brainrot
		task.spawn(function()

			while mesh and mesh.Parent and mesh.Transparency > 0 do
				task.wait(0.05)
			end

			if not model or not model.Parent then
				return
			end

			if model:GetAttribute("IsCarried") then
				return
			end
			prompt.Enabled = true

		end)

	else
		-- fallback safety
		task.delay(0.6, function()

			if not model or not model.Parent then
				return
			end
			if model:GetAttribute("IsCarried") then
				return
			end

			prompt.Enabled = true

		end)
	end

	model.Destroying:Connect(function()
		if promptConnections[model] then
			promptConnections[model]:Disconnect()
			promptConnections[model] = nil
		end
	end)
end

--------------------------------------------------
-- INIT
--------------------------------------------------

function BrainrotCarryService:KnitStart()
	BrainrotCarryService.BaseService = Knit.GetService("BaseService")
	BrainrotCarryService.BlocksSpawnAreaService = Knit.GetService("BlocksSpawnAreaService")
	BrainrotCarryService.GameAnalyticsService = Knit.GetService("GameAnalyticsService")

	BrainrotCarryService.Client.RequestDropEvent:Connect(function(player: Player)
		self:RequestDrop(player)
	end)

	for _,model in ipairs(CollectionService:GetTagged(BrainrotConfig.BRAINROT_TAG_NAME)) do
		self:_setupPrompt(model)
	end

	CollectionService:GetInstanceAddedSignal(BrainrotConfig.BRAINROT_TAG_NAME):Connect(function(model)
		self:_setupPrompt(model)
	end)
end

return BrainrotCarryService