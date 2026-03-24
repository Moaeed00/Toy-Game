--[Services]
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService: MarketplaceService = game:GetService("MarketplaceService")
local PlayerService: Players = game:GetService("Players")

--[Folders]
local Configuration: Folder = ReplicatedStorage:WaitForChild("Configuration")

--[Knit]
local Knit: {} = require(ReplicatedStorage.Packages.Knit)

--[Modules]
local StealConfiguration: {} = require(Configuration:WaitForChild("StealConfiguration"))
local FootballsConfig: {} = require(Configuration.Footballs.FootballsConfig)
local ProductStoreData: {} = require(Configuration:WaitForChild("ProductStoreData"))
local LobbyHudConfigurations: {} = require(Configuration:WaitForChild("LobbyHudConfigurations"))

--[Shop Tables]
local AllShops = {
	StealConfiguration = StealConfiguration,
	FootballsConfig = FootballsConfig,
	ProductStoreData = ProductStoreData,
	LobbyHudConfigurations = LobbyHudConfigurations,
}

--[Lookup Table]
local ProductLookup = {}
local GiftingPlayers = {}

--[Services]
local RewardHandlerService
local DataHandlerService

local ProductPurchaseService = Knit.CreateService({
	Name = "ProductPurchaseService",
	Client = {
		PromptPurchase = Knit.CreateSignal(),
	},
})

--[Local Functions]
local function GrantProduct(player: Player, product: {})
	local item = product.Item
	local mode = product.Mode

	local GamePasses = DataHandlerService:GetGamePasses(player)
	if GamePasses then
		GamePasses[item.Title] = true
	end

	RewardHandlerService:GiveReward(player, item.Type, item.RewardData, mode)
end

local function onGamePassPromptPurchaseFinished(player: Player, PurchasedPassID: number, PurchaseSuccess: boolean)
	if PurchaseSuccess then
		local product = ProductLookup[PurchasedPassID]
		if not product then
			warn("Unknown ProductId:", PurchasedPassID)
			return
		end

		--GamePassStoreEvent:FireClient(player, "PurchaseSuccessfull", product.Item.Title)

		GrantProduct(player, product)
	end
end

local function PromptPurchaseHandler(player: Player, ID: number, PlayerIdToGift: number)
	local product = ProductLookup[ID]

	if product.Mode == "Gift" then
		local item = product.Item

		if item.Category == "GamePass" then
			local GiftedPlayer = PlayerService:GetPlayerByUserId(PlayerIdToGift)
			local GamePasses = DataHandlerService:GetGamePasses(GiftedPlayer)

			if GamePasses and (GamePasses[item.Title] == true) then
				--GiftEvent:FireClient(player, GiftedPlayer.DisplayName, item.Title)
				return
			end
		end

		GiftingPlayers[player.UserId] = PlayerIdToGift
	end

	if product then
		MarketplaceService:PromptProductPurchase(player, ID, false)
	else
		warn("ProductId not found in ProductLookup!")
	end
end

local function Initialize()
	for shopName, shop in pairs(AllShops) do
		for _, item in pairs(shop) do
			if item.Id then
				if ProductLookup[item.Id] then
					warn(("Duplicate ProductId %d found in %s and another shop!"):format(item.Id, shopName))
				end
				ProductLookup[item.Id] = {
					Item = item,
					Mode = "Give",
				}
			end

			if item.UnlockID then
				if ProductLookup[item.UnlockID] then
					warn(("Duplicate UnlockID %d found in %s and another shop!"):format(item.UnlockID, shopName))
				end
				ProductLookup[item.UnlockID] = {
					Item = item,
					Mode = "Unlock",
				}
			end

			if item.GiftId then
				if ProductLookup[item.GiftId] then
					warn(("Duplicate UnlockID %d found in %s and another shop!"):format(item.GiftId, shopName))
				end
				ProductLookup[item.GiftId] = {
					Item = item,
					Mode = "Gift",
				}
			end

			if item.SaveFromStellID then
				if ProductLookup[item.SaveFromStellID] then
					warn(("Duplicate UnlockID %d found in %s and another shop!"):format(item.SaveFromStellID, shopName))
				end
				ProductLookup[item.SaveFromStellID] = {
					Item = item,
					Mode = "SaveFromSteal",
				}
			end
		end
	end

	--DataHandlerService.OnPlayerProfileLoaded:Connect(function(player, playerData)
	--	local GamePasses = DataHandlerService:GetGamePasses(player)

	--	for _, GamePassData in ipairs(GamePassStoreData) do
	--		if GamePassData.Id and ProductLookup[GamePassData.Id] then
	--			local hasPass = false

	--			local success, message = pcall(function()
	--				hasPass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, GamePassData.Id)
	--			end)

	--			if not success then
	--				warn("Error while checking if player has pass: " .. tostring(message))
	--			end

	--			-- Check in player datastore in gamepasses as well
	--			if GamePasses[GamePassData.Title] then
	--				hasPass = true
	--			end

	--			if hasPass then
	--				local product = ProductLookup[GamePassData.Id]
	--				GrantProduct(player, product)
	--			end

	--		end
	--	end

	--	-- Send Owned GamePasses
	--	GamePassStoreEvent:FireClient(player, "OwnedGamePasses", nil, GamePasses)
	--end)

	ProductPurchaseService.Client.PromptPurchase:Connect(PromptPurchaseHandler)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onGamePassPromptPurchaseFinished)
end

--[Process Receipt]
function MarketplaceService.ProcessReceipt(receiptInfo)
	local player = PlayerService:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local product = ProductLookup[receiptInfo.ProductId]
	if not product then
		warn("Unknown ProductId:", receiptInfo.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local item = product.Item
	local mode = product.Mode

	if mode == "Gift" then
		local GiftedPlayerID = GiftingPlayers[player.UserId]
		local GiftedPlayer = PlayerService:GetPlayerByUserId(GiftedPlayerID)

		if GiftedPlayer then
			if item.Category == "GamePass" then
				--GiftAnnouncementEvent:FireAllClients(player, GiftedPlayer, `{item.Title} GamePass`)
				--GamePassStoreEvent:FireClient(GiftedPlayer, "PurchaseSuccessfull", item.Title)

				GrantProduct(GiftedPlayer, product)
			else
				--GiftAnnouncementEvent:FireAllClients(player, GiftedPlayer, `{item.Title} Coins`)
				RewardHandlerService:GiveReward(GiftedPlayer, item.Type, item.RewardData, mode)
			end

			GiftingPlayers[player.UserId] = nil
		end
	else
		RewardHandlerService:GiveReward(player, item.Type, item.RewardData, mode)
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ProductPurchaseService:KnitInit()
	RewardHandlerService = Knit.GetService("RewardHandlerService")
	DataHandlerService = Knit.GetService("DataHandlerService")
end

function ProductPurchaseService:KnitStart()
	Initialize()
end

return ProductPurchaseService
