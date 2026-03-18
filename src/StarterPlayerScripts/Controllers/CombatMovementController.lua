--!strict
--// File: StarterPlayerScripts/KnitClient/Controllers/CombatMovementController.lua
--// CombatMovementController.lua
--// FIXED: Animation plays on first use

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService: ContextActionService = game:GetService("ContextActionService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage:WaitForChild("Configuration"):WaitForChild("CombatMovementConfig"))

print("[CombatMovementController] Loading slide animation...")
local slideAnimation: Animation? = nil
local slideAnimationTrack: AnimationTrack? = nil

local success, result = pcall(function()
	return ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Animations"):WaitForChild("Slide")
end)

if success and result and result:IsA("Animation") then
	slideAnimation = result
	print("[CombatMovementController] ✅ Slide animation loaded! ID:", slideAnimation.AnimationId)
else
	warn("[CombatMovementController] ❌ Failed to load Slide animation:", result)
end

local CombatMovementController = Knit.CreateController({
	Name = "CombatMovementController",
})

local toolConnections: { [Instance]: { RBXScriptConnection } } = {}

local function dprint(...: any)
	if Config.DEBUG_PRINTS then
		print("[CombatMovementController]", ...)
	end
end

--// [FIXED] Pre-load animation track on character spawn
local function preloadAnimationTrack()
	local player = Players.LocalPlayer
	if not player then return end

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or not slideAnimation then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	-- Pre-load track but don't play
	if slideAnimationTrack then
		slideAnimationTrack:Destroy()
	end

	slideAnimationTrack = animator:LoadAnimation(slideAnimation)
	slideAnimationTrack.Priority = Enum.AnimationPriority.Action4
	slideAnimationTrack.Looped = true

	print("[CombatMovementController] ✅ Animation track pre-loaded")
end

--// [FIXED] Play slide animation
local function playSlideAnimation(duration: number)
	print("[CombatMovementController] ▶ playSlideAnimation() called | duration:", duration)

	local player = Players.LocalPlayer
	if not player or not player.Character then
		warn("[CombatMovementController] No player or character")
		return
	end

	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or not slideAnimation then
		warn("[CombatMovementController] No humanoid or animation")
		return
	end

	-- Use pre-loaded track or create new one
	if not slideAnimationTrack or not slideAnimationTrack.IsPlaying then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end

		if slideAnimationTrack then
			slideAnimationTrack:Destroy()
		end

		slideAnimationTrack = animator:LoadAnimation(slideAnimation)
		slideAnimationTrack.Priority = Enum.AnimationPriority.Action4
		slideAnimationTrack.Looped = true
	end

	-- Play immediately
	slideAnimationTrack:Play(0, 1, 1)
	slideAnimationTrack:AdjustWeight(1, 0)

	print("[CombatMovementController] ✅ Animation playing")

	-- Stop after duration
	task.delay(duration, function()
		if slideAnimationTrack and slideAnimationTrack.IsPlaying then
			slideAnimationTrack:Stop(0.1)
			print("[CombatMovementController] ⏹ Animation stopped")
		end
	end)
end

local function disconnectTool(tool: Instance)
	local conns = toolConnections[tool]
	if not conns then
		return
	end

	for _, c in ipairs(conns) do
		c:Disconnect()
	end

	toolConnections[tool] = nil
end

function CombatMovementController:_hookTool(tool: Tool)
	if toolConnections[tool] then
		return
	end

	if tool.Name ~= Config.SLIDE_TOOL_NAME
		and tool.Name ~= Config.GOLDEN_SLIDE_TOOL_NAME then
		return
	end

	dprint("Hooking tool:", tool.Name)

	local conns: { RBXScriptConnection } = {}
	toolConnections[tool] = conns

	table.insert(conns, tool.Activated:Connect(function()
		dprint("Tool Activated:", tool.Name)

		if tool.Name == Config.SLIDE_TOOL_NAME or tool.Name == Config.GOLDEN_SLIDE_TOOL_NAME then
			dprint("RequestSlide() -> server")
			self.CombatMovementService:RequestSlide()
			return
		end
	end))

	table.insert(conns, tool.Destroying:Connect(function()
		dprint("Tool destroying -> cleanup:", tool.Name)
		disconnectTool(tool)
	end))
end

function CombatMovementController:_scanForTools()
	local player = Players.LocalPlayer
	if not player then
		return
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") then
				self:_hookTool(child)
			end
		end
	end

	local character = player.Character
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") then
				self:_hookTool(child)
			end
		end
	end
end

function CombatMovementController:_bindKeyInputs()
	dprint("_bindKeyInputs() binding legacy keys")

	ContextActionService:BindAction(
		"LegacySlide_CTRL",
		function(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
			if inputState == Enum.UserInputState.Begin then
				dprint("CTRL pressed -> RequestSlide()")
				self.CombatMovementService:RequestSlide()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.KeyCode.LeftControl,
		Enum.KeyCode.RightControl
	)
end

function CombatMovementController:KnitInit()
	dprint("KnitInit() start")

	self.CombatMovementService = Knit.GetService("CombatMovementService")
	dprint("Got CombatMovementService:", self.CombatMovementService)

	--// [FIXED] Listen for slide animation signal with duration
	self.CombatMovementService.PlaySlideAnimation:Connect(function(duration: number)
		print("[CombatMovementController] 🎬 SIGNAL RECEIVED | duration:", duration)
		playSlideAnimation(duration)
	end)
	print("[CombatMovementController] ✅ PlaySlideAnimation listener connected")

	self.CombatMovementService.ActionResult:Connect(function(actionName: string, success: boolean, reason: string)
		dprint("ActionResult ->", actionName, "success:", success, "reason:", reason)
	end)

	dprint("KnitInit() complete")
end

function CombatMovementController:KnitStart()
	dprint("KnitStart() start | INPUT_MODE =", Config.INPUT_MODE)

	if Config.INPUT_MODE == "Tool" then
		local player = Players.LocalPlayer
		if not player then
			dprint("No LocalPlayer in Tool mode")
			return
		end

		player.CharacterAdded:Connect(function(char: Model)
			dprint("CharacterAdded -> scan tools:", char.Name)

			-- Pre-load animation on spawn
			task.wait(0.5)
			preloadAnimationTrack()

			task.defer(function()
				self:_scanForTools()
			end)

			char.ChildAdded:Connect(function(child: Instance)
				if child:IsA("Tool") then
					dprint("Character tool added:", child.Name)
					self:_hookTool(child)
				end
			end)
		end)

		-- Pre-load for existing character
		if player.Character then
			task.wait(0.5)
			preloadAnimationTrack()
		end

		local backpack = player:WaitForChild("Backpack")
		backpack.ChildAdded:Connect(function(child: Instance)
			if child:IsA("Tool") then
				dprint("Backpack tool added:", child.Name)
				self:_hookTool(child)
			end
		end)

		self:_scanForTools()
	else
		self:_bindKeyInputs()
	end

	dprint("KnitStart() complete")
end

return CombatMovementController