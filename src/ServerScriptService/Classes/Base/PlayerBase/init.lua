local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AttributesConfiguration = require(ReplicatedStorage.Configuration.AttributesConfiguration)
local getPlayerCharacter = require(ReplicatedStorage.Shared.Utils.getPlayerCharacter)
local observeCharacter = require(ReplicatedStorage.Shared.Observers.observeCharacter)
local EntityInBase = require(ServerScriptService.Classes.Base.EntityInBase)
local entityUtils = require(ServerScriptService.Utils.entityUtils)
local Class = require(ReplicatedStorage.Shared.Modules.Class)
local whenBaseDestroyed = require(script.whenBaseDestroyed)
local getBiomeByEntity = require(ReplicatedStorage.Shared.Utils.getBiomeByEntity)
local offlineEarningsUtils = require(ServerScriptService.Utils.offlineEarningsUtils)
local Trove = require(ReplicatedStorage.Libraries.Trove)
local createBaseModel = require(script.createBaseModel)

export type PlayerBase = {
	_player: Player,
	_slot: BasePart,
	--_profile: DataServer.Profile,
	_level: number,

	_baseModel: Model,
	--_entitiesInBases: { [string]: EntityInBase.EntityInBase },
	_backpack: {},

	-- _connections: Trove.Trove,

	--PlaceEntity: (self: PlayerBase, biomeName: string, entityName: string, mutationName: string, slotPart: BasePart) -> EntityInBase.EntityInBase,
	StoreTool: (self: PlayerBase, toolId: string, biomeName: string, entityName: string, mutationName: string) -> (),
	--GetEntityById: (self: PlayerBase, entityId: string) -> EntityInBase.EntityInBase,
	ReleaseTool: (self: PlayerBase, toolId: string) -> (),
	TeleportPlayer: (self: PlayerBase) -> (),
	GetBaseModel: (self: PlayerBase) -> Model,
	GetPlayer: (self: PlayerBase) -> Player,
	GetSlot: (self: PlayerBase) -> BasePart,
	SaveBackpack: (self: PlayerBase) -> (),
	LoadEntities: (self: PlayerBase) -> (),
	RemoveEntity: (self: PlayerBase) -> (),
	GetBackpack: (self: PlayerBase) -> { [string]: string },
	WhenPlayerDie: (self: PlayerBase) -> (),
	LevelUp: (self: PlayerBase) -> (),
	LoadTools: (self: PlayerBase) -> (),
	SaveBase: (self: PlayerBase) -> (),
	Destroy: (self: PlayerBase) -> (),
	UnsafeToolsLoad: (self: PlayerBase) -> (),
	Init: (self: PlayerBase) -> (),
}
export type constructor = PlayerBase & {
	new: (player: Player, slot: BasePart) -> PlayerBase,
}

local PlayerBase: constructor = Class(
	function(self: PlayerBase, service: {}, timerservice: {}, player: Player, slot: BasePart, MoneyMultiplier: number)
		self._service = service
		self._timerservice = timerservice
		self._player = player
		self._slot = slot
		self._moneyMultiplier = MoneyMultiplier

		if slot then
			slot:SetAttribute(AttributesConfiguration.SLOT_TAKEN, true)
		end

		self._baseModel = createBaseModel(player, slot)
		self._defaultCharacter = getPlayerCharacter(player)

		self._entitiesInBases = {}
		self._backpack = {}

		self._connections = Trove.new()

		self:Init()
	end
)

function PlayerBase.LoadStagesFromLevel(self: PlayerBase)
	local data = self:GetPlayerData()

	for i = 1, data.Rebirth do
		self:CreateStage(i, i == data.Rebirth)
	end
end

