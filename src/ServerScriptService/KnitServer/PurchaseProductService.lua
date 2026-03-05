local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local PlayerService = game:GetService("Players")

local FootballsConfig = require(ReplicatedStorage.Configurations.Footballs.FootballsConfig)
local Knit = require(ReplicatedStorage.Packages.Knit)

local PurchaseProductService = Knit.CreateService {
    Name = "PurchaseProductService",
    Client = {},
}

function PurchaseProductService:KnitInit()
end

function PurchaseProductService:KnitStart()
    PurchaseProductService.RewardService = Knit.GetService("RewardService")
    PurchaseProductService.ProductLookup = {}

    self:Initialize()
end

function PurchaseProductService:Initialize()
	for name, data in pairs(FootballsConfig) do
        if data.UnlockID then
            if self.ProductLookup[data.UnlockID] then
                return
            end
            self.ProductLookup[data.UnlockID] = {
                Item = name,
                Mode = "Unlock"
            }
        end
	end
end

function PurchaseProductService:PromptPurchaseHandler(player: Player, id: number)
	local product = self.ProductLookup[id]
	if product then
		MarketplaceService:PromptProductPurchase(player, id)
	else
		warn(("ProductId not found in ProductLookup!"))
	end
end

function MarketplaceService.ProcessReceipt(receiptInfo)
    print(receiptInfo)
	local player = PlayerService:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local product = PurchaseProductService.ProductLookup[receiptInfo.ProductId]
	if not product then
		warn("Unknown ProductId:", receiptInfo.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local itemName = product.Item
	local mode = product.Mode
	local itemData = FootballsConfig[itemName]
	if not itemData then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local handler = PurchaseProductService.RewardService[itemData.Type]

	if not handler then
		warn("No handler for reward type:", itemData.Type)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	handler(player, itemData.RewardData, mode)

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

return PurchaseProductService