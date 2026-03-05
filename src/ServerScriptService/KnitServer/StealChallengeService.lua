local Players: Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local Configuration = ReplicatedStorage:WaitForChild("Configuration")
local StealConfiguration = require(Configuration:WaitForChild("StealConfiguration"))
local EntitiesConfiguration = require(Configuration:WaitForChild("EntitiesConfiguration"))

local ActiveChallenges: {} = {}

local ChallengeTime = 10

local DataHandlerService
local MiniGameService
local StealService

local StealChallengeService = Knit.CreateService({
	Name = "StealChallengeService",
	Client = {
		StealChallenge = Knit.CreateSignal(),
		AcceptChallengeButtonEvent = Knit.CreateSignal(),
	},
})

function PlayerRemoved(player: Player)
	local ChallengeId = player:GetAttribute("ChallengeId")
	if not ChallengeId or not ActiveChallenges[ChallengeId] then
		return
	end

	if ActiveChallenges[ChallengeId].State == "Started" then
		return
	end

	StealChallengeService:FinishChallenge(ChallengeId, player)
end

function Get_Guid()
	return HttpService:GenerateGUID(false)
end

function IsChallengeValid(ChallengeData: {})
	local OwnerPlayer = Players:GetPlayerByUserId(ChallengeData.OwnerUserId)
	local StealingPlayer = Players:GetPlayerByUserId(ChallengeData.StealerUserId)

	if not OwnerPlayer or not StealingPlayer then
		return false, "Player left"
	end

	if OwnerPlayer == StealingPlayer then
		return false, "Owner Player is Stealing Player"
	end

	if StealingPlayer:GetAttribute("ChallengeId") then
		return false, "You are Already In Challenge"
	end

	if OwnerPlayer:GetAttribute("ChallengeId") or OwnerPlayer:GetAttribute("InMiniGame") then
		return false, OwnerPlayer.Name .. " is already in the game"
	end

	local StealingPlayerPoints = DataHandlerService:GetPoints(StealingPlayer)
	local StealPoints = StealConfiguration[ChallengeData.EntityRarity].StealPoints

	if not StealPoints then
		return false, "StealPoints Not Found"
	end

	if StealingPlayerPoints < StealPoints then
		return false, "Not Enough Points"
	end

	return true
end

function StealChallengeService:HandleWinner(ChallengeId: string, ScoreCard: {}, QuittingPlayer, SlotData)
	if not (ActiveChallenges[ChallengeId].State == "Started") then
		return
	end

	local ChallengeData = ActiveChallenges[ChallengeId]

	local OwnerPlayer, StealingPlayer
	if QuittingPlayer then
		if QuittingPlayer.UserId == ActiveChallenges[ChallengeId].OwnerUserId then
			OwnerPlayer = QuittingPlayer
			StealingPlayer = Players:GetPlayerByUserId(ActiveChallenges[ChallengeId].StealerUserId)
		elseif QuittingPlayer.UserId == ActiveChallenges[ChallengeId].StealerUserId then
			StealingPlayer = QuittingPlayer
			OwnerPlayer = Players:GetPlayerByUserId(ActiveChallenges[ChallengeId].OwnerUserId)
		end
	else
		OwnerPlayer = Players:GetPlayerByUserId(ActiveChallenges[ChallengeId].OwnerUserId)
		StealingPlayer = Players:GetPlayerByUserId(ActiveChallenges[ChallengeId].StealerUserId)
	end

	if ScoreCard.Result == "Draw" then
		self.Client.StealChallenge:Fire(StealingPlayer, "WinnerAnnouncement", "Draw")
		self.Client.StealChallenge:Fire(OwnerPlayer, "WinnerAnnouncement", "Draw")
	elseif ScoreCard.WinnerUserID == ChallengeData.StealerUserId then
		StealService:HandleWinner(StealingPlayer, "Winner", OwnerPlayer)
		self.Client.StealChallenge:Fire(StealingPlayer, "WinnerAnnouncement", "Winner", nil, nil, SlotData[StealingPlayer.UserId])
		self.Client.StealChallenge:Fire(OwnerPlayer, "WinnerAnnouncement", "Loser")
	else
		StealService:HandleWinner(StealingPlayer, "Loser", OwnerPlayer)
		self.Client.StealChallenge:Fire(StealingPlayer, "WinnerAnnouncement", "Loser")
		self.Client.StealChallenge:Fire(OwnerPlayer, "WinnerAnnouncement", "Winner", nil, nil, SlotData[StealingPlayer.UserId])
	end

	self:FinishChallenge(ChallengeId, QuittingPlayer)
