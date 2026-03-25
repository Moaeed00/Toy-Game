--[[
DATA_HANDLER (by ROCKETFUEL)

	Functions:
	DataHandlerService:GetPlayerData(player: Player):		{[string]: any} | nil
		-- Returns data table belonging to that player

	Events:

		DataHandlerService.OnPlayerProfileLoaded			[Signal] (player: Player, PlayerDataTable: {[string]: any})
			-- When player's profile is loaded then this event will be fired
		DataHandlerService.OnPlayerSessionEnded			[Signal] (player: Player)
			-- When player is either disconnecting or being kicked this event will be fired
		DataHandlerService.OnPlayerDataChanged				[Signal] (player: Player, valueName: string, PlayerDataTable: {[string]: any})
			-- When player's profile is loaded then this function will run

--]]

-- [Services] ---
local PlayerService: Players = game:GetService("Players")
local ServerScriptService: ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlobalDataStores: Folder = script:WaitForChild("GlobalDataStores")
local CoinsDataStoreModule = require(GlobalDataStores:WaitForChild("CoinsDataStore"))
local PointsDataStoreModule = require(GlobalDataStores:WaitForChild("PointsDataStore"))

-- [References] --
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local ProfileStoreModule = require(ServerScriptService.ServerPackages.profilestore)
local PROFILE_TEMPLATE = require(script:WaitForChild("ProfileTemplate"))
local Format = require(ReplicatedStorage.Libraries.Format)

-- local GlobalDataStores: Folder = script:WaitForChild("GlobalDataStores")

local Configuration: {} = require(script:WaitForChild("Configuration"))
local DataStoreName = Configuration.DataStoreName
local DataStoreVersion = Configuration.DataStoreVersion

local DataStoreKey: string = `{DataStoreName}_{DataStoreVersion}`
local PlayerStore = ProfileStoreModule.New(DataStoreKey, PROFILE_TEMPLATE)
local Profiles = {}

-- local EnumDataValue = {
-- 	["Coins"] = "Coins",
-- }

local DataHandlerService = Knit.CreateService({
	Name = "DataHandlerService",
	Client = {
		UpdateMoney = Knit.CreateSignal(),
	},
})

DataHandlerService.OnPlayerProfileLoaded = Signal.new()
DataHandlerService.BeforeLastSave = Signal.new()
DataHandlerService.OnPlayerSessionEnded = Signal.new()
DataHandlerService.OnPlayerDataChanged = Signal.new()

-- the data that will be used to update to rank players
DataHandlerService.LeaderboardCategory = { "MoneyPerSec" }

local function OnPlayerRemoving(player: Player)
	local profile = Profiles[player]
	if profile ~= nil then
		local data = profile.Data
		if data then
			local mps = player:GetAttribute("MoneyPerSec") or 0

			task.spawn(function()
				CoinsDataStoreModule:SaveData(player, math.floor(mps))
			end)
			task.spawn(function()
				PointsDataStoreModule:SaveData(player, math.floor(data.Points))
			end)
		end
		profile:EndSession()
	end
end

local function OnPlayerAdded(player: Player)
	-- Start a profile session for this player's data:
	local profile = PlayerStore:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= PlayerService
		end,
	})

	-- Handling new profile session or failure to start it:

	if profile ~= nil then
		profile:AddUserId(player.UserId) -- GDPR compliance
		profile:Reconcile() -- Fill in missing variables from PROFILE_TEMPLATE (optional)

		profile.OnSessionEnd:Connect(function()
			DataHandlerService.OnPlayerSessionEnded:Fire(player) --
			profile[player] = nil
			player:Kick(`Profile session end - Please rejoin`)
		end)

		profile.OnSave:Connect(function()
			--print("profile on save called")
		end)

		if player.Parent == PlayerService then
			Profiles[player] = profile
			DataHandlerService.OnPlayerProfileLoaded:Fire(player, Profiles[player].Data)
			print(`Profile loaded for {player.DisplayName}!`)

			-- Fire any events you need to after the profile has been freshly loaded
			player:SetAttribute("Money", Profiles[player].Data.Money)
			DataHandlerService.Client.UpdateMoney:Fire(player, Profiles[player].Data.Money, true)
			-- For Leaderboard Initialization
		else
			-- The player has left before the profile session started
			profile:EndSession()
		end
	else
		-- This condition should only happen when the Roblox server is shutting down
		player:Kick(`Profile load fail - Please rejoin`)
	end
end

local function Main()
	for _, player in PlayerService:GetPlayers() do
		OnPlayerAdded(player)
	end

	PlayerService.PlayerAdded:Connect(OnPlayerAdded)
	PlayerService.PlayerRemoving:Connect(OnPlayerRemoving)
end

function DataHandlerService:GetPlayerData(player: Player)
	if not player then
		warn("Player doesn't exists while getting data")
		return nil
	end

	local playerProfile = Profiles[player]
	if not playerProfile then
		warn(`Profile doesn't exist for player: {player.UserId}`)
		return nil
	end

	return playerProfile.Data
end

function DataHandlerService:SetPlayerData(player: Player, dataTable: { [string]: any })
	if not player then
		warn("Player doesn't exists while getting data")
		return
	end

	local playerProfile = Profiles[player]
	if playerProfile then
		for valueName: string, value: any in dataTable do
			-- If not found in PlayerValues, update the profile data
			if playerProfile.Data[valueName] ~= nil then
				playerProfile.Data[valueName] = value
			else
				warn(`Value {valueName} doesn't exist in player's data table`)
			end

			local playerValueHolder = player:FindFirstChild("PlayerValues")
			-- Check if the value exists in PlayerValues folder and is an IntValue
			if playerValueHolder and playerValueHolder:FindFirstChild(valueName) then
				playerValueHolder[valueName].Value = value
			end
		end

		self.OnPlayerDataChanged:Fire(player, playerProfile.Data)
	else
		warn("Profile not found while setting data")
	end
