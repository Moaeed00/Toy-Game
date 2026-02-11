local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local GUIService = Knit.CreateService {
    Name = "GUIService",
    Client = {},
}

function GUIService:KnitInit()
end

function GUIService:KnitStart()
end

function GUIService:HandleProgressBar(progressBar: Frame, progressText: TextLabel, totalHitPower: number, updatedHitPower: number)
	if progressBar and progressBar:IsA("Frame") then
		local percent = math.clamp(updatedHitPower / totalHitPower, 0, 1)
		local newSize = UDim2.fromScale(percent, 1)

		local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		local tweenGoal = { Size = newSize }
		local tween = TweenService:Create(progressBar, tweenInfo, tweenGoal)
		tween:Play()
		tween.Completed:Wait()
	end

	if progressText and progressText:IsA("TextLabel") then
		progressText.Text = updatedHitPower
	end
end

return GUIService