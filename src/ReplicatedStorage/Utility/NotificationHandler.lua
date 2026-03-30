local PlayerService: Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService: TweenService = game:GetService("TweenService")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer: Player = PlayerService.LocalPlayer
local PlayerGui: PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Assets: Folder = ReplicatedStorage:WaitForChild("Assets")
local UiAssets: Folder = Assets:WaitForChild("UI")
local Configs: Folder = ReplicatedStorage:WaitForChild("Configuration")
local NotificationConfig: {} = require(Configs:WaitForChild("Notification"))

local NotificationItem: Frame = UiAssets:WaitForChild("NotificationFrame")
local ScreenGui = PlayerGui:WaitForChild("NotificationGui")
local Container = ScreenGui:WaitForChild("Container")
local SuccessSFX = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Sounds"):FindFirstChild("Claim")
local ErrorSFX = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Sounds"):FindFirstChild("Error")

local NotificationHandler = {}

NotificationHandler.OpeningTweenInfo = TweenInfo.new(NotificationConfig.AnimationTime, NotificationConfig.EasingStyle, Enum.EasingDirection.Out)
NotificationHandler.ClosingTweenInfo = TweenInfo.new(NotificationConfig.AnimationTime, NotificationConfig.EasingStyle, Enum.EasingDirection.In)

function NotificationHandler:CreateNotification(Text: string, Color: Color3?)
	local item = NotificationItem:Clone()
	local textLabel: TextLabel = item:FindFirstChild("TextLabel")
	if textLabel and Text then
		textLabel.Text = Text
		textLabel.TextColor3 = Color
	end

	local uiScale = item:FindFirstChild("UIScale")
	if uiScale then
		uiScale.Scale = 0
		item.Parent = Container

		local openingTween = TweenService:Create(uiScale, self.OpeningTweenInfo, { Scale = 2 })
		openingTween:Play()
	end

	task.delay(NotificationConfig.NotificationTime, function()
		local closingTween = TweenService:Create(uiScale, self.ClosingTweenInfo, { Scale = 0 })
		closingTween:Play()

		closingTween.Completed:Connect(function()
			item:Destroy()
		end)
	end)
end

function NotificationHandler:DisplayNotificationMessage(Text: string, NotificationType: "Success" | "Error" | "Gameplay" | "Win" | nil)
	if NotificationType == "Success" then
		self:PlaySuccessSFX()
	elseif NotificationType == "Error" then
		self:PlayErrorSFX()
	end

	local messageType = NotificationType and NotificationConfig.Types[NotificationType].Color or NotificationConfig.Types.Success.Color
	self:CreateNotification(Text, messageType)
end

function NotificationHandler:PlaySuccessSFX()
	if SuccessSFX then
		local successSfx = SuccessSFX:Clone()
		successSfx.Parent = LocalPlayer
		successSfx.Looped = false
		successSfx.Volume = 1
		successSfx:Play()

		Debris:AddItem(successSfx, successSfx.TimeLength + 0.1)
	end
end

function NotificationHandler:PlayErrorSFX()
	if ErrorSFX then
		local errorSfx = ErrorSFX:Clone()
		errorSfx.Parent = LocalPlayer
		errorSfx.Looped = false
		errorSfx.Volume = 1
		errorSfx:Play()

		Debris:AddItem(errorSfx, errorSfx.TimeLength + 0.1)
	end
end

return NotificationHandler