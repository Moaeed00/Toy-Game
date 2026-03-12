local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local AttributesConfiguration = require(ReplicatedStorage.Configuration.AttributesConfiguration)
local MutationsConfiguration = require(ReplicatedStorage.Configuration.MutationsConfiguration)
local getPlayerFromCharacter = require(ReplicatedStorage.Shared.Utils.getPlayerFromCharacter)
local tweenModelScale = require(ReplicatedStorage.Shared.Modules.tweenModelScale)
local getBiomeByEntity = require(ReplicatedStorage.Shared.Utils.getBiomeByEntity)
local setModelColor = require(ReplicatedStorage.Shared.Utils.setModelColor)
local headerUtils = require(ReplicatedStorage.Shared.Utils.headerUtils)
local RateLimit = require(ReplicatedStorage.Shared.Modules.RateLimit)
local Particle = require(ReplicatedStorage.Shared.Modules.Particle)
local Class = require(ReplicatedStorage.Shared.Modules.Class)
-- local Format = require(ReplicatedStorage.Libraries.Format)
local Trove = require(ReplicatedStorage.Libraries.Trove)
local PromptHelper = require(ReplicatedStorage.Shared.Modules.PromptHelper)
local StealConfiguration = require(ReplicatedStorage.Configuration.StealConfiguration)

local Assets = ReplicatedStorage:WaitForChild("Assets")

local EffectsFolder = Assets:WaitForChild("Effects")
--local CASH_COLLECT_SOUND = Sound.Get("SFX/CashCollect")
local TOUCH_COOLDOWN = RateLimit(1, 0.3)

local player = Players.LocalPlayer

export type EntityInBase = {
	_model: Model,
	_sellProximityPrompt: ProximityPrompt,
	_takeProximityPrompt: ProximityPrompt,

	-- _connections: Trove.Trove,
}
export type constructor = EntityInBase & {
	new: (biomeName: string, entityName: string, mutationName: string, slotName: string) -> (),
}

local function create_sell_proximity(entityModel: Model)
	local sellProximityPrompt = PromptHelper.CreateProximityPrompt(entityModel.PrimaryPart, {
		Style = Enum.ProximityPromptStyle.Custom,
		GamepadKeyCode = Enum.KeyCode.ButtonY,
		KeyboardKeyCode = Enum.KeyCode.F,
		UIOffset = Vector2.new(0, -90),
		RequiresLineOfSight = false,
		MaxActivationDistance = 15,
		ActionText = `Sell`,
		HoldDuration = 1.5,
		Enabled = false,
	})

	sellProximityPrompt:SetAttribute(AttributesConfiguration.COLOR, Color3.fromRGB(193, 0, 0))
	return sellProximityPrompt
end

local function create_steal_proximity(entityModel: Model, _biomeName: string, entityName: string)
	local _, entityInfo = getBiomeByEntity(entityName)
	if not entityInfo then
		return
	end

	local productId = StealConfiguration[entityInfo.Rarity.DisplayName].UnlockID
	if not productId then
		return
	end

	local stealProxmityPrompt = PromptHelper.CreateProximityPrompt(entityModel.PrimaryPart, {
		Style = Enum.ProximityPromptStyle.Custom,
		RequiresLineOfSight = false,
		UIOffset = Vector2.new(0, 90),
		MaxActivationDistance = 15,
		HoldDuration = 1,
		Enabled = false,
		ActionText = `Steal ({entityInfo.Rarity.DisplayName})`,
	})

	return stealProxmityPrompt
end

local function create_take_proximity(entityModel: Model)
	local takeProximityPrompt = PromptHelper.CreateProximityPrompt(entityModel.PrimaryPart, {
		Style = Enum.ProximityPromptStyle.Custom,
		RequiresLineOfSight = false,
		MaxActivationDistance = 15,
		ActionText = `Take`,
		HoldDuration = 0.5,
		Enabled = false,
	})

	return takeProximityPrompt
end

local function create_entity_model(_biomeName: string, entityName: string, mutationName: string, slotPart: BasePart)
	local biome = getBiomeByEntity(entityName)
	local entityModel = Assets:WaitForChild("Entities"):WaitForChild(mutationName):WaitForChild(entityName)
	if not entityModel then
		return
	end

	local model = entityModel:Clone()
	model:PivotTo(slotPart.CFrame)
	model.Parent = slotPart

	-- if mutationName then
	-- 	local mutationInfo = MutationsConfiguration[mutationName]
	-- 	if not mutationInfo then
	-- 		return
	-- 	end

	-- 	setModelColor(model, mutationInfo.Color, mutationName)
	-- end

	headerUtils.create(entityName, biome, mutationName, model)

	return model
end

local EntityInBase: constructor = Class(
	function(
		self: EntityInBase,
		controller: {},
		ownerId: number,
		entityId: string,
		biomeName: string,
		entityName: string,
		mutationName: string,
		slotPart: BasePart
	)
		self._controller = controller
		self._owner = Players:GetPlayerByUserId(tonumber(ownerId))
		if not self._owner then
			print("no player")
			return
		end

		self._model = create_entity_model(biomeName, entityName, mutationName, slotPart)
		self._sellProximityPrompt = create_sell_proximity(self._model)
		self._takeProximityPrompt = create_take_proximity(self._model)
		self._stealProximityPrompt = create_steal_proximity(self._model, biomeName, entityName)
		self._slot = slotPart

		self._biomeName = getBiomeByEntity(entityName)
		self._entityName = entityName
		self._mutationName = mutationName
		self._id = entityId

		self._connections = Trove.new()

		self._connections:Add(self._sellProximityPrompt.Triggered:Connect(function()
			self._controller:OnSellEntityRemote(entityId)
		end))

		self._connections:Add(self._takeProximityPrompt.Triggered:Connect(function()
			self._controller:OnTakeEntityRemote(entityId)
		end))

		self._connections:Add(self._stealProximityPrompt.Triggered:Connect(function()
			local _, entityData = getBiomeByEntity(entityName)
			if not entityData then
				return
			end

			local productId = StealConfiguration[entityData.Rarity.DisplayName].UnlockID
			if not productId then
				return
			end

			self._controller:OnStealRemote(biomeName, entityName, mutationName, entityId, ownerId, slotPart.Name)
		end))
	end
)

function EntityInBase.DisplayForOwner(self: EntityInBase)
	local slotPart = self._slot
	local defaultScale = self._model:GetScale()

	self._sellProximityPrompt.Enabled = true
	self._takeProximityPrompt.Enabled = true

	self._connections:Add(slotPart.Plate.Touched:Connect(function(hit: BasePart)
		if not TOUCH_COOLDOWN() then
			return
		end

		local playerWhoTouched = getPlayerFromCharacter(hit.Parent)
		if playerWhoTouched ~= player then
			return
		end

		self:OnTouch(defaultScale, slotPart)
	end))
end

function EntityInBase.OnTouch(self: EntityInBase, defaultScale: number, _slotPart: BasePart)
	Particle.EmitAt(self._model.PrimaryPart.Position + Vector3.new(0, 2, 0), EffectsFolder.Money)
	tweenModelScale(defaultScale, 1.2, TweenInfo.new(0.15), self._model)
	--Sound.PlayAt(CASH_COLLECT_SOUND, slotPart.Position)

	task.delay(0.15, function()
		tweenModelScale(1.2, defaultScale, TweenInfo.new(0.15), self._model)
	end)
end

function EntityInBase.Destroy(self: EntityInBase)
	self._connections:Destroy()
	self._model:Destroy()
end

return EntityInBase
