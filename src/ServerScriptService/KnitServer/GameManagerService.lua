-- local Players: Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local GameManagerService = Knit.CreateService({
	Name = "GameManagerService",
	Client = {},
})

-- local DataHandlerService

-- local function OnPlayerAdded(player: Player) end

function GameManagerService:KnitInit()
	-- DataHandlerService = Knit.GetService("DataHandlerService")
end

function GameManagerService:KnitStart()
	-- Players.PlayerAdded:Connect(OnPlayerAdded)
	-- DataHandlerService.OnPlayerProfileLoaded:Connect(function(player: Player, PlayerData: {}) end)
end

return GameManagerService
