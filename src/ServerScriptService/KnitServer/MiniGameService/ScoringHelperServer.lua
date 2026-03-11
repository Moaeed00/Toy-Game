local ReplicatedStorage = game:GetService("ReplicatedStorage")
local IndicatorHelperServer = require(script.Parent:WaitForChild("IndicatorHelperServer"))
local Trove = require(ReplicatedStorage.Packages.Trove)

local Toys = workspace:WaitForChild("Toys")

local ScoringHelperServer = {}
ScoringHelperServer._troves = {}
ScoringHelperServer._ActiveGames = {}
ScoringHelperServer._Challenger = {}

local BASE_SCORE = 10
local COMBO_BONUS = 5
local Max_Combos = 5

local function AddScore(player)
	player:SetAttribute("HasScored", true)

	local GameData = ScoringHelperServer._ActiveGames[player]
	GameData.LastScoreSide = player:GetAttribute("CurrentIndicator")

	local BonusCombo = math.min(GameData.Combo - 1, Max_Combos + 1)
	local ScoreGained = BASE_SCORE + (BonusCombo * COMBO_BONUS)
	GameData.Score += ScoreGained

	player:SetAttribute("Score", GameData.Score)

	local ChallengerPlayer = ScoringHelperServer._Challenger[player]
	if ChallengerPlayer then
		ChallengerPlayer:SetAttribute("OpponentScore", GameData.Score)
	end

	IndicatorHelperServer:SelectRandomIndicator(player)
end

local function AddCombo(player)
	local GameData = ScoringHelperServer._ActiveGames[player]
	GameData.Combo += 1

	GameData.Combo = math.min(GameData.Combo, Max_Combos + 1)
	player:SetAttribute("Combo", GameData.Combo)
end

local function ResetCombo(player)
	local GameData = ScoringHelperServer._ActiveGames[player]
	GameData.Combo = 0
	player:SetAttribute("Combo", GameData.Combo)
end

function ScoringHelperServer:OnStartScoring(player)
	IndicatorHelperServer:SelectRandomIndicator(player)
end

function ScoringHelperServer:GetScore(player)
	local GameData = self._ActiveGames[player]
	local Score = GameData.Score or 0

	return Score
end

function ScoringHelperServer:Initialize(player: Player, OpponentPlayer: Player)
	local SlotName = player:GetAttribute("MiniGameSlot")
	local ScoringParts = Toys:WaitForChild(SlotName):WaitForChild("ScoringParts")

	local trove = Trove.new()
	self._troves[player] = trove

	self._ActiveGames[player] = {
		Score = 0,
		Combo = 0,
		LastScoreSide = nil,
	}

	self._Challenger[player] = OpponentPlayer

	for _, part: BasePart in ipairs(ScoringParts:GetChildren()) do
		trove:Connect(part.Touched, function(hit)
			if hit.Parent.Name ~= player.Name .. "_FootBall" then
				return
			end

			if self._ActiveGames[player].LastScoreSide and self._ActiveGames[player].LastScoreSide == part.Name then
				return
			end

			if not player:GetAttribute("BallKicked") or player:GetAttribute("HasScored") then
				return
			end

			local CurrentIndicator = player:GetAttribute("CurrentIndicator")
			if not CurrentIndicator or CurrentIndicator ~= part.Name then
				player:SetAttribute("BallKicked", false)
				return
			end

			AddCombo(player)
			AddScore(player)
		end)
	end
end

function ScoringHelperServer:OnMiss(player)
	ResetCombo(player)
end

function ScoringHelperServer:CleanUp(player)
	IndicatorHelperServer:CleanUp(player)

	if self._troves[player] then
		self._troves[player]:Destroy()
		self._troves[player] = nil
	end
	if self._ActiveGames[player] then
		self._ActiveGames[player] = nil
	end
	player:SetAttribute("Combo", nil)
	player:SetAttribute("Score", nil)

	if self._Challenger[player] then
		local ChallengerPlayer = self._Challenger[player]
		ChallengerPlayer:SetAttribute("OpponentScore", nil)
		self._Challenger[player] = nil
	end
end

return ScoringHelperServer
