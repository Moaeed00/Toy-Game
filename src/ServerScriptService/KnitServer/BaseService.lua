local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Knit = require(ReplicatedStorage.Packages.Knit)

local AttributesConfiguration = require(ReplicatedStorage.Configuration.AttributesConfiguration)
local EntitiesConfiguration = require(ReplicatedStorage.Configuration.Brainrots.EntitiesConfiguration)
local getBiomeByEntity = require(ReplicatedStorage.Shared.Utils.getBiomeByEntity)
local PlayerBase = require(ServerScriptService.Classes.Base.PlayerBase)
local entityUtils = require(ServerScriptService.Utils.entityUtils)
local worldUtils = require(ServerScriptService.Utils.worldUtils)
local Format = require(ReplicatedStorage.Libraries.Format)
-- local Signal = require(ReplicatedStorage.Libraries.Signal)

local SELL_FACTOR = EntitiesConfiguration.Original.SELL_FACTOR

local TotalLikes
local LikesService
local TimerService
local IndexSevice
local DataHandlerService

local BaseService = Knit.CreateService({
	Name = "BaseService",
	Client = {
		ReplicatedOthersBase = Knit.CreateSignal(),
		PlaceEntity = Knit.CreateSignal(),
		TakeEntity = Knit.CreateSignal(),
		SellEntity = Knit.CreateSignal(),
		RemoveEntityInBase = Knit.CreateSignal(),
		BaseCreated = Knit.CreateSignal(),
	},
})

function BaseService:KnitInit()
	DataHandlerService = Knit.GetService("DataHandlerService")
	TimerService = Knit.GetService("TimerService")
	LikesService = Knit.GetService("LikesService")
	IndexSevice = Knit.GetService("IndexService")
end

function BaseService:KnitStart()
	self._activeBases = {}

	DataHandlerService.OnPlayerProfileLoaded:Connect(function(player)
		--local base = self:GetPlayerBase(player)
		--if not base then
		self:CreateBase(player)
		BaseService:ReplicateOthersBase(player)
		--	base:LoadTools()
		--	base:LoadEntities()
		--else
		--	base:LoadTools()
		--	base:LoadEntities()
		--end
	end)

	--Players.PlayerAdded:Connect(function(player: Player)
	--	local base = self:GetPlayerBase(player)
	--	if not base then
	--		self:CreateBase(player)
	--	end
	--end)

	Players.PlayerRemoving:Connect(function(player: Player)
		self:DestroyBase(player)
		DataHandlerService:SetPlayerData(player, { LastJoin = os.time() })
	end)

	self.Client.PlaceEntity:Connect(function(player: Player, slotName: string)
		self:PlaceEntity(player, slotName)
	end)

	self.Client.SellEntity:Connect(function(player: Player, entityId: string)
		self:SellEntity(player, entityId)
	end)

	self.Client.TakeEntity:Connect(function(player: Player, entityId: string)
		self:TakeEntity(player, entityId)
	end)

	self.Client.ReplicatedOthersBase:Connect(function(player: Player)
		self:ReplicateOthersBase(player)
	end)
end

function BaseService:ReplicateOthersBase(to: Player)
	for _, base in self._activeBases do
		local player = base:GetPlayer()
		if player == to then
			continue
		end

		local baseId = base:GetId()
		local entities = base:GetEntities()

		for entityId, entity in entities do
			local mutationName = entity:GetMutation()
			local biomeName = entity:GetBiome()
			local entityName = entity:GetName()
			local slot = entity:GetSlot()

			self.Client.PlaceEntity:Fire(to, baseId, entityId, biomeName, entityName, mutationName, slot.Name)
		end
	end
end

function BaseService:TakeEntity(player: Player, entityId: string)
	local playerBase, playerProfile = self:GetPlayerBase(player)
	if not playerBase or not playerProfile then
		return
	end

	local entity = playerBase:GetEntityById(entityId)
	if not entity then
		return
	end

	local mutationName = entity:GetMutation()
	local pendingMoney = entity:GetPending()
	local offlineMoney = entity:GetOffline()
	local biomeName = entity:GetBiome()
	local entityName = entity:GetName()

	self:RemoveEntity(player, entityId)
	self:UpdateMoney(player, pendingMoney)
	self:UpdateMoney(player, offlineMoney)
	self:GiveTool(player, biomeName, entityName, mutationName)
end

function BaseService:RemoveEntityFromBase(player: Player, slotName: string)
	local data = self:GetPlayerData(player)
	if not data or not data.Base then
		return
	end

	slotName = tostring(slotName)

	if not data.Base[slotName] then
		return
	end

	data.Base[slotName] = nil

	self:SetPlayerData(self._player, "Base", data.Base)
end

function BaseService:RemoveEntity(player: Player, entityId: string, slotName: number)
	if slotName then
		self:RemoveEntityFromBase(player, slotName)
	end

	local playerBase, playerProfile = self:GetPlayerBase(player)

	if not playerBase or not playerProfile then
		return
	end

	local entity = playerBase:GetEntityById(entityId)

	if not entity then
		return
	end

	playerBase:RemoveEntity(entityId)
end

function BaseService:SellEntity(player: Player, entityId: string)
	local playerBase, playerProfile = self:GetPlayerBase(player)
	if not playerBase or not playerProfile then
		return
	end

	local entity = playerBase:GetEntityById(entityId)
	if not entity then
		return
	end

	local entityName = entity:GetName()
	local entityData = entity:GetData()
	local sellPrice = math.floor(entityData.MoneyPerSec * (SELL_FACTOR * 100))

	local _, data = getBiomeByEntity(entityName)

	self:RemoveEntity(player, entityId)
	self:UpdateMoney(player, sellPrice)

	--Send Client Notification
	print(`{data.DisplayName or "Unknown"} sold for ${Format.abbreviate(sellPrice)}`)
