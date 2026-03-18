local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local Utils = ServerScriptService:WaitForChild("Utils")

local ScoringHelperServer = require(script:WaitForChild("ScoringHelperServer"))
local CollisionGroupHandler: {} = require(Utils:WaitForChild("CollisionGroupHandler"))
local CharacterSize = require(script:WaitForChild("CharacterSize"))

local Assets = ReplicatedStorage:WaitForChild("Assets")
local FootBalls = Assets:WaitForChild("FootBalls")
local Toys = workspace:WaitForChild("Toys")

local RoundTime = 20
local KickResetTime = 3
local ScaleValue = 1.5

local FootBallCollisionGroup = "FootBall"

local ProximityPrompts = {}
local Slots = {
	Toy1 = false,
	Toy2 = false,
	Toy3 = false,
	Toy4 = false,
}
local ClonedFootBalls = {}
local BallSpawnReferences = {}
local ActiveGames = {}
local ActiveChallenges: {} = {}
local PlayerPositionReferences: {} = {}

local DataHandlerService
local StealChallengeService

local MiniGameService = Knit.CreateService({
	Name = "MiniGameService",
	Client = {
		MiniGame = Knit.CreateSignal(),
		EndMiniGame = Knit.CreateSignal(),
	},
})

--Local Functions
function PlayerRemoved(player)
	if ActiveGames[player.UserId] then
		MiniGameService:EndMiniGame(player)
		return
	end

	local ChallengeGameId = player:GetAttribute("ChallengeId")
	local Challenge = ActiveChallenges[ChallengeGameId]
	if Challenge then
		MiniGameService:EndChallengeGame(ChallengeGameId, player)
	end
end

function GetAvailableSlots()
	for SlotName, Occupied in pairs(Slots) do
		if not Occupied then
			return SlotName
		end
	end
end

--MiniGame Helper Functions
function MiniGameService:PlayerHasBrainrot(player: Player)
	local character = player.Character
	if not character then
		return false
	end

	for _, obj in ipairs(CollectionService:GetTagged("brainrot")) do
		if obj:IsDescendantOf(character) then
			return true
		end
	end

	return false
end

function MiniGameService:DestroyBall(player)
	local ClonedFootball = ClonedFootBalls[player]
	if ClonedFootball then
		ClonedFootball:Destroy()
		ClonedFootBalls[player] = nil
	end
end

function MiniGameService:ResetBall(player)
	local FootBall = ClonedFootBalls[player]

	local BallSpawnReference = BallSpawnReferences[player]

	if BallSpawnReference then
		FootBall:PivotTo(BallSpawnReference.CFrame)
	end
end

function MiniGameService:SpawnBall(player, SlotName, BallName)
	if not BallName then
		BallName = "Basic"
	end

	local Football = FootBalls:FindFirstChild(BallName)
	if not Football then
		return warn("Football Not Found")
	end

	local BallSpawnReference = Toys:WaitForChild(SlotName):WaitForChild("BallSpawnReference")
	BallSpawnReferences[player] = BallSpawnReference

	local ClonedFootball = Football:Clone()
	ClonedFootball.Name = player.Name .. "_FootBall"

	CollisionGroupHandler:AddCollisionGroup(FootBallCollisionGroup, ClonedFootball)

	ClonedFootball.Parent = workspace
	ClonedFootBalls[player] = ClonedFootball

	self:ResetBall(player)

	ClonedFootball.PrimaryPart:SetNetworkOwner(player)

	return true
end

function MiniGameService:ReleaseSlot(player)
	local SlotName = player:GetAttribute("MiniGameSlot")
	if not SlotName then
		return warn("Slot Name Not Found")
	end

	Slots[SlotName] = false
	player:SetAttribute("MiniGameSlot", nil)

	local Prompt: ProximityPrompt = ProximityPrompts[SlotName]
	self:ToggleTeleporter(Prompt, true)
end

function MiniGameService:SetSlot(player, SlotName)
	if Slots[SlotName] then
		return warn(`{SlotName} Slot is Already Assigned`)
	end

	local Prompt: ProximityPrompt = ProximityPrompts[SlotName]
	self:ToggleTeleporter(Prompt, false)

	Slots[SlotName] = true
	player:SetAttribute("MiniGameSlot", SlotName)
	return true
end

