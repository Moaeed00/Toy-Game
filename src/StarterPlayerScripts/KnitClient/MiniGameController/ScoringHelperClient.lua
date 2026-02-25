local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player: Player = Players.LocalPlayer

local Trove = require(ReplicatedStorage.Packages.Trove)
Trove = Trove.new()

local PlayerGui: PlayerGui = player:WaitForChild("PlayerGui")
local ScoreGui: ScreenGui = PlayerGui:WaitForChild("ScoreGui")
local ScoreBG: ImageLabel = ScoreGui:WaitForChild("Main"):WaitForChild("ScoreBG")
local ScoreValue: TextLabel = ScoreBG:WaitForChild("Score")
local OpponentScoreBG: ImageLabel = ScoreGui:WaitForChild("Main"):WaitForChild("OpponentScoreBG")
local OpponentScoreValue: TextLabel = OpponentScoreBG:WaitForChild("Score")
local ComboValue: TextLabel = ScoreGui:WaitForChild("Main"):WaitForChild("Combo")

local ScoringHelperClient = {}

local function AddScore()
	local UpdatedScore = player:GetAttribute("Score")
	ScoreValue.Text = `{UpdatedScore}`
	ScoringHelperClient:PlayFireCrackers()
end

local function AddOpponentScore()
	local UpdatedScore = player:GetAttribute("OpponentScore")
	OpponentScoreValue.Text = `{UpdatedScore}`
end

local function AddCombo()
	local UpdatedCombo = player:GetAttribute("Combo")
	if (UpdatedCombo - 1) <= 0 then
		ComboValue.Visible = false
		return
	end

	ComboValue.Text = `+{UpdatedCombo - 1}`
	ComboValue.Visible = true
end

local function ResetCombo()
	ComboValue.Visible = false
	ComboValue.Text = 0
end

function ScoringHelperClient:PlayFireCrackers()
	local duration = 2
	local slotName = player:GetAttribute("MiniGameSlot")
	local FireCrackers = workspace:WaitForChild("Toys"):WaitForChild(slotName):WaitForChild("FireCrackers"):GetChildren()
	print("FireCrackers", FireCrackers)

	for _, fire: Part in FireCrackers do
		local emitter = fire:FindFirstChildOfClass("ParticleEmitter")
		if emitter then
			emitter.Enabled = true
		end
	end

	task.delay(duration, function()
		for _, fire: Part in FireCrackers do
			local emitter = fire:FindFirstChildOfClass("ParticleEmitter")
			if emitter then
				emitter.Enabled = false
			end
		end
	end)
end

function ScoringHelperClient:OnStartScoring(Challenge: boolean?)
	ScoreValue.Text = "0"
	ScoreGui.Enabled = true
	ComboValue.Visible = false

	if Challenge then
		OpponentScoreValue.Text = "0"
		OpponentScoreBG.Visible = true
	end
end

function ScoringHelperClient:Initialize()
	Trove:Connect(player:GetAttributeChangedSignal("Score"), function()
		AddScore()
	end)
	Trove:Connect(player:GetAttributeChangedSignal("Combo"), function()
		AddCombo()
	end)
	Trove:Connect(player:GetAttributeChangedSignal("OpponentScore"), function()
		AddOpponentScore()
	end)
end

function ScoringHelperClient:OnMiss()
	ResetCombo()
end

function ScoringHelperClient:CleanUp()
	ScoreGui.Enabled = false
	ComboValue.Visible = false
	OpponentScoreBG.Visible = false
	ScoreValue.Text = "0"
	OpponentScoreValue.Text = "0"
	Trove:Destroy()
end

return ScoringHelperClient
