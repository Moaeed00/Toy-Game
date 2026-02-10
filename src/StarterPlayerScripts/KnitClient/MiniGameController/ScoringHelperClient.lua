local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player: Player = Players.LocalPlayer

local Trove = require(ReplicatedStorage.Packages.Trove)
Trove = Trove.new()

local PlayerGui: PlayerGui = player:WaitForChild("PlayerGui")
local ScoreGui: ScreenGui = PlayerGui:WaitForChild("ScoreGui")
local ScoreValue: TextLabel = ScoreGui:WaitForChild("Main"):WaitForChild("Score")
local ComboValue: TextLabel = ScoreGui:WaitForChild("Main"):WaitForChild("Combo")

local ScoringHelperClient = {}

local function AddScore()
	local UpdatedScore = player:GetAttribute("Score")
	ScoreValue.Text = `Score {UpdatedScore}`
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

function ScoringHelperClient:OnStartScoring()
	ScoreValue.Text = "Score 0"
	ScoreGui.Enabled = true
	ComboValue.Visible = false
end

function ScoringHelperClient:Initialize()
	Trove:Connect(player:GetAttributeChangedSignal("Score"), function()
		AddScore()
	end)
	Trove:Connect(player:GetAttributeChangedSignal("Combo"), function()
		AddCombo()
	end)
end

function ScoringHelperClient:OnMiss()
	ResetCombo()
end

function ScoringHelperClient:CleanUp()
	ScoreGui.Enabled = false
	ComboValue.Visible = false
	ScoreValue.Text = "Score 0"
	Trove:Destroy()
end

return ScoringHelperClient
