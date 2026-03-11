local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local Configuration = ReplicatedStorage:WaitForChild("Configuration")
local EntitiesConfiguration = require(Configuration:WaitForChild("Brainrots"):WaitForChild("EntitiesConfiguration"))
local StealConfiguration = require(Configuration:WaitForChild("StealConfiguration"))

local player: Player = Players.LocalPlayer
local ConfettiParticles: Part = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("VFX"):WaitForChild("Confetti")

local Trove = require(ReplicatedStorage.Packages.Trove)
Trove = Trove.new()

local PlayerGui: PlayerGui = player:WaitForChild("PlayerGui")
local ChallengeGui: ScreenGui = PlayerGui:WaitForChild("ChallengeGui")
local Main: Frame = ChallengeGui:WaitForChild("Main")
local Buttons: Frame = Main:WaitForChild("Buttons")
local AcceptButton: ImageButton = Buttons:WaitForChild("Accept")
local DeclineButton: ImageButton = Buttons:WaitForChild("Decline")
local PointsText: TextLabel = DeclineButton:WaitForChild("Points")
local MessageValue: TextLabel = Main:WaitForChild("Message")
local TimerValue: TextLabel = Main:WaitForChild("TimerFrame"):WaitForChild("Timer")

local EntityInfo: {}
local ChallengeData: {}

local StealPoints
local productId
local ChallengePending = false
local OpponentPlayerName

local StealChallengeService
local ProductPurchaseService

local StealChallengeController = Knit.CreateController({
	Name = "StealChallengeController",
})

function FinishChallenge()
	ChallengePending = false

	player:SetAttribute("Owner", false)
	player:SetAttribute("Stealer", false)

	ChallengeGui.Enabled = false
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
	MessageValue.Visible = false
	TimerValue.Visible = false

	EntityInfo = nil
	OpponentPlayerName = nil
	StealPoints = nil
	productId = nil
end

function AnnounceWinnerToOwner(Result: string)
	print("EntityInfo", EntityInfo)
	if Result == "Draw" then
		--Prompt Notification
		print("Match Drawn")
	elseif Result == "Winner" then
		-- local OpponentName = getPlayerName(ChallengeData.StealerUserId)
		--Prompt Notification
		print(`You Saved Your {ChallengeData.EntityName} Brainrot From {OpponentPlayerName}`)
	elseif Result == "Loser" then
		-- local OpponentName = getPlayerName(ChallengeData.StealerUserId)
		--Prompt Notification
		print(`{OpponentPlayerName} Stealed Your {ChallengeData.EntityName} Brainrot`)
	end
end

function AnnounceWinnerToStealer(Result: string)
	if Result == "Draw" then
		--Prompt Notification
		print("Match Drawn")
	elseif Result == "Winner" then
		-- local OpponentName = getPlayerName(ChallengeData.OwnerUserId)
		--Prompt Notification
		print(`You Stealed {ChallengeData.EntityName} Brainrot From {OpponentPlayerName}`)
	elseif Result == "Loser" then
		-- local OpponentName = getPlayerName(ChallengeData.OwnerUserId)
		--Prompt Notification
		print(`{OpponentPlayerName} Saved his {ChallengeData.EntityName} Brainrot from stealing`)
	end
end

function PlayConfetti(slotName: string)
	if not slotName then
		return
	end
	local Confetti = ConfettiParticles:Clone()
	Confetti.Parent = workspace
	local ConfettiPositionReference: Part = workspace:WaitForChild("Toys"):WaitForChild(slotName):WaitForChild("ConfettiPositionReference")
	Confetti:PivotTo(ConfettiPositionReference.CFrame)

	local duration = 5
	for _, confetti: ParticleEmitter in ipairs(Confetti:GetChildren()) do
		confetti.Enabled = true
	end
	task.delay(duration, function()
		for _, confetti: ParticleEmitter in ipairs(Confetti:GetChildren()) do
			confetti.Enabled = false
		end
	end)
end

function AnnounceWinner(Result: string, slotName: string)
	PlayConfetti(slotName)
	if player:GetAttribute("Owner") then
		AnnounceWinnerToOwner(Result)
	elseif player:GetAttribute("Stealer") then
		AnnounceWinnerToStealer(Result)
	end
end

function StartChallenge()
	ChallengePending = false
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	ChallengeGui.Enabled = false
end

