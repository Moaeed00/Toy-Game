--!strict
--// File: ServerScriptService/KnitServer/Services/BlocksSpawnAreaService.lua
--// BlocksSpawnAreaService.lua
--// FINAL VERSION WITH OWNERSHIP:
--// - Player becomes "owner" of brainrot when exiting area with it
--// - Owned brainrots show backpack UI (even inside area)
--// - Non-owned brainrots (picked up inside) hide backpack UI

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local Config = require(ReplicatedStorage:WaitForChild("Configuration"):WaitForChild("BlocksSpawnAreaConfig"))

local BlocksSpawnAreaService = Knit.CreateService({
	Name = "BlocksSpawnAreaService",

	Client = {
		--// Signal to notify client of zone entry/exit
		ZoneChanged = Knit.CreateSignal(), -- (isInside: boolean)
	},
})

--// Track which players are inside the area
local playersInArea: { [Player]: boolean } = {}

--// Reference to the BlocksSpawnArea part
local blocksSpawnAreaPart: Part? = nil

--// ------------------------------
--// Debug print helper
--// ------------------------------
local function dprint(...: any)
	--// Function: dprint
	--// Debug print helper.

	--// IF: debug enabled
	if Config.DEBUG_PRINTS then
		print("[BlocksSpawnAreaService]", ...)
	end
end

--// ------------------------------
--// Check if player's character is inside area
--// ------------------------------
local function isCharacterInArea(character: Model): boolean
	--// Function: isCharacterInArea
	--// Returns true if character's HRP is inside BlocksSpawnArea bounds.

	--// IF: no area part
	if not blocksSpawnAreaPart or not blocksSpawnAreaPart.Parent then
		return false
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	--// IF: no HRP
	if not hrp or not hrp:IsA("BasePart") then
		return false
	end

	--// Check if HRP position is within part bounds
	local partPos = blocksSpawnAreaPart.Position
	local partSize = blocksSpawnAreaPart.Size
	local hrpPos = hrp.Position

	local inX = math.abs(hrpPos.X - partPos.X) <= (partSize.X / 2)
	local inY = math.abs(hrpPos.Y - partPos.Y) <= (partSize.Y / 2)
	local inZ = math.abs(hrpPos.Z - partPos.Z) <= (partSize.Z / 2)

	return inX and inY and inZ
end

