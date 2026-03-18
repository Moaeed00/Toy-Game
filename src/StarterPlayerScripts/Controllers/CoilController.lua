--!strict
--// File: StarterPlayerScripts/KnitClient/Controllers/CoilController.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local CoilController = Knit.CreateController({
	Name = "CoilController",
})

local player = Players.LocalPlayer

----------------------------------------------------
-- CONFIG
----------------------------------------------------

local SPEED_MULTIPLIER = 1.5

-- 50% weaker gravity jump than before
local GRAVITY_JUMP_POWER = 56

local MOON_GRAVITY_MULTIPLIER = 0.5

----------------------------------------------------
-- STATE
----------------------------------------------------

local originalWalkSpeed : number? = nil
local originalJumpPower : number? = nil
local originalGravity = workspace.Gravity

local activeCoil : string? = nil

local function dprint(...)
	print("[CoilController]", ...)
end

----------------------------------------------------
-- SPEED COIL
----------------------------------------------------

local function applySpeedCoil(humanoid : Humanoid)

	-- prevent stacking
	if activeCoil == "Speed Coil" then
		return
	end

	if not originalWalkSpeed then
		originalWalkSpeed = humanoid.WalkSpeed
	end

	humanoid.WalkSpeed = originalWalkSpeed * SPEED_MULTIPLIER

	dprint("Speed Coil activated:", humanoid.WalkSpeed)
end


local function removeSpeedCoil(humanoid : Humanoid)

	if originalWalkSpeed then
		humanoid.WalkSpeed = originalWalkSpeed
	end

	dprint("Speed Coil removed")
end


----------------------------------------------------
-- GRAVITY COIL
----------------------------------------------------

local function applyGravityCoil(humanoid : Humanoid)

	if activeCoil == "Gravity Coil" then
		return
	end

	if not originalJumpPower then
		originalJumpPower = humanoid.JumpPower
	end

	humanoid.UseJumpPower = true
	humanoid.JumpPower = GRAVITY_JUMP_POWER

	workspace.Gravity = originalGravity * MOON_GRAVITY_MULTIPLIER

	dprint("Gravity Coil activated")
end


local function removeGravityCoil(humanoid : Humanoid)

	if originalJumpPower then
		humanoid.JumpPower = originalJumpPower
	end

	workspace.Gravity = originalGravity

	dprint("Gravity Coil removed")
end


----------------------------------------------------
-- TOOL EVENTS
----------------------------------------------------

local function onEquipped(tool : Tool)

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local gearType = tool:GetAttribute("GearType")
	local gearName = tool:GetAttribute("GearName")

	if gearType ~= "Coil" then return end

	if gearName == "Speed Coil" then
		applySpeedCoil(humanoid)

	elseif gearName == "Gravity Coil" then
		applyGravityCoil(humanoid)
	end

	activeCoil = gearName
end


local function onUnequipped(tool : Tool)

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local gearType = tool:GetAttribute("GearType")
	local gearName = tool:GetAttribute("GearName")

	if gearType ~= "Coil" then return end

	if gearName == "Speed Coil" then
		removeSpeedCoil(humanoid)

	elseif gearName == "Gravity Coil" then
		removeGravityCoil(humanoid)
	end

	activeCoil = nil
end


----------------------------------------------------
-- TOOL CONNECTION
----------------------------------------------------

local function connectTool(tool : Tool)

	if tool:GetAttribute("GearType") ~= "Coil" then
		return
	end

	tool.Equipped:Connect(function()
		onEquipped(tool)
	end)

	tool.Unequipped:Connect(function()
		onUnequipped(tool)
	end)

	-- safety if tool removed
	tool.Destroying:Connect(function()
		onUnequipped(tool)
	end)

end


local function scanTools()

	local backpack = player:WaitForChild("Backpack")

	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") then
			connectTool(tool)
		end
	end

	backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			connectTool(child)
		end
	end)

end


----------------------------------------------------
-- CHARACTER RESET
----------------------------------------------------

local function onCharacterAdded(character : Model)

	task.wait(0.5)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		originalWalkSpeed = humanoid.WalkSpeed
		originalJumpPower = humanoid.JumpPower
	end

end


----------------------------------------------------
-- KNIT
----------------------------------------------------

function CoilController:KnitInit()
	dprint("KnitInit")
end


function CoilController:KnitStart()

	dprint("KnitStart")

	player.CharacterAdded:Connect(onCharacterAdded)

	if player.Character then
		onCharacterAdded(player.Character)
	end

	scanTools()

end

return CoilController