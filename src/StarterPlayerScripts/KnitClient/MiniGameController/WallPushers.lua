local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player: Player = Players.LocalPlayer

local Toys = workspace:WaitForChild("Toys")

local Trove = require(ReplicatedStorage.Packages.Trove)
Trove = Trove.new()

local WallPushers = {}

local PushDirections = {
	Right = Vector3.new(-1, 0, -0.3),
	Left = Vector3.new(1, 0, -0.3),
	RightCenter = Vector3.new(-1, 0, 0),
	LeftCenter = Vector3.new(1, 0, 0),
	Outward = Vector3.new(0, 0, 1),
	Front = Vector3.new(0, 0, 1),
}

local PushPowers = {
	Side = 60,
	Center = 60,
	Front = 60,
	Outward = 40,
}

local Lifts = {
	Side = 25,
	Center = 20,
	Front = 30,
	Outward = 25,
}
local PUSH_DIRECTION = nil
local PUSH_POWER = nil
local Lift = nil

local Cooldown = false
local CoolDownTime = 0.2

local function HandleDirections(WallPushersFolder: Folder)
	local RightDetector = WallPushersFolder:WaitForChild("RightDetector")
	local LeftDetector = WallPushersFolder:WaitForChild("LeftDetector")

	local Right = WallPushersFolder:WaitForChild("Right")
	local Left = WallPushersFolder:WaitForChild("Left")
	local Center = WallPushersFolder:WaitForChild("Center")

	Trove:Connect(RightDetector.Touched, function(hit)
		if hit.Name ~= player.Name .. "_FootBall" then
			return
		end

		Right:SetAttribute("PushDirection", PushDirections.Right)
		Center:SetAttribute("PushDirection", PushDirections.RightCenter)
		Left:SetAttribute("PushDirection", PushDirections.Outward)
	end)

	Trove:Connect(LeftDetector.Touched, function(hit)
		if hit.Name ~= player.Name .. "_FootBall" then
			return
		end

		Left:SetAttribute("PushDirection", PushDirections.Left)
		Center:SetAttribute("PushDirection", PushDirections.LeftCenter)
		Right:SetAttribute("PushDirection", PushDirections.Outward)
	end)
end

function WallPushers:AddWallPushers(ToyName: string)
	local Toy = Toys:WaitForChild(ToyName)
	local WallPushersFolder = Toy:WaitForChild("WallPushers")
	HandleDirections(WallPushersFolder)

	for _, pad in pairs(WallPushersFolder:GetDescendants()) do
		if pad:IsA("BasePart") and pad:HasTag("Pad") then
			Trove:Connect(pad.Touched, function(hit)
				if Cooldown then
					return
				end

				Cooldown = true
				task.delay(CoolDownTime, function()
					Cooldown = false
				end)

				if hit.Name ~= player.Name .. "_FootBall" then
					return
				end

				if pad.Name == "Left" then
					PUSH_DIRECTION = pad:GetAttribute("PushDirection") or PushDirections.Outward
					PUSH_POWER = PushPowers.Side
					Lift = Lifts.Side
				elseif pad.Name == "Right" then
					PUSH_DIRECTION = pad:GetAttribute("PushDirection") or PushDirections.Right
					PUSH_POWER = PushPowers.Side
					Lift = Lifts.Side
				elseif pad.Name == "Center" then
					PUSH_DIRECTION = pad:GetAttribute("PushDirection") or PushDirections.RightCenter
					PUSH_POWER = PushPowers.Center
					Lift = Lifts.Center
				elseif pad.Name == "Front" then
					PUSH_DIRECTION = PushDirections.Front
					PUSH_POWER = PushPowers.Front
					Lift = Lifts.Front
				else
					return
				end

				hit.AssemblyLinearVelocity = Vector3.zero
				hit.AssemblyAngularVelocity = Vector3.zero
				hit.AssemblyLinearVelocity = PUSH_DIRECTION.Unit * PUSH_POWER + Vector3.new(0, Lift, 0)
			end)
		end
	end
end

function WallPushers:CleanUp()
	Trove:Destroy()
end

return WallPushers
