local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local PlayerGui = Player:WaitForChild("PlayerGui")
local WarningGui = PlayerGui:WaitForChild("WarningGui")

local WarningFrame = WarningGui:WaitForChild("WarningFrame")
local Prompt = WarningFrame:WaitForChild("Prompt")
local Buttons = WarningFrame:WaitForChild("Buttons")
local YesButton = Buttons:WaitForChild("Yes")
local NoButton = Buttons:WaitForChild("No")

local PlayerScripts = Player:WaitForChild("PlayerScripts")

local Knit = require(ReplicatedStorage.Packages.Knit)

local ObservePlayerTool = require(ReplicatedStorage.Shared.Observers.observePlayerTool)
local PlacementGrid = require(PlayerScripts.Classes.Bases.PlacementGrid)
local EntityInBase = require(PlayerScripts.Classes.Bases.EntityInBase)
local getBiomeByEntity = require(ReplicatedStorage.Shared.Utils.getBiomeByEntity)
local EntitiesConfiguration = require(ReplicatedStorage.Configuration.Brainrots.EntitiesConfiguration)
-- local Signal = require(ReplicatedStorage.Libraries.Signal)

local SELL_FACTOR = EntitiesConfiguration.Original.SELL_FACTOR
local Debounce = false

local BaseService
local StealController
local EntityId

local BaseController = Knit.CreateController({
	Name = "BaseController",
})

local function get_base_model(basesFolder: Folder, baseId: string): Model?
	return basesFolder:FindFirstChild(baseId) :: Model?
end

function BaseController:KnitInit()
	BaseService = Knit.GetService("BaseService")
	StealController = Knit.GetController("StealController")
end

function BaseController:KnitStart()
	self._entitiesInBases = {}
	self._basesFolder = workspace:WaitForChild("Bases")

	YesButton.MouseButton1Click:Connect(function()
		self:OnSellEntityRemote(EntityId)
		WarningGui.Enabled = false
		-- print("selling", EntityId)
		Debounce = false
	end)

	NoButton.MouseButton1Click:Connect(function()
		WarningGui.Enabled = false
		-- print("not selling", EntityId)
		Debounce = false
	end)

	BaseService.BaseCreated:Connect(function()
		self._base = self._basesFolder:WaitForChild(tostring(Player.UserId)) :: Model

		self._YourBase =
			self._base:WaitForChild("Sign"):WaitForChild("YourBase"):WaitForChild("YourBaseGui") :: BillboardGui
		if self._YourBase then
			self._YourBase.Enabled = true
		end
	end)

	-- BaseService.ReplicatedOthersBase:Fire()

	ObservePlayerTool(Player, function(tool, connection)
		if tool.Name == "Bat" or tool:GetAttribute("GearType") then
			return
		end

		local placementGrid = PlacementGrid.new(self, self._base)
		connection:Add(function()
			placementGrid:Destroy()
		end)
	end)

	BaseService.PlaceEntity:Connect(
		function(
			baseId: string,
			entityId: string,
			biomeName: string,
			entityName: string,
			mutationName: string,
			slotName: string
		)
			self:PlaceEntity(baseId, entityId, biomeName, entityName, mutationName, slotName)
		end
	)

	BaseService.RemoveEntityInBase:Connect(function(baseId: string, entityId: string)
		self:RemoveEntityInBase(baseId, entityId)
	end)
end

function BaseController:GetEntityById(baseId: string, entityId: string)
	local bucket = self._entitiesInBases[baseId]
	if not bucket then
		return nil
	end
	return bucket[entityId]
end

function BaseController:RemoveEntityInBase(baseId: string, entityId: string)
	local entity = self:GetEntityById(baseId, entityId)
	if not entity then
		return
	end

	entity:Destroy()
	self._entitiesInBases[baseId][entityId] = nil
end

function BaseController:PlaceEntity(
	baseId: string,
	entityId: string,
	biomeName: string,
	entityName: string,
	mutationName: string,
	slotName: string
)
	print("entityId", entityId)

	if not self._entitiesInBases[baseId] then
		self._entitiesInBases[baseId] = {}
	end

	if self._entitiesInBases[baseId][entityId] then
		return
	end
	self._entitiesInBases[baseId][entityId] = entityId

	local baseModel = get_base_model(self._basesFolder, baseId)
	if not baseModel then
		baseModel = self._basesFolder:WaitForChild(baseId, 5) :: Model?
	end
	if not baseModel then
		return
	end

	local grid = baseModel:WaitForChild("Grid")
	if not grid then
		return
	end

	local slotPart = grid:WaitForChild(slotName)
	if not slotPart then
		return
	end

	local entityInBase = EntityInBase.new(self, baseId, entityId, biomeName, entityName, mutationName, slotPart)
	self._entitiesInBases[baseId][entityId] = entityInBase

	if tonumber(baseId) == Player.UserId then
		entityInBase:DisplayForOwner()
	else
		entityInBase._stealProximityPrompt.Enabled = true
	end
end

function BaseController:OnPlaceEntityRemote(slotName: string)
	BaseService.PlaceEntity:Fire(slotName)
end

function BaseController:TriggerSellEntity(entityId: string, entityName: string)
	if Debounce then
		return
	end
	Debounce = true

	EntityId = entityId
	local _biome, entityData = getBiomeByEntity(entityName)
	if entityData then
		local sellPrice = math.floor(entityData.MoneyPerSec * (SELL_FACTOR * 100))
		Prompt.Text = `Are you sure you want to sell {entityName} for ${sellPrice} coins?`
	end

	WarningGui.Enabled = true
end

function BaseController:OnSellEntityRemote(entityId: string)
	BaseService.SellEntity:Fire(entityId)
end

function BaseController:OnTakeEntityRemote(entityId: string)
	if Debounce then
		return
	end
	BaseService.TakeEntity:Fire(entityId)
end

function BaseController:OnStealRemote(
	biomeName: string,
	entityName: string,
	mutationName: string,
	entityId: string,
	ownerId: number,
	slotName: number
)
	StealController:EnableUI(biomeName, entityName, mutationName, entityId, ownerId, slotName)
end

return BaseController
