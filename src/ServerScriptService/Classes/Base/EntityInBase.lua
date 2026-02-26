local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttributesConfiguration = require(ReplicatedStorage.Configuration.AttributesConfiguration)
local getPlayerFromCharacter = require(ReplicatedStorage.Shared.Utils.getPlayerFromCharacter)
local EntitiesConfiguration = require(ReplicatedStorage.Configuration.EntitiesConfiguration)
local getBiomeByEntity = require(ReplicatedStorage.Shared.Utils.getBiomeByEntity)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.NumberUtils)
local Class = require(ReplicatedStorage.Shared.Modules.Class)
local Format = require(ReplicatedStorage.Libraries.Format)
local Trove = require(ReplicatedStorage.Libraries.Trove)

export type EntityInBase = {

	_id: string,
	_slot: BasePart,
	_player: Player,
	_biomeName: string,
	_entityName: string,
	_mutationName: string,
	_slotLabel: TextLabel,

	_pendingMoney: number,
	_multiplier: number,

	-- _connections: Trove.Trove,

	GetData: (self: EntityInBase) -> EntitiesConfiguration.Entity,
	SetPending: (self: EntityInBase, value: number) -> (),
	GetMutation: (self: EntityInBase) -> string,
	GetPending: (self: EntityInBase) -> number,
	GetSlot: (self: EntityInBase) -> BasePart,
	GenerateMoney: (self: EntityInBase) -> (),
	GetBiome: (self: EntityInBase) -> string,
	GetName: (self: EntityInBase) -> string,
	GetId: (self: EntityInBase) -> string,
	Destroy: (self: EntityInBase) -> (),
}
export type constructor = EntityInBase & {
	new: (player: Player, biomeName: string, entityName: string, mutationName: string, slot: BasePart) -> EntityInBase,
}

local function get_slot_label(slot: BasePart): TextLabel
	local moneyDisplay = slot.MoneyDisplay
	local canvas = moneyDisplay.Surface.Canvas

	return canvas.Value
end

local EntityBase: constructor = Class(
	function(
		self: EntityInBase,
		service: {},
		timerservice: {},
		player: Player,
		biomeName: string,
		entityName: string,
		mutationName: string,
		slot: BasePart
	)
		self._service = service
		self._timerservice = timerservice

		self._data = self._service:GetPlayerData(player)

		self._slot = slot
		self._player = player
		self._biomeName = biomeName
		self._entityName = entityName
		self._mutationName = mutationName
		self._id = NumberUtils.generateId(8)
		self._slotLabel = get_slot_label(self._slot)
		self._slotLabel.Text = "$0"

		self._pendingMoney = 0

		self._connections = Trove.new()
		self._service:OnAllPlaceEntityRemote(
			tostring(player.UserId),
			self._id,
			biomeName,
			entityName,
			mutationName,
			slot.Name
		)

		self:GenerateMoney()
	end
)

function EntityBase.GenerateMoney(self: EntityInBase)
	self._slotLabel.Parent.Parent.Enabled = true

	self._connections:Add(self._timerservice.SecondPast:Connect(function()
		-- local playerData = self._service:GetPlayerData(self._player)
		local _, entityData = getBiomeByEntity(self._entityName)
		if not entityData then
			return
		end

		local moneyPerSec = entityData.MoneyPerSec

		self._pendingMoney += moneyPerSec
		self._slotLabel.Text = `${Format.abreviate(self._pendingMoney)}`
	end))

	self._connections:Add(self._slot.Plate.Touched:Connect(function(hit: BasePart)
		local playerWhoTouched = getPlayerFromCharacter(hit.Parent)
		if not playerWhoTouched then
			return
		end
		if playerWhoTouched ~= self._player then
			return
		end

		self._service:UpdateMoney(self._player, self._pendingMoney)

		self._pendingMoney = 0

		self._slotLabel.Text = "$0"
	end))
end

function EntityBase.SetPending(self: EntityInBase, value: number)
	self._pendingMoney += value
end

function EntityBase.GetData(self: EntityInBase)
	local _, entityData = getBiomeByEntity(self._entityName)

	return entityData
end

function EntityBase.GetId(self: EntityInBase)
	return self._id
end

function EntityBase.GetBiome(self: EntityInBase)
	return self._biomeName
end

function EntityBase.GetPending(self: EntityInBase)
	return self._pendingMoney
end

function EntityBase.GetName(self: EntityInBase)
	return self._entityName
end

function EntityBase.GetMutation(self: EntityInBase)
	return self._mutationName
end

function EntityBase.GetSlot(self: EntityInBase)
	return self._slot
end

function EntityBase.Destroy(self: EntityInBase)
	self._slot:SetAttribute(AttributesConfiguration.SLOT_TAKEN, false)
	self._slotLabel.Parent.Parent.Enabled = false
	self._slotLabel.Text = "$0"

	self._connections:Destroy()
	self._service:OnAllRemoveEntityRemote(tostring(self._player.UserId), self._id)
end

return EntityBase
