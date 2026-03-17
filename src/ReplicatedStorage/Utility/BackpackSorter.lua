local BackpackSorter = {}

function BackpackSorter.Sort(player)
	local backpack = player:WaitForChild("Backpack")
	local character = player.Character or player.CharacterAdded:Wait()

	local tempFolder = Instance.new("Folder")
	tempFolder.Name = "TempSortFolder"
	tempFolder.Parent = player

	local order = { Football = 1, Gear = 2, Brainrot = 3 }
	local tools = {}

	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") then
			table.insert(tools, tool)
		end
	end

	for _, tool in ipairs(character:GetChildren()) do
		if tool:IsA("Tool") then
			table.insert(tools, tool)
		end
	end

	table.sort(tools, function(a, b)
		local aOrder = order[a:GetAttribute("ToolCategory")] or 999
		local bOrder = order[b:GetAttribute("ToolCategory")] or 999
		return aOrder < bOrder
	end)

	for _, tool in ipairs(tools) do
		tool.Parent = tempFolder
	end

	task.wait()

	for _, tool in ipairs(tools) do
		tool.Parent = backpack
	end

	tempFolder:Destroy()
end

return BackpackSorter
