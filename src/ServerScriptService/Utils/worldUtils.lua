local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttributesConfiguration = require(ReplicatedStorage.Configuration.AttributesConfiguration)

local SlotsFolder = workspace:WaitForChild("Slots")

local worldUtils = {}

function worldUtils.getAvailableSlot(): BasePart?
	for _, slot in SlotsFolder:GetChildren() do
		if not slot:IsA("BasePart") then
			continue
		end
		if slot:GetAttribute(AttributesConfiguration.SLOT_TAKEN) then
			continue
		end
		return slot
	end

	return nil
end

return worldUtils
