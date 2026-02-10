local PlayerService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataHandler = require(ServerScriptService:WaitForChild("DataHandler"))
local Knit = require(ReplicatedStorage.Packages.Knit)

local LeaderboardService = Knit.CreateService {
    Name = "LeaderboardService",
    Client = {
        UpdateLeaderboard = Knit.CreateSignal(),
    },
}

-- Configuration
local UPDATE_TICK: number = 15 -- seconds

-- Server Leaderboad Variables
local SortedPlayerList: {Player} = {}
local PlayerData: {[Player]: any} = {}
local Category: string = DataHandler.LeaderboardCategory and DataHandler.LeaderboardCategory[1] or "Coins"

local function SortTable()
	table.sort(SortedPlayerList, function(playerOne: Player, playerTwo: Player): boolean
		return PlayerData[playerOne][Category] >= PlayerData[playerTwo][Category]	
	end)
end

local function ReturnGlobalLeaderboardTable()
	local leaderboardTableCoins: {{[string]: any}} = {}
	local leaderboardTablePoints: {{[string]: any}} = {}
	local topTenPlayerDictionary: {[any]: any} = DataHandler:ReturnTopTenPlayers()


	-- For debugging
	--for k, v in pairs(topTenPlayerDictionary) do
	--print(k, v)
	--end

	if not topTenPlayerDictionary then
		warn("Error in topTenPlayerDictionary")
		return
	end

	for _, data in topTenPlayerDictionary.Coins do
		local userId = tonumber(data.key:sub(8))
		local playerTable = {}
		local name

		local success, err = pcall(function(...) 
			name = PlayerService:GetNameFromUserIdAsync(userId)
		end)

		playerTable.Name = success and name or "NotAvailable" 

		playerTable.Value = data.value
		table.insert(leaderboardTableCoins, playerTable)
	end

	for _, data in topTenPlayerDictionary.Points do
		local userId = tonumber(data.key:sub(8))
		local playerTable = {}
		local name

		local success, err = pcall(function(...) 
			name = PlayerService:GetNameFromUserIdAsync(userId)
		end)

		playerTable.Name = success and name or "NotAvailable" 

		playerTable.Value = data.value
		table.insert(leaderboardTablePoints, playerTable)
	end

	for _, data in topTenPlayerDictionary.Rebirths do
		local userId = tonumber(data.key:sub(8))
		local playerTable = {}
		local name

		local success, err = pcall(function(...) 
			name = PlayerService:GetNameFromUserIdAsync(userId)
		end)

		playerTable.Name = success and name or "NotAvailable" 

		playerTable.Value = data.value
		table.insert(leaderboardTableRebirths, playerTable)
	end

	return {Points = leaderboardTablePoints, Rebirths = leaderboardTableRebirths, Coins = leaderboardTableCoins}
end

local function ReturnServerLeaderboardTable()
	local leaderboardTable: {{[string]: any}} = {}

	for _, player in SortedPlayerList do
		local playerTable = {}
		local name

		local success, err = pcall(function(...) 
			name = PlayerService:GetNameFromUserIdAsync(player.UserId)
		end)

		playerTable.Name = success and name or "NotAvailable"

		playerTable.Value = PlayerData[player][Category]
		table.insert(leaderboardTable, playerTable)
	end

	return leaderboardTable
end

function LeaderboardService:UpdateServerLeaderboard()
    local leaderboardTable = ReturnServerLeaderboardTable()
	self.Client.UpdateLeaderboard:FireAll("Server", leaderboardTable)
end

function LeaderboardService:UpdateGlobalLeaderboard()
    local leaderboardTable = ReturnGlobalLeaderboardTable()
	self.Client.UpdateLeaderboard:FireAll("Global", leaderboardTable)
end

function LeaderboardService.Client:RequestLeaderboard()
	return {
		["Server"] = ReturnServerLeaderboardTable(),
		["Global"] = ReturnGlobalLeaderboardTable()	
	}
end

function LeaderboardService:KnitStart()
    DataHandler.OnPlayerProfileLoaded.Event:Connect(function(Player: Player, Profile: {})
        if Player and Profile ~= nil then
            PlayerData[Player] = Profile
            table.insert(SortedPlayerList, Player)

            --print("Profile",Profile)
            SortTable()
            self:UpdateServerLeaderboard()
        end
    end)

    DataHandler.OnPlayerDataChanged.Event:Connect(function(Player: Player, Profile: {})
        if Player and Profile ~= nil and PlayerData[Player] ~= nil then
            if PlayerData[Player][Category] == Profile[Category] then
                return
            end

            PlayerData[Player] = Profile
            SortTable()
            self:UpdateServerLeaderboard()
        end
    end)

    PlayerService.PlayerRemoving:Connect(function(Player: Player) 
        local playerIndex = table.find(SortedPlayerList, Player)
        if playerIndex ~= nil then
            table.remove(SortedPlayerList, playerIndex)
        end

        if PlayerData[Player] then
            PlayerData[Player] = nil	
        end

        self:UpdateServerLeaderboard()
    end)

    task.spawn(function()
        while true do
            self:UpdateGlobalLeaderboard()
            task.wait(UPDATE_TICK)
        end
    end)
end


function LeaderboardService:KnitInit()
end


return LeaderboardService
