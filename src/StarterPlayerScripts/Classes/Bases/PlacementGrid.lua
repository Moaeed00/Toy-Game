local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttributesConfiguration = require(ReplicatedStorage.Configuration.AttributesConfiguration)
local PromptHelper = require(ReplicatedStorage.Shared.Modules.PromptHelper)
local Class = require(ReplicatedStorage.Shared.Modules.Class)
local Trove = require(ReplicatedStorage.Libraries.Trove)

export type PlacementGrid = {
	-- _connections: Trove.Trove,

	Destroy: (self: PlacementGrid) -> (),
}
export type constructor = PlacementGrid & {
	new: (baseModel: Model) -> (),
}

local function create_proximity_prompt(slot: BasePart)
	local proximityPrompt = PromptHelper.CreateProximityPrompt(slot, {
		Style = Enum.ProximityPromptStyle.Custom,
		RequiresLineOfSight = false,
		ActionText = `Place Here!`,
		HoldDuration = 0,
	})

	return proximityPrompt
end

local function get_available_slots(baseModel: Model)
	local grid = baseModel:WaitForChild("Grid")

	local availableSlots = {}

	for _, slot in grid:GetChildren() do
		if slot:GetAttribute(AttributesConfiguration.SLOT_TAKEN) then
			continue
		end

		local proximityPrompt = create_proximity_prompt(slot)
		table.insert(availableSlots, proximityPrompt)
	end

	return availableSlots
end

local function on_prompt_triggered(self: PlacementGrid, slotName: string)
	self._controller:OnPlaceEntityRemote(slotName)
	self:Destroy()
end

local PlacementGrid: constructor = Class(function(self: PlacementGrid, controller: {}, baseModel: Model)
	self._controller = controller
	self._connections = Trove.new()

	local availableSlots = get_available_slots(baseModel)
	local baseGrid = baseModel:WaitForChild("Grid")

	for _, proximityPrompt in availableSlots do
		self._connections:Add(proximityPrompt.Triggered:Connect(function()
			local slotName = proximityPrompt.Parent.Name
			on_prompt_triggered(self, slotName)
		end))

		self._connections:Add(proximityPrompt)
	end

	for _, slot in baseGrid:GetChildren() do
		self._connections:Add(slot:GetAttributeChangedSignal(AttributesConfiguration.SLOT_TAKEN):Connect(function()
			local value = slot:GetAttribute(AttributesConfiguration.SLOT_TAKEN)
			if value == true then
				return
			end

			local prompt = create_proximity_prompt(slot)
			self._connections:Add(prompt.Triggered:Connect(function()
				on_prompt_triggered(self, slot.Name)
			end))

			self._connections:Add(prompt)
		end))
	end
end)

function PlacementGrid.Destroy(self: PlacementGrid)
	self._connections:Destroy()
end

return PlacementGrid
