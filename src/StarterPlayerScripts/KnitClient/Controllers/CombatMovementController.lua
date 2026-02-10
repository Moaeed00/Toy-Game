--!strict
--// File: src/StarterPlayerScripts/KnitClient/Controllers/CombatMovementController.lua
--// CombatMovementController.lua
--// UPDATED:
--// - Supports new approach via Tool.Activated (mouse left click)
--// - Optional legacy keybind mode via Config.INPUT_MODE

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService: ContextActionService = game:GetService("ContextActionService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage:WaitForChild("Configuration"):WaitForChild("CombatMovementConfig"))

local CombatMovementController = Knit.CreateController({
	Name = "CombatMovementController",
})

--// Internal tool connection storage
local toolConnections: { [Instance]: { RBXScriptConnection } } = {}

local function dprint(...: any)
	--// Function: dprint
	--// Debug print helper.

	--// IF: debug enabled
	if Config.DEBUG_PRINTS then
		print("[CombatMovementController]", ...)
	end
end

local function disconnectTool(tool: Instance)
	--// Function: disconnectTool
	--// Disconnect stored connections.

	local conns = toolConnections[tool]
	--// IF: no conns
	if not conns then
		return
	end

	--// LOOP: disconnect all
	for _, c in ipairs(conns) do
		--// Loop: connection
		c:Disconnect()
	end

	toolConnections[tool] = nil
end

function CombatMovementController:_hookTool(tool: Tool)
	--// Function: _hookTool
	--// Hooks Tool.Activated for Slide + Punch tools.

	--// IF: already hooked
	if toolConnections[tool] then
		return
	end

	--// IF: not our tool names
	if tool.Name ~= Config.SLIDE_TOOL_NAME and tool.Name ~= Config.PUNCH_TOOL_NAME then
		return
	end

	dprint("Hooking tool:", tool.Name, "path:", tool:GetFullName())

	local conns: { RBXScriptConnection } = {}
	toolConnections[tool] = conns

	--// Event: Activated (mouse left click)
	table.insert(conns, tool.Activated:Connect(function()
		--// Event call: Activated
		dprint("Tool Activated:", tool.Name)

		--// IF: Slide tool
		if tool.Name == Config.SLIDE_TOOL_NAME then
			--// IMPORTANT: request slide on server
			dprint("RequestSlide() -> server")
			self.CombatMovementService:RequestSlide()
			return
		end

		--// ELSE IF: Punch tool
		if tool.Name == Config.PUNCH_TOOL_NAME then
			--// IMPORTANT: request punch on server
			dprint("RequestPunch() -> server")
			self.CombatMovementService:RequestPunch()
			return
		end
	end))

	--// Event: Destroying -> cleanup
	table.insert(conns, tool.Destroying:Connect(function()
		--// Event call: Destroying
		dprint("Tool destroying -> cleanup:", tool.Name)
		disconnectTool(tool)
	end))
end

function CombatMovementController:_scanForTools()
	--// Function: _scanForTools
	--// Scans Backpack + Character for tools to hook.

	local player = Players.LocalPlayer
	--// IF: no player
	if not player then
		return
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	--// IF: backpack exists
	if backpack then
		--// LOOP: backpack children
		for _, child in ipairs(backpack:GetChildren()) do
			--// Loop: child
			if child:IsA("Tool") then
				self:_hookTool(child)
			end
		end
	end

	local character = player.Character
	--// IF: character exists
	if character then
		--// LOOP: character children
		for _, child in ipairs(character:GetChildren()) do
			--// Loop: child
			if child:IsA("Tool") then
				self:_hookTool(child)
			end
		end
	end
end

function CombatMovementController:_bindKeyInputs()
	--// Function: _bindKeyInputs
	--// Legacy mode: CTRL slide + Q punch.

	dprint("_bindKeyInputs() binding legacy keys")

	--// Slide binding
	ContextActionService:BindAction(
		"LegacySlide_CTRL",
		function(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
			--// Event call: Slide key
			--// IF: key pressed
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

	--// Punch binding
	ContextActionService:BindAction(
		"LegacyPunch_Q",
		function(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
			--// Event call: Punch key
			--// IF: key pressed
			if inputState == Enum.UserInputState.Begin then
				dprint("Q pressed -> RequestPunch()")
				self.CombatMovementService:RequestPunch()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.KeyCode.Q
	)
end

function CombatMovementController:KnitInit()
	--// Function: KnitInit
	--// Get service and connect debug result.

	dprint("KnitInit() start")

	self.CombatMovementService = Knit.GetService("CombatMovementService")
	dprint("Got CombatMovementService:", self.CombatMovementService)

	self.CombatMovementService.ActionResult:Connect(function(actionName: string, success: boolean, reason: string)
		--// Event: ActionResult
		dprint("ActionResult ->", actionName, "success:", success, "reason:", reason)
	end)

	dprint("KnitInit() complete")
end

function CombatMovementController:KnitStart()
	--// Function: KnitStart
	--// Choose input mode (Tool vs Keybind).

	dprint("KnitStart() start | INPUT_MODE =", Config.INPUT_MODE)

	--// IF: Tool mode
	if Config.INPUT_MODE == "Tool" then
		local player = Players.LocalPlayer
		--// IF: no local player
		if not player then
			dprint("No LocalPlayer in Tool mode")
			return
		end

		--// Event: CharacterAdded
		player.CharacterAdded:Connect(function(char: Model)
			--// Event call: CharacterAdded
			dprint("CharacterAdded -> scan tools:", char.Name)

			task.defer(function()
				--// Deferred: scan
				self:_scanForTools()
			end)

			--// Event: tool added to character
			char.ChildAdded:Connect(function(child: Instance)
				--// Event call: Character ChildAdded
				if child:IsA("Tool") then
					dprint("Character tool added:", child.Name)
					self:_hookTool(child)
				end
			end)
		end)

		--// Hook backpack tool adds
		local backpack = player:WaitForChild("Backpack")
		backpack.ChildAdded:Connect(function(child: Instance)
			--// Event call: Backpack ChildAdded
			if child:IsA("Tool") then
				dprint("Backpack tool added:", child.Name)
				self:_hookTool(child)
			end
		end)

		--// Initial scan
		self:_scanForTools()
	else
		--// ELSE: Keybind mode
		self:_bindKeyInputs()
	end

	dprint("KnitStart() complete")
end

return CombatMovementController
