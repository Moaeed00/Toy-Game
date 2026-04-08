local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local RebirthConfiguration = require(ReplicatedStorage.Configuration.RebirthConfiguration)

local DataHandlerService
local BaseService
local GameAnalyticsService

local RebirthService = Knit.CreateService({
	Name = "RebirthService",
	Client = {
		Rebirth = Knit.CreateSignal(),
	},
})

function RebirthService:KnitInit()
	DataHandlerService = Knit.GetService("DataHandlerService")
	BaseService = Knit.GetService("BaseService")
	GameAnalyticsService = Knit.GetService("GameAnalyticsService")
end

function RebirthService:KnitStart()
	self.Client.Rebirth:Connect(function(player: Player)
		self:Rebirth(player)
	end)
end

local function next_money_requirement(rebirth: number)
	return RebirthConfiguration.REBIRTH[rebirth + 1].MoneyRequired
end

local function next_money_reward(rebirth: number)
	return RebirthConfiguration.REBIRTH[rebirth + 1].MoneyReward
end

function RebirthService:Rebirth(player: Player)
	local playerBase, data = BaseService:GetPlayerBase(player)
	if not playerBase or not data then
		return
	end

	local rebirth = data.Rebirth
	local money = data.Money

	local moneyRequirement = next_money_requirement(rebirth)
	if not moneyRequirement then
		print(`You can't rebirth!`)
		return
	end

	if money < moneyRequirement then
		print(`You need more money to rebirth!`)
		return
	end

	local moneyReward = next_money_reward(rebirth)
	BaseService:DoRebirth(player)
	GameAnalyticsService:TrackFunnelStep(player, "rebirth_used")
	DataHandlerService:UpdateMoney(player, moneyReward)
end

return RebirthService