end

-- LeaderStat Helpers
local function SetLeaderboardStats(player: Player, Name: string, value: number)
	local LeaderStats = player:FindFirstChild("leaderstats")
	local Attr = LeaderStats:FindFirstChild(Name)

	if Attr.Name == "Cash" then
		player:SetAttribute("Money", value)
		DataHandlerService.Client.UpdateMoney:Fire(player, value)
		Attr.Value = Format.abbreviate(value)
	else
		Attr.Value = value
	end
end

--MoneyMultiplierHelpers
function DataHandlerService:GetMoneyMultiplier(player: Player)
	local data = self:GetPlayerData(player)

	if data then
		return data.MoneyMultiplier
	end
end

-- Points Helpers
function DataHandlerService:DeductPoints(player: Player, amount: number)
	local data = self:GetPlayerData(player)

	if data then
		if amount <= 0 then
			return false
		end

		if data.Points >= amount then
			data.Points -= amount
			self:SetPlayerData(player, { Points = data.Points })
			SetLeaderboardStats(player, "Points", data.Points)
			return true
		end
		return false
	end

	return false
end

function DataHandlerService:GetPoints(player: Player)
	local data = self:GetPlayerData(player)

	if data then
		return data.Points
	end
end

function DataHandlerService:UpdatePoints(player: Player, pointsEarned: number)
	local playerData = self:GetPlayerData(player)

	if playerData then
		local prevPoints = playerData.Points
		local updatedPoints = prevPoints + pointsEarned
		self:SetPlayerData(player, { Points = updatedPoints })
		SetLeaderboardStats(player, "Points", updatedPoints)
	end
end

-- Coins Helpers
function DataHandlerService:ResetMoney(player)
	local data = self:GetPlayerData(player)
	if data then
		self:SetPlayerData(player, { Money = 0 })
		SetLeaderboardStats(player, "Cash", 0)
		return true
	end
end

function DataHandlerService:DeductMoney(player: Player, amount: number)
	local data = self:GetPlayerData(player)

	if data then
		if amount <= 0 then
			return false
		end

		if data.Money >= amount then
			data.Money -= amount
			self:SetPlayerData(player, { Money = data.Money })
			SetLeaderboardStats(player, "Cash", data.Money)
			return true
		end
		return false
	end

	return false
end

function DataHandlerService:GetMoney(player: Player)
	local data = self:GetPlayerData(player)

	if data then
		return data.Money
	end
end

function DataHandlerService:UpdateMoney(player: Player, MoneyEarned: number)
	local playerData = self:GetPlayerData(player)

	if playerData then
		local prevMoney = playerData.Money
		local updatedMoney = prevMoney + MoneyEarned
		self:SetPlayerData(player, { Money = updatedMoney })
		SetLeaderboardStats(player, "Cash", updatedMoney)
	end
end

function DataHandlerService:ReturnTopTenPlayers()
	local coins = {}
	local points = {}

	pcall(function()
		coins = CoinsDataStoreModule:GetTopPlayersData(false, 10)
	end)

	pcall(function()
		points = PointsDataStoreModule:GetTopPlayersData(false, 10)
	end)

	return {
		Coins = coins,
		Points = points,
	}
end

--- Base Likes Helpers
function DataHandlerService:AddLike(likerPlayer: Player, targetPlayer: Player)
	if likerPlayer == targetPlayer then
		warn("You can not like yourself")
		return false, "self_like"
	end

	local likerData = self:GetPlayerData(likerPlayer)
	local targetData = self:GetPlayerData(targetPlayer)
	if not likerData or not targetData then
		warn("One of the players has no profile data")
		return false, "no_data"
	end

	likerData.LikedPlayers = likerData.LikedPlayers or {}
	targetData.LikesReceived = targetData.LikesReceived or 0

	local targetKey = tostring(targetPlayer.UserId)

	if likerData.LikedPlayers[targetKey] then
		return false, "already_liked"
	end

	likerData.LikedPlayers[targetKey] = true
	targetData.LikesReceived = targetData.LikesReceived + 1

	self:SetPlayerData(likerPlayer, { LikedPlayers = likerData.LikedPlayers })
	self:SetPlayerData(targetPlayer, { LikesReceived = targetData.LikesReceived })

	return true, targetData.LikesReceived
end

function DataHandlerService:GetLikes(likerPlayer: Player, targetPlayer: Player)
	local likerData = self:GetPlayerData(likerPlayer)
	local targetData = self:GetPlayerData(targetPlayer)
	if not likerData or not targetData then
		return 0, "no_data"
	end
	return likerData.LikedPlayers[targetPlayer.UserId] or false
end

function DataHandlerService:GetTotalLikes(player: Player)
	local data = self:GetPlayerData(player)
	return data and data.LikesReceived or 0
end

function DataHandlerService:HasPlayerLiked(likerPlayer: Player, targetPlayer: Player)
	local likerData = self:GetPlayerData(likerPlayer)
	if not likerData then
		return false
	end

	likerData.LikedPlayers = likerData.LikedPlayers or {}

	local targetKey = tostring(targetPlayer.UserId)

	return likerData.LikedPlayers[targetKey] == true
end

--Initialization
function DataHandlerService:KnitInit() end

function DataHandlerService:KnitStart()
	Main()
end

return DataHandlerService
