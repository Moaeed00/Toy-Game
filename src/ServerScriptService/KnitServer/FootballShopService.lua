local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FootballTools = ReplicatedStorage:WaitForChild("Assets").Tools
local Knit = require(ReplicatedStorage.Packages.Knit)
local DataStoreHandler = require(script.Parent.DataHandlerService)

local FootballsConfig = require(ReplicatedStorage.Configurations.Footballs.FootballsConfig)

local FootballShopService = Knit.CreateService {
	Name = "FootballShopService",
	Client = {
		BuyFootballViaCoinsEvent = Knit.CreateSignal(),
		BuyFootballViaRobuxEvent = Knit.CreateSignal(),
		EquipFootballEvent = Knit.CreateSignal(),
		UpdateClientData = Knit.CreateSignal(),
	}
}

function FootballShopService:KnitInit()
end

function FootballShopService:KnitStart()
    FootballShopService.PlayerData = {}
	
    DataStoreHandler.OnPlayerProfileLoaded:Connect(function(player, profile)
        local footballData = profile.Footballs or {
            Owned = {},
            Equipped = nil
        }
    
        self.PlayerData[player] = footballData
        self.Client.UpdateClientData:Fire(player, footballData)
    end)
	self.Client.BuyFootballViaCoinsEvent:Connect(function(player, footballName)
		self:BuyWithCoins(player, footballName)
	end)
	self.Client.BuyFootballViaRobuxEvent:Connect(function(player, footballName)
		self:GiveFootballViaRobux(player, footballName)
	end)
	self.Client.EquipFootballEvent:Connect(function(player, footballName)
		self:EquipFootball(player, footballName)
	end)
end

function FootballShopService:BuyWithCoins(player: Player, footballName: string)
    local config = FootballsConfig[footballName]
    if not config then
        warn("Invalid football:", footballName)
        return
    end

    local data = DataStoreHandler:GetPlayerData(player)
    if not data then 
        print("no data")
        return 
    end

    -- if self:IsOwned(player, footballName) then
    --     return
    -- end

    local currentCoins = DataStoreHandler:GetCoins(player)
    if currentCoins < config.Price then
        warn(player.Name .. " tried to buy without enough coins")
        return
    end

    DataStoreHandler:SetCoins(player, -config.Price)
    self:EquipFootball(player, footballName)
    self.Client.UpdateClientData:Fire(player, data)
end

function FootballShopService:GiveFootballViaRobux(player, footballName)
    local data = DataStoreHandler:GetPlayerData(player)
    local footballId = FootballsConfig[footballName].Id
    
    if self:IsOwned(player, footballName) then 
        return 
    end
    
    table.insert(data.Owned, footballId)
    self.Client.UpdateClientData:Fire(player, data)
end

function FootballShopService:EquipFootball(player, footballName)
	if not self:IsOwned(player, footballName) then 
        return 
    end
    
	local data = DataStoreHandler:GetPlayerData(player)
	data.Equipped = FootballsConfig[footballName].Id

	self:GiveFootballTool(player, footballName)
	self.Client.UpdateClientData:Fire(player, data)
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

function FootballShopService.Client:GetPlayerData(player: Player)
	return self.PlayerData[player]
end

return FootballShopService