function HandleRobuxRejection()
	if player:GetAttribute("Owner") then
		--Prompt Notification Brainrot Saved Sucessfully
		print(`{ChallengeData.EntityName} Brainrot Saved Sucessfully`)
	elseif player:GetAttribute("Stealer") then
		--Prompt Notification
		print(`Challenge Declined`)
	end
end

function HandlePointsRejection()
	--Prompt Notification
	-- print(`Challenge Declined you got {StealPoints} points`)
	print(`Challenge Declined`)
end

function HandlePointDeclineButton()
	local PlayerPoints: IntValue = player:WaitForChild("leaderstats"):WaitForChild("Points")
	if not PlayerPoints then
		return
	end

	if PlayerPoints.Value < StealPoints then
		--Prompt Notification
		print("Points Not Enough")
		if not productId then
			return
		end
		ProductPurchaseService.PromptPurchase:Fire(productId)
	else
		StealChallengeService.StealChallenge:Fire("PointsRejection")
		--Prompt Notification Brainrot Saved Sucessfully
		print(`{ChallengeData.EntityName} Brainrot Saved Sucessfully`)
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

			if RmainingTime < 10 then
				TimerValue.Text = "00:0" .. RmainingTime
			else
				TimerValue.Text = "00:" .. RmainingTime
			end
			task.wait(1)
		end
		--Hide Robux Purchase Prompt
		TimerValue.Visible = false
	end)
end

function ChallengeSent(StealerPlayerName: string, Time: number)
	if not ChallengeData then
		warn("ChallengeData missing")
		return
	end

	OpponentPlayerName = StealerPlayerName

	player:SetAttribute("Stealer", true)
	ChallengePending = true

	Buttons.Visible = false
	ChallengeGui.Enabled = true
	MessageValue.Visible = true

	MessageValue.Text = `You Challenged {StealerPlayerName} for {ChallengeData.EntityName} Brainrot`

	StartTimer(Time)
end

function ChallengeReceived(StealerPlayerName: string, Time: number)
	if not ChallengeData then
		warn("ChallengeData missing")
		return
	end

	OpponentPlayerName = StealerPlayerName
	print("OpponentPlayerName", OpponentPlayerName)

	player:SetAttribute("Owner", true)
	ChallengePending = true

	Buttons.Visible = true
	ChallengeGui.Enabled = true
	MessageValue.Visible = true

	MessageValue.Text = `{StealerPlayerName} has challenged you for {ChallengeData.EntityName} Brainrot`
	PointsText.Text = `{EntityInfo.StealPoints} Points`

	StartTimer(Time)
end

function StealChallengeController:AcceptChallenge()
	StealChallengeService.AcceptChallengeButtonEvent:Fire(ChallengeData)
end

function StealChallengeController:HandleStates(State: string, Message: string, Time: number, CurrentChallengeData: {}, SlotName: string)
	if CurrentChallengeData then
		ChallengeData = CurrentChallengeData
		EntityInfo = EntitiesConfiguration.Original[ChallengeData.EntityRarity][ChallengeData.EntityName]
		StealPoints = StealConfiguration[ChallengeData.EntityRarity].StealPoints
		productId = StealConfiguration[ChallengeData.EntityRarity].SaveFromStellID
	end

	if State == "ChallengeRevoked" then
		--Prompt Notification
		print("Message ", Message)
	elseif State == "ChallengeSent" then
		ChallengeSent(Message, Time)
	elseif State == "ChallengeReceived" then
		ChallengeReceived(Message, Time)
	elseif State == "RobuxRejection" then
		HandleRobuxRejection()
	elseif State == "PointsRejection" then
		HandlePointsRejection()
	elseif State == "ChallengeStarted" then
		StartChallenge()
	elseif State == "ChallengeFinished" then
		FinishChallenge()
	elseif State == "WinnerAnnouncement" then
		AnnounceWinner(Message, SlotName)
	end
end

function StealChallengeController:KnitInit()
	StealChallengeService = Knit.GetService("StealChallengeService")
	ProductPurchaseService = Knit.GetService("ProductPurchaseService")
end

function StealChallengeController:KnitStart()
	-- print("StealChallengeController Started")

	StealChallengeService.StealChallenge:Connect(function(State: string, Message: string, Time: number, CurrentChallengeData: {}, SlotName: string)
		self:HandleStates(State, Message, Time, CurrentChallengeData, SlotName)
	end)

	AcceptButton.Activated:Connect(function()
		self:AcceptChallenge()
	end)
	DeclineButton.Activated:Connect(HandlePointDeclineButton)
end

return StealChallengeController
