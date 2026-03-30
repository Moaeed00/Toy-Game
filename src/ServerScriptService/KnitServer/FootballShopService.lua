local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataStoreHandler = require(script.Parent.DataHandlerService)
local Knit = require(ReplicatedStorage.Packages.Knit)

local FootballsConfig = require(ReplicatedStorage.Configuration.Footballs.FootballsConfig)

local FootballShopService = Knit.CreateService {
	Name = "FootballShopService",
	Client = {
		BuyFootballViaRobuxEvent = Knit.CreateSignal(),
		EquipFootballEvent = Knit.CreateSignal(),
		UpdateClientDataEvent = Knit.CreateSignal(),
	}
}

function FootballShopService:KnitInit()
end

function FootballShopService:KnitStart()
	FootballShopService.FootballService = Knit.GetService("FootballService")
	FootballShopService.TutorialService = Knit.GetService("TutorialService")
    FootballShopService.PlayerData = {}

    DataStoreHandler.OnPlayerProfileLoaded:Connect(function(player, profile)
        local footballData = profile.Footballs or {
            Owned = {},
            Equipped = 0
        }
        self.PlayerData[player] = footballData
        self.Client.UpdateClientDataEvent:Fire(player, footballData)
    end)
	self.Client.EquipFootballEvent:Connect(function(player, footballName)
		self:EquipFootball(player, footballName)
	end)
end

function FootballShopService:EquipFootball(player, footballName)
	if not self:IsOwned(player, footballName) then
        return
    end

	local data = DataStoreHandler:GetPlayerData(player)
	data.Footballs.Equipped = FootballsConfig[footballName].Id

	self.FootballService:GiveFootball(player)
	self.Client.UpdateClientDataEvent:Fire(player, data.Footballs)
end

function FootballShopService:IsOwned(player, footballName)
	local data = DataStoreHandler:GetPlayerData(player)
	if not data or not data.Footballs then
		return false
	end

	local footballId = FootballsConfig[footballName].Id

	for _, ownedId in ipairs(data.Footballs.Owned) do
		if ownedId == footballId then
			return true
		end
	end

	return false
end

function FootballShopService.Client:BuyFootballViaCoins(player: Player, footballName: string)
	local config = FootballsConfig[footballName]
	if not config then
		warn("Invalid football:", footballName)
		return
	end

	local data = DataStoreHandler:GetPlayerData(player)
	if not data then
		return
	end

	local currentCoins = DataStoreHandler:GetMoney(player)
	if currentCoins < config.Price then
		return {
			Success = false,
			CoinsRequired = config.Price - currentCoins
		}
	end

	DataStoreHandler:DeductMoney(player, config.Price)
	table.insert(data.Footballs.Owned, config.Id)
	self.Server:EquipFootball(player, footballName)

	self.Server.TutorialService:NotifyFootballBought(player)
	return {
		Success = true,
		FootballName = footballName
	}
end

function FootballShopService.Client:GetPlayerData(player: Player)
	return self.PlayerData[player]
end

return FootballShopService