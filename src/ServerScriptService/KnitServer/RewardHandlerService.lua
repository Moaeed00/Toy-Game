--[Services]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--[Modules]
local Knit = require(ReplicatedStorage.Packages.Knit)
local Format = require(ReplicatedStorage.Libraries.Format)

local FootballsConfig = require(ReplicatedStorage.Configuration.Footballs.FootballsConfig)
local EntitiesConfig = require(ReplicatedStorage.Configuration.Brainrots.EntitiesConfiguration)

local RewardHandlerService = Knit.CreateService({
	Name = "RewardHandlerService",
	Client = {
		OnPurchaseNotification = Knit.CreateSignal(),
	},
})

local DataHandlerService

local RewardHandlers = {}

function RewardHandlers.Football(player: Player, RewardData: {}, _mode: string)
	local FootballShopService = Knit.GetService("FootballShopService")
	local data = DataHandlerService:GetPlayerData(player)
	local footballName = RewardData.ItemName
	local footballData = FootballsConfig[footballName]
	local footballId = footballData.Id

	if footballData then
		table.insert(data.Footballs.Owned, footballId)
		FootballShopService.Client.UpdateClientDataEvent:Fire(player, data.Footballs)
		-- FootballShopService:EquipFootball(player, footballName)
	end
end

function RewardHandlers.Brainrot(player: Player, RewardData: {}, _mode: string)
	local BaseService = Knit.GetService("BaseService")
	local brainrotName
	local brainrotRarity

	if RewardData.Random then
		local totalWeight = 0
		local pool = {}
		for rarityName, rarityGroup in pairs(EntitiesConfig) do
			if type(rarityGroup) == "table" then
				for name, brainrotData in pairs(rarityGroup) do
					if brainrotData.RarityWeight then
						totalWeight += brainrotData.RarityWeight
						table.insert(pool, { Name = name, Rarity = rarityName, Weight = brainrotData.RarityWeight })
					end
				end
			end
		end

		if #pool == 0 then
			warn("[RewardHandlerService] EntitiesConfig has no weighted entries")
			return
		end

		local roll = math.random(1, totalWeight)
		local cumulative = 0
		for _, entry in ipairs(pool) do
			cumulative += entry.Weight
			if roll <= cumulative then
				brainrotName = entry.Name
				brainrotRarity = entry.Rarity
				break
			end
		end
	else
		brainrotName = RewardData.Name

		for rarityName, rarityGroup in pairs(EntitiesConfig) do
			if type(rarityGroup) == "table" then
				if rarityGroup[brainrotName] then
					brainrotRarity = rarityName
					break
				end
			end
		end
	end

	if not brainrotName or not brainrotRarity then
		warn("[RewardHandlerService] Could not resolve brainrot or rarity:", brainrotName)
		return
	end

	BaseService:GiveTool(player, brainrotRarity, brainrotName, nil)
	RewardHandlerService.Client.OnPurchaseNotification:Fire(player, `You Got {brainrotName} Brainrot`)
end

function RewardHandlers.Money(player: Player, RewardData: {}, _mode: string)
	local Amount = RewardData.Amount
	DataHandlerService:UpdateMoney(player, Amount)
	RewardHandlerService.Client.OnPurchaseNotification:Fire(
		player,
		`Successfully Purchased ${Format.commaNumber(RewardData.Amount)} Money`
	)
end

function RewardHandlers.Steal(Player: Player, _RewardData: {}, Mode: string)
	if Mode == "Unlock" then
		local StealService = Knit.GetService("StealService")
		StealService:Steal(Player)
	elseif Mode == "SaveFromSteal" then
		local StealChallengeService = Knit.GetService("StealChallengeService")
		StealChallengeService:HandleRobuxRejection(Player)
	end
end

function RewardHandlers.Bundle(Player: Player, RewardData: {}, Mode: string)
	for _, reward in ipairs(RewardData) do
		local handler = RewardHandlers[reward.Type]
		if handler then
			handler(Player, reward.Data, Mode)
		end
	end
end

function RewardHandlerService:GiveReward(Player: Player, RewardType: string, RewardData: {}, Mode: string?)
	local handler = RewardHandlers[RewardType]
	if handler then
		handler(Player, RewardData, Mode or "Default")
	end
end

function RewardHandlerService:KnitInit()
	DataHandlerService = Knit.GetService("DataHandlerService")
end

function RewardHandlerService:KnitStart() end

return RewardHandlerService
