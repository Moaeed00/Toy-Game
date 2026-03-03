--[Services]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--[Modules]
local Knit = require(ReplicatedStorage.Packages.Knit)

local RewardHandlerService = Knit.CreateService({
	Name = "RewardHandlerService",
	Client = {},
})

-- local DataHandlerService

local RewardHandlers = {}

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
	-- DataHandlerService = Knit.GetService("DataHandlerService")
end

function RewardHandlerService:KnitStart() end

return RewardHandlerService
