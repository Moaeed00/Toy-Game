local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local Configuration = ReplicatedStorage:WaitForChild("Configuration")
local EntitiesConfiguration = require(Configuration:WaitForChild("EntitiesConfiguration"))

local player: Player = Players.LocalPlayer

local Trove = require(ReplicatedStorage.Packages.Trove)
Trove = Trove.new()

local PlayerGui: PlayerGui = player:WaitForChild("PlayerGui")
local ChallengeGui: ScreenGui = PlayerGui:WaitForChild("ChallengeGui")
local Main: Frame = ChallengeGui:WaitForChild("Main")
local PointsButton: TextButton = Main:WaitForChild("Points")
local RobuxButton: TextButton = Main:WaitForChild("Robux")
local MessageValue: TextLabel = Main:WaitForChild("Message")
local DeclineMessage: TextLabel = Main:WaitForChild("DeclineMessage")
local TimerValue: TextLabel = Main:WaitForChild("Timer")

local EntityInfo: {}
local ChallengePending = false
local ChallengeData: {}

local StealChallengeService

local StealChallengeController = Knit.CreateController({
	Name = "StealChallengeController",
})

function FinishChallenge()
	ChallengePending = false

	player:SetAttribute("Owner", false)
	player:SetAttribute("Stealer", false)

	ChallengeGui.Enabled = false
	MessageValue.Visible = false
	DeclineMessage.Visible = false
	RobuxButton.Visible = false
	PointsButton.Visible = false
	TimerValue.Visible = false

	EntityInfo = nil
end

function StartChallenge()
	ChallengePending = false
	ChallengeGui.Enabled = false
end

function HandleRobuxRejection()
	if player:GetAttribute("Owner") then
		--Prompt Notification Brainrot Saved Sucessfully
		print(`{EntityInfo.EntityName} Brainrot Saved Sucessfully`)
		FinishChallenge()
	elseif player:GetAttribute("Stealer") then
		--Prompt Notification
		print(`Challenge Declined`)
		FinishChallenge()
	end
end

function HandlePointsRejection()
	--Prompt Notification
	print(`Challenge Declined you got {EntityInfo.StealPoints} points`)
	FinishChallenge()
end

function HandlePointDeclineButton()
	local PlayerPoints: IntValue = player:WaitForChild("leaderstats"):WaitForChild("Points")
	if not PlayerPoints then
		return
	end

	if PlayerPoints.Value < EntityInfo.StealPoints then
		--Prompt Notification
		print("Points Not Enough")
	else
		StealChallengeService.StealChallenge:Fire("PointsRejection")
		--Prompt Notification Brainrot Saved Sucessfully
		print(`{ChallengeData.EntityName} Brainrot Saved Sucessfully`)
		FinishChallenge()
	end
end

function StartTimer(Time: number)
	local RmainingTime = math.round((Time - workspace:GetServerTimeNow()))

	if not RmainingTime then
		return
	end

	TimerValue.Visible = true

	task.spawn(function()
		while RmainingTime >= 1 and ChallengePending do
			RmainingTime -= 1
			print("ChallengeTimeLeftClient", RmainingTime)

			TimerValue.Text = `Challenge Will be Started in {RmainingTime} Sec`
			task.wait(1)
		end
		TimerValue.Visible = false
	end)
end

function ChallengeSent(StealerPlayerName: string, Time: number)
	if not ChallengeData then
		warn("ChallengeData missing")
		return
	end

	player:SetAttribute("Stealer", true)
	ChallengePending = true

	ChallengeGui.Enabled = true
	MessageValue.Visible = true

	MessageValue.Text = `You Challenged {StealerPlayerName} for {ChallengeData.EntityName} Brainrot`

	StartTimer(Time)
end

function ChallengeRecieved(StealerPlayerName: string, Time: number)
	if not ChallengeData then
		warn("ChallengeData missing")
		return
	end

	player:SetAttribute("Owner", true)
	ChallengePending = true

	ChallengeGui.Enabled = true
	MessageValue.Visible = true
	DeclineMessage.Visible = true
	RobuxButton.Visible = true
	PointsButton.Visible = true

	MessageValue.Text = `{StealerPlayerName} has challenged you for {ChallengeData.EntityName} Brainrot`
	RobuxButton.Text = `{EntityInfo.Robux} Robux`
	PointsButton.Text = `{EntityInfo.StealPoints} Points`

	StartTimer(Time)
end

function StealChallengeController:HandleStates(State: string, Message: string, Time: number, CurrentChallengeData: {})
	if CurrentChallengeData then
		ChallengeData = CurrentChallengeData
		EntityInfo = EntitiesConfiguration[ChallengeData.EntityRarity][ChallengeData.EntityName]
	end

	if State == "ChallengeRevoked" then
		--Prompt Notification
		print("Message ", Message)
	elseif State == "ChallengeSent" then
		ChallengeSent(Message, Time)
	elseif State == "ChallengeReceived" then
		ChallengeRecieved(Message, Time)
	elseif State == "RobuxRejection" then
		HandleRobuxRejection()
	elseif State == "PointsRejection" then
		HandlePointsRejection()
	elseif State == "ChallengeStarted" then
		StartChallenge()
	end
end

function StealChallengeController:KnitInit()
	StealChallengeService = Knit.GetService("StealChallengeService")
end

function StealChallengeController:KnitStart()
	print("StealChallengeController Started")

	StealChallengeService.StealChallenge:Connect(
		function(State: string, Message: string, Time: number, CurrentChallengeData: {})
			self:HandleStates(State, Message, Time, CurrentChallengeData)
		end
	)

	PointsButton.Activated:Connect(HandlePointDeclineButton)
	RobuxButton.Activated:Connect(function()
		StealChallengeService.StealChallenge:Fire("ShowRobuxPrompt")
	end)
end

return StealChallengeController
