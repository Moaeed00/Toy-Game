local ReplicatedStorage = game:GetService("ReplicatedStorage")

local functions = require(ReplicatedStorage.Shared.Utils.functions)

local TWENTY_FOUR_HOUR = 24

local offlineEarningsUtils = {}

function offlineEarningsUtils.ComputeRewards(
	player: Player,
	moneyMultiplier: number,
	entities: {},
	currentTime: number,
	previousTime: number
)
	local secondSinceLastJoin = currentTime - previousTime
	local timeOffline = math.clamp(secondSinceLastJoin, 0, TWENTY_FOUR_HOUR)

	local sum = 0

	for _, entity in entities do
		local biomeName = entity:GetBiome()
		local entityName = entity:GetName()
		local mutationName = entity:GetMutation()
		local level = entity:GetLevel()

		sum += functions.computeMultiplier(player, biomeName, entityName, mutationName, moneyMultiplier, level)
	end

	local total = math.round((timeOffline * sum) / 5)
	return total
end

return offlineEarningsUtils