function MiniGameService:OnBallKicked(player)
	local BallKicked = player:GetAttribute("BallKicked")
	if BallKicked then
		return warn("Ball Already Kicked")
	end

	player:SetAttribute("BallKicked", true)
	player:SetAttribute("HasScored", false)

	task.delay(KickResetTime, function()
		local Id = player:GetAttribute("ChallengeId")

		if not ActiveGames[player.UserId] and not ActiveChallenges[Id] then
			return
		end

		local PlayerScored = player:GetAttribute("HasScored")
		if not PlayerScored then
			ScoringHelperServer:OnMiss(player)
		end

		self:ResetBall(player)
		player:SetAttribute("BallKicked", false)
		self.Client.MiniGame:Fire(player, "EnableKick")
	end)
end

--Solo Mode Helpers
function MiniGameService:StartTimer(player)
	local GameData = ActiveGames[player.UserId]
	if not GameData then
		return
	end

	task.spawn(function()
		while GameData.TimeLeft >= 1 and GameData.Running do
			GameData.TimeLeft -= 1
			print("TimeLeftServer", GameData.TimeLeft)
			task.wait(1)
		end
		self:EndMiniGame(player)
	end)
end

function MiniGameService:EndMiniGame(player: Player)
	if not ActiveGames[player.UserId] then
		return
	end

	local Score = ScoringHelperServer:GetScore(player)
	DataHandlerService:UpdatePoints(player, Score)

	ActiveGames[player.UserId].Running = false
	ActiveGames[player.UserId] = nil
	PlayerPositionReferences[player.UserId] = nil

	ScoringHelperServer:CleanUp(player)

	self:DestroyBall(player)

	player:SetAttribute("BallKicked", nil)
	player:SetAttribute("HasScored", nil)
	player:SetAttribute("InMiniGame", nil)
	player:SetAttribute("Mode", nil)

	self.Client.EndMiniGame:Fire(player)

	self:ReleaseSlot(player)
end

function MiniGameService:InitializeMiniGame(player, SlotName)
	local SlotAssigned = self:SetSlot(player, SlotName)
	if not SlotAssigned then
		return warn("Slot Not Assigned")
	end

	local BallName = player:GetAttribute("CurrentFootball")
	local BallSpawned = self:SpawnBall(player, SlotName, BallName)
	if not BallSpawned then
		return warn("FootBall Not Assigned")
	end

	CharacterSize:ScaleUp(player, ScaleValue)
	local PlayerPositionReference = Toys:WaitForChild(SlotName):WaitForChild("PlayerPositionReference")
	player.Character:PivotTo(PlayerPositionReference.CFrame)

	PlayerPositionReferences[player.UserId] = PlayerPositionReference

	player:SetAttribute("InMiniGame", true)
	player:SetAttribute("Mode", "Solo")

	ActiveGames[player.UserId] = {
		TimeLeft = RoundTime,
		SlotName = SlotName,
		Running = false,
	}

	ScoringHelperServer:Initialize(player)

	self.Client.MiniGame:Fire(player, "InitializeMiniGame")
end

function MiniGameService:StartMiniGame(player)
	if ActiveGames[player.UserId].Running then
		return warn("Game Already Running")
	end

	ActiveGames[player.UserId].Running = true

	local RemainingTime = (workspace:GetServerTimeNow() + ActiveGames[player.UserId].TimeLeft)
	self.Client.MiniGame:Fire(player, "StartMiniGame", RemainingTime)

	ScoringHelperServer:OnStartScoring(player)
	self:StartTimer(player)
end

--Challengte Mode Helpers
function MiniGameService:ResolveWinner(player1: Player, player2: Player, QuittingPlayer: Player?)
	local score1 = ScoringHelperServer:GetScore(player1)
	local score2 = ScoringHelperServer:GetScore(player2)

	local ScoreCard = {
		Result = "Draw",
		WinnerUserID = nil,
		WinnerScore = nil,
		LoserUserID = nil,
		LoserScore = nil,
	}

	if QuittingPlayer then
		local winner = (QuittingPlayer == player1) and player2 or player1
		local loser = QuittingPlayer

		ScoreCard.Result = "Win"
		ScoreCard.WinnerUserID = winner.UserId
		ScoreCard.WinnerScore = ScoringHelperServer:GetScore(winner)
		ScoreCard.LoserUserID = loser.UserId
		ScoreCard.LoserScore = ScoringHelperServer:GetScore(loser)

		return ScoreCard
	end

	if score1 == score2 then
		ScoreCard.WinnerScore = score1
		return ScoreCard
	end

	local winner, loser, winScore, loseScore

	if score1 > score2 then
		winner, loser = player1, player2
		winScore, loseScore = score1, score2
	else
		winner, loser = player2, player1
		winScore, loseScore = score2, score1
	end

	ScoreCard.Result = "Win"
	ScoreCard.WinnerUserID = winner.UserId
	ScoreCard.WinnerScore = winScore
	ScoreCard.LoserUserID = loser.UserId
	ScoreCard.LoserScore = loseScore

	return ScoreCard