end

function StealChallengeService:FinishChallenge(ChallengeId: string, QuittingPlayer: Player)
	if not ActiveChallenges[ChallengeId] then
		return
	end

	ActiveChallenges[ChallengeId].State = "Finished"

	local OwnerPlayer, StealingPlayer
	if QuittingPlayer then
		if QuittingPlayer.UserId == ActiveChallenges[ChallengeId].OwnerUserId then
			OwnerPlayer = QuittingPlayer
			StealingPlayer = Players:GetPlayerByUserId(ActiveChallenges[ChallengeId].StealerUserId)
		elseif QuittingPlayer.UserId == ActiveChallenges[ChallengeId].StealerUserId then
			StealingPlayer = QuittingPlayer
			OwnerPlayer = Players:GetPlayerByUserId(ActiveChallenges[ChallengeId].OwnerUserId)
		end
	else
		OwnerPlayer = Players:GetPlayerByUserId(ActiveChallenges[ChallengeId].OwnerUserId)
		StealingPlayer = Players:GetPlayerByUserId(ActiveChallenges[ChallengeId].StealerUserId)
	end

	OwnerPlayer:SetAttribute("ChallengeId", nil)
	StealingPlayer:SetAttribute("ChallengeId", nil)
	OwnerPlayer:SetAttribute("InMiniGame", nil)
	StealingPlayer:SetAttribute("InMiniGame", nil)

	ActiveChallenges[ChallengeId] = nil

	StealService:Cleanup(OwnerPlayer, StealingPlayer)

	self.Client.StealChallenge:Fire(OwnerPlayer, "ChallengeFinished")
	self.Client.StealChallenge:Fire(StealingPlayer, "ChallengeFinished")
end

function StealChallengeService:HandleRobuxRejection(player: Player)
	local ChallengeId = player:GetAttribute("ChallengeId")
	if not ChallengeId or not ActiveChallenges[ChallengeId] then
		return warn("ChallengeID not Found")
	end

	if not (ActiveChallenges[ChallengeId].OwnerUserId == player.UserId) then
		return warn("Not Rejected By Owner")
	end

	if ActiveChallenges[ChallengeId].State ~= "Pending" then
		return warn("Challenge Already Started")
	end

	local StealingPlayer = Players:GetPlayerByUserId(ActiveChallenges[ChallengeId].StealerUserId)
	local OwnerPlayer = Players:GetPlayerByUserId(ActiveChallenges[ChallengeId].OwnerUserId)

	local EntityPrice = ActiveChallenges[ChallengeId].StealPoints
	DataHandlerService:DeductPoints(StealingPlayer, EntityPrice)

	self.Client.StealChallenge:Fire(StealingPlayer, "RobuxRejection")
	self.Client.StealChallenge:Fire(OwnerPlayer, "RobuxRejection")
	self:FinishChallenge(ChallengeId)
end

function StealChallengeService:HandlePointsRejection(player: Player)
	local ChallengeId = player:GetAttribute("ChallengeId")
	if not ChallengeId or not ActiveChallenges[ChallengeId] then
		return warn("ChallengeID not Found")
	end

	if not (ActiveChallenges[ChallengeId].OwnerUserId == player.UserId) then
		return warn("Not Rejected By Owner")
	end

	if ActiveChallenges[ChallengeId].State ~= "Pending" then
		return warn("Challenge Already Started")
	end

	local EntityPrice = ActiveChallenges[ChallengeId].StealPoints

	if not EntityPrice then
		return warn("EntityPrice Not Found")
	end

	if not DataHandlerService:DeductPoints(player, EntityPrice) then
		return warn("Not Enough Points")
	end

	local StealingPlayer = Players:GetPlayerByUserId(ActiveChallenges[ChallengeId].StealerUserId)
	DataHandlerService:DeductPoints(StealingPlayer, EntityPrice)

	self.Client.StealChallenge:Fire(StealingPlayer, "PointsRejection")

	self:FinishChallenge(ChallengeId)
end

function StealChallengeService:StartTimer(ChallengeId: string)
	task.spawn(function()
		while ActiveChallenges[ChallengeId] and ActiveChallenges[ChallengeId].TimeLeft >= 1 do
			ActiveChallenges[ChallengeId].TimeLeft -= 1
			print("ChallengeTimeLeftServer", ActiveChallenges[ChallengeId].TimeLeft)
			task.wait(1)
		end

		self:StartChallenge(ChallengeId)
	end)