function PlayerBase.CreateStage(self: PlayerBase, id: number, lock: boolean)
    if id > 5 then
        return
    end

    local stageNumber = math.clamp(id, 1, 5)

    local stageTemplate = ServerStorage.Assets.Stages:FindFirstChild(`Stage{stageNumber}`)
    if not stageTemplate then
        return
    end

    local stage = stageTemplate:Clone()
    stage:PivotTo(self._baseModel.Primary.CFrame)

    if lock then
        stage.RoofHole.Transparency = 0
        stage.RoofHole.CanCollide = true
        stage.RoofHole.CanQuery = true
    end

    stage.Name = tostring(stageNumber)

    for _, slot in stage.Grid:GetChildren() do
        slot.Parent = self._baseModel.Grid
    end

    stage.Parent = self._baseModel.Stages

    local prevStageNumber = stageNumber - 1
    if prevStageNumber >= 1 then
        local prevStage = self._baseModel.Stages:FindFirstChild(tostring(prevStageNumber))
        if prevStage and prevStage:FindFirstChild("RoofHole") then
            prevStage.RoofHole.Transparency = 1
            prevStage.RoofHole.CanCollide = false
            prevStage.RoofHole.CanQuery = false
        end
    else
        self._baseModel.RoofHole.Transparency = 1
        self._baseModel.RoofHole.CanCollide = false
        self._baseModel.RoofHole.CanQuery = false
    end
end

function PlayerBase.DoRebirth(self: PlayerBase, playerData: {})
	self:RemoveAllEntities()
	local nextLevel = playerData.Rebirth + 1

	self:CreateStage(nextLevel, true)
end

