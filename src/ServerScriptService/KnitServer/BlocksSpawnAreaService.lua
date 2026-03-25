--!strict
-- BlocksSpawnAreaService.lua
-- CLEAN REWRITE
-- Responsibilities:
-- Zone detection
-- Speed control
-- Pickup permission
-- Drop permission
-- Convert carried brainrot to tool on exit

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local Config = require(
	ReplicatedStorage.Configuration.BlocksSpawnAreaConfig
)

local BlocksSpawnAreaService = Knit.CreateService({
	Name = "BlocksSpawnAreaService",

	Client = {
		ZoneChanged = Knit.CreateSignal(),
	}
})

local playersInArea: {[Player]:boolean} = {}

local areaPart: Part?

local BrainrotCarryService
local IndexService

--------------------------------------------------
-- Area Check
--------------------------------------------------

local function isCharacterInside(character: Model): boolean

	if not areaPart then
		return false
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end

	local pos = hrp.Position
	local size = areaPart.Size
	local center = areaPart.Position

	local inX = math.abs(pos.X - center.X) <= size.X/2
	local inY = math.abs(pos.Y - center.Y) <= size.Y/2
	local inZ = math.abs(pos.Z - center.Z) <= size.Z/2

	return inX and inY and inZ
end

--------------------------------------------------
-- Speed Control
--------------------------------------------------

function BlocksSpawnAreaService:UpdatePlayerSpeed(player: Player)

	local char = player.Character
	if not char then return end

	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	local inside = playersInArea[player] == true
	local carrying = player:GetAttribute("IsCarryingBrainrot") == true

	if inside and carrying then
		hum.WalkSpeed = Config.NORMAL_SPEED
	else
		hum.WalkSpeed = Config.BOOSTED_SPEED
	end
end

--------------------------------------------------
-- Pickup Check
--------------------------------------------------

function BlocksSpawnAreaService:CanPickupBrainrot(player: Player): boolean

	return playersInArea[player] == true

end

--------------------------------------------------
-- Drop Check
--------------------------------------------------

function BlocksSpawnAreaService:CanDropBrainrot(player: Player): boolean

	return playersInArea[player] == true

end

--------------------------------------------------
-- Player Enter Area
--------------------------------------------------

function BlocksSpawnAreaService:_playerEntered(player: Player)

	if playersInArea[player] then
		return
	end

	playersInArea[player] = true

	player:SetAttribute("IsInBlocksSpawnArea", true)

	self:UpdatePlayerSpeed(player)

	self.Client.ZoneChanged:Fire(player,true)

end

--------------------------------------------------
-- Player Exit Area
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

function BlocksSpawnAreaService:_playerExited(player: Player)

	if not playersInArea[player] then
		return
	end

	playersInArea[player] = false

	player:SetAttribute("IsInBlocksSpawnArea", false)

	--------------------------------------------------
	-- Convert brainrot to tool if carrying
	--------------------------------------------------
	if player:GetAttribute("IsCarryingBrainrot") then

		local carried = getCarriedBrainrot(player)
		if carried then
			local brainrotName = carried:GetAttribute("Name") or carried.Name
			local variantPrefix = carried:GetAttribute("Variant") or "Normal"

			if IndexService then
				IndexService:UnlockBrainrot(player, brainrotName, variantPrefix)
			end
		end

		-- THEN convert (this destroys it)
		task.defer(function()
			if BrainrotCarryService then
				BrainrotCarryService:ConvertToTool(player)
			end
		end)

	end

	self:UpdatePlayerSpeed(player)

	self.Client.ZoneChanged:Fire(player,false)

end

--------------------------------------------------
-- Brainrot Destroyed While Carrying
--------------------------------------------------

function BlocksSpawnAreaService:_brainrotDestroyed(player: Player)

	-- reset player state
	player:SetAttribute("IsCarryingBrainrot", false)

	-- reset speed
	self:UpdatePlayerSpeed(player)

	-- remove drop UI / restart pickup loop
	self.Client.ZoneChanged:Fire(player, playersInArea[player] == true)

end

--------------------------------------------------
-- Tracking Loop
--------------------------------------------------

function BlocksSpawnAreaService:_startTracking()

	RunService.Heartbeat:Connect(function()

		for _,player in ipairs(Players:GetPlayers()) do

			local char = player.Character
			if not char then
				continue
			end

			local inside = isCharacterInside(char)
			local wasInside = playersInArea[player] == true

			if inside and not wasInside then
				self:_playerEntered(player)
			end

			if not inside and wasInside then
				self:_playerExited(player)
			end

		end

	end)

end

--------------------------------------------------
-- Player Setup
--------------------------------------------------

function BlocksSpawnAreaService:_setupPlayer(player: Player)

	player:SetAttribute("IsInBlocksSpawnArea", false)

	player.CharacterAdded:Connect(function()

		task.wait(0.5)

		self:UpdatePlayerSpeed(player)

	end)

	player:GetAttributeChangedSignal("IsCarryingBrainrot"):Connect(function()

		self:UpdatePlayerSpeed(player)

	end)

end

--------------------------------------------------
-- Knit Init
--------------------------------------------------

function BlocksSpawnAreaService:KnitInit()

	Players.PlayerRemoving:Connect(function(player)

		playersInArea[player] = nil

	end)

end

--------------------------------------------------
-- Knit Start
--------------------------------------------------

function BlocksSpawnAreaService:KnitStart()
	areaPart = workspace.Environment:WaitForChild(Config.BLOCKS_SPAWN_AREA_NAME)

	pcall(function()
		BrainrotCarryService = Knit.GetService("BrainrotCarryService")
		IndexService = Knit.GetService("IndexService")
	end)

	for _,player in ipairs(Players:GetPlayers()) do
		self:_setupPlayer(player)
	end

	Players.PlayerAdded:Connect(function(player)

		self:_setupPlayer(player)

	end)

	self:_startTracking()

end

return BlocksSpawnAreaService