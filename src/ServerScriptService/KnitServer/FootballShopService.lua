local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FootballTools = ReplicatedStorage:WaitForChild("Assets").Tools
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
	FootballShopService.PurchaseProductService = Knit.GetService("PurchaseProductService")
    FootballShopService.PlayerData = {}

    DataStoreHandler.OnPlayerProfileLoaded:Connect(function(player, profile)
        local footballData = profile.Footballs or {
            Owned = { 1 },
            Equipped = 1
        }
        self.PlayerData[player] = footballData
        self.Client.UpdateClientDataEvent:Fire(player, footballData)
    end)
	self.Client.BuyFootballViaRobuxEvent:Connect(function(player, footballName)
		self:GiveFootballViaRobux(player, footballName)
	end)
	self.Client.EquipFootballEvent:Connect(function(player, footballName)
		self:EquipFootball(player, footballName)
	end)
end

function FootballShopService:GiveFootballViaRobux(player, footballName)
	local footballUnlockId = FootballsConfig[footballName].UnlockID
	self.PurchaseProductService:PromptPurchaseHandler(player, footballUnlockId)
end

function FootballShopService:EquipFootball(player, footballName)
	if not self:IsOwned(player, footballName) then
        return
    end

	local data = DataStoreHandler:GetPlayerData(player)
	data.Footballs.Equipped = FootballsConfig[footballName].Id

	self:GiveFootballTool(player, footballName)
	self.Client.UpdateClientDataEvent:Fire(player, data)
end

function FootballShopService:GiveFootballTool(player: Player, footballName: string)
	local newTool: Tool = FootballTools:FindFirstChild(footballName)
	if not newTool then
        return
    end

	-- remove old football tools
	for _, tool in ipairs(player.Backpack:GetChildren()) do
		if FootballTools:FindFirstChild(tool.Name) then
			tool:Destroy()
		end
	end

	for _, tool in ipairs(player.Character:GetChildren()) do
		if tool:IsA("Tool") then
			tool:Destroy()
		end
	end

	newTool:Clone().Parent = player.Backpack
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

	local currentCoins = DataStoreHandler:GetCoins(player)
	if currentCoins < config.Price then
		return {
			Success = false,
			CoinsRequired = config.Price - currentCoins
		}
	end

	DataStoreHandler:SetCoins(player, -config.Price)
	table.insert(data.Footballs.Owned, config.Id)
	self.Server:EquipFootball(player, footballName)
	self.Server.UpdateClientDataEvent:Fire(player, data)
	return {
		Success = true,
		FootballName = footballName
	}
end

function FootballShopService.Client:GetPlayerData(player: Player)
	return self.PlayerData[player]
end

return FootballShopService