end

function MiniGameService:EndChallengeGame(ChallengeGameId: number, QuittingPlayer: Player?)
	local Challenge = ActiveChallenges[ChallengeGameId]
	if not Challenge then
		return
	end

	local player1 = Challenge.Players[1]
	local player2 = Challenge.Players[2]
	local ScoreCard = self:ResolveWinner(player1, player2, QuittingPlayer)
	local SlotData = {}

	for _, Player in ipairs(Challenge.Players) do
		local score = ScoringHelperServer:GetScore(Player)
		DataHandlerService:UpdatePoints(Player, score)

		SlotData[Player.UserId] = Player:GetAttribute("MiniGameSlot")
		Challenge.Running = false
		ActiveChallenges[Challenge.Id] = nil
		PlayerPositionReferences[Player.UserId] = nil

		ScoringHelperServer:CleanUp(Player)

		self:DestroyBall(Player)

		Player:SetAttribute("BallKicked", nil)
		Player:SetAttribute("HasScored", nil)
		Player:SetAttribute("InMiniGame", nil)
		Player:SetAttribute("Mode", nil)

		if QuittingPlayer and QuittingPlayer.UserId == Player.UserId then
			Player = QuittingPlayer
			self.Client.EndMiniGame:Fire(QuittingPlayer, ScoreCard)
		else
			self.Client.EndMiniGame:Fire(Player, ScoreCard)
		end

		self:ReleaseSlot(Player)
	end

	StealChallengeService:HandleWinner(ChallengeGameId, ScoreCard, QuittingPlayer, SlotData)
end

function MiniGameService:StartChallengeTimer(ChallengeGameId: number)
	local Challenge = ActiveChallenges[ChallengeGameId]
	if not Challenge then
		return
	end

	task.spawn(function()
		while Challenge.TimeLeft >= 1 and Challenge.Running do
			Challenge.TimeLeft -= 1
			print("TimeLeftServer", Challenge.TimeLeft)
			task.wait(1)
		end
		self:EndChallengeGame(ChallengeGameId)
	end)
end

function MiniGameService:InitializeChallengeGame(ChallengeGameData: {})
	local ChallengeGameId = ChallengeGameData.ChallengeGameId
	local Player1 = ChallengeGameData.Player1
	local Player2 = ChallengeGameData.Player2
	local MiniGamePlayers = { Player1, Player2 }

	for _, Player in pairs(MiniGamePlayers) do
		local Slot = GetAvailableSlots()
		if not Slot then
			return warn("Slots Not Available")
		end

		local SlotAssigned = self:SetSlot(Player, Slot)
		if not SlotAssigned then
			return warn("Slot Not Assigned")
		end

		local BallName = Player:GetAttribute("CurrentFootball")
		local BallSpawned = self:SpawnBall(Player, Slot, BallName)
		if not BallSpawned then
			return warn("FootBall Not Assigned")
		end

		CharacterSize:ScaleUp(Player, ScaleValue)
		local PlayerPositionReference = Toys:WaitForChild(Slot):WaitForChild("PlayerPositionReference")
		Player.Character:PivotTo(PlayerPositionReference.CFrame)

		PlayerPositionReferences[Player.UserId] = PlayerPositionReference

		Player:SetAttribute("InMiniGame", true)
		Player:SetAttribute("Mode", "Challenge")
	end

	ActiveChallenges[ChallengeGameId] = {
		Id = ChallengeGameId,
		TimeLeft = RoundTime,
		Players = MiniGamePlayers,
		Ready = {},
		Running = false,
	}

	ScoringHelperServer:Initialize(Player1, Player2)
	ScoringHelperServer:Initialize(Player2, Player1)
	self.Client.MiniGame:Fire(Player1, "InitializeMiniGame", nil, "Challenge")
	self.Client.MiniGame:Fire(Player2, "InitializeMiniGame", nil, "Challenge")
