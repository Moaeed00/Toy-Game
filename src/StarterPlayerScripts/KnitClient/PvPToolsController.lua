--!strict
--// File: StarterPlayerScripts/KnitClient/Controllers/PvPToolsController.lua
--// UPDATED:
--// - Uses Humanoid Punch Animation
--// - Removes fake grip tween swing
--// - Clean Knit signal usage

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local Config = require(
	ReplicatedStorage
		:WaitForChild("Configuration")
		:WaitForChild("PvPToolsConfig")
)

local PvPToolsController = Knit.CreateController({
	Name = "PvPToolsController",
})

--=====================================================
-- DEBUG
--=====================================================

local function dprint(...)
	if Config.DEBUG_PRINTS then
		print("[PvPToolsController]", ...)
	end
end

--=====================================================
-- ANIMATION LOADING
--=====================================================

local punchAnimation: Animation? = nil
local punchTrack: AnimationTrack? = nil

-- Load animation safely
do
	local success, result = pcall(function()
		return ReplicatedStorage
			:WaitForChild("Assets")
			:WaitForChild("Animations")
			:WaitForChild("PunchAnim")
	end)

	if success and result and result:IsA("Animation") then
		punchAnimation = result
		print("[PvPToolsController] ✅ Punch animation loaded | ID:", punchAnimation.AnimationId)
	else
		warn("[PvPToolsController] ❌ Failed to load PunchAnim")
	end
end

--=====================================================
-- PRELOAD TRACK ON SPAWN
--=====================================================

local function preloadPunchTrack()

	local player = Players.LocalPlayer
	if not player then return end

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	if not punchAnimation then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	if punchTrack then
		punchTrack:Destroy()
	end

	punchTrack = animator:LoadAnimation(punchAnimation)
	punchTrack.Priority = Enum.AnimationPriority.Action4
	punchTrack.Looped = false

	print("[PvPToolsController] ✅ Punch animation preloaded")
end

--=====================================================
-- PLAY PUNCH ANIMATION
--=====================================================

local function playPunchAnimation()

	local player = Players.LocalPlayer
	if not player then return end
	if not player.Character then return end
	if not punchAnimation then return end

	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	if not punchTrack then
		punchTrack = animator:LoadAnimation(punchAnimation)
		punchTrack.Priority = Enum.AnimationPriority.Action4
		punchTrack.Looped = false
	end

	punchTrack:Play(0, 1, 1)

	dprint("👊 Punch animation playing")
end

--=====================================================
-- TOOL HOOKING
--=====================================================

local toolConnections: { [Tool]: { RBXScriptConnection } } = {}

local function disconnectTool(tool: Tool)
	local conns = toolConnections[tool]
	if not conns then return end

	for _, c in ipairs(conns) do
		c:Disconnect()
	end

	toolConnections[tool] = nil
end

local function isPunchTool(tool: Tool): boolean
	return tool:GetAttribute("GearType") == "Punch"
end

function PvPToolsController:_hookTool(tool: Tool)

	if toolConnections[tool] then
		return
	end

	if not isPunchTool(tool) then
		return
	end

	dprint("🔗 Hooking Punch tool:", tool.Name)

	local conns: { RBXScriptConnection } = {}
	toolConnections[tool] = conns

	table.insert(conns, tool.Activated:Connect(function()
		dprint("➡️ RequestPunch()")
		self.PvPToolsService:RequestPunch()
	end))

	table.insert(conns, tool.Destroying:Connect(function()
		disconnectTool(tool)
	end))
end

function PvPToolsController:_scanForTools()

	local player = Players.LocalPlayer
	if not player then return end

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

--=====================================================
-- KNIT INIT
--=====================================================

function PvPToolsController:KnitInit()

	dprint("KnitInit() start")

	self.PvPToolsService = Knit.GetService("PvPToolsService")

	self.PvPToolsService.PlayPunchAnimation:Connect(function()
		playPunchAnimation()
	end)

	self.PvPToolsService.ActionResult:Connect(function(actionName, success, reason)
		dprint("ActionResult:", actionName, success, reason)
	end)

	dprint("KnitInit() complete")
end

--=====================================================
-- KNIT START
--=====================================================

function PvPToolsController:KnitStart()

	dprint("KnitStart() start")

	local player = Players.LocalPlayer
	if not player then return end

	player.CharacterAdded:Connect(function(character)

		task.wait(0.5)
		preloadPunchTrack()

		task.defer(function()
			self:_scanForTools()
		end)

		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				self:_hookTool(child)
			end
		end)
	end)

	if player.Character then
		task.wait(0.5)
		preloadPunchTrack()
	end

	local backpack = player:WaitForChild("Backpack")
	backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			self:_hookTool(child)
		end
	end)

	self:_scanForTools()

	dprint("KnitStart() complete")
end

return PvPToolsController