local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local Knit = require(ReplicatedStorage.Packages.Knit)

local RebirthConfiguration = require(ReplicatedStorage.Configuration.RebirthConfiguration)
local Format = require(ReplicatedStorage.Libraries.Format)
local NotificationHandler = require(ReplicatedStorage.Utility.NotificationHandler)
local SoundPlay = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utils"):WaitForChild("PlaySound"))

local PlayerGui = Player:WaitForChild("PlayerGui")
local RebirthGui = PlayerGui:WaitForChild("RebirthGui")
local Canvas = RebirthGui:WaitForChild("Canvas")
local CashProgress = Canvas:WaitForChild("CashProgress")
local CashRewardCard = Canvas:WaitForChild("Rewards"):WaitForChild("Cash")
local CashRewardText: TextLabel = CashRewardCard:WaitForChild("RewardAmount")
local RebirthButton = Canvas:WaitForChild("Rebirth")
local CloseButton = Canvas:WaitForChild("CloseButton")

local RebirthService

local RebirthController = Knit.CreateController({ Name = "RebirthController" })

local function next_money_requirement(rebirth: number)
	local nextRebirth = RebirthConfiguration.REBIRTH[rebirth + 1]
	return nextRebirth and nextRebirth.MoneyRequired
end

local function next_money_reward(rebirth: number)
	local nextRebirth = RebirthConfiguration.REBIRTH[rebirth + 1]
	return nextRebirth and nextRebirth.MoneyReward
end

function RebirthController:KnitInit()
	RebirthService = Knit.GetService("RebirthService")
end

function RebirthController:KnitStart()
	RebirthController.LobbyHud = Knit.GetController("Hud")

	Player:GetAttributeChangedSignal("Money"):Connect(function()
		local nextRebirth = next_money_requirement(Player:GetAttribute("Rebirth"))
		if not nextRebirth then
			return
		end

		self:_updateMoney(Player:GetAttribute("Money"), nextRebirth)
	end)

	Player:GetAttributeChangedSignal("Rebirth"):Connect(function()
		self:UpdateUI()
	end)

	RebirthButton.MouseButton1Click:Connect(function()
		local nextRebirth = next_money_requirement(Player:GetAttribute("Rebirth"))
		if not nextRebirth then
			NotificationHandler:DisplayNotificationMessage("You've already completed every rebirth!", "Error")
			return
		end

		if Player:GetAttribute("Money") < nextRebirth then
			NotificationHandler:DisplayNotificationMessage("You don't have enough money to rebirth!", "Error")
			return
		end

		RebirthService.Rebirth:Fire()
		SoundPlay:Play("RewardSound", "Touch", 1, 1)
		NotificationHandler:DisplayNotificationMessage("Your base has been reborn!", "Success")
	end)

	CloseButton.MouseButton1Click:Connect(function()
		self.LobbyHud:OpenContainer("MainGui")
	end)
end

function RebirthController:_updateMoney(currentValue: number, maxValue: number)
	local ratio = currentValue / maxValue
	if ratio >= 1 then
		CashProgress.Value.Text = "Completed!"
		CashProgress.Bar.Size = UDim2.fromScale(0, 1)
		return
	end

	CashProgress.Value.Text = `${Format.abbreviate(currentValue)} / ${Format.abbreviate(maxValue)}`
	CashProgress.Bar.Size = UDim2.fromScale((1 - ratio), 1)
end

function RebirthController:UpdateUI()
	local rebirthCount = Player:GetAttribute("Rebirth")
	local money = Player:GetAttribute("Money")
	local nextRebirth = next_money_requirement(rebirthCount)

	if not nextRebirth then
		CashProgress.Value.Text = "Max Rebirth Reached!"
		CashProgress.Bar.Size = UDim2.fromScale(0, 1)
		CashRewardText.Text = "N/A"
		RebirthButton.Active = false
		RebirthButton.AutoButtonColor = false
		RebirthButton.ImageTransparency = 0.5
		return
	end

	local reward = next_money_reward(rebirthCount)
	CashRewardText.Text = Format.abbreviate(reward)

	RebirthButton.Active = true
	RebirthButton.AutoButtonColor = true
	RebirthButton.ImageTransparency = 0
	self:_updateMoney(money, nextRebirth)
end

function RebirthController:SetEnabled(enabled: boolean)
	RebirthGui.Enabled = enabled
	self:UpdateUI()
end

return RebirthController