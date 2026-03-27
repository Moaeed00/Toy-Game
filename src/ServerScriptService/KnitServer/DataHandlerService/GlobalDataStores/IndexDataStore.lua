local DataStoreService = game:GetService("DataStoreService")

local Configuration = require(script.Parent.Parent:WaitForChild("Configuration"))
local DataStoreName = Configuration.DataStoreName
local DataStoreVersion = Configuration.DataStoreVersion

local DataStoreKey = `{DataStoreName}_{DataStoreVersion}_Index`
local OrderedStore = DataStoreService:GetOrderedDataStore(DataStoreKey)

local DataStore = {}

function DataStore:SaveData(player: Player, percent: number)
    if player and typeof(percent) == "number" then
        local key = `Player_{player.UserId}`

        local success, error = pcall(function()
            OrderedStore:SetAsync(key, percent)
        end)
        if success then
			print("Leaderboad data saved successfully")
		else
			print("Leaderboad data didn't save")
			warn(error)
		end
    end
end

function DataStore:GetTopPlayersData(ascending: boolean, length: number)
    local pages = OrderedStore:GetSortedAsync(ascending, length)
    local topPlayers = pages:GetCurrentPage()
	return topPlayers
end

return DataStore