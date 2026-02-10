local Players: Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ServerModules: Folder = ServerScriptService:WaitForChild("ServerModules")
local CollisionGroupHandler: {} = require(ServerModules:WaitForChild("CollisionGroupHandler"))

local GameManagerService = Knit.CreateService({
	Name = "GameManagerService",
	Client = {},
})

local PlayerCollisionGroup = "Player"

local function OnPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		CollisionGroupHandler:AddCollisionGroup(PlayerCollisionGroup, character)
	end)
end

function GameManagerService:KnitInit() end

function GameManagerService:KnitStart()
	Players.PlayerAdded:Connect(OnPlayerAdded)
end

return GameManagerService
