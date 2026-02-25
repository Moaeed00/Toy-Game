local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local Trove = require(ReplicatedStorage.Packages.Trove)
Trove = Trove.new()

local Toys = workspace:WaitForChild("Toys")

local IndicatorHelperClient = {}

local Indicators: Folder
local CurrentIndicator: Part
local SlotName: string
local ActiveTween
local OriginalCFrame

local function GetDirectionOffset(name)
	if name == "Left" then
		return Vector3.new(-0.5, 0, 0)
	elseif name == "Right" then
		return Vector3.new(0.5, 0, 0)
	elseif name == "LeftFront" or name == "RightFront" then
		return Vector3.new(0, 0.5, 0)
	end

	return Vector3.zero
end

function SetIndicator(IndicatorName)
	IndicatorHelperClient:StopCurrentAnimation()

	if CurrentIndicator then
		CurrentIndicator:WaitForChild("SurfaceGui").Enabled = false
	end

	local Indicator: Part = Indicators:WaitForChild(IndicatorName)
	Indicator:WaitForChild("SurfaceGui").Enabled = true
	CurrentIndicator = Indicator
	OriginalCFrame = Indicator.CFrame

	local offset = GetDirectionOffset(IndicatorName)

	local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local goal = { CFrame = OriginalCFrame + offset }
	ActiveTween = TweenService:Create(Indicator, tweenInfo, goal)
	ActiveTween:Play()
end

function IndicatorHelperClient:Initialize()
	SlotName = player:GetAttribute("MiniGameSlot")
	Indicators = Toys:WaitForChild(SlotName):WaitForChild("Indicators")

	Trove:Connect(player:GetAttributeChangedSignal("CurrentIndicator"), function()
		local indicator = player:GetAttribute("CurrentIndicator")
		if indicator then
			SetIndicator(indicator)
		end
	end)
end

function IndicatorHelperClient:CleanUp()
	Trove:Destroy()
	if CurrentIndicator then
		CurrentIndicator:WaitForChild("SurfaceGui").Enabled = false
		CurrentIndicator = nil
	end
	SlotName = nil
	Indicators = nil
end

function IndicatorHelperClient:StopCurrentAnimation()
	if ActiveTween then
		ActiveTween:Cancel()
		ActiveTween = nil
	end

	if CurrentIndicator and OriginalCFrame then
		CurrentIndicator.CFrame = OriginalCFrame
	end
end

return IndicatorHelperClient
