--!strict
-- GiftingService.lua
-- Server side Brainrot gifting logic

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local GiftingConfig = require(ReplicatedStorage.Configuration.GiftingConfig)
local AttributesConfiguration = require(ReplicatedStorage.Configuration.AttributesConfiguration)
local getBiomeByEntity = require(ReplicatedStorage.Shared.Utils.getBiomeByEntity)

local GiftingService = Knit.CreateService({
	Name = "GiftingService",

	Client = {
		ShowGiftUI = Knit.CreateSignal(),
		ShowWaitingUI = Knit.CreateSignal(),
		HideGiftUI = Knit.CreateSignal(),
		HideWaitingUI = Knit.CreateSignal(),
		GiftRejected = Knit.CreateSignal(),
		GiftAccepted = Knit.CreateSignal(),
		InventoryFull = Knit.CreateSignal(),

		RequestGiftToPlayer = function() end,
		RespondToGift = function() end,
		CancelGiftRequest = function() end,
	},
})

local activeGiftRequests = {}

local BaseService

--------------------------------------------------
-- Helper: check if tool is Brainrot
--------------------------------------------------

local function isBrainrotTool(tool: Tool): boolean
	return tool:GetAttribute("Id") ~= nil
end

--------------------------------------------------
-- Helper: get equipped brainrot tool
--------------------------------------------------

local function getEquippedBrainrotTool(player: Player): Tool?
	local char = player.Character
	if not char then
		return nil
	end

	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("Tool") and isBrainrotTool(child) then
			return child
		end
	end

	return nil
end

--------------------------------------------------
-- Helper: count inventory
--------------------------------------------------

local function getBrainrotToolCount(player: Player): number

	local count = 0

	local function scan(container)

		if not container then return end

		for _, inst in ipairs(container:GetChildren()) do
			if inst:IsA("Tool") and isBrainrotTool(inst) then
				count += 1
			end
		end

	end

	scan(player:FindFirstChildOfClass("Backpack"))
	scan(player.Character)

	return count
end

--------------------------------------------------
-- Track Brainrot equipped state
--------------------------------------------------

local function updateBrainrotEquippedState(player: Player)

	local equipped = getEquippedBrainrotTool(player) ~= nil
	player:SetAttribute("IsBrainrotEquipped", equipped)

end

--------------------------------------------------
-- Setup player tool tracking
--------------------------------------------------

function GiftingService:_setupPlayer(player: Player)

	local function monitorCharacter(character: Model)

		updateBrainrotEquippedState(player)

		character.ChildAdded:Connect(function(child)

			if child:IsA("Tool") then
				task.defer(function()
					updateBrainrotEquippedState(player)
				end)
			end

		end)

		character.ChildRemoved:Connect(function(child)

			if child:IsA("Tool") then
				task.defer(function()
					updateBrainrotEquippedState(player)
				end)
			end

		end)

	end

	if player.Character then
		monitorCharacter(player.Character)
	end

	player.CharacterAdded:Connect(monitorCharacter)

end

--------------------------------------------------
-- Handle gift request
--------------------------------------------------

function GiftingService:_handleGiftRequest(gifter: Player, receiver: Player)

	if gifter == receiver then
		return
	end

	local brainrotTool = getEquippedBrainrotTool(gifter)

	if not brainrotTool then
		return
	end

	if activeGiftRequests[gifter.UserId] then
		return
	end

	activeGiftRequests[gifter.UserId] = {
		receiver = receiver,
		brainrotTool = brainrotTool,
		timestamp = os.clock(),
	}

	self.Client.ShowGiftUI:Fire(receiver, gifter)
	self.Client.ShowWaitingUI:Fire(gifter, receiver)

	task.delay(GiftingConfig.GIFT_REQUEST_TIMEOUT, function()

		self:_cancelGiftRequest(gifter)

	end)

end

--------------------------------------------------
-- Cancel request
--------------------------------------------------

function GiftingService:_cancelGiftRequest(gifter: Player)

	local request = activeGiftRequests[gifter.UserId]
	if not request then return end

	self.Client.HideGiftUI:Fire(request.receiver)
	self.Client.HideWaitingUI:Fire(gifter)

	activeGiftRequests[gifter.UserId] = nil

end

--------------------------------------------------
-- Handle gift response
--------------------------------------------------

function GiftingService:_handleGiftResponse(receiver: Player, accepted: boolean)

	local gifterUserId
	local request

	for userId, req in pairs(activeGiftRequests) do
		if req.receiver == receiver then
			gifterUserId = userId
			request = req
			break
		end
	end

	if not request then
		return
	end

	local gifter = Players:GetPlayerByUserId(gifterUserId)
	if not gifter then
		activeGiftRequests[gifterUserId] = nil
		return
	end

	if not accepted then

		self.Client.GiftRejected:Fire(gifter, receiver.Name)
		self.Client.HideGiftUI:Fire(receiver)

		activeGiftRequests[gifterUserId] = nil
		return

	end

	if getBrainrotToolCount(receiver) >= GiftingConfig.MAX_BRAINROT_INVENTORY then
		self.Client.InventoryFull:Fire(receiver)
		return
	end

	local brainrotTool = request.brainrotTool

	if not brainrotTool or not brainrotTool.Parent then
		activeGiftRequests[gifterUserId] = nil
		return
	end

	local entity = brainrotTool:GetAttribute("EntityName") or brainrotTool.Name
	local biome = getBiomeByEntity(entity)
	local mutation = brainrotTool:GetAttribute("Mutation")
	local entityId = brainrotTool:GetAttribute("Id")

	BaseService:ReleaseTool(gifter, entityId)

	brainrotTool:Destroy()

	BaseService:GiveTool(receiver, biome, entity, mutation)

	self.Client.GiftAccepted:Fire(gifter, receiver.Name)
	self.Client.HideGiftUI:Fire(receiver)

	activeGiftRequests[gifterUserId] = nil

end

--------------------------------------------------
-- Client remotes
--------------------------------------------------

function GiftingService.Client:RequestGiftToPlayer(player: Player, target: Player)

	self.Server:_handleGiftRequest(player, target)

end

function GiftingService.Client:RespondToGift(player: Player, accepted: boolean)

	self.Server:_handleGiftResponse(player, accepted)

end

function GiftingService.Client:CancelGiftRequest(player: Player)

	self.Server:_cancelGiftRequest(player)

end

--------------------------------------------------
-- Knit lifecycle
--------------------------------------------------

function GiftingService:KnitInit()

	Players.PlayerAdded:Connect(function(player)
		self:_setupPlayer(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:_setupPlayer(player)
	end

end

function GiftingService:KnitStart()

	BaseService = Knit.GetService("BaseService")

end

return GiftingService