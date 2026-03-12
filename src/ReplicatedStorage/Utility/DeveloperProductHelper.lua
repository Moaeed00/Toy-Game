--[Services]
local MarketplaceService: MarketplaceService = game:GetService("MarketplaceService")

--[Local Variables]
local DeveloperProductHelper = {}

--[Global Function]
function DeveloperProductHelper:GetPrice(ProductId: number, OriginalPrice: number, ProductType: string)
	local Type = ProductType == "GamePass" and Enum.InfoType.GamePass or Enum.InfoType.Product

	local success, productInfo = pcall(function()
		return MarketplaceService:GetProductInfoAsync(ProductId, Type)
	end)

	if success and productInfo.PriceInRobux then
		return productInfo.PriceInRobux
	end

	return OriginalPrice
end

return DeveloperProductHelper
