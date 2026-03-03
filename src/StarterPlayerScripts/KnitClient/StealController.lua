--[Services]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

--[Modulles]
local Configuration = ReplicatedStorage:WaitForChild("Configuration")
local StealConfiguration = require(Configuration:WaitForChild("StealConfiguration"))

--[Player]
local player: Player = Players.LocalPlayer

local Trove = require(ReplicatedStorage.Packages.Trove)
Trove = Trove.new()

--[UI's]
local PlayerGui: PlayerGui = player:WaitForChild("PlayerGui")
local StealGUi: ScreenGui = PlayerGui:WaitForChild("StealGUi")
local Main: Frame = StealGUi:WaitForChild("Main")
local Message: TextLabel = Main:WaitForChild("Message")
local ChallengeButton: TextButton = Main:WaitForChild("Challenge")
local RobuxButton: TextButton = Main:WaitForChild("Robux")
local CloseButton: TextButton = Main:WaitForChild("Close")

--[Variables]
local ProductPurchaseService
local StealService
local StealChallengeService
local StealData
local BiomeData
local processed

local StealController = Knit.CreateController({
	Name = "StealController",
})

function StealController:getOwnerPlayer(userId)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		return player
	else
		print("Player with UserId " .. userId .. " is not currently in the game.")
	end
end

function StealController:CleanUp()
	processed = false
	StealData = nil
	BiomeData = nil
end

function StealController:DisableUI()
	StealGUi.Enabled = false
end

function StealController:EnableUI(
	biomeName: string,
	entityName: string,
	mutationName: string,
	entityId: string,
	ownerId: number,
	slotName: number
)
	if processed then
		return
	end

	if player:GetAttribute("InMiniGame") then
		--Prompt Notification
		print("Player Already In A Challenge")
		return
	end

	processed = true

	StealData = {
		biomeName = biomeName,
		entityName = entityName,
		mutationName = mutationName,
		entityId = entityId,
		ownerId = ownerId,
		slotName = slotName,
	}

	Message.Text = `Choose any one below option to steal {entityName}`

	BiomeData = StealConfiguration[biomeName]
	local RobuxPrice = BiomeData.Price
	RobuxButton.Text = `{RobuxPrice} Robux`

	local ChallengePoints = BiomeData.StealPoints
	ChallengeButton.Text = `Challenge with {ChallengePoints} Points`

	StealGUi.Enabled = true
end

function StealController:HandleChallengeButton()
	local ownerPlayer = self:getOwnerPlayer(StealData.ownerId)
	if ownerPlayer and ownerPlayer:GetAttribute("InMiniGame") then
		--Prompt Notification
		print("Player Already In A Challenge")
		return
	end

	local PlayerPoints: IntValue = player:WaitForChild("leaderstats"):WaitForChild("Points")
	if not PlayerPoints then
		return
	end

	if PlayerPoints.Value < BiomeData.StealPoints then
		--Prompt Notification
		print("Points Not Enough")
		return
	end

	StealService.Steal:Fire(
		StealData.biomeName,
		StealData.entityName,
		StealData.mutationName,
		StealData.entityId,
		StealData.ownerId,
		true,
		StealData.slotName
	)
	self:DisableUI()

	local ChallengeData = {
		OwnerUserId = tonumber(StealData.ownerId),
		StealerUserId = player.UserId,
		EntityName = StealData.entityName,
		EntityRarity = StealData.biomeName,
	}
	StealChallengeService.StealChallenge:Fire("Challenge", ChallengeData)
end

function StealController:HandleRobuxButton()
	local ownerPlayer = self:getOwnerPlayer(StealData.ownerId)
	if not ownerPlayer then
		--Prompt Notification
		print("Player Left")
		return
	end

	local Success, IsChallenged = StealService:IsEntityChallenged(StealData.entityId):await()
	if not Success or IsChallenged then
		print("This Brainrot is Challenged")
		return
	end

	StealService.Steal:Fire(
		StealData.biomeName,
		StealData.entityName,
		StealData.mutationName,
		StealData.entityId,
		StealData.ownerId
	)
	self:DisableUI()

	local productId = StealConfiguration[StealData.biomeName].UnlockID
	if not productId then
		return
	end

	ProductPurchaseService.PromptPurchase:Fire(productId)
	self:CleanUp()
end

function StealController:HandleStates(State: string)
	if State == "OwnerLeaves" then
		self:DisableUI()
		self:CleanUp()
	elseif State == "CleanUp" then
		self:CleanUp()
	end
end

function StealController:KnitInit()
	StealService = Knit.GetService("StealService")
	ProductPurchaseService = Knit.GetService("ProductPurchaseService")
	StealChallengeService = Knit.GetService("StealChallengeService")
end

function StealController:KnitStart()
	ChallengeButton.Activated:Connect(function()
		self:HandleChallengeButton()
	end)

	RobuxButton.Activated:Connect(function()
		self:HandleRobuxButton()
	end)

	CloseButton.Activated:Connect(function()
		self:DisableUI()
		self:CleanUp()
	end)

	StealService.Steal:Connect(function(State: string)
		self:HandleStates(State)
	end)

	Players.PlayerRemoving:Connect(function(Player)
		if StealData and (Player.UserId == tonumber(StealData.ownerId)) then
			self:DisableUI()
			self:CleanUp()
		end
	end)
end

return StealController
