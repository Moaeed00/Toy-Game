local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttributesConfiguration = require(ReplicatedStorage.Configuration.AttributesConfiguration)
local MutationsConfiguration = require(ReplicatedStorage.Configuration.MutationsConfiguration)
local EntitiesConfiguration = require(ReplicatedStorage.Configuration.EntitiesConfiguration)
local getPlayerCharacter = require(ReplicatedStorage.Shared.Utils.getPlayerCharacter)
local getBiomeByEntity = require(ReplicatedStorage.Shared.Utils.getBiomeByEntity)
local setModelColor = require(ReplicatedStorage.Shared.Utils.setModelColor)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.NumberUtils)
local headerUtils = require(ReplicatedStorage.Shared.Utils.headerUtils)
local glue = require(ReplicatedStorage.Shared.Utils.glue)

local Assets = ReplicatedStorage:WaitForChild("Assets")

local RANDOM = Random.new()

local entityUtils = {}

function entityUtils.makeItNetworkable(dict: { [string]: string })
	local result = {}

	for biomeName, entitiesInBiome in dict do
		if not result[biomeName] then
			result[biomeName] = {}
		end

		for _, entity in entitiesInBiome do
			local mutationName = entity:GetMutation()
			local position = entity:GetPosition()
			local entityName = entity:GetName()
			local id = entity:GetId()
			local lifetime = entity._lifetime

			table.insert(result[biomeName], { entityName, mutationName, id, position, lifetime })
		end
	end

	return result
end

function entityUtils.getPlayerCarryModel(player: Player): Model
	local playerCharacter = getPlayerCharacter(player)
	if not playerCharacter then
		return
	end

	local entityModel = playerCharacter:FindFirstChildOfClass("Model")
	if not entityModel then
		return
	end

	return entityModel
end

function entityUtils.getEquippedEntity(player: Player): Tool?
	local playerCharacter = getPlayerCharacter(player)
	if not playerCharacter then
		return nil
	end

	local entityTool = playerCharacter:FindFirstChildOfClass("Tool")
	if not entityTool then
		return
	end

	return entityTool
end

function entityUtils.createCarryModel(player: Player, entityName: string, biomeName: string, mutationName: string)
	local playerCharacter = getPlayerCharacter(player)
	if not playerCharacter then
		return
	end

	local humanoid = playerCharacter:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local model = Assets:WaitForChild("Entities"):WaitForChild(biomeName):WaitForChild(entityName)
	if not model then
		return
	end

	humanoid:UnequipTools()

	local entityModel = model:Clone()
	entityModel.Name = entityName

	for _, part: BasePart? in entityModel:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		end

		part.CanCollide = false
		part.Anchored = false
		part.Massless = true
	end

	entityModel:PivotTo(playerCharacter.Head.CFrame)
	entityModel:SetAttribute(AttributesConfiguration.BIOME, biomeName)
	entityModel:SetAttribute(AttributesConfiguration.MUTATION, mutationName)

	glue(playerCharacter.Head, entityModel.PrimaryPart)
	headerUtils.create(entityName, biomeName, mutationName, entityModel)

	if mutationName then
		local mutationInfo = MutationsConfiguration[mutationName]
		if not mutationInfo then
			return
		end

		setModelColor(entityModel, mutationInfo.Color, mutationName)
	end

	entityModel.Parent = playerCharacter

	return entityModel
end

function entityUtils.createEntityTool(player: Player, biomeName: string, entityName: string, mutationName: string)
	local playerBackpack = player.Backpack
	if not playerBackpack then
		return
	end

	local _, entityData = getBiomeByEntity(entityName)
	local model = Assets:WaitForChild("Entities"):WaitForChild(biomeName):WaitForChild(entityName)
	if not model then
		return
	end

	local id = NumberUtils.generateId(8)

	local entityModel = model:Clone()
	local handle = entityModel.PrimaryPart
	local tool = Instance.new("Tool")

	tool:SetAttribute(AttributesConfiguration.ID, id)
	tool:SetAttribute(AttributesConfiguration.BIOME, biomeName)
	tool:SetAttribute(AttributesConfiguration.MUTATION, mutationName)
	tool:SetAttribute(AttributesConfiguration.ENTITY_NAME, entityModel.Name)

	tool.TextureId = entityData.Icon
	handle.Name = "Handle"

	for _, part: BasePart? in entityModel:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end

		part.CanCollide = false
		part.Anchored = false
		part.Massless = true
		part.Parent = tool
	end

	handle.CFrame = handle.CFrame
	tool.Name = entityName
	tool.PrimaryPart = handle

	if mutationName then
		local mutationInfo = MutationsConfiguration[mutationName]
		if not mutationInfo then
			return
		end

		setModelColor(tool, mutationInfo.Color, mutationName)
	end

	headerUtils.create(entityName, biomeName, mutationName, model, false, handle)

	tool.CanBeDropped = false
	tool.Parent = playerBackpack

	return tool, id
end

function entityUtils.getRandomEntityIndexInBiome(biomeName: string)
	local entitiesInBiome = EntitiesConfiguration[biomeName]
	if not entitiesInBiome then
		return
	end

	local keys = {}
	for key in entitiesInBiome do
		keys[#keys + 1] = key
	end

	local randomKey = keys[RANDOM:NextInteger(1, #keys)]
	-- local value = entitiesInBiome[randomKey]

	return randomKey
end

return entityUtils