--// ------------------------------
--// Check if player is carrying brainrot MODEL
--// ------------------------------
local function isPlayerCarryingBrainrotModel(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("IsCarried") == true then
			return true
		end
	end

	return false
end

--// ------------------------------
--// Get equipped brainrot tool
--// ------------------------------
local function getEquippedBrainrotTool(player: Player): Tool?
	--// Function: getEquippedBrainrotTool
	--// Returns the equipped brainrot tool if any.

	local character = player.Character
	--// IF: no character
	if not character then
		return nil
	end

	--// LOOP: character children
	for _, child in ipairs(character:GetChildren()) do
		--// Loop: character child
		if child:IsA("Tool") and child:GetAttribute("IsBrainrotTool") == true then
			return child
		end
	end

	return nil
end

--// ------------------------------
--// Mark brainrot as owned by player
--// ------------------------------
local function markBrainrotAsOwned(brainrotTool: Tool, player: Player)
	--// Function: markBrainrotAsOwned
	--// Marks a brainrot tool as owned by a specific player.

	--// [IMPORTANT] Set ownership attribute on the tool
	brainrotTool:SetAttribute("OwnedByUserId", player.UserId)

	--// [IMPORTANT] Also mark on the Handle if it exists
	local handle = brainrotTool:FindFirstChild("Handle")
	if handle then
		handle:SetAttribute("OwnedByUserId", player.UserId)
	end

	dprint("Brainrot marked as owned by:", player.Name, "tool:", brainrotTool.Name)
end

--// ------------------------------
--// Check if player owns the equipped brainrot
--// ------------------------------
local function doesPlayerOwnEquippedBrainrot(player: Player): boolean
	-- Check equipped tool first
	local character = player.Character
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("IsBrainrotTool") == true then
				local ownerId = child:GetAttribute("OwnedByUserId")
				return ownerId == player.UserId
			end
		end
	end

	-- 🔥 NEW: Also check backpack tools
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("IsBrainrotTool") == true then
				local ownerId = child:GetAttribute("OwnedByUserId")
				if ownerId == player.UserId then
					return true
				end
			end
		end
	end

	return false
end

--// ------------------------------
--// Update player speed based on zone and brainrot state
--// ------------------------------
function BlocksSpawnAreaService:UpdatePlayerSpeed(player: Player)

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local isInside = playersInArea[player] == true
	local carryingModel = isPlayerCarryingBrainrotModel(player)

	local newSpeed

	-- 🔥 Only slow when player carries MODEL inside area
	if isInside and carryingModel then
		newSpeed = Config.NORMAL_SPEED
	else
		newSpeed = Config.BOOSTED_SPEED
	end

	humanoid.WalkSpeed = newSpeed
end

--// ------------------------------
--// Handle player entering area
--// ------------------------------
function BlocksSpawnAreaService:_onPlayerEnterArea(player: Player)
	--// Function: _onPlayerEnterArea
	--// Called when player enters BlocksSpawnArea.

	--// IF: already marked as inside
	if playersInArea[player] == true then
		return
	end

	dprint("Player ENTERED area:", player.Name)

	--// [IMPORTANT] Mark as inside
	playersInArea[player] = true

	--// [IMPORTANT] Set player attribute
	player:SetAttribute("IsInBlocksSpawnArea", true)

	--// [IMPORTANT] Check if they own the equipped brainrot
	local isOwned = doesPlayerOwnEquippedBrainrot(player)
	player:SetAttribute("OwnsEquippedBrainrot", isOwned)

	--// [IMPORTANT] Update speed
	self:UpdatePlayerSpeed(player)

	--// [IMPORTANT] Fire to client
	self.Client.ZoneChanged:Fire(player, true)
end

--// ------------------------------
--// Handle player exiting area
--// ------------------------------
function BlocksSpawnAreaService:_onPlayerExitArea(player: Player)
	--// Function: _onPlayerExitArea
	--// Called when player exits BlocksSpawnArea.
	--// [IMPORTANT] This is where player becomes OWNER of brainrot!

	--// IF: not marked as inside
	if playersInArea[player] ~= true then
		return
	end

	dprint("Player EXITED area:", player.Name)

	--// [IMPORTANT] Check if they're carrying a brainrot
	local brainrotTool = getEquippedBrainrotTool(player)
	if brainrotTool then
		--// [CRITICAL] Mark brainrot as owned when exiting area
		markBrainrotAsOwned(brainrotTool, player)

		--// [IMPORTANT] Update ownership attribute
		player:SetAttribute("OwnsEquippedBrainrot", true)

		brainrotTool:FindFirstChildOfClass("Model"):SetAttribute("TimerPaused", true)

		local meshPart: MeshPart = brainrotTool:FindFirstChildOfClass("Model"):FindFirstChildOfClass("MeshPart")
		if meshPart then
			local infoGUI: BillboardGui = meshPart:FindFirstChild("InfoGUI")
			if infoGUI then
				infoGUI.Enabled = false
			end
		end

		dprint("Player exited with brainrot -> NOW OWNS IT:", player.Name)
	end

	--// [IMPORTANT] Mark as outside
	playersInArea[player] = false

	--// [IMPORTANT] Set player attribute
	player:SetAttribute("IsInBlocksSpawnArea", false)
	
	print("========== PLAYER EXIT AREA ==========")
	print("Player:", player.Name)
	print("IsBrainrotEquipped:", player:GetAttribute("IsBrainrotEquipped"))

	local BrainrotCarryService = Knit.GetService("BrainrotCarryService")

	print("BrainrotCarryService:", BrainrotCarryService)

	if player:GetAttribute("IsBrainrotEquipped") then
		print("🚀 Scheduling GiveOwnership")

		task.defer(function()

			if not player or not player.Parent then
				return
			end

			print("🚀 Executing GiveOwnership after zone exit")

			local BrainrotCarryService = Knit.GetService("BrainrotCarryService")
			BrainrotCarryService:GiveOwnership(player)

			-- 🔥 CRITICAL FIX
			player:SetAttribute("IsBrainrotEquipped", false)

		end)

	else
		print("❌ Player not holding brainrot on exit")
	end

	--// [IMPORTANT] Update speed
	self:UpdatePlayerSpeed(player)

	--// [IMPORTANT] Fire to client
	self.Client.ZoneChanged:Fire(player, false)
end

--// ------------------------------
--// Check if player can pickup brainrot
--// ------------------------------
function BlocksSpawnAreaService:CanPickupBrainrot(player: Player): boolean
	--// Function: CanPickupBrainrot
	--// Returns true only if player is inside BlocksSpawnArea.

	local isInside = playersInArea[player] == true

	--// IF: not inside
	if not isInside then
		dprint("CanPickupBrainrot() BLOCKED ->", player.Name, "not in area")
		return false
	end

	dprint("CanPickupBrainrot() ALLOWED ->", player.Name)
	return true
end

--// ------------------------------
--// Check if player can drop brainrot
--// ------------------------------
function BlocksSpawnAreaService:CanDropBrainrot(player: Player): boolean

	local isInside = playersInArea[player] == true
	local carryingModel = isPlayerCarryingBrainrotModel(player)

	if not isInside then
		return false
	end

	if not carryingModel then
		return false
	end

	return true
end

--// ------------------------------
--// Setup player tracking
--// ------------------------------
function BlocksSpawnAreaService:_setupPlayer(player: Player)
	--// Function: _setupPlayer
	--// Sets up tracking for a player.

	dprint("_setupPlayer() for:", player.Name)

	--// [EVENT] Character added
	player.CharacterAdded:Connect(function(character: Model)
		--// Event: CharacterAdded

		dprint("CharacterAdded ->", player.Name)

		--// Reset state
		playersInArea[player] = false
		player:SetAttribute("IsInBlocksSpawnArea", false)
		local BrainrotCarryService = Knit.GetService("BrainrotCarryService")

		if player:GetAttribute("IsBrainrotEquipped") then
			BrainrotCarryService:GiveOwnership(player)
		end
		
		player:SetAttribute("OwnsEquippedBrainrot", false)

		--// Wait for HRP
		local hrp = character:WaitForChild("HumanoidRootPart", 10)
		--// IF: no HRP
		if not hrp then
			return
		end

		--// Initial speed (boosted by default)
		self:UpdatePlayerSpeed(player)

		--// Initial check
		task.wait(0.5)
		if isCharacterInArea(character) then
			self:_onPlayerEnterArea(player)
		end
	end)

	--// [EVENT] IsBrainrotEquipped changed
	player:GetAttributeChangedSignal("IsBrainrotEquipped"):Connect(function()
		--// Event: IsBrainrotEquipped changed
		local isEquipped = player:GetAttribute("IsBrainrotEquipped")
		dprint("IsBrainrotEquipped changed for:", player.Name, "->", isEquipped)

		--// [IMPORTANT] Update ownership status
		if isEquipped then
			local isOwned = doesPlayerOwnEquippedBrainrot(player)
			player:SetAttribute("OwnsEquippedBrainrot", isOwned)
		end

		self:UpdatePlayerSpeed(player)
	end)

	--// Initial character check
	if player.Character then
		task.defer(function()
			self:UpdatePlayerSpeed(player)
		end)
	end
end

--// ------------------------------
--// Main tracking loop (heartbeat)
--// ------------------------------
function BlocksSpawnAreaService:_startTrackingLoop()
	--// Function: _startTrackingLoop
	--// Runs every Heartbeat to check player positions.

	dprint("_startTrackingLoop() starting")

	RunService.Heartbeat:Connect(function()
		--// Event: Heartbeat

		--// IF: no area part
		if not blocksSpawnAreaPart or not blocksSpawnAreaPart.Parent then
			return
		end

		--// LOOP: all players
		for _, player in ipairs(Players:GetPlayers()) do
			--// Loop: player

			local character = player.Character
			--// IF: no character
			if not character then
				continue
			end

			local wasInside = (playersInArea[player] == true)
			local isInside = isCharacterInArea(character)

			--// IF: state changed (entered)
			if isInside and not wasInside then
				self:_onPlayerEnterArea(player)
			end

			--// IF: state changed (exited)
			if not isInside and wasInside then
				self:_onPlayerExitArea(player)
			end
		end
	end)
end

--// ------------------------------
--// Knit Lifecycle: Init
--// ------------------------------
function BlocksSpawnAreaService:KnitInit()
	--// Function: KnitInit
	--// Setup player cleanup.

	dprint("KnitInit() start")

	--// [EVENT] Player removing
	Players.PlayerRemoving:Connect(function(player: Player)
		--// Event: PlayerRemoving

		dprint("PlayerRemoving ->", player.Name)
		playersInArea[player] = nil
	end)

	dprint("KnitInit() complete")
end

--// ------------------------------
--// Knit Lifecycle: Start
--// ------------------------------
function BlocksSpawnAreaService:KnitStart()
	--// Function: KnitStart
	--// Find area part and start tracking.

	dprint("KnitStart() start")

	--// [IMPORTANT] Find BlocksSpawnArea part in Workspace
	blocksSpawnAreaPart = workspace:WaitForChild("Environment"):FindFirstChild(Config.BLOCKS_SPAWN_AREA_NAME)

	--// IF: not found
	if not blocksSpawnAreaPart or not blocksSpawnAreaPart:IsA("Part") then
		warn("[BlocksSpawnAreaService] BlocksSpawnArea part not found in Workspace!")
		warn("[BlocksSpawnAreaService] Please create a Part named:", Config.BLOCKS_SPAWN_AREA_NAME)
		return
	end

	dprint("Found BlocksSpawnArea:", blocksSpawnAreaPart:GetFullName())

	--// Setup existing players
	for _, player in ipairs(Players:GetPlayers()) do
		self:_setupPlayer(player)
	end

	--// Setup new players
	Players.PlayerAdded:Connect(function(player: Player)
		--// Event: PlayerAdded
		dprint("PlayerAdded ->", player.Name)
		self:_setupPlayer(player)
	end)

	--// Start tracking loop
	self:_startTrackingLoop()

	dprint("KnitStart() complete ✅")
end

return BlocksSpawnAreaService