end

function BaseService:PlaceEntity(player: Player, slotName: string)
	local entity = entityUtils.getEquippedEntity(player)
	local playerBase = self:GetPlayerBase(player)
	if not entity or not playerBase then
		return
	end

	local mutationName = entity:GetAttribute(AttributesConfiguration.MUTATION)
	local biomeName = entity:GetAttribute(AttributesConfiguration.BIOME)
	local entityId = entity:GetAttribute(AttributesConfiguration.ID)
	local entityName = entity.Name

	local baseModel = playerBase:GetBaseModel()

	local slotPart = baseModel.Grid:FindFirstChild(slotName)
	if not slotPart then
		return
	end
	if slotPart:GetAttribute(AttributesConfiguration.SLOT_TAKEN) then
		return
	end

	playerBase:PlaceEntity(biomeName, entityName, mutationName, slotPart)
	self:ReleaseTool(player, entityId)
	entity:Destroy()
end

function BaseService:GiveTool(player: Player, biomeName: string, entityName: string, mutationName: string)
	local playerBase = self:GetPlayerBase(player)
	if not playerBase then
		return
	end

	local _, toolId = entityUtils.createEntityTool(player, biomeName, entityName, mutationName)
	playerBase:StoreTool(toolId, biomeName, entityName, mutationName)
end

function BaseService:ReleaseTool(player: Player, toolId: string)
	local playerBase = self:GetPlayerBase(player)
	if not playerBase then
		return
	end

	playerBase:ReleaseTool(toolId)
end

function BaseService:CreateBase(player: Player)
	local availableSlot = worldUtils.getAvailableSlot()

	if not availableSlot then
		return
	end

	local playerData = self:GetPlayerData(player)

	local playerBase = PlayerBase.new(self, TimerService, player, availableSlot, playerData.MoneyMultiplier)
	local key = tostring(player.UserId)

	self._activeBases[key] = playerBase
	self.Client.BaseCreated:Fire(player)

	TotalLikes = DataHandlerService:GetTotalLikes(player)
	playerBase:UpdateLikes(TotalLikes)
	LikesService:BroadcastLikeUpdate(player.UserId, TotalLikes)
	self:NotifyAlreadyLikedPlayers(player)
	self:AttachLikePromptHandler(player, playerBase)
	IndexSevice:ApplySavedBaseColor(player)
end

function BaseService:NotifyAlreadyLikedPlayers(owner: Player)
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer == owner then
			continue
		end

		local otherData = DataHandlerService:GetPlayerData(otherPlayer)
		if not otherData or not otherData.LikedPlayers then
			continue
		end

		-- check if this player already liked the owner's base
		if otherData.LikedPlayers[tostring(owner.UserId)] then
			print("[BaseService]", otherPlayer.Name, "already liked", owner.Name, "— hiding prompt")
			LikesService.Client.OnPromptHide:Fire(otherPlayer, owner.UserId)
		end
	end
end

function BaseService:AttachLikePromptHandler(owner: Player, playerBase)
	local baseModel = playerBase:GetBaseModel()
	if not baseModel then
		return
	end

	local surface = baseModel.Sign.Surface
	local prompt = surface:FindFirstChild("LikePrompt")
	if not prompt then
		warn(" No LikePrompt found on base for", owner.Name)
		return
	end

	prompt.Triggered:Connect(function(triggeringPlayer: Player)
		if triggeringPlayer == owner then
			return
		end
		local success, result = DataHandlerService:AddLike(triggeringPlayer, owner)

		if not success then
			print("Like rejected:", result)
			return
		end

		local newCount = result
		print("[BaseService]", triggeringPlayer.Name, "liked", owner.Name, "| Total:", newCount)

		playerBase:UpdateLikes(newCount)
		LikesService:BroadcastLikeUpdate(owner.UserId, newCount)

		LikesService.Client.OnPromptHide:Fire(triggeringPlayer, owner.UserId)
	end)
end

function BaseService:OnAllRemoveEntityRemote(playerUserId: number, id: string)
	self.Client.RemoveEntityInBase:FireAll(playerUserId, id)
end

function BaseService:OnAllPlaceEntityRemote(
	playerUserId: number,
	id: string,
	biomeName: string,
	entityName: string,
	mutationName: string,
	slotName: number
)
	self.Client.PlaceEntity:FireAll(playerUserId, id, biomeName, entityName, mutationName, slotName)
end

function BaseService:UpdateMoney(player: Player, sellPrice: number)
	DataHandlerService:UpdateMoney(player, sellPrice)
end

function BaseService:GetPlayerData(player: Player)
	return DataHandlerService:GetPlayerData(player)
end

function BaseService:SetPlayerData(player: Player, name: string, result: {})
	local saveTable = {}
	saveTable[name] = result
	print("saveTable", saveTable)
	DataHandlerService:SetPlayerData(player, saveTable)
end

function BaseService:DestroyBase(player: Player)
	local playerBase = self:GetPlayerBase(player)
	if not playerBase then
		return
	end

	local key = tostring(player.UserId)
	playerBase:Destroy()
	self._activeBases[key] = nil
end

function BaseService:GetPlayerBase(player: Player)
	local key = tostring(player.UserId)

	local playerBase = self._activeBases[key]
	if not playerBase then
		return nil
	end

	local data = self:GetPlayerData(player)
	if not data then
		return playerBase, nil
	end

	return playerBase, data
end

return BaseService
