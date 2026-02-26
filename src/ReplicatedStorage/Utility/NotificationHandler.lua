local PlayerService: Players = game:GetService("Players")
local TweenService: TweenService = game:GetService("TweenService")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

--local SoundModule: {} = require(ReplicatedStorage:WaitForChild("Utility"):WaitForChild("SoundModule"))
--local Constants: {} = require(ReplicatedStorage:WaitForChild("EnumsAndContants"):WaitForChild("Constants"))

local LocalPlayer: Player = PlayerService.LocalPlayer
local PlayerGui: PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- [Configs]					-----
-- local UtilityFLD : Folder = ReplicatedStorage:WaitForChild("Utility")
local Assets: Folder = ReplicatedStorage:WaitForChild("Assets")
local UiAssets: Folder = Assets:WaitForChild("UI")
local Configs: Folder = ReplicatedStorage:WaitForChild("Configuration")
local NotificationConfig: {} = require(Configs:WaitForChild("Notification"))
--local PlaySound : {} = require(UtilityFLD:WaitForChild("PlaySound"))

-- [UI Templates]				-----
local NotificationItem: Frame = UiAssets:WaitForChild("NotificationFrame")

-- [References]
local ScreenGui = PlayerGui:WaitForChild("NotificationGui")
local Container = ScreenGui:WaitForChild("Container")

local NotificationHandler = {}

NotificationHandler.OpeningTweenInfo =
	TweenInfo.new(NotificationConfig.AnimationTime, NotificationConfig.EasingStyle, Enum.EasingDirection.Out)

NotificationHandler.ClosingTweenInfo =
	TweenInfo.new(NotificationConfig.AnimationTime, NotificationConfig.EasingStyle, Enum.EasingDirection.In)

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

		local openingTween = TweenService:Create(uiScale, self.OpeningTweenInfo, { Scale = 1 })
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

function NotificationHandler:DisplayNotificationMessage(Text: string, NotificationType: "Success" | "Error" | nil)
	--print("displaying")
	-- if NotificationType == "Success" then
	-- 	--SoundModule.PlayTouchSound(Constants.Sounds.Success,1,1)
	-- else
	-- 	--SoundModule.PlayTouchSound(Constants.Sounds.Error,1,1)
	-- end

	local messageType = NotificationType and NotificationConfig.Types[NotificationType].Color
		or NotificationConfig.Types.Success.Color
	self:CreateNotification(Text, messageType)
end

return NotificationHandler
