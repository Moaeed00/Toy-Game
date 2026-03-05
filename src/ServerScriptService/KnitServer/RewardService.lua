local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FootballsConfig = require(ReplicatedStorage.Configuration.Footballs.FootballsConfig)
local DataStoreHandler = require(script.Parent.DataHandlerService)
local Knit = require(ReplicatedStorage.Packages.Knit)

local RewardService = Knit.CreateService {
    Name = "RewardService",
    Client = {},
}

function RewardService:KnitInit()
end

function RewardService:KnitStart()
    RewardService.FootballShopService = Knit.GetService("FootballShopService")
end

RewardService.Football = function(player: Player, RewardData: {}, _mode: string)
    local data = DataStoreHandler:GetPlayerData(player)
    local footballName = RewardData.ItemName
    local footballData = FootballsConfig[footballName]
    local footballId = footballData.Id

    if footballData then
        table.insert(data.Footballs.Owned, footballId)
        RewardService.FootballShopService.Client.UpdateClientDataEvent:Fire(player, data.Footballs)
        -- RewardService.FootballShopService:EquipFootball(player, footballName)
    end
end

return RewardService