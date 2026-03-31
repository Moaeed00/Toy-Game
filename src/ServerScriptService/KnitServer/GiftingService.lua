local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local GiftingConfig = require(ReplicatedStorage.Configuration.GiftingConfig)
local getBiomeByEntity = require(ReplicatedStorage.Shared.Utils.getBiomeByEntity)

local GiftingService = Knit.CreateService({
	Name = "GiftingService",
	Client = {
		ShowGiftUI    = Knit.CreateSignal(),
		ShowWaitingUI = Knit.CreateSignal(),
		HideGiftUI    = Knit.CreateSignal(),
		HideWaitingUI = Knit.CreateSignal(),
		GiftRejected  = Knit.CreateSignal(),
		GiftAccepted  = Knit.CreateSignal(),
		InventoryFull = Knit.CreateSignal(),

		RequestGiftToPlayer = function() end,
		RespondToGift       = function() end,
		CancelGiftRequest   = function() end,
	},
})

local activeGiftRequests: {[number]: {
	receiver:    Player,
	brainrotTool: Tool,
	timestamp:   number,
}} = {}
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

	local function scan(container: Instance?)
		if not container then
			return
		end
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
		receiver     = receiver,
		brainrotTool = brainrotTool,
		timestamp    = os.clock(),
	}

	self.Client.ShowGiftUI:Fire(receiver, gifter)
	self.Client.ShowWaitingUI:Fire(gifter, receiver)

	-- BUG FIX 3: capture UserId, not the Player object, so the
	-- closure doesn't hold a stale reference after the player leaves.
	local gifterUserId = gifter.UserId

	task.delay(GiftingConfig.GIFT_REQUEST_TIMEOUT, function()
		-- request may already be resolved; _cancelByUserId returns early if so
		self:_cancelGiftRequestByUserId(gifterUserId)
	end)
end

--------------------------------------------------
-- Cancel request (by Player)
--------------------------------------------------
function GiftingService:_cancelGiftRequest(gifter: Player)
	self:_cancelGiftRequestByUserId(gifter.UserId)
end

--------------------------------------------------
-- Cancel request (by UserId) — safe after player leaves
--------------------------------------------------
function GiftingService:_cancelGiftRequestByUserId(gifterUserId: number)
	local request = activeGiftRequests[gifterUserId]
	if not request then
		return
	end

	-- Only fire signals if the players are still in the game
	local receiver = request.receiver
	if receiver and receiver.Parent then
		self.Client.HideGiftUI:Fire(receiver)
	end

	local gifter = Players:GetPlayerByUserId(gifterUserId)
	if gifter then
		self.Client.HideWaitingUI:Fire(gifter)
	end

	activeGiftRequests[gifterUserId] = nil
end

--------------------------------------------------
-- Handle gift response
--------------------------------------------------
function GiftingService:_handleGiftResponse(receiver: Player, accepted: boolean)
	local gifterUserId: number?
	local request

	for userId, req in pairs(activeGiftRequests) do
		if req.receiver == receiver then
			gifterUserId = userId
			request = req
			break
		end
	end

	if not request or not gifterUserId then
		return
	end

	local gifter = Players:GetPlayerByUserId(gifterUserId)
	if not gifter then
		-- BUG FIX 2a: gifter already left — clean up and bail
		activeGiftRequests[gifterUserId] = nil
		self.Client.HideGiftUI:Fire(receiver)
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

	local entityName = brainrotTool:GetAttribute("EntityName") or brainrotTool.Name
	local mutation   = brainrotTool:GetAttribute("Mutation")
	local entityId   = brainrotTool:GetAttribute("Id")

	-- BUG FIX 1: guard against entity not found in config
	local biomeName = getBiomeByEntity(entityName)
	if not biomeName then
		warn("[GiftingService] Entity not found in config:", entityName)
		activeGiftRequests[gifterUserId] = nil
		return
	end

	BaseService:ReleaseTool(gifter, entityId)
	brainrotTool:Destroy()
	BaseService:GiveTool(receiver, biomeName, entityName, mutation)

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

	-- BUG FIX 2b: clean up any active requests when a player leaves
	Players.PlayerRemoving:Connect(function(player)
		-- If the leaving player was a gifter, cancel their outgoing request
		self:_cancelGiftRequestByUserId(player.UserId)

		-- If the leaving player was a pending receiver, cancel that request too
		for gifterUserId, request in pairs(activeGiftRequests) do
			if request.receiver == player then
				local gifter = Players:GetPlayerByUserId(gifterUserId)
				if gifter then
					self.Client.HideWaitingUI:Fire(gifter)
				end
				activeGiftRequests[gifterUserId] = nil
				break
			end
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:_setupPlayer(player)
	end
end

function GiftingService:KnitStart()
	BaseService = Knit.GetService("BaseService")
end

return GiftingService