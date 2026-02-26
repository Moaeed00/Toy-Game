--[Services]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--[Modules]
local Knit = require(ReplicatedStorage.Packages.Knit)

local StealService = Knit.CreateService({
	Name = "StealService",
	Client = {
		Steal = Knit.CreateSignal(),
	},
})

local BaseService

function StealService:Steal(player: Player)
	local pendingEntity = self._pendingRequest[player.UserId]

	if not pendingEntity then
		return
	end

	local biomeName = pendingEntity[1]
	local entityName = pendingEntity[2]
	local mutation = pendingEntity[3]
	local entityId = pendingEntity[4]
	local ownerId = pendingEntity[5]

	local ownerPlayer = Players:GetPlayerByUserId(tonumber(ownerId))
	if not ownerPlayer then
		return
	end

	BaseService:GiveTool(player, biomeName, entityName, mutation)
	BaseService:RemoveEntity(ownerPlayer, entityId)
end

function StealService:TryToSteal(
	player: Player,
	biomeName: string,
	entityName: string,
	mutationName: string,
	entityId: string,
	ownerId: number
)
	self._pendingRequest[player.UserId] = { biomeName, entityName, mutationName, entityId, ownerId }
end

function StealService:KnitInit()
	BaseService = Knit.GetService("BaseService")
end

function StealService:KnitStart()
	self._pendingRequest = {}

	self.Client.Steal:Connect(
		function(
			player: Player,
			biomeName: string,
			entityName: string,
			mutationName: string,
			entityId: string,
			ownerId: number
		)
			self:TryToSteal(player, biomeName, entityName, mutationName, entityId, ownerId)
		end
	)

	Players.PlayerRemoving:Connect(function(player: Player)
		if self._pendingRequest[player.UserId] then
			self._pendingRequest[player.UserId] = nil
		end
	end)
end

return StealService