function PlayerBase.RemoveAllEntities(self: PlayerBase)
	local ids = {}
	for id in self._entitiesInBases do
		ids[#ids + 1] = id
	end

	for _, id in ids do
		self:RemoveEntity(id)
	end

	self._backpack = {}

	local Player = self:GetPlayer()
	entityUtils.clearBrainrotTools(Player)
end

function PlayerBase.RemoveFromBaseEarning(self: PlayerBase, entityName: string)
	local _biome, entityData = getBiomeByEntity(entityName)
	if entityData then
		local moneyPerSec = math.floor(entityData.MoneyPerSec)
		local existingValue = self._player:GetAttribute("MoneyPerSec")
		if existingValue then
			local updatedValue = existingValue - (moneyPerSec * self._moneyMultiplier)
			self._player:SetAttribute("MoneyPerSec", updatedValue)
		end
	end
end

function PlayerBase.AddToBaseEarning(self: PlayerBase, entityName: string)
	local _biome, entityData = getBiomeByEntity(entityName)
	if entityData then
		local moneyPerSec = math.floor(entityData.MoneyPerSec)
		local existingValue = self._player:GetAttribute("MoneyPerSec")
		local updatedValue = moneyPerSec * self._moneyMultiplier

		if existingValue then
			updatedValue = existingValue + (moneyPerSec * self._moneyMultiplier)
		end

		self._player:SetAttribute("MoneyPerSec", updatedValue)
	end
end

function PlayerBase.ComputeOfflineRewards(
	self: PlayerBase,
	data: {},
	entity: {},
	offlineMoney: number,
	moneyMultiplier: number
)
	local currentTime = os.time()
	local previousJoin = data.LastJoin or currentTime

	local total = offlineEarningsUtils.ComputeRewards(
		self._player,
		entity,
		currentTime,
		previousJoin,
		offlineMoney,
		moneyMultiplier
	)

	return total
end

function PlayerBase.LoadTools(self: PlayerBase)
	local data = self:GetPlayerData()
	if not data then
		return
	end
	print("BackPack", data.Backpack)
	for _, tool in data.Backpack do
		local biomeName = tool[1]
		local entityName = tool[2]
		local mutation = tool[3]

		local _, createdToolId = entityUtils.createEntityTool(self._player, biomeName, entityName, mutation)
		self:StoreTool(createdToolId, biomeName, entityName, mutation)
	end
end

function PlayerBase.LoadEntities(self: PlayerBase)
	local data = self:GetPlayerData()
	if not data then
		return
	end

	local baseModel = self:GetBaseModel()
	local grid = baseModel.Grid
	print("Base", data.Base)
	for slotIndex: string, packed in data.Base do
		local slot = grid:FindFirstChild(slotIndex)
		if not slot then
			continue
		end

		local biomeName = packed[1]
		local entityName = packed[2]
		local pendingMoney = packed[3]
		local mutation = packed[4]
		local offlineMoney = packed[5] or 0

		local entity = self:PlaceEntity(biomeName, entityName, mutation, slot)
		if entity then
			entity:SetPending(pendingMoney)

			local offlineUpdated = self:ComputeOfflineRewards(data, entity, offlineMoney, self._moneyMultiplier)
			entity:SetOffline(offlineUpdated)
		end
	end
end

function PlayerBase.UnsafeToolsLoad(self: PlayerBase)
	local backpack = self:GetBackpack()

	for _, tool in backpack do
		local biomeName = tool[1]
		local entityName = tool[2]
		local mutation = tool[3]

		entityUtils.createEntityTool(self._player, biomeName, entityName, mutation)
	end
end

function PlayerBase.WhenPlayerDie(self: PlayerBase)
	local cleanupObserver = observeCharacter(self._player, function(characterModel, connection)
		local humanoid = characterModel:WaitForChild("Humanoid", 5)
		if not humanoid then
			return
		end

		self._player:SetAttribute(AttributesConfiguration.RESPAWNING, false)

		local diedConn = humanoid.Died:Connect(function()
			-- local rootPart = characterModel:FindFirstChild("HumanoidRootPart")
			-- local position = if rootPart then rootPart.Position else characterModel:GetPivot().Position

			--SignalBank.DropEntity:Fire(self._player, position)

			self._player:SetAttribute(AttributesConfiguration.RESPAWNING, true)
		end)

		if characterModel ~= self._defaultCharacter then
			self:UnsafeToolsLoad()
			self:TeleportPlayer()
		end

		connection:Add(diedConn)
	end)

	self._connections:Add(function()
		if cleanupObserver then
			cleanupObserver()
		end
	end)
end

function PlayerBase.Init(self: PlayerBase)
	self:LoadStagesFromLevel()
	self:LoadTools()
	self:LoadEntities()

	self:WhenPlayerDie()
	self:TeleportPlayer()
end

function PlayerBase.GetEntityById(self: PlayerBase, id: string)
	return self._entitiesInBases[id]
end

function PlayerBase.GetToolDataById(self: PlayerBase, id: string)
	local backpack = self:GetBackpack()
	return backpack[id]
end

function PlayerBase.GetToolModelById(self: PlayerBase, toolId: string)
	local backpack = self._player.Backpack
	local character = getPlayerCharacter(self._player)

	for _, tool in backpack:GetChildren() do
		local id = tool:GetAttribute(AttributesConfiguration.ID)
		if id == toolId then
			return tool
		end
	end

	local tool = character:FindFirstChildOfClass("Tool")
	if not tool then
		return nil
	end
	local id = tool:GetAttribute(AttributesConfiguration.ID)
	if id == toolId then
		return tool
	end

	return nil
end

function PlayerBase.RemoveEntity(self: PlayerBase, id: string)
	local entity = self:GetEntityById(id)
	if not entity then
		return
	end

	local entityName = entity:GetName()
	self:RemoveFromBaseEarning(entityName)

	entity:Destroy()
	self._entitiesInBases[id] = nil
end

function PlayerBase.TeleportPlayer(self: PlayerBase)
	local player = self:GetPlayer()
	local baseModel = self:GetBaseModel()
	if not baseModel then
		return
	end

	local playerCharacter = getPlayerCharacter(player)
	if not playerCharacter then
		return
	end

	local spawnPart = baseModel:WaitForChild("Spawn")
	if not spawnPart or not spawnPart:IsA("BasePart") then
		return
	end

	playerCharacter:PivotTo(spawnPart.CFrame)
end

function PlayerBase.PlaceEntity(
	self: PlayerBase,
	biomeName: string,
	entityName: string,
	mutationName: string,
	slotPart: BasePart
)
	if slotPart:GetAttribute(AttributesConfiguration.SLOT_TAKEN) then
		return
	end

	local player = self:GetPlayer()

	local entityInBase =
		EntityInBase.new(self._service, self._timerservice, player, biomeName, entityName, mutationName, slotPart)
	local entityId = entityInBase:GetId()

	self:AddToBaseEarning(entityName)

	slotPart:SetAttribute(AttributesConfiguration.SLOT_TAKEN, true)
	self._entitiesInBases[entityId] = entityInBase

	return entityInBase
end

function PlayerBase.GetBackpack(self: PlayerBase)
	local out = {}

	for key, value in self._backpack do
		out[key] = { value[1], value[2], value[3], value[4] }
	end

	return out
end

function PlayerBase.StoreTool(
	self: PlayerBase,
	toolId: string,
	biomeName: string,
	entityName: string,
	mutationName: string
)
	if self._backpack[toolId] then
		return
	end
	self._backpack[toolId] = { biomeName, entityName, mutationName }
end

function PlayerBase.ReleaseTool(self: PlayerBase, toolId: string)
	if self._backpack[toolId] then
		self._backpack[toolId] = nil
	end
end

function PlayerBase.GetBaseModel(self: PlayerBase): Model
	return self._baseModel
end

function PlayerBase.GetPlayer(self: PlayerBase): Player
	return self._player
end

function PlayerBase.GetSlot(self: PlayerBase): BasePart
	return self._slot
end

function PlayerBase.UpdateLikes(self: PlayerBase, likes)
	self:updateLikeDisplay(likes)
end

function PlayerBase.updateLikeDisplay(self: PlayerBase, count)
	print("BaseModel", self:GetBaseModel())
	local sign = self._baseModel.Sign
	local likesLabel = sign.Surface.SurfaceGui.Frame.Likes.LikeDisplay
	likesLabel.Text = tostring(count)
end

function PlayerBase.GetPlayerData(self: PlayerBase)
	return self._service:GetPlayerData(self._player)
end

function PlayerBase.GetEntities(self: PlayerBase)
	return self._entitiesInBases
end

function PlayerBase.SaveBackpack(self: PlayerBase)
	local data = self:GetPlayerData()
	if not data then
		return
	end

	local result = {}
	for id, tool in self._backpack do
		result[id] = { tool[1], tool[2], tool[3], tool[4] }
	end

	self._service:SetPlayerData(self._player, "Backpack", result)
end

function PlayerBase.GetId(self: PlayerBase)
	return tostring(self._player.UserId)
end

function PlayerBase.SaveBase(self: PlayerBase)
	local data = self:GetPlayerData()
	if not data then
		return
	end

	local result = {}
	for _, entity in self._entitiesInBases do
		local slot = entity:GetSlot()
		local biomeName = entity:GetBiome()
		local entityName = entity:GetName()
		local mutationName = entity:GetMutation()
		local pending = entity:GetPending()
		local offline = entity:GetOffline()

		result[tostring(slot.Name)] = { biomeName, entityName, math.floor(pending), mutationName, math.floor(offline) }
	end

	self._service:SetPlayerData(self._player, "Base", result)
end

function PlayerBase.Destroy(self: PlayerBase)
	self:SaveBackpack()
	self:SaveBase()

	self._connections:Destroy()

	if self._baseModel then
		self._baseModel:Destroy()
	end

	local slot = self:GetSlot()
	if slot then
		slot:SetAttribute(AttributesConfiguration.SLOT_TAKEN, false)
		whenBaseDestroyed(slot)
	end
end

return PlayerBase
