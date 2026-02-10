local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ScoringHelperServer = require(script:WaitForChild("ScoringHelperServer"))

local Assets = ReplicatedStorage:WaitForChild("Assets")
local FootBalls = Assets:WaitForChild("FootBalls")
local Toys = workspace:WaitForChild("Toys")

local RoundTime = 20
local KickResetTime = 3

local ProximityPrompts = {}
local Slots = {}
local ClonedFootBalls = {}
local BallSpawnReferences = {}
local ActiveGames = {}

local MiniGameService = Knit.CreateService({
	Name = "MiniGameService",
	Client = {
		MiniGame = Knit.CreateSignal(),
		EndMiniGame = Knit.CreateSignal(),
	},
})

function PlayerRemoved(player)
	if not ActiveGames[player.UserId] then
		return
	end
	MiniGameService:EndMiniGame(player)
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
		FootBall.CFrame = BallSpawnReference.CFrame
	end
end

function MiniGameService:SpawnBall(player, SlotName, BallName)
	if not BallName then
		BallName = "Default"
	end

	local Football = FootBalls:FindFirstChild(BallName)
	if not Football then
		return warn("Football Not Found")
	end

	local BallSpawnReference = Toys:WaitForChild(SlotName):WaitForChild("BallSpawnReference")
	BallSpawnReferences[player] = BallSpawnReference

	local ClonedFootball = Football:Clone()
	ClonedFootball.Name = player.Name .. "_FootBall"
	ClonedFootball.Parent = workspace
	ClonedFootBalls[player] = ClonedFootball

	self:ResetBall(player)

	ClonedFootball:SetNetworkOwner(player)

	return true
end

function MiniGameService:ReleaseSlot(player)
	local SlotName = player:GetAttribute("MiniGameSlot")
	if not SlotName then
		return warn("Slot Name Not Found")
	end

	Slots[SlotName] = false
	player:SetAttribute("MiniGameSlot", nil)

	local Prompt = ProximityPrompts[SlotName]
	Prompt.Enabled = true
end

function MiniGameService:SetSlot(player, SlotName)
	if Slots[SlotName] then
		return warn(`{SlotName} Slot is Already Assigned`)
	end

	Slots[SlotName] = true
	player:SetAttribute("MiniGameSlot", SlotName)
	return true
end

function MiniGameService:StartTimer(player)
	local GameData = ActiveGames[player.UserId]
	if not GameData then
		return
	end

	task.spawn(function()
		while GameData.TimeLeft >= 0 and GameData.Running do
			print("TimeLeftServer", GameData.TimeLeft)
			task.wait(1)
			GameData.TimeLeft -= 1
		end
		self:EndMiniGame(player)
	end)
end

function MiniGameService:EndMiniGame(player)
	if not ActiveGames[player.UserId] then
		return
	end

	self.Client.EndMiniGame:Fire(player)

	ActiveGames[player.UserId].Running = false
	ActiveGames[player.UserId] = nil

	ScoringHelperServer:CleanUp(player)

	self:DestroyBall(player)

	player:SetAttribute("BallKicked", nil)
	player:SetAttribute("HasScored", nil)

	self:ReleaseSlot(player)
end

function MiniGameService:InitializeMiniGame(player, SlotName)
	local SlotAssigned = self:SetSlot(player, SlotName)
	if not SlotAssigned then
		return warn("Slot Not Assigned")
	end

	local BallSpawned = self:SpawnBall(player, SlotName)
	if not BallSpawned then
		return warn("FootBall Not Assigned")
	end

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

	ScoringHelperServer:OnStartScoring(player)
	self:StartTimer(player)

	local RemainingTime = (workspace:GetServerTimeNow() + ActiveGames[player.UserId].TimeLeft)
	self.Client.MiniGame:Fire(player, "StartMiniGame", RemainingTime)
end

function MiniGameService:OnBallKicked(player)
	local BallKicked = player:GetAttribute("BallKicked")
	if BallKicked then
		return warn("Ball Already Kicked")
	end

	player:SetAttribute("BallKicked", true)
	player:SetAttribute("HasScored", false)

	task.delay(KickResetTime, function()
		if not ActiveGames[player.UserId] then
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

function MiniGameService:HandleStates(player, State, SlotName)
	if State == "InitializeMiniGame" then
		self:InitializeMiniGame(player, SlotName)
	elseif State == "StartMiniGame" then
		self:StartMiniGame(player)
	elseif State == "BallKicked" then
		self:OnBallKicked(player)
	end
end

function MiniGameService:KnitInit() end

function MiniGameService:KnitStart()
	print("MiniGameService Started")
	for _, ProximityPrompt: ProximityPrompt in Toys:GetDescendants() do
		if ProximityPrompt.Name == "MiniGamePrompt" and ProximityPrompt:IsA("ProximityPrompt") then
			ProximityPrompt.Enabled = true

			ProximityPrompt.Triggered:Connect(function(player)
				ProximityPrompt.Enabled = false
				self:HandleStates(player, "InitializeMiniGame", ProximityPrompt.Parent.Parent.Name)
			end)

			ProximityPrompts[ProximityPrompt.Parent.Parent.Name] = ProximityPrompt
		end
	end

	self.Client.MiniGame:Connect(function(player, State)
		self:HandleStates(player, State)
	end)

	Players.PlayerRemoving:Connect(PlayerRemoved)
end

return MiniGameService
