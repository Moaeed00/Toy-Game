local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local RebirthConfiguration = require(ReplicatedStorage.Configuration.RebirthConfiguration)

local DataHandlerService
local BaseService

local RebirthService = Knit.CreateService({
	Name = "RebirthService",
	Client = {
		Rebirth = Knit.CreateSignal(),
	},
})

local function next_money_requiremenet(rebirth: number)
	return RebirthConfiguration.REBIRTH[rebirth + 1]
end

function RebirthService:Rebirth(player: Player)
	local playerBase, data = BaseService:GetPlayerBase(player)
	if not playerBase or not data then
		return
	end

	local rebirth = data.Rebirth
	local money = data.Money

	local moneyRequirement = next_money_requiremenet(rebirth)
	if not moneyRequirement then
		print(`You can't rebirth!`)
		return
	end

	if money < moneyRequirement then
		print(`You need more money to rebirth!`)
		return
	end

	DataHandlerService:ResetMoney(player)
	BaseService:DoRebirth(player)
end

function RebirthService:KnitInit()
	DataHandlerService = Knit.GetService("DataHandlerService")
	BaseService = Knit.GetService("BaseService")
end

function RebirthService:KnitStart()
	self.Client.Rebirth:Connect(function(player: Player)
		self:Rebirth(player)
	end)
end

return RebirthService
