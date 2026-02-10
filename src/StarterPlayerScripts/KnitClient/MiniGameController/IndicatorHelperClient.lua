local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local Trove = require(ReplicatedStorage.Packages.Trove)
Trove = Trove.new()

local Toys = workspace:WaitForChild("Toys")

local IndicatorHelperClient = {}

local Indicators: Folder
local CurrentIndicator: MeshPart
local SlotName: string

function SetIndicator(IndicatorName)
	if CurrentIndicator then
		CurrentIndicator.Highlight.Enabled = false
	end

	local Indicator = Indicators:WaitForChild(IndicatorName)
	Indicator.Highlight.Enabled = true
	CurrentIndicator = Indicator
end

function IndicatorHelperClient:Initialize()
	SlotName = player:GetAttribute("MiniGameSlot")
	Indicators = Toys:WaitForChild(SlotName):WaitForChild("Indicators")

	Trove:Connect(player:GetAttributeChangedSignal("CurrentIndicator"), function()
		local indicator = player:GetAttribute("CurrentIndicator")
		print("indicatorClient", indicator)
		if indicator then
			SetIndicator(indicator)
		end
	end)
end

function IndicatorHelperClient:CleanUp()
	Trove:Destroy()
	if CurrentIndicator then
		CurrentIndicator.Highlight.Enabled = false
		CurrentIndicator = nil
	end
	SlotName = nil
	Indicators = nil
end

return IndicatorHelperClient
