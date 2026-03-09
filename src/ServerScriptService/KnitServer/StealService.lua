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

function StealService:IsEntityChallenged(entityId: string): boolean
	for _, pendingEntityId in pairs(self._ownerToChallengeEntities) do
		if pendingEntityId == entityId then
			return true
		end
	end
	return false
end

function StealService:Cleanup(OwnerPlayer: Player, StealingPlayer: Player)
	if self._pendingRequest[StealingPlayer.UserId] then
		local ownerId = self._pendingRequest[StealingPlayer.UserId][5]
		self._pendingRequest[StealingPlayer.UserId] = nil
		self._ownerToStealer[tostring(ownerId)] = nil
		self._ownerToChallengeEntities[StealingPlayer.UserId] = nil

		self.Client.Steal:Fire(OwnerPlayer, "CleanUp")
		self.Client.Steal:Fire(StealingPlayer, "CleanUp")
	end
end

function StealService:HandleWinner(stealingPlayer: Player, result: string, ownerPlayer: Player)
	local pendingEntity = self._pendingRequest[stealingPlayer.UserId]

	if not pendingEntity then
		return
	end

	local biomeName = pendingEntity[1]
	local entityName = pendingEntity[2]
	local mutation = pendingEntity[3]
	local entityId = pendingEntity[4]
	local ownerId = tonumber(pendingEntity[5])
	local slotName = pendingEntity[6]

	if result == "Winner" then
		if ownerPlayer.UserId == ownerId then
			BaseService:RemoveEntity(ownerPlayer, entityId, slotName)
		end
		BaseService:GiveTool(stealingPlayer, biomeName, entityName, mutation)
	end
end

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

	BaseService:RemoveEntity(ownerPlayer, entityId)
	BaseService:GiveTool(player, biomeName, entityName, mutation)

	self._pendingRequest[player.UserId] = nil
	self._ownerToStealer[tostring(ownerId)] = nil
end

function StealService:TryToSteal(
	player: Player,
	biomeName: string,
	entityName: string,
	mutationName: string,
	entityId: string,
	ownerId: number,
	challenge: boolean,
	slotName: number
)
	if challenge then
		self._ownerToChallengeEntities[player.UserId] = entityId
	end

	self._pendingRequest[player.UserId] = { biomeName, entityName, mutationName, entityId, ownerId, slotName }
	self._ownerToStealer[tostring(ownerId)] = player.UserId
end

function StealService:KnitInit()
	BaseService = Knit.GetService("BaseService")
end

function StealService:KnitStart()
	self._pendingRequest = {}
	self._ownerToStealer = {}
	self._ownerToChallengeEntities = {}

	self.Client.Steal:Connect(
		function(
			player: Player,
			biomeName: string,
			entityName: string,
			mutationName: string,
			entityId: string,
			ownerId: number,
			challenge: boolean,
			slotName: number
		)
			self:TryToSteal(player, biomeName, entityName, mutationName, entityId, ownerId, challenge, slotName)
		end
	)

	Players.PlayerRemoving:Connect(function(player: Player)
		if player:GetAttribute("InMiniGame") then
			return
		end

		local userId = player.UserId

		if self._pendingRequest[userId] then
			local ownerId = self._pendingRequest[userId][5]
			self._pendingRequest[userId] = nil
			self._ownerToStealer[tostring(ownerId)] = nil
			self._ownerToChallengeEntities[userId] = nil
		end

		local stealerUserId = self._ownerToStealer[tostring(userId)]
		if stealerUserId then
			self._pendingRequest[stealerUserId] = nil
			self._ownerToStealer[tostring(userId)] = nil
			self._ownerToChallengeEntities[stealerUserId] = nil
		end
	end)
end

--RemoteFunctions
function StealService.Client:IsEntityChallenged(_player, entityId)
	return self.Server:IsEntityChallenged(entityId)
end

return StealService
