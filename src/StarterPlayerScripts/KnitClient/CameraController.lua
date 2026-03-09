local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Camera = workspace.CurrentCamera
local Blur: BlurEffect = Lighting:WaitForChild("Blur")
local Knit = require(ReplicatedStorage.Packages.Knit)

local CameraController = Knit.CreateController { Name = "CameraController" }

local DEFAULT_FOV = 70
local SHOP_OPEN_FOV = 110

function CameraController:ToggleCameraBlurEffect(toggle: boolean)
    Blur.Enabled = toggle
    local targetFOV = toggle and SHOP_OPEN_FOV or DEFAULT_FOV
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.InOut)
    local tween = TweenService:Create(Camera, tweenInfo, { FieldOfView = targetFOV })
    tween:Play()
end

return CameraController