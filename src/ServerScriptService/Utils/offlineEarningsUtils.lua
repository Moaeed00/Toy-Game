local ReplicatedStorage = game:GetService("ReplicatedStorage")

local functions = require(ReplicatedStorage.Shared.Utils.functions)

local TWENTY_FOUR_HOUR = 24

local offlineEarningsUtils = {}

function offlineEarningsUtils.ComputeRewards(
	player: Player,
	entity: {},
	currentTime: number,
	previousTime: number,
	offlineMoney: number
)
	local secondSinceLastJoin = currentTime - previousTime
	local timeOffline = math.clamp(secondSinceLastJoin, 0, TWENTY_FOUR_HOUR)

	if not entity then
		return 0
	end

	local biomeName = entity:GetBiome()
	local entityName = entity:GetName()
	local mutationName = entity:GetMutation()

	local sum = functions.computeMultiplier(player, biomeName, entityName, mutationName)

	local total = math.round((timeOffline * sum) / 5)

	if offlineMoney > 0 then
		total += offlineMoney
	end

	if total and total < 0 then
		return 0
	end

	return total
end

return offlineEarningsUtils