end

function StealChallengeService:TryStartChallenge(player: Player, ChallengeData: {})
	local ValidChallenge, Message = IsChallengeValid(ChallengeData)

	if ValidChallenge then
		local ChallengeId = Get_Guid()

		local OwnerPlayer = Players:GetPlayerByUserId(ChallengeData.OwnerUserId)
		local StealingPlayer = Players:GetPlayerByUserId(ChallengeData.StealerUserId)

		OwnerPlayer:SetAttribute("ChallengeId", ChallengeId)
		StealingPlayer:SetAttribute("ChallengeId", ChallengeId)
		OwnerPlayer:SetAttribute("InMiniGame", true)
		StealingPlayer:SetAttribute("InMiniGame", true)

		local EntityInfo = EntitiesConfiguration[ChallengeData.EntityRarity][ChallengeData.EntityName]
		local StealPoints = StealConfiguration[ChallengeData.EntityRarity].StealPoints

		ActiveChallenges[ChallengeId] = {
			OwnerUserId = ChallengeData.OwnerUserId,
			StealerUserId = ChallengeData.StealerUserId,
			EntityName = ChallengeData.EntityName,
			EntityRarity = ChallengeData.EntityRarity,
			EntityInfo = EntityInfo,
			StealPoints = StealPoints,
			TimeLeft = ChallengeTime,
			State = "Pending",
		}

		local TimeRemaining = (workspace:GetServerTimeNow() + ActiveChallenges[ChallengeId].TimeLeft)
		self.Client.StealChallenge:Fire(
			OwnerPlayer,
			"ChallengeReceived",
			StealingPlayer.Name,
			TimeRemaining,
			ChallengeData
		)
		self.Client.StealChallenge:Fire(StealingPlayer, "ChallengeSent", OwnerPlayer.Name, TimeRemaining, ChallengeData)

		self:StartTimer(ChallengeId)
	else
		self.Client.StealChallenge:Fire(player, "ChallengeRevoked", Message)
	end
end

function StealChallengeService:StartChallenge(ChallengeId: string)
	local Challenge = ActiveChallenges[ChallengeId]
	if not Challenge or Challenge.State ~= "Pending" or Challenge.State == "Finished" then
		return
	end

	ActiveChallenges[ChallengeId].State = "Started"

	local OwnerPlayer = Players:GetPlayerByUserId(ActiveChallenges[ChallengeId].OwnerUserId)
	local StealingPlayer = Players:GetPlayerByUserId(ActiveChallenges[ChallengeId].StealerUserId)

	local EntityPrice = ActiveChallenges[ChallengeId].StealPoints
	DataHandlerService:DeductPoints(StealingPlayer, EntityPrice)

	self.Client.StealChallenge:Fire(OwnerPlayer, "ChallengeStarted")
	self.Client.StealChallenge:Fire(StealingPlayer, "ChallengeStarted")

	local ChallengeGameData: {} = {
		Player1 = OwnerPlayer,
		Player2 = StealingPlayer,
		ChallengeGameId = ChallengeId,
	}
	MiniGameService:InitializeChallengeGame(ChallengeGameData)
end

function StealChallengeService:HandleStates(player: Player, State: string, ChallengeData: {})
	if State == "Challenge" then
		self:TryStartChallenge(player, ChallengeData)
	elseif State == "PointsRejection" then
		self:HandlePointsRejection(player)
	end
end

function StealChallengeService:KnitInit()
	DataHandlerService = Knit.GetService("DataHandlerService")
	StealService = Knit.GetService("StealService")
	MiniGameService = Knit.GetService("MiniGameService")
end

function StealChallengeService:KnitStart()
	-- print("StealChallengeService Started")
	self.Client.StealChallenge:Connect(function(player: Player, State: string, ChallengeData: {})
		self:HandleStates(player, State, ChallengeData)
	end)

	self.Client.AcceptChallengeButtonEvent:Connect(function(_player: Player, ChallengeData: {})
		local OwnerPlayer = Players:GetPlayerByUserId(ChallengeData.OwnerUserId)
		local ChallengeId = OwnerPlayer:GetAttribute("ChallengeId")

		self:StartChallenge(ChallengeId)
	end)

	Players.PlayerRemoving:Connect(PlayerRemoved)
end

return StealChallengeService
