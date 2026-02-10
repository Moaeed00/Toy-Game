--!strict
--// File: src/StarterPlayerScripts/KnitClient/Controllers/PvPToolsController.lua
--// PvPToolsController.lua
--// Client controller:
--// - Detects Slide / Punch tools in Backpack/Character
--// - On Tool.Activated: sends server request (RequestSlide / RequestPunch)
--// NOTE: No damage is handled here; server is authoritative.

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService: TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local Config = require(ReplicatedStorage:WaitForChild("Configuration"):WaitForChild("PvPToolsConfig"))

local PvPToolsController = Knit.CreateController({
	Name = "PvPToolsController",
})

--// Connections per tool instance (to avoid duplicates)
local toolConnections: { [Instance]: { RBXScriptConnection } } = {}
local swingingTools: { [Tool]: boolean } = {}
local originalGripByTool: { [Tool]: CFrame } = {}

--// ------------------------------
--// Debug print helper
--// ------------------------------
local function dprint(...: any)
	--// Function: dprint
	--// Prints only when DEBUG_PRINTS enabled.

	--// IF: debug enabled
	if Config.DEBUG_PRINTS then
		print("[PvPToolsController]", ...)
	end
end

function PvPToolsController:_playSlapHandSwing(tool: Tool)
	--// Function: _playSlapHandSwing
	--// Tween Tool.Grip from 0 -> 90 degrees and back (local cosmetic animation).

	--// [IF] prevent spam stacking
	if swingingTools[tool] == true then
		--// [DEBUG] Already swinging
		dprint("_playSlapHandSwing() blocked -> already swinging:", tool.Name)
		return
	end

	--// [DEBUG] Start swing
	dprint("_playSlapHandSwing() START:", tool:GetFullName())

	swingingTools[tool] = true

	--// [IMPORTANT] Save original grip once
	if originalGripByTool[tool] == nil then
		originalGripByTool[tool] = tool.Grip
		dprint("_playSlapHandSwing() stored original Tool.Grip")
	end

	local originalGrip = originalGripByTool[tool]

	--// [IMPORTANT] Rotate by 90 degrees (punch swing)
	--// [IMPORTANT] Front -> Left swing (Yaw around Y axis)
	local swingCFrame = originalGrip * CFrame.Angles(0, math.rad(-90), 0)
	print("[PvPToolsController] Slap swing yaw 90 (front->left)")

	--// [IMPORTANT] Tween out then back
	local tweenOut = TweenService:Create(tool, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Grip = swingCFrame,
	})

	local tweenBack = TweenService:Create(tool, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Grip = originalGrip,
	})

	local outConn: RBXScriptConnection? = nil
	local backConn: RBXScriptConnection? = nil

	--// [EVENT] tweenOut completed -> play back
	outConn = tweenOut.Completed:Connect(function()
		--// Event: tweenOut complete
		dprint("_playSlapHandSwing() OUT complete -> returning")
		if outConn then outConn:Disconnect() end
		tweenBack:Play()
	end)

	--// [EVENT] tweenBack completed -> unlock
	backConn = tweenBack.Completed:Connect(function()
		--// Event: tweenBack complete
		dprint("_playSlapHandSwing() END:", tool.Name)
		if backConn then backConn:Disconnect() end
		swingingTools[tool] = false
	end)

	--// [IMPORTANT] start
	tweenOut:Play()
end


--// ------------------------------
--// Cleanup connections for a tool
--// ------------------------------
local function disconnectTool(tool: Instance)
	--// Function: disconnectTool
	--// Disconnects stored connections for a tool.

	local conns = toolConnections[tool]
	--// IF: no connections
	if not conns then
		return
	end

	--// LOOP: disconnect each
	for _, c in ipairs(conns) do
		--// Loop: connection
		c:Disconnect()
	end

	toolConnections[tool] = nil
end

