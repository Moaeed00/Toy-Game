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

-- [References] --
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local ProfileStoreModule = require(ServerScriptService.ServerPackages.profilestore)
local PROFILE_TEMPLATE = require(script:WaitForChild("ProfileTemplate"))

-- local GlobalDataStores: Folder = script:WaitForChild("GlobalDataStores")

local Configuration: {} = require(script:WaitForChild("Configuration"))
local DataStoreName = Configuration.DataStoreName
local DataStoreVersion = Configuration.DataStoreVersion

local DataStoreKey: string = `{DataStoreName}_{DataStoreVersion}`
local PlayerStore = ProfileStoreModule.New(DataStoreKey, PROFILE_TEMPLATE)
local Profiles = {}

local EnumDataValue = {
	["Coins"] = "Coins",
}

local DataHandlerService = Knit.CreateService({
	Name = "DataHandlerService",
})

DataHandlerService.OnPlayerProfileLoaded = Signal.new()
DataHandlerService.BeforeLastSave = Signal.new()
DataHandlerService.OnPlayerSessionEnded = Signal.new()
DataHandlerService.OnPlayerDataChanged = Signal.new()

-- the data that will be used to update to rank players
DataHandlerService.LeaderboardCategory = { EnumDataValue.Coins }

local function OnPlayerRemoving(player: Player)
	local profile = Profiles[player]

	if profile ~= nil then
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

function DataHandlerService:GetCoins(player: Player)
	local playerData = self:GetPlayerData(player)
	if playerData then
		return playerData.Coins
	end	
end

function DataHandlerService:SetCoins(player: Player, newCoins: number)
	local playerData = self:GetPlayerData(player)
	if playerData then
		local previousCoins = playerData.Coins
		local updatedCoins = previousCoins + newCoins
		self:SetPlayerData(player, { Coins = updatedCoins })
	end
end

function DataHandlerService:KnitInit() end

function DataHandlerService:KnitStart()
	Main()
end

return DataHandlerService
