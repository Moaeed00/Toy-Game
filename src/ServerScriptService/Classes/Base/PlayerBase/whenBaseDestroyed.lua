local ServerStorage = game:GetService("ServerStorage")

return function(slot: BasePart)
	local emptyBaseModel = ServerStorage:WaitForChild("Assets"):WaitForChild("Bases"):WaitForChild("EmptyBase")
	if not emptyBaseModel then
		return
	end

	local emptyBase = emptyBaseModel:Clone()
	emptyBase:PivotTo(slot.CFrame)
	emptyBase.Parent = slot
end