--// ------------------------------
--// Hook a tool instance
--// ------------------------------
function PvPToolsController:_hookTool(tool: Tool)
	--// Function: _hookTool
	--// Connects Activated/Equipped/Unequipped for Slide + Punch tools.

	--// IF: already hooked
	if toolConnections[tool] then
		return
	end

	--// IF: not our tool
	if tool.Name ~= Config.SLIDE_TOOL_NAME and tool.Name ~= Config.PUNCH_TOOL_NAME then
		return
	end

	dprint("Hooking tool:", tool.Name, "tool:", tool:GetFullName())

	local conns: { RBXScriptConnection } = {}
	toolConnections[tool] = conns

	--// Event: Equipped
	table.insert(conns, tool.Equipped:Connect(function()
		--// Event call: Equipped
		dprint("Equipped:", tool.Name)
	end))

	--// Event: Unequipped
	table.insert(conns, tool.Unequipped:Connect(function()
		--// Event call: Unequipped
		dprint("Unequipped:", tool.Name)
	end))

	--// Event: Activated (Mouse1 click)
	table.insert(conns, tool.Activated:Connect(function()
		--// Event call: Activated
		dprint("Activated:", tool.Name)

		--// IF: slide tool
		if tool.Name == Config.SLIDE_TOOL_NAME then
			--// IMPORTANT: request slide on server
			dprint("RequestSlide() -> sending to server")
			self.PvPToolsService:RequestSlide()
			return
		end

		--// ELSE IF: punch tool
		if tool.Name == Config.PUNCH_TOOL_NAME then
			--// [DEBUG] Punch tool activated
			dprint("Punch tool Activated -> swing + RequestPunch()")

			--// [IMPORTANT] Local swing for visuals
			self:_playSlapHandSwing(tool)

			--// [IMPORTANT] Server request
			self.PvPToolsService:RequestPunch()
			return
		end

	end))

	--// Event: tool destroyed -> cleanup
	table.insert(conns, tool.Destroying:Connect(function()
		--// Event call: Destroying
		dprint("Tool destroying -> cleanup:", tool.Name)
		disconnectTool(tool)
	end))
end

--// ------------------------------
--// Scan containers for tools
--// ------------------------------
function PvPToolsController:_scanForTools()
	--// Function: _scanForTools
	--// Scans Backpack and Character to hook any tools.

	local player = Players.LocalPlayer
	--// IF: no local player
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

--// ------------------------------
--// Knit lifecycle
--// ------------------------------
function PvPToolsController:KnitInit()
	--// Function: KnitInit
	--// Fetch service + connect ActionResult.

	dprint("KnitInit() start")

	--// IMPORTANT: get PvPToolsService
	self.PvPToolsService = Knit.GetService("PvPToolsService")
	dprint("Got PvPToolsService:", self.PvPToolsService)

	--// Event: debug action result from server
	self.PvPToolsService.ActionResult:Connect(function(actionName: string, success: boolean, reason: string)
		--// Event call: ActionResult
		dprint("ActionResult:", actionName, "success:", success, "reason:", reason)
	end)

	dprint("KnitInit() complete")
end

function PvPToolsController:KnitStart()
	--// Function: KnitStart
	--// Hook tool events for Backpack/Character changes.

	dprint("KnitStart() start")

	local player = Players.LocalPlayer
	--// IF: no local player (should not happen)
	if not player then
		dprint("No LocalPlayer in KnitStart()")
		return
	end

	--// Event: CharacterAdded (rescan tools each respawn)
	player.CharacterAdded:Connect(function(char: Model)
		--// Event call: CharacterAdded
		dprint("CharacterAdded -> rescan tools:", char.Name)

		--// IMPORTANT: wait a tick so tools replicate
		task.defer(function()
			--// Deferred: scan
			self:_scanForTools()
		end)

		--// Event: child added to character
		char.ChildAdded:Connect(function(child: Instance)
			--// Event call: Character ChildAdded
			if child:IsA("Tool") then
				dprint("Character tool added:", child.Name)
				self:_hookTool(child)
			end
		end)
	end)

	--// Hook Backpack changes
	local backpack = player:WaitForChild("Backpack")
	--// Event: Backpack ChildAdded
	backpack.ChildAdded:Connect(function(child: Instance)
		--// Event call: Backpack ChildAdded
		if child:IsA("Tool") then
			dprint("Backpack tool added:", child.Name)
			self:_hookTool(child)
		end
	end)

	--// Initial scan
	self:_scanForTools()

	dprint("KnitStart() complete")
end

return PvPToolsController