end

function MiniGameService:AllPlayersReady(ChallengeGameId: number)
	local Challenge = ActiveChallenges[ChallengeGameId]
	if not Challenge then
		return
	end

	for _, player in ipairs(Challenge.Players) do
		if not Challenge.Ready[player] then
			return false
		end
	end
	return true
end

function MiniGameService:StartChallengeGame(player)
	local ChallengeGameId = player:GetAttribute("ChallengeId")
	local Challenge = ActiveChallenges[ChallengeGameId]

	Challenge.Ready[player] = true

	if not self:AllPlayersReady(ChallengeGameId) then
		return
	end

	Challenge.Running = true

	local RemainingTime = (workspace:GetServerTimeNow() + Challenge.TimeLeft)

	for _, Player in pairs(Challenge.Players) do
		self.Client.MiniGame:Fire(Player, "StartMiniGame", RemainingTime, "Challenge")
		ScoringHelperServer:OnStartScoring(Player)
	end

	self:StartChallengeTimer(ChallengeGameId)
end

--States Handler For Modes
function MiniGameService:HandleStates(player, State, SlotName)
	local Mode = player:GetAttribute("Mode")
	if State == "InitializeMiniGame" then
		self:InitializeMiniGame(player, SlotName)
	elseif State == "StartMiniGame" and Mode == "Solo" then
		self:StartMiniGame(player)
	elseif State == "StartMiniGame" and Mode == "Challenge" then
		self:StartChallengeGame(player)
	elseif State == "BallKicked" then
		self:OnBallKicked(player)
	elseif State == "ScaleDown" then
		CharacterSize:ScaleDown(player)
	end
end

function MiniGameService:ToggleTeleporter(proximityPrompt: ProximityPrompt, toggle: boolean)
	proximityPrompt.Enabled = toggle
	local Parts = proximityPrompt.Parent.Parent:GetChildren()
	if not toggle then
		for _, part in ipairs(Parts) do
			if part.Name == "TopCylinder" or part.Name == "BottomCylinder" then
				print("Kk", part.Name)
				part.Transparency = 1
			end
		end
		return
	end
	for _, part in ipairs(Parts) do
		if part.Name == "TopCylinder" then
			part.Transparency = 0.25
		end
		if part.Name == "BottomCylinder" then
			part.Transparency = 0.5
		end
	end
end

--Initializers
function MiniGameService:KnitInit()
	DataHandlerService = Knit.GetService("DataHandlerService")
	StealChallengeService = Knit.GetService("StealChallengeService")
end

function MiniGameService:KnitStart()
	-- print("MiniGameService Started")
	for _, ProximityPrompt: ProximityPrompt in Toys:GetDescendants() do
		if ProximityPrompt.Name == "MiniGamePrompt" and ProximityPrompt:IsA("ProximityPrompt") then
			self:ToggleTeleporter(ProximityPrompt, true)
			ProximityPrompt.Triggered:Connect(function(player)
				if player:GetAttribute("InMiniGame") then
					return
				end
				if self:PlayerHasBrainrot(player) then
					self.Client.MiniGame:Fire(player, "BrainrotBlocked")
					return
				end

				self:ToggleTeleporter(ProximityPrompt, false)
				self:HandleStates(player, "InitializeMiniGame", ProximityPrompt.Parent.Parent.Parent.Name)
			end)

			ProximityPrompts[ProximityPrompt.Parent.Parent.Parent.Name] = ProximityPrompt
		end
	end

	self.Client.MiniGame:Connect(function(player, State)
		self:HandleStates(player, State)
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(Character)
			if player:GetAttribute("InMiniGame") then
				print("RespawnedCharacter")
				local HRP = Character:WaitForChild("HumanoidRootPart")
				local PlayerPositionReference = PlayerPositionReferences[player.UserId]

				if not HRP or not PlayerPositionReference then
					return
				end

				CharacterSize:ScaleUp(player, ScaleValue)
				player.Character:PivotTo(PlayerPositionReference.CFrame)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(PlayerRemoved)
end

return MiniGameService
