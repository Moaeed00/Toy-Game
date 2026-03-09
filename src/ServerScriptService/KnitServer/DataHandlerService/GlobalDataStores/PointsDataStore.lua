-- [Services] 	---
local DataStoreService: DataStoreService = game:GetService("DataStoreService")

-- [References] ---
local Configuration: {} = require(script.Parent.Parent:WaitForChild("Configuration"))
local DataStoreName = Configuration.DataStoreName
local DataStoreVersion = Configuration.DataStoreVersion

local DataStoreKey: string = `{DataStoreName}_{DataStoreVersion}_Points`
local LeaderboardDataStore = DataStoreService:GetOrderedDataStore(DataStoreKey)

local DataStore = {}

function DataStore:SaveData(Player: Player, PointsValue: number)
	if Player and typeof(PointsValue) == 'number' then
		local key = `Player_{Player.UserId}`

		print("PointsValue: ", PointsValue)
		local success, err = pcall(function()
			LeaderboardDataStore:SetAsync(key, PointsValue)
		end)

		if success then
			print("Leaderboad data saved successfully")
		else
			print("Leaderboad data didn't save")
			warn(err)
		end
	end
end

function DataStore:GetTopPlayersData(Ascending: boolean, Length: number)
	local pages = LeaderboardDataStore:GetSortedAsync(Ascending, Length)
	local topPlayers = pages:GetCurrentPage()

	return topPlayers
end

return DataStore