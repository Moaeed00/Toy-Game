local Players: Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ServerModules: Folder = ServerScriptService:WaitForChild("ServerModules")
local CollisionGroupHandler: {} = require(ServerModules:WaitForChild("CollisionGroupHandler"))

local DataHandlerService

local GameManagerService = Knit.CreateService({
	Name = "GameManagerService",
	Client = {},
})

local PlayerCollisionGroup = "Player"

local function leaderboardSetup(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local Points = Instance.new("IntValue")
	Points.Name = "Points"
	Points.Value = DataHandlerService:GetPoints(player)
	Points.Parent = leaderstats

	local Priority = Instance.new("NumberValue")
	Priority.Name = "Priority"
	Priority.Value = 2 --[Bigger Value Will Come First]
	Priority.Parent = Points
end

local function OnPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		CollisionGroupHandler:AddCollisionGroup(PlayerCollisionGroup, character)
	end)
end

function GameManagerService:KnitInit()
	DataHandlerService = Knit.GetService("DataHandlerService")
end

function GameManagerService:KnitStart()
	print("GameManagerService Started")
	Players.PlayerAdded:Connect(OnPlayerAdded)
	DataHandlerService.OnPlayerProfileLoaded:Connect(function(Player)
		leaderboardSetup(Player)
		-- DataHandlerService:UpdatePoints(Player, 1000)
	end)
end

return GameManagerService
