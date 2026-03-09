local Players: Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Format = require(ReplicatedStorage.Libraries.Format)
local Knit = require(ReplicatedStorage.Packages.Knit)

local Utils: Folder = ServerScriptService:WaitForChild("Utils")
local CollisionGroupHandler: {} = require(Utils:WaitForChild("CollisionGroupHandler"))

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

	local Cash = Instance.new("StringValue")
	Cash.Name = "Cash"
	Cash.Value = Format.abbreviate(math.floor(DataHandlerService:GetMoney(player)))
	Cash.Parent = leaderstats

	local Priority2 = Instance.new("NumberValue")
	Priority2.Name = "Priority"
	Priority2.Value = 2 --[Bigger Value Will Come First]
	Priority2.Parent = Points

	local Priority1 = Instance.new("NumberValue")
	Priority1.Name = "Priority"
	Priority1.Value = 1
	Priority1.Parent = Cash
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
	-- print("GameManagerService Started")
	Players.PlayerAdded:Connect(OnPlayerAdded)
	DataHandlerService.OnPlayerProfileLoaded:Connect(function(Player)
		leaderboardSetup(Player)
		-- DataHandlerService:UpdatePoints(Player, 1000)
	end)
end

return GameManagerService
